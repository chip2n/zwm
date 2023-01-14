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
    .{ "M-1", focusMonitor0 },
    .{ "M-2", focusMonitor1 },
    .{ "M-S-1", moveToMonitor0 },
    .{ "M-S-2", moveToMonitor1 },
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
    const win = wm.windows.items[0].window;
    std.log.info("Closing window {}", .{win});

    _ = c.XDestroyWindow(wm.display, win);
}

fn focusWindow() !void {
    const window = wm.windows.items[0].window;
    std.log.info("Attempt manual focus for window {}", .{window});
    _ = c.XSetInputFocus(wm.display, window, c.RevertToParent, c.CurrentTime);
}

fn focusMonitor0() !void {
    wm.focused_monitor = 0;
}

fn focusMonitor1() !void {
    wm.focused_monitor = 1;
}

fn moveToMonitor0() !void {
    const win_index = wm.focused_window orelse return;
    var win = wm.windows.items[win_index];
    win.monitor = 0;
}

fn moveToMonitor1() !void {
    const win_index = wm.focused_window orelse return;
    var win = wm.windows.items[win_index];
    win.monitor = 1;
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

    windows: std.ArrayList(WindowState),
    focused_window: ?usize = null,

    monitors: []MonitorState,
    focused_monitor: usize = 0,

    layout_state: ColumnLayout = ColumnLayout{},
};

const WindowState = struct {
    window: c.Window,
    monitor: usize,
};

const MonitorState = struct {
    info: xinerama.ScreenInfo,
    windows: std.ArrayList(usize),
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var allocator = gpa.allocator();

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

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
        .windows = std.ArrayList(WindowState).init(allocator),
        .monitors = undefined,
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

    {
        const monitors = try xinerama.queryScreens(allocator, wm.display);
        defer allocator.free(monitors);

        wm.monitors = try arena.allocator().alloc(MonitorState, monitors.len);

        for (monitors) |info, i| {
            std.log.info("Monitor {}: {}x{}:{}x{}", .{
                info.screen_number,
                info.x_org,
                info.y_org,
                info.width,
                info.height,
            });
            wm.monitors[i] = .{ .info = info, .windows = std.ArrayList(usize).init(arena.allocator()) };
        }
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
        std.log.debug("Received event: {s}\n{?}", .{ @tagName(ev.data), ev });

        switch (ev.data) {
            .create_notify => |d| {
                std.log.info("Adding window {}", .{d.window});
                try wm.windows.append(.{ .window = d.window, .monitor = wm.focused_monitor });
                try wm.monitors[wm.focused_monitor].windows.append(wm.windows.items.len - 1);
            },
            .destroy_notify => |d| {
                std.log.info("Destroying window {}", .{d.window});
                { // Remove from window list
                    var i: usize = 0;
                    while (i < wm.windows.items.len) : (i += 1) {
                        const win_state = wm.windows.items[i];
                        if (win_state.window == d.window) {
                            _ = wm.windows.orderedRemove(i);

                            // Remove from monitors window list
                            var monitor = wm.monitors[win_state.monitor];
                            const win_index = std.mem.indexOfScalar(usize, monitor.windows.items, i);
                            if (win_index) |w| {
                                _ = monitor.windows.orderedRemove(w);
                            }

                            break;
                        }
                    }
                }

                updateWindowTiles();
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

const WindowIterator = struct {
    monitor: usize,
    index: usize,

    fn next(self: *@This()) ?WindowState {
        const monitor = wm.monitors[self.monitor];
        if (self.index >= monitor.windows.items.len) return null;
        const win = wm.windows.items[monitor.windows.items[self.index]];
        self.index += 1;
        return win;
    }
};

fn monitorWindowIterator(monitor: usize) WindowIterator {
    return .{ .monitor = monitor, .index = 0 };
}

fn updateWindowTiles() void {
    for (wm.monitors) |monitor, monitor_index| {
        const width = monitor.info.width;
        const height = monitor.info.height;

        var iter = monitorWindowIterator(monitor_index);

        const tiles = wm.layout_state.tile(wm.allocator, width, height, monitor.windows.items.len) catch unreachable;
        for (tiles) |t| {
            const win = iter.next().?;
            if (win.monitor != monitor_index) continue;
            _ = c.XMoveResizeWindow(
                wm.display,
                win.window,
                @intCast(c_int, monitor.info.x_org + t.x),
                @intCast(c_int, monitor.info.y_org + t.y),
                @intCast(c_uint, t.w),
                @intCast(c_uint, t.h),
            );
        }
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
