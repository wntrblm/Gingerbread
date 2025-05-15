const std = @import("std");
const print = std.debug.print;
const testing = std.testing;
const geometry = @import("geometry.zig");
const Poly = geometry.Poly;
const PolyList = geometry.PolyList;
const FauxUUID = @import("fauxuuid.zig").FauxUUID;

fn is_back_layer(layer: []const u8) bool {
    return std.ascii.startsWithIgnoreCase(layer, "B.");
}

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
pub var mirror_back_layers: bool = true;

pub fn add_xx_poly_point(pt: geometry.Point, layer_name: []const u8, scale_factor: f64, writer: anytype) !void {
    const scaled_x = pt.x * scale_factor;
    const scaled_y = pt.y * scale_factor;

    // For back layers, mirror around x=0 then translate back
    const final_x = if (is_back_layer(layer_name) and mirror_back_layers)
        -scaled_x + (2 * scaled_x) // Mirror around x=0, then translate back by 2x
    else
        scaled_x;

    try writer.print("      (xy {d:.3} {d:.3})\n", .{ final_x, scaled_y });
}

pub fn end_xx_poly(layer_name: []const u8, width: f64, fill: bool, writer: anytype) !void {
    try writer.writeAll("    )\n");
    try writer.print("    (layer \"{s}\")\n", .{layer_name});
    try writer.print("    (width {d:.3})\n", .{width});
    try writer.print("    (fill {s})\n", .{if (fill) "solid" else "none"});
    try writer.print("    (tstamp \"{s}\")\n", .{FauxUUID.init()});
    try writer.writeAll("  )\n");
}

pub fn points_to_xx_poly(kind: []const u8, pts: []geometry.Point, scale_factor: f64, layer_name: []const u8, width: f64, fill: bool, writer: anytype) !void {
    try start_xx_poly(kind, writer);

    for (pts) |pt| {
        try add_xx_poly_point(pt, layer_name, scale_factor, writer);
    }

    try end_xx_poly(layer_name, width, fill, writer);
}

pub fn polylist_to_footprint(polylist: PolyList, layer: []const u8, scale_factor: f64, writer: anytype) !void {
    try writer.writeAll("(footprint \"Graphics\"\n");
    try writer.print("  (layer \"{s}\")\n", .{layer});
    try writer.writeAll("  (at 0 0)\n");
    try writer.writeAll("  (attr board_only exclude_from_pos_files exclude_from_bom)\n");
    try writer.print("  (tstamp \"{s}\")\n", .{FauxUUID.init()});
    try writer.print("  (tedit \"{s}\")\n", .{FauxUUID.init()});

    for (polylist.items) |poly| {
        try points_to_xx_poly("fp", poly.outline, scale_factor, layer, 0, true, writer);
    }

    try writer.writeAll(")\n");
}

pub fn add_drill(x: f64, y: f64, d: f64, scale_factor: f64, writer: anytype) !void {
    try writer.writeAll("(footprint \"DrillHole\"\n");
    try writer.writeAll("(layer \"F.Cu\")\n");
    try writer.print("  (at {d:.3} {d:.3})\n", .{ x * scale_factor, y * scale_factor });
    try writer.writeAll("  (attr board_only exclude_from_pos_files exclude_from_bom)\n");
    try writer.print("  (tstamp \"{s}\")\n", .{FauxUUID.init()});
    try writer.print("  (tedit \"{s}\")\n", .{FauxUUID.init()});
    try writer.print("(pad \"\" np_thru_hole circle (at 0 0) (size {d:.3} {d:.3}) (drill {d:.3}) (layers *.Cu *.Mask)", .{
        d * scale_factor,
        d * scale_factor,
        d * scale_factor,
    });
    try writer.print("(clearance 0.1) (zone_connect 0) (tstamp {s}))", .{FauxUUID.init()});

    try writer.writeAll(")\n");
}
