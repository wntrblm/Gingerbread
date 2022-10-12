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

test {
    _ = potrace;
    _ = bezier;
    _ = clipper;
    _ = geometry;
}


test "complete trace" {
    const a = std.testing.allocator;
    var bitmap = try potrace.load_example_bitmap(a);
    defer bitmap.deinit();

    var trace = try bitmap.trace();
    defer trace.deinit();

    var polylist = try trace.to_polylist(a, 1);
    defer polylist.deinit();

    print("\nPotrace result:\n{?}", .{polylist});

    print("\n\n", .{});

    for (polylist.items) |*poly, i| {
        _ = i;
        try poly.simplify();

        var fractured = try poly.fracture(a);

        poly.svg_path();

        poly.deinit();
        poly.* = fractured;
    }

    const footprint = try pcb.polylist_to_footprint(a, polylist);
    defer a.free(footprint);

    print("{s}", .{footprint});

    print("\n\n", .{});
}
