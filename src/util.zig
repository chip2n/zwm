const std = @import("std");
const c = @import("c.zig");

/// Check X11 status for success.
pub fn check(status: c.Status) !void {
    if (status == 0) {
        return error.XlibError;
    }
}

const XGeometry = struct {
    root: c.Window,
    x: c_int,
    y: c_int,
    width: c_uint,
    height: c_uint,
    border: c_uint,
    depth: c_uint,
};

/// Returns the root window and the current geometry of the drawable.
pub fn getGeometry(display: *c.Display, d: c.Drawable) XGeometry {
    var root: c.Window = undefined;
    var x: c_int = undefined;
    var y: c_int = undefined;
    var width: c_uint = undefined;
    var height: c_uint = undefined;
    var border_width: c_uint = undefined;
    var depth: c_uint = undefined;

    _ = c.XGetGeometry(display, d, &root, &x, &y, &width, &height, &border_width, &depth);

    return .{
        .root = root,
        .x = x,
        .y = y,
        .width = width,
        .height = height,
        .border = border_width,
        .depth = depth,
    };
}

pub fn getInputFocus(display: *c.Display) c.Window {
    var win: c.Window = undefined;
    var revert_to: c_int = undefined;
    _ = c.XGetInputFocus(display, &win, &revert_to);
    return win;
}
