const std = @import("std");
const print = std.debug.print;
const testing = std.testing;
const geometry = @import("geometry.zig");
const Poly = geometry.Poly;
const PolyList = geometry.PolyList;

pub fn start_pcb(writer: anytype) !void {
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

pub fn end_pcb(writer: anytype) !void {
    try writer.writeAll(")\n");
}

pub fn start_xx_poly(kind: []const u8, writer: anytype) !void {
    try writer.print("  ({s}_poly\n", .{kind});
    try writer.writeAll("    (pts\n");
}

pub fn add_xx_poly_point(pt: geometry.Point, scale_factor: f64, writer: anytype) !void {
    try writer.print("      (xy {d:.3} {d:.3})\n", .{ pt.x * scale_factor, pt.y * scale_factor });
}

pub fn end_xx_poly(layer: []const u8, width: f64, fill: bool, writer: anytype) !void {
    try writer.writeAll("    )\n");
    try writer.print("    (layer \"{s}\")\n", .{layer});
    try writer.print("    (width {d:.3})\n", .{width});
    try writer.print("    (fill {s})\n", .{if (fill) "solid" else "none"});
    try writer.writeAll("    (tstamp \"e9dc14e2-3c62-11ed-ab80-7a0c86e760e0\")\n");
    try writer.writeAll("  )\n");
}

pub fn points_to_xx_poly(kind: []const u8, pts: []geometry.Point, scale_factor: f64, layer: []const u8, width: f64, fill: bool, writer: anytype) !void {
    try start_xx_poly(kind, writer);

    for (pts) |pt| {
        try add_xx_poly_point(pt, scale_factor, writer);
    }

    try end_xx_poly(layer, width, fill, writer);
}

pub fn polylist_to_footprint(polylist: PolyList, layer: []const u8, scale_factor: f64, writer: anytype) !void {
    try writer.writeAll("(footprint \"Graphics\"\n");
    try writer.print("  (layer \"{s}\")\n", .{layer});
    try writer.writeAll("  (at 0 0)\n");
    try writer.writeAll("  (attr board_only exclude_from_pos_files exclude_from_bom)\n");
    try writer.writeAll("  (tstamp \"e9dc178a-3c62-11ed-ab80-7a0c86e760e0\")\n");
    try writer.writeAll("  (tedit \"e9dc1794-3c62-11ed-ab80-7a0c86e760e0\")\n");

    for (polylist.items) |poly| {
        try points_to_xx_poly("fp", poly.outline, scale_factor, layer, 0, true, writer);
    }

    try writer.writeAll(")\n");
}
