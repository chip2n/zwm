const std = @import("std");
const util = @import("util.zig");
const c = @import("c.zig");

const Event = @import("event.zig").Event;

var wm: WindowManager = undefined;

const WindowManager = struct {
    allocator: std.mem.Allocator,
    display: *c.Display,
    root: c.Window,
    wm_detected: bool = false,
    clients: std.AutoHashMap(c.Window, c.Window),
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var allocator = gpa.allocator();

    const display = c.XOpenDisplay(null) orelse {
        std.log.err("Unable to open X11 display {s}", .{c.XDisplayName(null)});
        return error.X11InitFailed;
    };
    defer _ = c.XCloseDisplay(display);

    const root = c.DefaultRootWindow(display);

    wm = WindowManager{
        .allocator = allocator,
        .display = display,
        .root = root,
        .clients = std.AutoHashMap(c.Window, c.Window).init(allocator),
    };

    _ = c.XSetErrorHandler(onWMDetected);

    _ = c.XSelectInput(
        display,
        root,
        c.SubstructureRedirectMask | c.SubstructureNotifyMask | c.KeyPressMask,
    );
    _ = c.XSync(display, 0);

    if (wm.wm_detected) {
        std.log.err("Detected another window manager on display {s}", .{c.XDisplayString(display)});
        return error.X11InitFailed;
    }

    std.log.info("Window manager initialized", .{});

    _ = c.XSetErrorHandler(onXError);

    { // Handle any existing top-level windows that are already mapped
        _ = c.XGrabServer(wm.display);
        defer _ = c.XUngrabServer(wm.display);

        var returned_root: c.Window = undefined;
        var returned_parent: c.Window = undefined;
        var top_level_windows: [*c]c.Window = undefined;
        var num_top_level_windows: c_uint = undefined;
        try util.check(c.XQueryTree(
            wm.display,
            wm.root,
            &returned_root,
            &returned_parent,
            &top_level_windows,
            &num_top_level_windows,
        ));
        std.debug.assert(returned_root == wm.root);
        var i: usize = 0;
        while (i < num_top_level_windows) : (i += 1) {
            try frame_window(top_level_windows[i], true);
        }
        _ = c.XFree(top_level_windows);
    }

    while (true) {
        var e: c.XEvent = undefined;
        _ = c.XNextEvent(display, &e);

        var ev = Event.fromNative(e);
        std.log.debug("Received event: {s}\n{s}", .{ @tagName(ev.data), try ev.toString(allocator) });

        switch (ev.data) {
            .create_notify => |d| onCreateNotify(&d),
            .configure_request => |d| onConfigureRequest(&d),
            .configure_notify => |d| onConfigureNotify(&d),
            .map_request => |d| try onMapRequest(&d),
            .map_notify => |d| onMapNotify(&d),
            .unmap_notify => |d| try onUnmapNotify(&d),
            .destroy_notify => |d| onDestroyNotify(&d),
            .reparent_notify => |d| onReparentNotify(&d),
            .key_press => |d| try onKeyPress(&d),
            else => {},
        }

        std.log.debug("------------", .{});
    }
}

// Newly created windows are always invisible, so there's nothing for us to do.
fn onCreateNotify(e: *const c.XCreateWindowEvent) void {
    _ = e;
}

fn onDestroyNotify(e: *const c.XDestroyWindowEvent) void {
    _ = e;
}

fn onReparentNotify(e: *const c.XReparentEvent) void {
    _ = e;
}

fn onMapNotify(e: *const c.XMapEvent) void {
    _ = e;
}

fn onUnmapNotify(e: *const c.XUnmapEvent) !void {
    // If we don't manage the window, we'll ignore this event (we receive
    // UnmapNotify events for frame windows we've destroyed ourselves)
    const frame = wm.clients.get(e.window) orelse {
        std.log.info("Ignore UnmapNotify for non-client window {}", .{e.window});
        return;
    };

    // Ignore event if it is triggered by reparenting a window that was mapped
    // before the wm started.
    if (e.event == wm.root) {
        std.log.info("Ignore UnmapNotify for reparented pre-existing window {}", .{e.window});
        return;
    }

    _ = c.XUnmapWindow(wm.display, frame);
    _ = c.XReparentWindow(
        wm.display,
        e.window,
        wm.root,
        0,
        0,
    );
    _ = c.XRemoveFromSaveSet(wm.display, e.window);
    _ = c.XDestroyWindow(wm.display, frame);
    _ = wm.clients.remove(e.window);

    std.log.info("Unframed window {} [{}]", .{ e.window, frame });
}

// Since window is still invisible at this point, we grant configure requests
// without modification
fn onConfigureRequest(e: *const c.XConfigureRequestEvent) void {
    var changes = std.mem.zeroes(c.XWindowChanges);
    changes.x = e.x;
    changes.y = e.y;
    changes.width = e.width;
    changes.height = e.height;
    changes.border_width = e.border_width;
    changes.sibling = e.above;
    changes.stack_mode = e.detail;

    // Resize corresponding frame in the same way
    if (wm.clients.get(e.window)) |frame| {
        _ = c.XConfigureWindow(wm.display, frame, @intCast(c_uint, e.value_mask), &changes);
    }

    _ = c.XConfigureWindow(wm.display, e.window, @intCast(c_uint, e.value_mask), &changes);
    std.log.info("Resize {} to ({}x{})", .{ e.window, e.width, e.height });
}

fn onConfigureNotify(e: *const c.XConfigureEvent) void {
    _ = e;
}

fn onMapRequest(e: *const c.XMapRequestEvent) !void {
    try frame_window(e.window, false);
    _ = c.XMapWindow(wm.display, e.window);
}

fn frame_window(w: c.Window, created_before_wm: bool) !void {
    const border_width = 3;
    const border_color = 0xff0000;
    const bg_color = 0x0000ff;

    var x_window_attrs: c.XWindowAttributes = undefined;
    try util.check(c.XGetWindowAttributes(wm.display, w, &x_window_attrs));

    // If window was created before wm started, we should frame it only if it is
    // visible and doesn't set override_redirect
    if (created_before_wm) {
        if (x_window_attrs.override_redirect == 1 or x_window_attrs.map_state != c.IsViewable) {
            return;
        }
    }

    const frame = c.XCreateSimpleWindow(
        wm.display,
        wm.root,
        x_window_attrs.x,
        x_window_attrs.y,
        @intCast(c_uint, x_window_attrs.width),
        @intCast(c_uint, x_window_attrs.height),
        border_width,
        border_color,
        bg_color,
    );
    _ = c.XSelectInput(
        wm.display,
        frame,
        c.SubstructureRedirectMask | c.SubstructureNotifyMask,
    );
    _ = c.XAddToSaveSet(wm.display, w);
    _ = c.XReparentWindow(
        wm.display,
        w,
        frame,
        0,
        0,
    );
    _ = c.XMapWindow(wm.display, frame);
    try wm.clients.put(w, frame);

    // TODO We may need to grab the final keybindings for all windows
    // _ = c.XGrabKey(
    //     wm.display,
    //     c.XKeysymToKeycode(wm.display, c.XK_A),
    //     c.AnyModifier, // TODO or 0?
    //     w,
    //     0,
    //     c.GrabModeAsync,
    //     c.GrabModeAsync,
    // );

    std.log.info("Framed window {} [{}]", .{ w, frame });
}

fn onKeyPress(e: *const c.XKeyEvent) !void {
    std.log.info("Key pressed", .{});
    if ((e.keycode == c.XKeysymToKeycode(wm.display, c.XK_A))) {
        std.log.info("Key pressed2", .{});
        var process = std.ChildProcess.init(&.{"xterm"}, wm.allocator);
        try process.spawn();
    }
}

fn onWMDetected(display: ?*c.Display, e: [*c]c.XErrorEvent) callconv(.C) c_int {
    _ = display;
    std.debug.assert(e.*.error_code == c.BadAccess);
    wm.wm_detected = true;
    return 0;
}

fn onXError(display: ?*c.Display, e: [*c]c.XErrorEvent) callconv(.C) c_int {
    _ = display;
    var text: [1024]u8 = undefined;
    _ = c.XGetErrorText(wm.display, e.*.error_code, &text, text.len);
    std.log.err("X11 error: {s}", .{std.mem.sliceTo(&text, 0)});
    return 0;
}
