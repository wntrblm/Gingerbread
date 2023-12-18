const std = @import("std");
const print = std.debug.print;
const testing = std.testing;

pub const FauxUUID = struct {
    bytes: [16]u8,

    pub fn init() FauxUUID {
        var uuid = FauxUUID{ .bytes = undefined };
        std.crypto.random.bytes(&uuid.bytes);
        return uuid;
    }

    pub fn format(self: FauxUUID, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        try writer.print("{x}-{x}-{x}-{x}-{x}", .{
            std.fmt.fmtSliceHexLower(self.bytes[0..4]),
            std.fmt.fmtSliceHexLower(self.bytes[4..6]),
            std.fmt.fmtSliceHexLower(self.bytes[6..8]),
            std.fmt.fmtSliceHexLower(self.bytes[8..10]),
            std.fmt.fmtSliceHexLower(self.bytes[10..16]),
        });
    }
};

test "fauxuuid" {
    std.debug.print("\n{any}\n", .{FauxUUID.init()});
}
