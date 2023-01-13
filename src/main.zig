const std = @import("std");
const util = @import("util.zig");
const c = @import("c.zig");
const input = @import("input.zig");
const layout = @import("layout.zig");
const xinerama = @import("xinerama.zig");

const ColumnLayout = layout.ColumnLayout;
const Event = @import("event.zig").Event;

pub const log_level: std.log.Level = .info;

const bindings = .{
    .{ "M-RET", launchTerminal },
    .{ "M-a", launchBrowser },
    .{ "M-c", closeWindow },
    .{ "M-f", focusWindow },
    .{ "M-q", exitWM },
};

fn launchTerminal() !void {
    try launch("xterm");
}

fn launchBrowser() !void {
    try launch("google-chrome-stable");
}

fn closeWindow() !void {
    //const win = util.getInputFocus(wm.display);
    const win = wm.windows.items[0];
    std.log.info("Closing window {}", .{win});

    _ = c.XDestroyWindow(wm.display, win);
}

fn focusWindow() !void {
    const window = wm.windows.items[0];
    std.log.info("Attempt manual focus for window {}", .{window});
    _ = c.XSetInputFocus(wm.display, window, c.RevertToParent, c.CurrentTime);
}

fn exitWM() !void {
    wm.finished = true;
}

fn launch(cmd: []const u8) !void {
    var process = std.ChildProcess.init(&.{cmd}, wm.allocator);
    try process.spawn();
}

var wm: WindowManager = undefined;

const WindowManager = struct {
    allocator: std.mem.Allocator,
    display: *c.Display,
    root: c.Window,
    wm_detected: bool = false,
    finished: bool = false,

    windows: std.ArrayList(c.Window),
    focused_window: ?usize = null,
    layout_state: ColumnLayout = ColumnLayout{},
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
        .windows = std.ArrayList(c.Window).init(allocator),
    };

    _ = c.XSetErrorHandler(onWMDetected);
    _ = c.XSelectInput(
        display,
        root,
        c.SubstructureRedirectMask | c.SubstructureNotifyMask | c.KeyPressMask | c.FocusChangeMask,
    );
    _ = c.XSync(display, 0);

    if (wm.wm_detected) {
        std.log.err("Detected another window manager on display {s}", .{c.XDisplayString(display)});
        return error.X11InitFailed;
    }

    std.log.info("Window manager initialized (root window {})", .{root});

    // Xinerama
    if (!xinerama.isActive(wm.display)) {
        std.log.err("Xinerama not activated.", .{});
        return error.XineramaNotActive;
    }
    const monitor_info = try xinerama.queryScreens(allocator, wm.display);
    defer allocator.free(monitor_info);
    for (monitor_info) |info| {
        std.log.info("Monitor {}: {}x{}:{}x{}", .{
            info.screen_number,
            info.x_org,
            info.y_org,
            info.width,
            info.height,
        });
    }

    _ = c.XSetErrorHandler(onXError);

    // Grab all bindings in root window
    inline for (bindings) |binding| {
        input.grabKey(wm.display, wm.root, binding[0]);
    }

    // { // Handle any existing top-level windows that are already mapped
    //     _ = c.XGrabServer(wm.display);
    //     defer _ = c.XUngrabServer(wm.display);

    //     var returned_root: c.Window = undefined;
    //     var returned_parent: c.Window = undefined;
    //     var top_level_windows: [*c]c.Window = undefined;
    //     var num_top_level_windows: c_uint = undefined;
    //     try util.check(c.XQueryTree(
    //         wm.display,
    //         wm.root,
    //         &returned_root,
    //         &returned_parent,
    //         &top_level_windows,
    //         &num_top_level_windows,
    //     ));
    //     std.debug.assert(returned_root == wm.root);
    //     var i: usize = 0;
    //     while (i < num_top_level_windows) : (i += 1) {
    //         try frame_window(top_level_windows[i], true);
    //     }
    //     _ = c.XFree(top_level_windows);
    // }

    while (!wm.finished) {
        var e: c.XEvent = undefined;
        _ = c.XNextEvent(display, &e);

        var ev = Event.fromNative(e);
        std.log.debug("Received event: {s}\n{s}", .{ @tagName(ev.data), try ev.toString(allocator) });

        switch (ev.data) {
            .create_notify => |d| {
                std.log.info("Adding window {}", .{d.window});
                try wm.windows.append(d.window);
            },
            .destroy_notify => |d| {
                std.log.info("Destroying window {}", .{d.window});
                var i: usize = 0;
                while (i < wm.windows.items.len) : (i += 1) {
                    if (wm.windows.items[i] == d.window) {
                        _ = wm.windows.orderedRemove(i);
                        updateWindowTiles();
                        break;
                    }
                }
            },
            .focus_in => |d| {
                std.log.info("Focusing window: {}", .{d.window});
            },
            .focus_out => |d| {
                std.log.info("Unfocusing window: {}", .{d.window});
            },
            .configure_request => |d| onConfigureRequest(&d),
            .map_request => |d| try onMapRequest(&d),
            .key_press => |d| try onKeyPress(&d),
            else => {},
        }

        std.log.debug("------------", .{});
    }
}

fn updateWindowTiles() void {
    const root_geo = util.getGeometry(wm.display, wm.root);
    const tiles = wm.layout_state.tile(wm.allocator, root_geo.width, root_geo.height, wm.windows.items.len) catch unreachable;
    for (tiles) |t, i| {
        const win = wm.windows.items[i];
        _ = c.XMoveResizeWindow(
            wm.display,
            win,
            @intCast(c_int, t.x),
            @intCast(c_int, t.y),
            @intCast(c_uint, t.w),
            @intCast(c_uint, t.h),
        );
    }
}

// Since window is still invisible at this point, we grant configure requests
// without modification
fn onConfigureRequest(e: *const c.XConfigureRequestEvent) void {
    var changes = c.XWindowChanges{
        .x = e.x,
        .y = e.y,
        .width = e.width,
        .height = e.height,
        .border_width = e.border_width,
        .sibling = e.above,
        .stack_mode = e.detail,
    };
    _ = c.XConfigureWindow(wm.display, e.window, @intCast(c_uint, e.value_mask), &changes);

    updateWindowTiles();
}

fn onMapRequest(e: *const c.XMapRequestEvent) !void {
    // _ = c.XGrabKey(
    //     wm.display,
    //     c.XKeysymToKeycode(wm.display, c.XK_A),
    //     c.Mod1Mask,
    //     e.window,
    //     0,
    //     c.GrabModeAsync,
    //     c.GrabModeAsync,
    // );
    _ = c.XMapWindow(wm.display, e.window);
}

fn onKeyPress(e: *const c.XKeyEvent) !void {
    inline for (bindings) |binding| {
        if (input.pressed(wm.display, e, binding[0])) {
            try binding[1]();
        }
    }
    // if (input.pressed(wm.display, e, "M-RET")) {
    //     var process = std.ChildProcess.init(&.{"xterm"}, wm.allocator);
    //     try process.spawn();
    // }

    // if (input.pressed(wm.display, e, "M-a")) {
    //     var process = std.ChildProcess.init(&.{"xfontsel"}, wm.allocator);
    //     try process.spawn();
    // }
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

test {
    _ = @import("input.zig");
}
