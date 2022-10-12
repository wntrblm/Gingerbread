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
    print("allocated {d} bytes @ {d}\n", .{n, @ptrToInt(buf.ptr)});
    return @ptrToInt(buf.ptr);
}

export fn z_free_zero(x: [*:0]u8) void {
    allocator.free(std.mem.span(x));
}

export fn z_free(x: [*]u8, n: usize) void {
    allocator.free(x[0..n]);
}

export fn add(a: i32, b: i32) i32 {
    return a + b;
}

export fn print_memory(a: [*]u8, n: u32) void {
    const span = std.mem.span(a[0..n]);
    print("{*}: {any}\n", .{a, span});
}


fn _trace(image_pixels: [*]u8, image_width: u32, image_height: u32) ![]u8 {
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

    const footprint = try pcb.polylist_to_footprint(allocator, polylist);

    // caller owns the memory here.
    return footprint;
}

export fn trace(image_pixels: [*]u8, image_width: u32, image_height: u32) u32 {
    const footprint = _trace(image_pixels, image_width, image_height) catch {
        @panic("Memory error.");
    };

    print("trace() complete, footprint at {d} len {d}\n", .{@ptrToInt(footprint.ptr), footprint.len});

    var result: []u32 = allocator.alloc(u32, 2) catch return 0;
    result[0] = @ptrToInt(footprint.ptr);
    result[1] = footprint.len;

    print("result at {d}\n", .{@ptrToInt(result.ptr)});

    return @ptrToInt(result.ptr);
}
