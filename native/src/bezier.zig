const std = @import("std");
const math = std.math;
const print = std.debug.print;
const testing = std.testing;
const Point = @import("geometry.zig").Point;

pub const Approximator = struct {
    p1: Point,
    p2: Point,
    p3: Point,
    p4: Point,

    interval: f64,
    t: f64 = 0,
    finished: bool = false,

    pub fn init(p1: Point, p2: Point, p3: Point, p4: Point, delta: f64) Approximator {
        // dd = maximal value of 2nd derivative over curve - this must occur at an endpoint.
        const dd0 = math.pow(f64, p1.x - 2 * p2.x + p3.x, 2) + math.pow(f64, p1.y - 2 * p2.y + p3.y, 2);
        const dd1 = math.pow(f64, p2.x - 2 * p3.x + p4.x, 2) + math.pow(f64, p2.y - 2 * p3.y + p4.y, 2);
        const dd = 6 * @sqrt(@maximum(dd0, dd1));
        const e2 = if (8 * delta <= dd) 8 * delta / dd else 1;
        const interval = math.sqrt(e2);

        return Approximator {
            .p1 = p1,
            .p2 = p2,
            .p3 = p3,
            .p4 = p4,
            .interval = interval
        };
    }

    pub fn next(self: *Approximator) ?Point {
        if (self.finished) {
            return null;
        }

        if (self.t >= 1.0) {
            self.finished = true;
            return self.p4;
        }

        const x = (
            self.p1.x * math.pow(f64, 1 - self.t, 3)
            + 3 * self.p2.x * math.pow(f64, 1 - self.t, 2) * self.t
            + 3 * self.p3.x * (1 - self.t) * math.pow(f64, self.t, 2)
            + self.p4.x * math.pow(f64, self.t, 3)
        );
        const y = (
            self.p1.y * math.pow(f64, 1 - self.t, 3)
            + 3 * self.p2.y * math.pow(f64, 1 - self.t, 2) * self.t
            + 3 * self.p3.y * (1 - self.t) * math.pow(f64, self.t, 2)
            + self.p4.y * math.pow(f64, self.t, 3)
        );

        self.t += self.interval;
        return Point {.x = x, .y = y};
    }
};


test "bezier" {
    var b = Approximator.init(
        .{.x = 0, .y = 0},
        .{.x = 20, .y = 40},
        .{.x = 80, .y = 160},
        .{.x = 100, .y = 200},
        1
    );

    while (b.next()) |p| {
        print("{d}, {d}\n", .{p.x, p.y});
    }
}
