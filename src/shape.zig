//All SDFs adapted from https://iquilezles.org/articles/distfunctions/ by Inigo Quilez under the MIT license
const std = @import("std");
const vec = @import("vector.zig");

pub fn inShape(p: vec.Vector3f) bool {
    const dist: f32 = boxSDF(p, .{.x = 10.0, .y = 10.0, .z = 10.0});
    return dist < 0.0;
}

fn sphereSDF(p: vec.Vector3f, s: f32) f32 {
    return p.length()-s;
}

fn boxSDF(p: vec.Vector3f, b: vec.Vector3f) f32 {
    const q: vec.Vector3f = p.abs().sub(b);
    return vec.Vector3f.length(q.max(.{.x = 0.0, .y = 0.0, .z = 0.0})) + @min(@max(q.x,@max(q.y,q.z)),0.0);
}