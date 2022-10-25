const std = @import("std");
const print = std.debug.print;
const testing = std.testing;
const c = @import("cdefs.zig");
const potrace = @import("potrace.zig");
const bezier = @import("bezier.zig");
const clipper = @import("clipper.zig");
const geometry = @import("geometry.zig");
const Point = geometry.Point;
const Poly = geometry.Poly;
const PolyList = geometry.PolyList;
const pcb = @import("pcb.zig");
const gingerbread = @import("gingerbread.zig");

test {
    _ = potrace;
    _ = bezier;
    _ = clipper;
    _ = geometry;
    _ = gingerbread;
}
