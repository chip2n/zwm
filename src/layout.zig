const std = @import("std");
const x11 = @import("x11.zig");

/// The golden ratio is used to get a good default tile size (main window
/// occupies more space than secondary windows)
const golden_ratio = 1.61803398875;

const Tile = struct { x: u32, y: u32, w: u32, h: u32 };

pub const ColumnLayout = struct {
    pub fn tile(
        self: @This(),
        allocator: std.mem.Allocator,
        screen_w: u32,
        screen_h: u32,
        count: usize,
    ) ![]Tile {
        _ = self;

        if (count == 0) return &.{};

        const tiles = try allocator.alloc(Tile, count);
        errdefer allocator.free(tiles);

        const main_w = @floatToInt(u32, @intToFloat(f32, screen_w) / golden_ratio);
        const side_w = screen_w - main_w;

        // Layout main window
        if (tiles.len == 1) {
            tiles[0] = Tile{ .x = 0, .y = 0, .w = screen_w, .h = screen_h };
        } else {
            tiles[0] = Tile{ .x = 0, .y = 0, .w = main_w, .h = screen_h };
        }

        // Layout side windows (if any)
        const side_tiles = tiles[1..];
        if (side_tiles.len > 0) {
            const side_h = @intCast(u32, screen_h / side_tiles.len);
            for (side_tiles) |*t, i| {
                t.* = Tile{ .x = main_w, .y = @intCast(u32, i) * side_h, .w = side_w, .h = side_h };
            }
        }

        return tiles;
    }
};
