const std = @import("std");
const print = std.debug.print;
const testing = std.testing;
const c_translation = std.zig.c_translation;
const c = @import("cdefs.zig");
const Image = c.image_t;
const bezier = @import("bezier.zig");
const geometry = @import("geometry.zig");
const Point = geometry.Point;
const Poly = geometry.Poly;
const PolyList = geometry.PolyList;

pub fn version() []const u8 {
    return std.mem.span(c.potrace_version());
}

// TODO: This should be moved elsewhere once the thresholding logic is pulled out.
pub fn pixel_at(image: Image, x: usize, y: usize) []u8 {
    const idx = y * (image.w * image.channels) + (x * image.channels);
    return image.pixels[idx..(idx + image.channels)];
}

pub fn luminosity(px: []u8) u32 {
    const avg: u32 = (px[0] + px[1] + px[2]) / 3;
    if(px.len == 4) {
        return avg * px[3] / 255;
    }
    return avg;
}

pub fn luminosity2(image: Image, x: usize, y: usize) u32 {
    const idx = y * (image.w * image.channels) + (x * image.channels);
    var avg: u32 = image.pixels[idx];
    avg += image.pixels[idx + 1];
    avg += image.pixels[idx + 2];
    avg /= 3;
    if(image.channels == 4) {
        return avg * image.pixels[idx + 3] / 255;
    }
    return avg;
}

pub inline fn alpha_test(image: Image, x: usize, y: usize) u32 {
    const idx = y * (image.w * image.channels) + (x * image.channels);
    return image.pixels[idx + 3];
}

pub const Bitmap = struct {
    allocator: std.mem.Allocator,
    data: []c.potrace_word,
    bm: c.potrace_bitmap_t,

    pub fn from_image(allocator: std.mem.Allocator, image: Image) !Bitmap {
        const dy = try Bitmap.dy_for_width(image.w);
        const size_in_words = dy * image.h;

        var bitmap = Bitmap {
            .allocator = allocator,
            .data = try allocator.alloc(c.potrace_word, size_in_words),
            .bm = c.potrace_bitmap_t {
                .w = @intCast(c_int, image.w),
                .h = @intCast(c_int, image.h),
                .dy = @intCast(c_int, dy),
                .map = null,
            }
        };

        std.mem.set(c.potrace_word, bitmap.data, 0);
        bitmap.bm.map = @ptrCast([*c]c.potrace_word, bitmap.data);

        var y: usize = 0;
        while (y < image.h) : (y += 1) {
            var x: usize = 0;
            while (x < image.w) : (x += 1) {
                //const pix = pixel_at(image, x, y);
                if (image.channels == 4) {
                    bitmap.put(x, y, alpha_test(image, x, y) > 127);
                } else {
                    bitmap.put(x, y, luminosity2(image, x, y) > 127);
                }
            }
        }

        return bitmap;
    }

    pub fn deinit(self: Bitmap) void {
        self.allocator.free(self.data);
    }

    pub fn trace(self: *Bitmap) !Trace {
        var params = c.potrace_param_default();
        defer c.potrace_param_free(params);

        var state = c.potrace_trace(params, &self.bm).?;

        if (state.*.status != c.POTRACE_STATUS_OK) {
            return error.TraceFailed;
        }

        return .{.state = state};
    }

    inline fn dy_for_width(w: usize) !usize {
        return (w - 1) / (@bitSizeOf(c.potrace_word)) + 1;
    }

    inline fn mask_for(x: usize) c.potrace_word {
        const hibit: c.potrace_word = 1 << (@bitSizeOf(c.potrace_word) - 1);
        return std.math.shr(c.potrace_word, hibit, x & (@bitSizeOf(c.potrace_word) - 1));
    }

    inline fn index_for(self: *Bitmap, x: usize, y: usize) usize {
        return (y * @intCast(usize, self.bm.dy)) + (x / @bitSizeOf(c.potrace_word));
    }

    pub inline fn put(self: *Bitmap, x: usize, y: usize, b: bool) void {
        if (b) {
            self.bm.map[self.index_for(x, y)] |= Bitmap.mask_for(x);
        } else {
            self.bm.map[self.index_for(x, y)] &= ~Bitmap.mask_for(x);
        }
    }
};

pub const Trace = struct {
    state: *c.potrace_state_t,

    pub fn deinit(self: *Trace) void {
        c.potrace_state_free(self.state);
    }

    pub const Iterator = struct {
        current: ?*c.potrace_path_t,

        pub fn init(plist: *c.potrace_path_t) Iterator {
            return Iterator {
                .current = plist,
            };
        }

        pub fn next(self: *Iterator) ?*c.potrace_path_t {
            var p = self.current;
            if (self.current) |current| {
                self.current = current.next;
            }
            return p;
        }
    };

    pub fn to_polylist(self: *Trace, allocator: std.mem.Allocator, bezier_resolution: f32) !PolyList {
        var polys = std.ArrayList(Poly).init(allocator);
        var outline: ?[]Point = null;
        var holes = std.ArrayList([]Point).init(allocator);

        var it = Iterator.init(self.state.plist);
        while (it.next()) |path| {
            var points = try path_to_points(allocator, path, bezier_resolution);
            if(path.sign == "+"[0]) {
                if (outline) |outline_points| {
                    try polys.append(.{
                        .allocator = allocator,
                        .outline = outline_points,
                        .holes = holes.toOwnedSlice(),
                    });
                }
                outline = points;
            } else {
                try holes.append(points);
            }
        }

        if (outline) |outline_points| {
            try polys.append(.{
                .allocator = allocator,
                .outline = outline_points,
                .holes = holes.toOwnedSlice(),
            });
        }

        return .{
            .allocator = allocator,
            .items = polys.toOwnedSlice()
        };
    }

    // // TODO: change to format
    // pub fn print_trace(plist: [*c]c.potrace_path_t) void {
    //     var path = plist;
    //     var path_n: usize = 0;

    //     while (path != null) : ({
    //         path = path.*.next;
    //         path_n += 1;
    //     }) {
    //     print("Path {d}: {u}\n", .{ path_n, @intCast(u21, path.*.sign) });

    //         var curve_n: usize = 0;
    //         while (curve_n < path.*.curve.n) : (curve_n += 1) {
    //                 print("Curve {d}: tag: {d} pts: ({d:.4}, {d:.4}), ({d:.4}, {d:.4}), ({d:.4}, {d:.4})\n", .{
    //                 curve_n,
    //                 path.*.curve.tag[curve_n],
    //                 path.*.curve.c[curve_n][0].x,
    //                 path.*.curve.c[curve_n][0].y,
    //                 path.*.curve.c[curve_n][1].x,
    //                 path.*.curve.c[curve_n][1].y,
    //                 path.*.curve.c[curve_n][2].x,
    //                 path.*.curve.c[curve_n][2].y,
    //             });
    //         }
    //     }
    // }
};


fn path_to_points(allocator: std.mem.Allocator, path: *c.potrace_path_t, bezier_resolution: f32) ![]Point {
    var out = std.ArrayList(Point).init(allocator);
    var n: usize = 0;
    var curve = path.*.curve;
    var last = @intCast(usize, curve.n) - 1;
    var start_point = curve.c[last][2];

    try out.append(.{.x = start_point.x, .y = start_point.y});

    while (n < path.*.curve.n) : ({last = n; n += 1;}) {
        switch (curve.tag[n]) {
            c.POTRACE_CORNER => {
                try out.append(.{.x = curve.c[n][1].x, .y = curve.c[n][1].y});
                try out.append(.{.x = curve.c[n][2].x, .y = curve.c[n][2].y});
            },
            c.POTRACE_CURVETO => {
                var b = bezier.Approximator.init(
                    .{.x = curve.c[last][2].x, .y = curve.c[last][2].y},
                    .{.x = curve.c[n][0].x, .y = curve.c[n][0].y},
                    .{.x = curve.c[n][1].x, .y = curve.c[n][1].y},
                    .{.x = curve.c[n][2].x, .y = curve.c[n][2].y},
                    bezier_resolution,
                );

                while (b.next()) |p| {
                    try out.append(.{.x = p.x, .y = p.y});
                }
            },
            else => {},
        }
    }

    return out.toOwnedSlice();
}

pub fn load_example_bitmap(allocator: std.mem.Allocator) !Bitmap {
    var image = c.load_image("resources/example-100px.png");
    try testing.expect(image.w > 0 and image.h > 0);
    defer c.free_image(image);
    return Bitmap.from_image(allocator, image);
}

test "version" {
    try testing.expectEqualStrings("potracelib 1.16", version());
}

test "trace png" {
    var bitmap = try load_example_bitmap(std.testing.allocator);
    defer bitmap.deinit();

    print("Bitmap w: {d}, h: {d}, dy: {d}\n", .{bitmap.bm.w, bitmap.bm.h, bitmap.bm.dy});

    var trace = try bitmap.trace();
    defer trace.deinit();

    var polylist = try trace.to_polylist(std.testing.allocator, 1);
    defer polylist.deinit();
    print("{?}\n", .{polylist});
    print("\nSVG Path: ", .{});
    for (polylist.items) |poly| {
        poly.svg_path();
    }
    print("\n", .{});
}
