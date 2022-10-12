const std = @import("std");
const print = std.debug.print;
const testing = std.testing;
const c_translation = std.zig.c_translation;
const c = @import("cdefs.zig");
const clipper = @import("clipper.zig");

pub const Point = struct {
    x: f64,
    y: f64,

    pub fn format(self: Point, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        try writer.print("({d:3.3}, {d:3.3})", self);
    }
};

pub const Poly = struct {
    allocator: std.mem.Allocator,
    outline: []Point,
    holes: [][]Point,

    pub fn copy(self: Poly) !Poly {
        const outline = try self.allocator.dupe(Point, self.outline);
        var holes = try std.ArrayList([]Point).initCapacity(self.allocator, self.holes.len);
        for (self.holes) |hole| {
            try holes.append(try self.allocator.dupe(Point, hole));
        }
        return Poly {
            .allocator = self.allocator,
            .outline = outline,
            .holes = holes.toOwnedSlice(),
        };
    }

    pub fn deinit(self: *Poly) void {
        self.allocator.free(self.outline);
        for (self.holes) |hole| {
            self.allocator.free(hole);
        }
        self.allocator.free(self.holes);
    }

    pub fn simplify(self: *Poly) !void {
        var simplified = try clipper.simplify_poly(self.allocator, self.*);
        errdefer simplified.deinit();

        self.deinit();
        self.outline = simplified.outline;
        self.holes = simplified.holes;
    }

    // Ported from SHAPE_POLY_SET::fractureSingle
    // This works by collecting all the points in the polygon and its holes into
    // a linked list of edges. It then goes through that linked list and
    // joins hole edges to outer polygon.
    pub fn fracture(self: Poly, allocator: std.mem.Allocator) !Poly {
        // If there's no holes there's no need to do anything.
        if(self.holes.len == 0) {
            return try self.copy();
        }

        var edges = std.ArrayList(*Edge).init(allocator);

        defer {
            for (edges.items) |edge| {
                allocator.destroy(edge);
            }
            edges.clearAndFree();
        }

        // Start by gathering the edges of the outline. The edges of the outline
        // are already "connected", where the edges of the holes will start
        // "unconnected" and get iteratively connected to the outside.
        var outline_edges = try Edge.from_points(allocator, self.outline);
        defer allocator.free(outline_edges);

        try edges.ensureUnusedCapacity(outline_edges.len);
        for (outline_edges) |edge| {
            edge.connected = true;
            try edges.append(edge);
        }

        // Next, gather the edges for all of the holes. These are all "unconnected".
        var border_edges = std.ArrayList(*Edge).init(allocator);
        defer border_edges.clearAndFree();

        var num_unconnected: usize = 0;

        for (self.holes) |hole| {
            var hole_edges = try Edge.from_points(allocator, hole);
            defer allocator.free(hole_edges);

            var x_min: f64 = std.math.f64_max;
            try edges.ensureUnusedCapacity(hole_edges.len);
            for (hole_edges) |edge| {
                try edges.append(edge);
                num_unconnected += 1;

                // Is this a leftmost ("border") edge?
                // Note: this can end up with multiple edges from a single hole
                // getting put into border edges. This matches KiCAD's logic and
                // doesn't seem to have any negative effects other than making
                // the next step possibly slower.
                if (edge.p1.x <= x_min) {
                    try border_edges.append(edge);
                    x_min = edge.p1.x;
                }
            }
        }

        // Connect all holes to the outline.
        while (num_unconnected > 0) {
            var x_min: f64 = std.math.f64_max;
            var leftmost: ?*Edge = null;

            // find the left-most unconnected hole edge and merge with the outline
            for (border_edges.items) |edge| {
                if (edge.p1.x <= x_min and !edge.connected) {
                    x_min = edge.p1.x;
                    leftmost = edge;
                }
            }

            var num_processed = try leftmost.?.connect_hole_to_outline(allocator, &edges);

            if (num_processed > num_unconnected) {
                return error.HoleConnectionOverflow;
            } else {
                num_unconnected -= num_processed;
            }
        }

        // All the edges are connected, construct the polygon.
        return try Edge.to_poly(allocator, outline_edges);
    }

    pub fn svg_path(self: Poly) void {
        for (self.outline) |pt, n| {
            var letter = if (n == 0) "M" else "L";
            print("{s} {d:3.3},{d:3.3} ", .{letter, pt.x, pt.y});
        }
        print("\n", .{});
        for (self.holes) |hole| {
            for (hole) |pt, n| {
                var letter = if (n == 0) "M" else "L";
                print("{s} {d:3.3},{d:3.3} ", .{letter, pt.x, pt.y});
            }
        }
    }

    pub fn format(self: Poly, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        const tabs = options.width orelse 0;

        try tab(writer, tabs);
        try writer.print("Poly outline={d} holes={d}:\n", .{ self.outline.len, self.holes.len });
        try tab(writer, tabs + 1);
        try writer.writeAll("Outline: ");
        for (self.outline) |pt, n| {
            try writer.print("{?}", .{pt});
            if (n < self.outline.len - 1) {
                try writer.writeAll(", ");
            }
        }
        try writer.writeAll("\n");
        for (self.holes) |hole, i| {
            try tab(writer, tabs + 1);
            try writer.print("Hole {d}: ", .{i});
            for (hole) |pt, n| {
                try writer.print("{?}", .{pt});
                if (n < self.outline.len - 1) {
                    try writer.writeAll(", ");
                }
            }
            try writer.writeAll("\n");
        }
    }
};

pub const PolyList = struct {
    allocator: std.mem.Allocator,
    items: []Poly,

    pub fn deinit(self: *PolyList) void {
        for (self.items) |*item| {
            item.deinit();
        }
        self.allocator.free(self.items);
    }

    pub fn format(self: PolyList, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        try writer.print("PolyList len={d}:\n", .{self.items.len});
        for (self.items) |poly| {
            try writer.print("{?:1}", .{poly});
        }
    }
};

// Used to during the "fracture" algorithm to track edges (line segments)
// that comprise the polygon and its holes.
const Edge = struct {
    p1: Point,
    p2: Point,
    connected: bool = false,
    next: ?*Edge = null,

    fn from_points(allocator: std.mem.Allocator, pts: []Point) ![]*Edge {
        var edges = try std.ArrayList(*Edge).initCapacity(allocator, pts.len);

        for (pts) |pt, i| {
            var edge = try allocator.create(Edge);

            edge.* = .{
                .p1 = pt,
                .p2 = pts[if (i + 1 == pts.len) 0 else i + 1],
                .connected = false,
            };

            if (i > 0) {
                edges.items[i-1].next = edge;
            }

            try edges.append(edge);
        }

        // Connect the last edge back to the first, completing the shape.
        edges.items[edges.items.len - 1].next = edges.items[0];

        return edges.toOwnedSlice();
    }

    fn to_poly(allocator: std.mem.Allocator, edges: []*Edge) !Poly {
        var outline = try std.ArrayList(Point).initCapacity(allocator, edges.len);

        var root = edges[0];
        var e = root;
        while (e.next != root) : (e = e.next.?) {
            if(!e.connected) { print("warning: unconnected edge at index {d}.\n", .{outline.items.len}); }
            try outline.append(e.p1);
        }
        try outline.append(e.p1);

        return Poly {
            .allocator = allocator,
            .outline = outline.toOwnedSlice(),
            .holes = &[_][]Point{},
        };
    }

    fn shape_edge_count(self: *Edge) usize {
        var last = self;
        var count: usize = 0;
        while (last.next != self) : (last = last.next.?) {
            count += 1;
        }

        return count;
    }

    // Does this edge contain the given y coordinate?
    // Used to determine if one edge can be connected to another.
    fn contains_y(self: Edge, y: f64) bool {
        return (y >= self.p1.y or y >= self.p2.y) and (y <= self.p1.y or y <= self.p2.y);
    }

    // Break this edge into two, splitting at the given (x, y).
    fn split(self: *Edge, allocator: std.mem.Allocator, x: f64, y: f64) !*Edge {
        var after = try allocator.create(Edge);
        after.* = .{
            .connected = self.connected,
            .p1 = .{.x = x, .y = y},
            .p2 = self.p2,
            .next = self.next,
        };

        self.p2 = .{.x = x, .y = y};
        self.next = after;

        return after;
    }

    // Connects a hole to the outline in *edges*. The hole starts with the
    // edge this is called on.
    fn connect_hole_to_outline(self: *Edge, allocator: std.mem.Allocator, edges: *std.ArrayList(*Edge)) !usize {
        const nearest = try self.find_nearest_connectable_edge(edges.items);

        // Split the nearest connected edge at the x-intersection, creating a
        // spot for the hole's edges to be connected in.
        var split_after = try nearest.edge.split(allocator, nearest.x_intersect, self.p1.y);

        // Connects the outline's edge to the hole's first edge
        var bridge_before = try allocator.create(Edge);
        bridge_before.* = .{
            .connected = true,
            .p1 = .{.x = nearest.x_intersect, .y = self.p1.y},
            .p2 = self.p1,
        };

        // Connects the hole's last edge back to the outline.
        var bridge_after = try allocator.create(Edge);
        bridge_after.* = .{
            .connected = true,
            .p1 = self.p1,
            .p2 = .{.x = nearest.x_intersect, .y = self.p1.y},
        };

        try edges.append(bridge_before);
        try edges.append(split_after);
        try edges.append(bridge_after);

        // Mark all the hole edges as connected
        var last = self;
        var count: usize = 0;
        while (last.next != self) : (last = last.next.?) {
            last.connected = true;
            count += 1;
        }
        last.connected = true;

        // Link the edges together.
        nearest.edge.next = bridge_before;
        bridge_before.next = self;
        last.next = bridge_after;
        bridge_after.next = split_after;

        self.connected = true;
        bridge_after.connected = true;

        return count + 1;
    }


    // Find the nearest connected edge that this edge could be connected to.
    // An edge is connectable if this edge's "y" is contained within the
    // extents of the edge. "Nearest" is determined by the distance from this
    // edge to the point on the other edge where they would intersect
    // (the x_intersect).
    fn find_nearest_connectable_edge(self: *Edge, edges: []*Edge) !struct {edge: *Edge, x_intersect: f64} {
        var nearest: ?*Edge = null;
        var nearest_x_intersect: f64 = 0;
        var nearest_dist: f64 = std.math.f64_max;

        for (edges) |e| {
            if (!e.connected) {
                continue;
            }

            if (!e.contains_y(self.p1.y)) {
                continue;
            }

            var x_intersect: f64 = 0;

            // Check if is this a horizontal edge to avoid divide by zero when
            // calculating the x_intersect.
            if( e.p1.y == e.p2.y ) {
                x_intersect = @maximum( e.p1.x, e.p2.x );
            } else {
                x_intersect = e.p1.x + ((e.p2.x - e.p1.x) * (self.p1.y - e.p1.y) / (e.p2.y - e.p1.y));
            }

            var dist: f64 = self.p1.x - x_intersect;

            if (dist >= 0 and dist < nearest_dist) {
                nearest_dist = dist;
                nearest_x_intersect = x_intersect;
                nearest = e;
            }
        }

        return .{.edge = nearest.?, .x_intersect = nearest_x_intersect};
    }

    pub fn format(self: Edge, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        try writer.print("Edge p1={?} p2={?}, next=0x{x}, connected={?}", .{self.p1, self.p2, @ptrToInt(self.next), self.connected});
    }
};


fn tab(writer: anytype, times: usize) !void {
    var n: usize = 0;
    while (n < times) : (n += 1) {
        try writer.writeAll("  ");
    }
}
