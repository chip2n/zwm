const std = @import("std");
const util = @import("util.zig");
const x11 = @import("c.zig");

const Event = @import("event.zig").Event;

var wm: WindowManager = undefined;

const WindowManager = struct {
    allocator: std.mem.Allocator,
    display: *x11.Display,
    root: x11.Window,
    wm_detected: bool = false,
    clients: std.AutoHashMap(x11.Window, x11.Window),
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var allocator = gpa.allocator();

    const display = x11.XOpenDisplay(null) orelse {
        std.log.err("Unable to open X11 display {s}", .{x11.XDisplayName(null)});
        return error.X11InitFailed;
    };
    defer _ = x11.XCloseDisplay(display);

    const root = x11.DefaultRootWindow(display);

    wm = WindowManager{
        .allocator = allocator,
        .display = display,
        .root = root,
        .clients = std.AutoHashMap(x11.Window, x11.Window).init(allocator),
    };

    _ = x11.XSetErrorHandler(onWMDetected);

    _ = x11.XSelectInput(
        display,
        root,
        x11.SubstructureRedirectMask | x11.SubstructureNotifyMask | x11.KeyPressMask,
    );
    _ = x11.XSync(display, 0);

    if (wm.wm_detected) {
        std.log.err("Detected another window manager on display {s}", .{x11.XDisplayString(display)});
        return error.X11InitFailed;
    }

    std.log.info("Window manager initialized", .{});

    _ = x11.XSetErrorHandler(onXError);

    { // Handle any existing top-level windows that are already mapped
        _ = x11.XGrabServer(wm.display);
        defer _ = x11.XUngrabServer(wm.display);

        var returned_root: x11.Window = undefined;
        var returned_parent: x11.Window = undefined;
        var top_level_windows: [*c]x11.Window = undefined;
        var num_top_level_windows: c_uint = undefined;
        try util.check(x11.XQueryTree(
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
        _ = x11.XFree(top_level_windows);
    }

    while (true) {
        var e: x11.XEvent = undefined;
        _ = x11.XNextEvent(display, &e);

        var ev = Event.fromNative(e);
        std.log.debug("Received event: {s}\n{s}", .{@tagName(ev.type), try ev.toString(allocator)});

        switch (e.type) {
            x11.CreateNotify => onCreateNotify(&e.xcreatewindow),
            x11.ConfigureRequest => onConfigureRequest(&e.xconfigurerequest),
            x11.ConfigureNotify => onConfigureNotify(&e.xconfigure),
            x11.MapRequest => try onMapRequest(&e.xmaprequest),
            x11.MapNotify => onMapNotify(&e.xmap),
            x11.UnmapNotify => onUnmapNotify(&e.xunmap),
            x11.DestroyNotify => return,
            x11.ReparentNotify => onReparentNotify(&e.xreparent),
            x11.KeyPress => try onKeyPress(&e.xkey),
            else => {},
        }
    }
}

// Newly created windows are always invisible, so there's nothing for us to do.
fn onCreateNotify(e: *const x11.XCreateWindowEvent) void {
    _ = e;
}

fn onReparentNotify(e: *const x11.XReparentEvent) void {
    _ = e;
}

fn onMapNotify(e: *const x11.XMapEvent) void {
    _ = e;
}

fn onUnmapNotify(e: *const x11.XUnmapEvent) void {
    const frame = wm.clients.get(e.window) orelse {
        std.log.info("Ignore UnmapNotify for non-client window {}", .{e.window});
        return;
    };

    _ = x11.XUnmapWindow(wm.display, frame);
    _ = x11.XReparentWindow(
        wm.display,
        e.window,
        wm.root,
        0,
        0,
    );
    _ = x11.XRemoveFromSaveSet(wm.display, e.window);
    _ = x11.XDestroyWindow(wm.display, frame);
    _ = wm.clients.remove(e.window);

    std.log.info("Unframed window {} [{}]", .{ e.window, frame });
}

// Since window is still invisible at this point, we grant configure requests
// without modification
fn onConfigureRequest(e: *const x11.XConfigureRequestEvent) void {
    var changes = std.mem.zeroes(x11.XWindowChanges);
    changes.x = e.x;
    changes.y = e.y;
    changes.width = e.width;
    changes.height = e.height;
    changes.border_width = e.border_width;
    changes.sibling = e.above;
    changes.stack_mode = e.detail;

    // Resize corresponding frame in the same way
    if (wm.clients.get(e.window)) |frame| {
        _ = x11.XConfigureWindow(wm.display, frame, @intCast(c_uint, e.value_mask), &changes);
    }

    _ = x11.XConfigureWindow(wm.display, e.window, @intCast(c_uint, e.value_mask), &changes);
    std.log.info("Resize {} to ({}x{})", .{ e.window, e.width, e.height });
}

fn onConfigureNotify(e: *const x11.XConfigureEvent) void {
    _ = e;
}

fn onMapRequest(e: *const x11.XMapRequestEvent) !void {
    try frame_window(e.window, false);
    _ = x11.XMapWindow(wm.display, e.window);
}

fn frame_window(w: x11.Window, created_before_wm: bool) !void {
    const border_width = 3;
    const border_color = 0xff0000;
    const bg_color = 0x0000ff;

    var x_window_attrs: x11.XWindowAttributes = undefined;
    try util.check(x11.XGetWindowAttributes(wm.display, w, &x_window_attrs));

    // If window was created before wm started, we should frame it only if it is
    // visible and doesn't set override_redirect
    if (created_before_wm) {
        if (x_window_attrs.override_redirect == 1 or x_window_attrs.map_state != x11.IsViewable) {
            return;
        }
    }

    const frame = x11.XCreateSimpleWindow(
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
    _ = x11.XSelectInput(
        wm.display,
        frame,
        x11.SubstructureRedirectMask | x11.SubstructureNotifyMask,
    );
    _ = x11.XAddToSaveSet(wm.display, w);
    _ = x11.XReparentWindow(
        wm.display,
        w,
        frame,
        0,
        0,
    );
    _ = x11.XMapWindow(wm.display, frame);
    try wm.clients.put(w, frame);

    // TODO We may need to grab the final keybindings for all windows
    // _ = x11.XGrabKey(
    //     wm.display,
    //     x11.XKeysymToKeycode(wm.display, x11.XK_A),
    //     x11.AnyModifier, // TODO or 0?
    //     w,
    //     0,
    //     x11.GrabModeAsync,
    //     x11.GrabModeAsync,
    // );

    std.log.info("Framed window {} [{}]", .{ w, frame });
}

fn onKeyPress(e: *const x11.XKeyEvent) !void {
    std.log.info("Key pressed", .{});
    if ((e.keycode == x11.XKeysymToKeycode(wm.display, x11.XK_A))) {
        std.log.info("Key pressed2", .{});
        var process = std.ChildProcess.init(&.{"xterm"}, wm.allocator);
        try process.spawn();
    }
}

fn onWMDetected(display: ?*x11.Display, e: [*c]x11.XErrorEvent) callconv(.C) c_int {
    _ = display;
    std.debug.assert(e.*.error_code == x11.BadAccess);
    wm.wm_detected = true;
    return 0;
}

fn onXError(display: ?*x11.Display, e: [*c]x11.XErrorEvent) callconv(.C) c_int {
    _ = display;
    var text: [1024]u8 = undefined;
    _ = x11.XGetErrorText(wm.display, e.*.error_code, &text, text.len);
    std.log.err("X11 error: {s}", .{std.mem.sliceTo(&text, 0)});
    return 0;
}
