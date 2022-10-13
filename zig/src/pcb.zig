const std = @import("std");
const print = std.debug.print;
const testing = std.testing;
const geometry = @import("geometry.zig");
const Poly = geometry.Poly;
const PolyList = geometry.PolyList;


pub fn start_pcb(buffer: *std.ArrayList(u8)) !void {
    var writer = buffer.writer();
    try writer.writeAll("(kicad_pcb (version 20211014) (generator pcbnew)\n");
    try writer.writeAll("(layers\n");
    try writer.writeAll("    (0 \"F.Cu\" signal)\n");
    try writer.writeAll("    (31 \"B.Cu\" signal)\n");
    try writer.writeAll("    (36 \"B.SilkS\" user \"B.Silkscreen\")\n");
    try writer.writeAll("    (37 \"F.SilkS\" user \"F.Silkscreen\")\n");
    try writer.writeAll("    (38 \"B.Mask\" user)\n");
    try writer.writeAll("    (39 \"F.Mask\" user)\n");
    try writer.writeAll("    (40 \"Dwgs.User\" user \"User.Drawings\")\n");
    try writer.writeAll("    (41 \"Cmts.User\" user \"User.Comments\")\n");
    try writer.writeAll("    (44 \"Edge.Cuts\" user)\n");
    try writer.writeAll(")\n");
}

pub fn end_pcb(buffer: *std.ArrayList(u8)) !void {
    var writer = buffer.writer();
    try writer.writeAll(")\n");
}


pub fn polylist_to_footprint(allocator: std.mem.Allocator, polylist: PolyList, layer: []const u8) ![]u8 {
    var buffer = std.ArrayList(u8).init(allocator);
    errdefer buffer.deinit();
    var writer = buffer.writer();

    try writer.writeAll("(footprint \"Graphics\"\n");
    try writer.print("  (layer \"{s}\")\n", .{layer});
    try writer.writeAll("  (at 0 0)\n");
    try writer.writeAll("  (attr board_only exclude_from_pos_files exclude_from_bom)\n");
    try writer.writeAll("  (tstamp \"e9dc178a-3c62-11ed-ab80-7a0c86e760e0\")\n");
    try writer.writeAll("  (tedit \"e9dc1794-3c62-11ed-ab80-7a0c86e760e0\")\n");

    for (polylist.items) |poly| {
        try writer.writeAll("  (fp_poly\n");
        try writer.writeAll("    (pts\n");

        for (poly.outline) |pt| {
            try writer.print("      (xy {d} {d})\n", .{pt.x / 10, pt.y / 10});
        }

        try writer.writeAll("    )\n");
        try writer.print("    (layer \"{s}\")\n", .{layer});
        try writer.writeAll("    (width 0)\n");
        try writer.writeAll("    (fill solid)\n");
        try writer.writeAll("    (tstamp \"e9dc14e2-3c62-11ed-ab80-7a0c86e760e0\")\n");
        try writer.writeAll("  )\n");
    }

    try writer.writeAll(")\n");

    return buffer.toOwnedSlice();
}
