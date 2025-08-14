//All SDFs adapted from https://iquilezles.org/articles/distfunctions/ by Inigo Quilez under the MIT license
const std = @import("std");
const vec = @import("vector.zig");

pub fn inShape(p: vec.Vector3f) bool {
    //const boxDist: f32 = boxSDF(p, .{.x = 10.0, .y = 5.0, .z = 5.0});
    //const boxDist2: f32 = boxSDF(p, .{.x = 5.0, .y = 10.0, .z = 5.0});
    //const sphereDist: f32 = sphereSDF(p, 10.0);
    //return @min(boxDist, boxDist2) < 0.0;
    return mandlebrot(p);
}

fn mandlebrot(p: vec.Vector3f) bool {
    const pos: vec.Vector2f = p.xy();
    const offset: vec.Vector2f = .{.x = 0.0, .y = 0.0};
    const zoom: f32 = 10.0;
    
    const x_input: std.math.Complex(f32) = std.math.Complex(f32).init(pos.x / zoom + offset.x, pos.y / zoom + offset.y);
    var result: std.math.Complex(f32) = x_input;
    const detail: usize = 12;
    for (0..detail) |i| {
        _ = i;
        result = result.mul(result).add(x_input);
    }
    const threshold: f32 = 110427941548649020598956093796432407239217743554726184882600387580788736.0;
    const inside: bool = result.magnitude() < threshold;
    
    return inside;
}

fn sphereSDF(p: vec.Vector3f, s: f32) f32 {
    return p.length()-s;
}

fn boxSDF(p: vec.Vector3f, b: vec.Vector3f) f32 {
    const q: vec.Vector3f = p.abs().sub(b);
    return vec.Vector3f.length(q.max(.{.x = 0.0, .y = 0.0, .z = 0.0})) + @min(@max(q.x,@max(q.y,q.z)),0.0);
}