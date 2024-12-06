const std = @import("std");
const print = std.debug.print;
const testing = std.testing;
const potrace = @import("potrace.zig");
const geometry = @import("geometry.zig");
const Point = geometry.Point;
const Poly = geometry.Poly;
const PolyList = geometry.PolyList;
const pcb = @import("pcb.zig");
const wasm = @import("wasm.zig");

const a = wasm.allocator;

fn trace(allocator: std.mem.Allocator, layer_name: []const u8, scale_factor: f64, image_pixels: [*]u8, image_width: usize, image_height: usize, writer: anytype) !void {
    var bitmap = try potrace.Bitmap.from_image(allocator, .{
        .pixels = image_pixels,
        .w = image_width,
        .h = image_height,
        .channels = 4,
    });
    defer bitmap.deinit();

    var result = try bitmap.trace();
    defer result.deinit();

    var polylist = try result.to_polylist(allocator, 1);
    defer polylist.deinit();

    print("Trace complete, polylist len: {d}\n", .{polylist.items.len});

    for (polylist.items) |*poly| {
        try poly.simplify();

        const fractured = try poly.fracture(allocator);

        poly.deinit();
        poly.* = fractured;
    }

    print("Polylist fractured\n", .{});

    try pcb.polylist_to_footprint(polylist, layer_name, scale_factor, writer);
}

test "trace" {
    const al = std.testing.allocator;
    const img = try potrace.load_example_image();
    defer potrace.free_example_image(img);

    var buf = std.ArrayList(u8).init(al);

    try trace(al, "F.SilkS", 1, img.pixels, img.w, img.h, buf.writer());

    print("Trace result: {s}", .{buf.items});

    try testing.expect(buf.items.len > 300);

    print("\n\n", .{});
}

var conversion_buffer: ?std.ArrayList(u8) = null;

export fn conversion_start() void {
    if (conversion_buffer) |*buf| {
        buf.clearAndFree();
    }

    conversion_buffer = std.ArrayList(u8).init(a);

    pcb.start_pcb(conversion_buffer.?.writer()) catch @panic("memory");
}

export fn conversion_add_raster_layer(layer: u32, scale_factor: f64, image_pixels: [*]u8, image_width: u32, image_height: u32) void {
    const layer_name = switch (layer) {
        1 => "F.Cu",
        2 => "B.Cu",
        3 => "F.SilkS",
        4 => "B.SilkS",
        5 => "F.Mask",
        6 => "B.Mask",
        else => "Unknown",
    };

    trace(a, layer_name, scale_factor, image_pixels, image_width, image_height, conversion_buffer.?.writer()) catch @panic("memory");
}

export fn conversion_start_poly() void {
    pcb.start_xx_poly("gr", conversion_buffer.?.writer()) catch @panic("memory");
}

export fn conversion_add_poly_point(
    x: f64,
    y: f64,
    layer_number: u32,
    scale_factor: f64,
) void {
    const layer_name = switch (layer_number) {
        1 => "F.Cu",
        2 => "B.Cu",
        3 => "F.SilkS",
        4 => "B.SilkS",
        5 => "F.Mask",
        6 => "B.Mask",
        else => "Unknown",
    };

    pcb.add_xx_poly_point(.{ .x = x, .y = y }, layer_name, scale_factor, conversion_buffer.?.writer()) catch @panic("memory");
}

export fn conversion_end_poly(layer: u32, width: f32, fill: bool) void {
    const layer_name = switch (layer) {
        7 => "Edge.Cuts",
        else => "Unknown",
    };

    print("layer number: {d}, layer name: {s}\n", .{ layer, layer_name });

    pcb.end_xx_poly(layer_name, width, fill, conversion_buffer.?.writer()) catch @panic("memory");
}

export fn conversion_add_drill(x: f64, y: f64, d: f64, scale_factor: f64) void {
    pcb.add_drill(x, y, d, scale_factor, conversion_buffer.?.writer()) catch @panic("memory");
}

export fn conversion_finish() wasm.StringResult {
    pcb.end_pcb(&conversion_buffer.?.writer()) catch @panic("memory");
    return wasm.return_string(conversion_buffer.?.toOwnedSlice() catch @panic("memory"));
}

export fn set_mirror_back_layers(val: bool) void {
    pcb.mirror_back_layers = val;
}
