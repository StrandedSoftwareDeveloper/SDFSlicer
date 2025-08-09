const std = @import("std");
const vec = @import("vector.zig");

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
    try toolpath.append(.{.is_travel = false, .pos = .{.x = 10.0, .y = 0.0, .z = 0.0}});
    try toolpath.append(.{.is_travel = true, .pos = .{.x = 0.0, .y = 10.0, .z = 0.0}});
    try toolpath.append(.{.is_travel = false, .pos = .{.x = 0.0, .y = 20.0, .z = 0.0}});

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    try toolpathToGcode(toolpath, stdout);

    try bw.flush();
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
