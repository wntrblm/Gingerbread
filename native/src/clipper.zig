const builtin = @import("builtin");
const std = @import("std");
const print = std.debug.print;
const testing = std.testing;
const c = @import("cdefs.zig");
const geometry = @import("geometry.zig");
const Point = geometry.Point;
const Poly = geometry.Poly;

const PathD = struct {
    ptr: *c.pathd_t,

    pub fn init() PathD {
        return .{
            .ptr = c.PathD_new().?,
        };
    }

    pub fn deinit(self: *PathD) void {
        c.PathD_delete(self.ptr);
    }

    pub fn len(self: PathD) usize {
        return c.PathD_size(self.ptr);
    }

    pub fn append(self: *PathD, pt: Point) void {
        return c.PathD_push_back(self.ptr, pt.x, pt.y);
    }

    pub fn get(self: PathD, index: usize) Point {
        const val = c.PathD_at(self.ptr, index);
        return .{ .x = val.x, .y = val.y };
    }

    pub const Iterator = struct {
        parent: PathD,
        len: usize,
        n: usize = 0,

        pub fn next(self: *Iterator) ?Point {
            if (self.n >= self.len) {
                return null;
            }

            const val = self.parent.get(self.n);
            self.n += 1;

            return val;
        }
    };

    pub fn iterator(self: PathD) Iterator {
        return .{
            .parent = self,
            .len = self.len(),
        };
    }

    pub fn format(self: PathD, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        try writer.print("PathD len={d}: ", .{self.len()});
        var it = self.iterator();
        while (it.next()) |pt| {
            try writer.print("{?}", .{pt});
            if (it.n < it.len) {
                try writer.writeAll(", ");
            }
        }
        try writer.writeAll("\n");
    }

    pub fn svg_path(self: PathD) void {
        var it = self.iterator();
        while (it.next()) |pt| {
            const letter = if (it.n == 1) "M" else "L";
            print("{s} {d:3.3},{d:3.3} ", .{ letter, pt.x, pt.y });
        }
        print("\n", .{});
    }

    pub fn from_points(points: []const Point) PathD {
        var path = PathD.init();
        // TODO: Reserve
        for (points) |pt| {
            path.append(pt);
        }
        return path;
    }

    pub fn to_points(self: PathD, allocator: std.mem.Allocator) ![]Point {
        var points = try std.ArrayList(Point).initCapacity(allocator, self.len());
        var it = self.iterator();
        while (it.next()) |pt| {
            points.appendAssumeCapacity(pt);
        }
        return points.toOwnedSlice();
    }
};

const PathList = struct {
    ptr: *c.pathsd_t,

    pub fn init() PathList {
        return .{
            .ptr = c.PathsD_new().?,
        };
    }

    pub fn deinit(self: *PathList) void {
        c.PathsD_delete(self.ptr);
    }

    pub fn len(self: PathList) usize {
        return c.PathsD_size(self.ptr);
    }

    pub fn append(self: *PathList, path: PathD) void {
        return c.PathsD_push_back(self.ptr, path.ptr);
    }

    pub fn get(self: PathList, index: usize) PathD {
        const val = c.PathsD_at(self.ptr, index).?;
        return .{ .ptr = val };
    }

    pub const Iterator = struct {
        parent: PathList,
        len: usize,
        n: usize = 0,

        pub fn next(self: *Iterator) ?PathD {
            if (self.n >= self.len) {
                return null;
            }

            const val = self.parent.get(self.n);
            self.n += 1;

            return val;
        }
    };

    pub fn iterator(self: PathList) Iterator {
        return .{
            .parent = self,
            .len = self.len(),
        };
    }

    pub fn format(self: PathList, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        try writer.print("PathList len={d}:\n", .{self.len()});
        var it = self.iterator();
        while (it.next()) |path| {
            try writer.print("  {?}\n", .{path});
        }
    }

    pub fn svg_path(self: PathList) void {
        var it = self.iterator();
        while (it.next()) |path| {
            path.svg_path();
        }
    }

    pub fn to_poly(self: PathList, allocator: std.mem.Allocator) !Poly {
        const outline = try self.get(0).to_points(allocator);
        var holes = try std.ArrayList([]Point).initCapacity(allocator, self.len() - 1);

        // The first path is the outline, subsequent paths are holes, so skip
        // the first path
        var it = self.iterator();
        _ = it.next();
        while (it.next()) |path| {
            try holes.append(try path.to_points(allocator));
        }

        return .{
            .allocator = allocator,
            .outline = outline,
            .holes = try holes.toOwnedSlice(),
        };
    }
};

pub const ClipType = enum(u8) {
    None = c.CLIP_TYPE_NONE,
    Intersection = c.CLIP_TYPE_INTERSECTION,
    Union = c.CLIP_TYPE_UNION,
    Difference = c.CLIP_TYPE_DIFFERENCE,
    Xor = c.CLIP_TYPE_XOR,
};

pub const FillRule = enum(u8) {
    EvenOdd = c.FILL_RULE_EVEN_ODD,
    NonZero = c.FILL_RULE_NON_ZERO,
    Positive = c.FILL_RULE_POSITIVE,
    Negative = c.FILL_RULE_NEGATIVE,
};

pub fn boolean_op(clip_type: ClipType, fill_rule: FillRule, subjects: PathList, clips: PathList, decimal_precision: i32) PathList {
    const solution_ptr = c.clipper2_boolean_op(
        @intFromEnum(clip_type),
        @intFromEnum(fill_rule),
        subjects.ptr,
        clips.ptr,
        decimal_precision,
    ).?;

    return .{ .ptr = solution_ptr };
}

pub const Options = struct {
    fill_rule: FillRule = FillRule.NonZero,
    decimal_precision: i32 = 3,
};

pub fn intersection(subjects: PathList, clips: PathList, options: Options) PathList {
    return boolean_op(ClipType.Intersection, options.fill_rule, subjects, clips, options.decimal_precision);
}

pub fn union_(subjects: PathList, clips: PathList, options: Options) PathList {
    return boolean_op(ClipType.Union, options.fill_rule, subjects, clips, options.decimal_precision);
}

pub fn difference(subjects: PathList, clips: PathList, options: Options) PathList {
    return boolean_op(ClipType.Difference, options.fill_rule, subjects, clips, options.decimal_precision);
}

pub fn xor(subjects: PathList, clips: PathList, options: Options) PathList {
    return boolean_op(ClipType.Xor, options.fill_rule, subjects, clips, options.decimal_precision);
}

pub fn simplify_poly(allocator: std.mem.Allocator, poly: Poly) !Poly {
    var subjects = PathList.init();
    defer subjects.deinit();

    var subject = PathD.from_points(poly.outline);
    subjects.append(subject);
    subject.deinit();

    var clips = PathList.init();
    for (poly.holes) |hole| {
        var clip = PathD.from_points(hole);
        clips.append(clip);
        clip.deinit();
    }

    var result = difference(subjects, clips, .{});
    defer result.deinit();

    return try result.to_poly(allocator);
}

test "PathD" {
    var pathd = PathD.init();
    defer pathd.deinit();

    try testing.expect(pathd.len() == 0);

    pathd.append(Point{ .x = 1, .y = 2 });
    pathd.append(Point{ .x = 3, .y = 4 });

    try testing.expect(pathd.len() == 2);

    var it = pathd.iterator();
    try testing.expect(std.meta.eql(it.next().?, Point{ .x = 1, .y = 2 }));
    try testing.expect(std.meta.eql(it.next().?, Point{ .x = 3, .y = 4 }));
    try testing.expect(it.next() == null);

    // Converting to and from points
    const points = try pathd.to_points(std.testing.allocator);
    defer std.testing.allocator.free(points);

    try testing.expect(points.len == 2);
    try testing.expect(std.meta.eql(points[0], Point{ .x = 1, .y = 2 }));
    try testing.expect(std.meta.eql(points[1], Point{ .x = 3, .y = 4 }));

    var pathd2 = PathD.from_points(points);
    defer pathd2.deinit();

    try testing.expect(pathd2.len() == 2);
    var it2 = pathd2.iterator();
    try testing.expect(std.meta.eql(it2.next().?, points[0]));
    try testing.expect(std.meta.eql(it2.next().?, points[1]));
    try testing.expect(it2.next() == null);

    // Printing and such
    print("\n{?}", .{pathd});
    pathd.svg_path();
}

test "PathList" {
    var pathsd = PathList.init();
    defer pathsd.deinit();

    try testing.expect(pathsd.len() == 0);

    var pathd = PathD.init();
    pathd.append(Point{ .x = 1, .y = 2 });
    pathsd.append(pathd);
    pathd.deinit();

    try testing.expect(pathsd.len() == 1);
    try testing.expect(pathsd.get(0).len() == 1);

    print("{?}", .{pathsd});

    pathsd.svg_path();
}

test "PathList to Poly" {
    var pathsd = PathList.init();
    defer pathsd.deinit();

    var outline = PathD.init();
    outline.append(Point{ .x = 1, .y = 2 });
    pathsd.append(outline);
    outline.deinit();

    var hole = PathD.init();
    hole.append(Point{ .x = 3, .y = 4 });
    pathsd.append(hole);
    hole.deinit();

    var poly = try pathsd.to_poly(std.testing.allocator);
    defer poly.deinit();

    try testing.expect(poly.outline.len == 1);
    try testing.expect(poly.holes.len == 1);
    try testing.expect(poly.holes[0].len == 1);

    print("{?}", .{poly});
}

test "boolean op" {
    var subjects = PathList.init();
    defer subjects.deinit();
    var subject = PathD.from_points(&[_]Point{
        .{ .x = 0, .y = 0 },
        .{ .x = 100, .y = 0 },
        .{ .x = 100, .y = 100 },
        .{ .x = 0, .y = 100 },
    });
    subjects.append(subject);
    subject.deinit();

    var clips = PathList.init();
    defer clips.deinit();
    var clip = PathD.from_points(&[_]Point{
        .{ .x = 25, .y = 25 },
        .{ .x = 75, .y = 25 },
        .{ .x = 75, .y = 75 },
        .{ .x = 25, .y = 75 },
    });
    clips.append(clip);
    clip.deinit();

    var result = boolean_op(ClipType.Difference, FillRule.EvenOdd, subjects, clips, 1);
    defer result.deinit();

    // TODO: Actually check the result here.

    print("Result: {?}\n", .{result});
}

test "simplify poly" {
    const a = std.testing.allocator;
    var outline = std.ArrayList(Point).init(a);
    var hole = std.ArrayList(Point).init(a);
    var holes = std.ArrayList([]Point).init(a);

    try outline.appendSlice(&[_]Point{
        .{ .x = 0, .y = 0 },
        .{ .x = 100, .y = 0 },
        .{ .x = 100, .y = 100 },
        .{ .x = 0, .y = 100 },
    });
    try hole.appendSlice(&[_]Point{
        .{ .x = 25, .y = 25 },
        .{ .x = 75, .y = 25 },
        .{ .x = 75, .y = 75 },
        .{ .x = 25, .y = 75 },
    });
    try holes.append(try hole.toOwnedSlice());

    var poly = Poly{
        .allocator = a,
        .outline = try outline.toOwnedSlice(),
        .holes = try holes.toOwnedSlice(),
    };

    defer poly.deinit();

    var simplified = try simplify_poly(a, poly);
    defer simplified.deinit();

    print("Result: {?}\n", .{simplified});

    try testing.expect(simplified.outline.len == 4);
    try testing.expect(simplified.holes.len == 1);

    // TODO: Actually check the result here.

    // Check simplify in place
    try poly.simplify();

    print("Result: {?}\n", .{poly});

    for (poly.outline, 0..) |_, i| {
        try testing.expect(std.meta.eql(poly.outline[i], simplified.outline[i]));
    }
}
