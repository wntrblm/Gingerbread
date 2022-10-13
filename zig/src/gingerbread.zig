const std = @import("std");
const print = std.debug.print;
const testing = std.testing;
const potrace = @import("potrace.zig");
const geometry = @import("geometry.zig");
const Point = geometry.Point;
const Poly = geometry.Poly;
const PolyList = geometry.PolyList;
const pcb = @import("pcb.zig");

const allocator = std.heap.c_allocator;

// https://github.com/mbrock/wisp/blob/master/core/wasm.zig#L349
export fn z_allocate(n: u32) u32 {
    const buf = allocator.alloc(u8, n) catch return 0;
    print("allocated {d} bytes @ {d}\n", .{ n, @ptrToInt(buf.ptr) });
    return @ptrToInt(buf.ptr);
}

export fn z_free_zero(x: [*:0]u8) void {
    allocator.free(std.mem.span(x));
}

export fn z_free(x: [*]u8, n: usize) void {
    allocator.free(x[0..n]);
}

export fn print_memory(a: [*]u8, n: u32) void {
    const span = std.mem.span(a[0..n]);
    print("{*}: {any}\n", .{ a, span });
}

fn _trace(layer_name: []const u8, image_pixels: [*]u8, image_width: u32, image_height: u32, writer: anytype) !void {
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

        var fractured = try poly.fracture(allocator);

        poly.deinit();
        poly.* = fractured;
    }

    print("Polylist fractured\n", .{});

    try pcb.polylist_to_footprint(polylist, layer_name, writer);
}

fn return_string(str: []u8) u32 {
    var result: []u32 = allocator.alloc(u32, 2) catch return 0;
    result[0] = @ptrToInt(str.ptr);
    result[1] = str.len;
    return @ptrToInt(result.ptr);
}

var conversion_buffer: ?std.ArrayList(u8) = null;

fn _conversion_start() !void {
    if (conversion_buffer) |*buf| {
        buf.clearAndFree();
    }

    conversion_buffer = std.ArrayList(u8).init(allocator);

    try pcb.start_pcb(conversion_buffer.?.writer());
}

export fn conversion_start() void {
    _conversion_start() catch @panic("Memory error.");
}

fn _conversion_add(layer: u32, image_pixels: [*]u8, image_width: u32, image_height: u32) !void {
    const layer_name = switch (layer) {
        1 => "F.Cu",
        2 => "B.Cu",
        3 => "F.SilkS",
        4 => "B.SilkS",
        5 => "F.Mask",
        6 => "B.Mask",
        else => "Unknown",
    };

    try _trace(layer_name, image_pixels, image_width, image_height, conversion_buffer.?.writer());
}

export fn conversion_add(layer: u32, image_pixels: [*]u8, image_width: u32, image_height: u32) void {
    _conversion_add(layer, image_pixels, image_width, image_height) catch @panic("Memory error.");
}

fn _conversion_finish() !u32 {
    try pcb.end_pcb(&conversion_buffer.?.writer());
    return return_string(conversion_buffer.?.toOwnedSlice());
}

export fn conversion_finish() u32 {
    return _conversion_finish() catch @panic("Memory error!");
}
