const std = @import("std");
const vec = @import("vector.zig");
const inShape = @import("shape.zig").inShape;

const EXTRUSION_FACTOR: f32 = 1.0; //Note: Extrusion factor is measured in mm of extrusion per mm traveled

const ToolpathEntry = struct {
    pos: vec.Vector3f,
    is_travel: bool,
};

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator: std.mem.Allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var toolpath: std.ArrayList(ToolpathEntry) = std.ArrayList(ToolpathEntry).init(allocator);
    defer toolpath.deinit();
    
    try toolpath.append(.{.is_travel = true, .pos = .{.x = 0.0, .y = 0.0, .z = 0.0}});
    
    try tracePerimeter(&toolpath);

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    try writeTemplateGcode("start.gcode", stdout);
    try toolpathToGcode(toolpath, stdout);
    try writeTemplateGcode("end.gcode", stdout);

    try bw.flush();
}

fn tracePerimeter(toolpath: *std.ArrayList(ToolpathEntry)) !void {
    const start_point: vec.Vector2f = findSurface();
    try toolpath.append(.{.is_travel = true, .pos = .{.x = start_point.x, .y = start_point.y, .z = 0.0}});
    
    var pos: vec.Vector2f = start_point;
    var prev_pos: vec.Vector2f = pos;
    var facing: vec.Vector2f = .{.x = 0.0, .y = -0.5};
    for (0..160) |i| {
        _ = i;
        
        while (true) {
            const facing_perp: vec.Vector2f = vec.Vector2f.rotate(.{ .x = facing.x, .y = facing.y }, std.math.pi * 0.5);  //Perpendicular (90 degrees CCW) to `facing`
            //const facing_perp: vec.Vector2f = .{.x = facing_perp_2d.x, .y = facing_perp_2d.y};
            
            const left_pos: vec.Vector2f = pos.add(facing).add(facing_perp);
            const right_pos: vec.Vector2f = pos.add(facing).sub(facing_perp);
            
            const left: bool = inShape(.{.x = left_pos.x, .y = left_pos.y, .z = 0.0});
            const right: bool = inShape(.{.x = right_pos.x, .y = right_pos.y, .z = 0.0});
            
            //std.debug.print("pos:         {d:.2} {d:.2}\n", .{pos.x, pos.y});
            //std.debug.print("facing:      {d:.2} {d:.2}\n", .{facing.x, facing.y});
            //std.debug.print("facing_perp: {d:.2} {d:.2}\n", .{facing_perp.x, facing_perp.y});
            //std.debug.print("{} {}\n\n", .{left, right});
            
            if (!left and right) { //Tracking the edge, following CW
                prev_pos = pos;
                pos = findEdge(.{.x = left_pos.x, .y = left_pos.y, .z = 0.0}, .{.x = right_pos.x, .y = right_pos.y, .z = 0.0}).xy();
                facing = pos.sub(prev_pos).normalize().multScalar(0.5);
                break;
            } else if (!left and !right) { //Both are outside, turn right so we follow CW
                //std.debug.print("Turning right\n", .{});
                facing = facing.rotate(-0.1);
            }
        }
        
        try toolpath.append(.{.is_travel = false, .pos = .{.x = pos.x, .y = pos.y, .z = 0.0}});
        //try toolpath.append(.{.is_travel = true, .pos = .{.x = pos.x+facing.x, .y = pos.y+facing.y, .z = 0.0}});
        //try toolpath.append(.{.is_travel = true, .pos = .{.x = left_pos.x, .y = left_pos.y, .z = 0.0}});
        //try toolpath.append(.{.is_travel = true, .pos = .{.x = right_pos.x, .y = right_pos.y, .z = 0.0}});
    }
}

//Binary searches between `a` and `b` to find the edge of the shape
//Asserts that one is in the shape and the other isn't
fn findEdge(a: vec.Vector3f, b: vec.Vector3f) vec.Vector3f {
    var k: f32 = 0.5;
    var factor: f32 = 0.25;
    
    if (inShape(b)) {
        factor = -factor;
    }
    
    for (0..10) |i| {
        _ = i;
        const test_point: vec.Vector3f = vec.Vector3f.lerp(a, b, .{.x = k, .y = k, .z = k});
        
        if (inShape(test_point)) { //`a` is in the shape and we are too, so the edge must be closer to b
            k += factor;
        } else {
            k -= factor;
        }
        
        factor *= 0.5;
    }
    
    return vec.Vector3f.lerp(a, b, .{.x = k, .y = k, .z = k});
}

fn findSurface() vec.Vector2f {
    return .{.x = 10.0, .y = 0.0};
}

fn writeTemplateGcode(path: []const u8, writer: anytype) !void {
    const file: std.fs.File = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    
    var fifo = std.fifo.LinearFifo(u8, .{ .Static = 1024 * 4 }).init();
    try fifo.pump(file.reader(), writer);
}

fn toolpathToGcode(toolpath: std.ArrayList(ToolpathEntry), writer: anytype) !void {
    try writer.print("G90\nM83\n", .{}); //Absolute positioning, relative extrusion
    var lastPos: vec.Vector3f = vec.Vector3f.zero();
    for (0..toolpath.items.len) |i| {
        const pos: vec.Vector3f = toolpath.items[i].pos;
        if (toolpath.items[i].is_travel) {
            try writer.print("G0 X{d:.4} Y{d:.4} Z{d:.4}\n", .{pos.x, pos.y, pos.z});
        } else {
            try writer.print("G1 X{d:.4} Y{d:.4} Z{d:.4} E{d:.4} F1500\n", .{pos.x, pos.y, pos.z, lastPos.sub(pos).length() * EXTRUSION_FACTOR});
        }
        lastPos = pos;
    }
}
