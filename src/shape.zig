const std = @import("std");
const vec = @import("vector.zig");

pub fn inShape(p: vec.Vector3f) bool {
    dist = sphereSDF(p, 1.0);
    return dist < 0.0;
}

fn sphereSDF(p: vec.Vector3f, r: f32) f32 {
    return p.length() - r;
}