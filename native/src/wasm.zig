const std = @import("std");
const print = std.debug.print;

pub const allocator = std.heap.c_allocator;

// https://github.com/mbrock/wisp/blob/master/core/wasm.zig#L349
export fn z_allocate(n: u32) u32 {
    const buf = allocator.alloc(u8, n) catch return 0;
    print("allocated {d} bytes @ {d}\n", .{ n, @intFromPtr(buf.ptr) });
    return @as(u32, @intCast(@intFromPtr(buf.ptr)));
}

export fn z_free_zero(x: [*:0]u8) void {
    allocator.free(std.mem.span(x));
}

export fn z_free(x: [*]u8, n: usize) void {
    allocator.free(x[0..n]);
}

export fn z_print_memory(a: [*]u8, n: u32) void {
    const span = a[0..n];
    print("{*}: {any}\n", .{ a, span });
}

pub fn return_string(str: []u8) u32 {
    var result: []u32 = allocator.alloc(u32, 2) catch return 0;
    result[0] = @as(u32, @intCast(@intFromPtr(str.ptr)));
    result[1] = @as(u32, @intCast(str.len));
    return @as(u32, @intCast(@intFromPtr(result.ptr)));
}

pub const StringResult = @typeInfo(@TypeOf(return_string)).Fn.return_type.?;
