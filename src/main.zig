const std = @import("std");
const c = @import("c.zig");
const x11 = @import("x11.zig");

const input = @import("input.zig");
const layout = @import("layout.zig");
const xinerama = @import("xinerama.zig");
const bar = @import("bar.zig");

const ColumnLayout = layout.ColumnLayout;
const Event = @import("event.zig").Event;

pub const log_level: std.log.Level = .debug;

const bindings = .{
    .{ "M-RET", launchTerminal },
    .{ "M-a", launchBrowser },
    .{ "M-c", closeWindow },
    .{ "M-n", focusNext },
    .{ "M-e", focusPrev },
    .{ "M-b", enableBar },
    .{ "M-1", focusMonitor0 },
    .{ "M-2", focusMonitor1 },
    .{ "M-S-1", moveToMonitor0 },
    .{ "M-S-2", moveToMonitor1 },
    .{ "M-q", exitWM },
};

const AtomType = enum {
    net_wm_window_type,
    net_wm_window_type_dock,
    net_wm_strut,
    net_wm_strut_partial,

    fn name(t: AtomType) [:0]const u8 {
        return switch (t) {
            .net_wm_window_type => "_NET_WM_WINDOW_TYPE",
            .net_wm_window_type_dock => "_NET_WM_WINDOW_TYPE_DOCK",
            .net_wm_strut => "_NET_WM_STRUT",
            .net_wm_strut_partial => "_NET_WM_STRUT_PARTIAL",
        };
    }
};

fn launchTerminal() !void {
    try launch("xterm");
}

fn launchBrowser() !void {
    try launch("google-chrome-stable");
}

fn enableBar() !void {
    // TODO size
    const win = try bar.createWindow(wm.display, wm.root, 0, 100);

    const gc = try bar.createGC(wm.display, win);
    try bar.loadFont(wm.display, gc, "fixed");
    //try bar.loadFont(wm.display, gc, "*-iosevka-*-*-*-*-*-*-*-*-*-*-*-*");

    bar.drawBar(wm.display, win, gc);
}

fn closeWindow() !void {
    if (wm.monitors[wm.focused_monitor].focused_window) |win| {
        std.log.info("Closing window {}", .{win});
        x11.destroyWindow(wm.display, win);
    }
}

fn focusMonitor0() !void {
    std.log.info("Focusing monitor 0", .{});
    wm.focused_monitor = 0;
}

fn focusMonitor1() !void {
    std.log.info("Focusing monitor 1", .{});
    wm.focused_monitor = 1;
}

fn focusNext() !void {
    const mon = &wm.monitors[wm.focused_monitor];
    const curr_win = mon.focused_window orelse return;
    std.log.info("Focus next (curr {})", .{curr_win});

    const index = std.mem.indexOfScalar(c.Window, mon.windows.items, curr_win) orelse unreachable;
    const new_win = mon.windows.items[@mod(index + 1, mon.windows.items.len)];
    focus(new_win);
}

fn focusPrev() !void {
    const mon = &wm.monitors[wm.focused_monitor];
    const curr_win = mon.focused_window orelse return;
    std.log.info("Focus prev (curr {})", .{curr_win});

    const index = std.mem.indexOfScalar(c.Window, mon.windows.items, curr_win) orelse unreachable;
    const new_win = mon.windows.items[@intCast(usize, @mod(@intCast(isize, index) - 1, @intCast(isize, mon.windows.items.len)))];
    focus(new_win);
}

fn moveToMonitor0() !void {
    const mon = &wm.monitors[wm.focused_monitor];
    const win = mon.focused_window orelse return;
    var win_state = wm.windows.getPtr(win) orelse return;
    win_state.monitor = 0;
}

fn moveToMonitor1() !void {
    const mon = &wm.monitors[wm.focused_monitor];
    const win = mon.focused_window orelse return;
    var win_state = wm.windows.getPtr(win) orelse return;
    win_state.monitor = 1;
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

    windows: std.AutoHashMap(c.Window, WindowState),

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
    windows: std.ArrayList(c.Window),
    focused_window: ?c.Window = null,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var allocator = gpa.allocator();

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const display = try x11.openDisplay(null);
    defer x11.closeDisplay(display);

    const root = x11.defaultRootWindow(display);

    wm = WindowManager{
        .allocator = allocator,
        .display = display,
        .root = root,
        .windows = std.AutoHashMap(c.Window, WindowState).init(arena.allocator()),
        .monitors = undefined,
    };

    x11.setErrorHandler(onWMDetected);
    x11.selectInput(
        display,
        root,
        .{
            .substructure_redirect = true,
            .substructure_notify = true,
            .key_press = true,
        },
    );
    x11.sync(display, false);

    if (wm.wm_detected) {
        std.log.err("Detected another window manager on display {s}", .{x11.displayString(display)});
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
            wm.monitors[i] = .{ .info = info, .windows = std.ArrayList(c.Window).init(arena.allocator()) };
        }
    }

    x11.setErrorHandler(onXError);

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
        const e = x11.nextEvent(display);

        var ev = Event.fromNative(e);
        std.log.debug("Received event: {s}\n{?}", .{ @tagName(ev.data), ev });
        defer std.log.info("------------", .{});

        switch (ev.data) {
            .create_notify => |d| {
                std.log.info("Adding window {}", .{d.window});
                try wm.windows.put(d.window, .{ .window = d.window, .monitor = wm.focused_monitor });
                try wm.monitors[wm.focused_monitor].windows.append(d.window);
            },
            .destroy_notify => |d| {
                std.log.info("Destroying window {}", .{d.window});

                const win_state = wm.windows.get(d.window) orelse unreachable;
                var was_removed = wm.windows.remove(d.window);
                std.debug.assert(was_removed);

                var monitor_windows = &wm.monitors[win_state.monitor].windows;
                const index = std.mem.indexOfScalar(c.Window, monitor_windows.items, d.window) orelse unreachable;
                _ = monitor_windows.orderedRemove(index);

                // Focus next window
                const was_focused = wm.monitors[win_state.monitor].focused_window == d.window;
                if (was_focused and monitor_windows.items.len > 0) {
                    const new_index = @min(index, monitor_windows.items.len - 1);
                    focus(monitor_windows.items[new_index]);
                }

                updateWindowTiles();
            },
            .focus_in => |d| {
                std.log.info("Focusing window: {}", .{d.window});
                if (d.mode == c.NotifyGrab) continue;
                if (findMonitorForWindow(d.window)) |mon| {
                    if (d.window != wm.monitors[mon].focused_window) {
                        if (wm.monitors[mon].focused_window) |w| {
                            unfocus(w);
                        }
                        wm.monitors[mon].focused_window = d.window;
                        std.log.info("Monitor {} is now focusing {?}", .{ mon, wm.monitors[mon].focused_window });
                        focus(d.window);
                        //wm.focused_monitor = mon;
                    }
                }
            },
            .focus_out => |d| {
                std.log.info("Unfocusing window: {}", .{d.window});
                //unfocus(d.window);
            },
            .enter_notify => |d| {
                std.log.info("ENTER {}", .{d.window});
                //focus(d.window);
            },
            .configure_request => |d| onConfigureRequest(&d),
            .map_request => |d| try onMapRequest(&d),
            .key_press => |d| try onKeyPress(&d),
            else => {},
        }
    }
}

fn focus(win: c.Window) void {
    std.log.info("Setting focus: {}", .{win});
    x11.setWindowBorder(wm.display, win, 0xff0000);

    var changes: x11.WindowChanges = undefined;
    changes.border_width = 1;
    x11.configureWindow(wm.display, win, .{ .border_width = true }, &changes);
    x11.setInputFocus(wm.display, win, .revert_to_pointer_root, x11.CurrentTime);
}

fn unfocus(win: c.Window) void {
    x11.setWindowBorder(wm.display, win, 0xffffff);
    //_ = c.XSetInputFocus(wm.display, wm.root, c.RevertToPointerRoot, c.CurrentTime);
}

fn findMonitorForWindow(win: c.Window) ?usize {
    var i: usize = 0;
    while (i < wm.monitors.len) : (i += 1) {
        const mon = wm.monitors[i];
        const index = std.mem.indexOfScalar(c.Window, mon.windows.items, win);
        if (index != null) return i;
    }
    return null;
}

const WindowIterator = struct {
    monitor: usize,
    index: usize,

    fn next(self: *@This()) ?*WindowState {
        const monitor = wm.monitors[self.monitor];
        if (self.index >= monitor.windows.items.len) return null;
        const win = wm.windows.getPtr(monitor.windows.items[self.index]);
        self.index += 1;
        return win;
    }
};

fn monitorWindowIterator(monitor: usize) WindowIterator {
    return .{ .monitor = monitor, .index = 0 };
}

fn updateWindowTiles() void {
    for (wm.monitors) |monitor, monitor_index| {
        // TODO
        // There may be a dock on this monitor; we need to find it and figure out
        // how much space we have left
        //monitor.windows.items

        const width = monitor.info.width;
        const height = monitor.info.height;

        var iter = monitorWindowIterator(monitor_index);

        const tiles = wm.layout_state.tile(wm.allocator, width, height, monitor.windows.items.len) catch unreachable;
        for (tiles) |t| {
            const win = iter.next().?;
            if (win.monitor != monitor_index) continue;
            x11.moveResizeWindow(
                wm.display,
                win.window,
                @intCast(i32, monitor.info.x_org + t.x),
                @intCast(i32, monitor.info.y_org + t.y),
                t.w,
                t.h,
            );
        }
    }
}

// Since window is still invisible at this point, we grant configure requests
// without modification
fn onConfigureRequest(e: *const c.XConfigureRequestEvent) void {
    var changes = x11.WindowChanges{
        .x = e.x,
        .y = e.y,
        .width = e.width,
        .height = e.height,
        .border_width = e.border_width,
        .sibling = e.above,
        .stack_mode = e.detail,
    };
    const flags = @bitCast(x11.ConfigureWindowFlags, @intCast(c_uint, e.value_mask));
    x11.configureWindow(wm.display, e.window, flags, &changes);

    updateWindowTiles();
}

fn onMapRequest(e: *const c.XMapRequestEvent) !void {
    std.log.info("map request {}", .{e.window});
    x11.mapWindow(wm.display, e.window);
    x11.selectInput(wm.display, e.window, .{ .enter_window = true, .focus_change = true });
    focus(e.window);
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

fn onWMDetected(display: *x11.Display, e: *x11.ErrorEvent) void {
    _ = display;
    std.debug.assert(e.error_code == c.BadAccess);
    wm.wm_detected = true;
}

fn onXError(display: *x11.Display, e: *x11.ErrorEvent) void {
    var buf: [1024]u8 = undefined;
    const text = x11.getErrorText(display, e.error_code, &buf);
    std.log.err("X11 error: {s}", .{text});
}

test {
    _ = @import("input.zig");
}
