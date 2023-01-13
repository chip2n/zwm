const c = @import("c.zig");
const std = @import("std");

pub const ScreenInfo = struct {
    screen_number: u32,
    x_org: u16,
    y_org: u16,
    width: u16,
    height: u16,
};

pub fn isActive(display: *c.Display) bool {
    const active = c.XineramaIsActive(display);
    return active != 0;
}

/// Returns information about all existing screens.
/// The caller owns the returned memory.
pub fn queryScreens(allocator: std.mem.Allocator, display: *c.Display) ![]ScreenInfo {
    var monitor_count: c_int = undefined;
    var monitor_info = c.XineramaQueryScreens(display, &monitor_count);
    defer _ = c.XFree(monitor_info);

    const result = try allocator.alloc(ScreenInfo, @intCast(usize, monitor_count));
    errdefer allocator.free(result);
    for (monitor_info[0..@intCast(usize, monitor_count)]) |info, i| {
        result[i] = ScreenInfo{
            .screen_number = @intCast(u32, info.screen_number),
            .x_org = @intCast(u16, info.x_org),
            .y_org = @intCast(u16, info.y_org),
            .width = @intCast(u16, info.width),
            .height = @intCast(u16, info.height),
        };
    }
    return result;
}
