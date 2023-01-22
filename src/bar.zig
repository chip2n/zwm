const c = @import("c.zig");
const x11 = @import("x11.zig");

const bar_height = 30;

pub fn createGC(display: *c.Display, win: c.Window) !c.GC {
    var values: c.XGCValues = undefined;
    var gc: c.GC = c.XCreateGC(display, win, 0, &values);
    //if (gc < 0) return error.CreateGCFailed;

    const screen_num = c.DefaultScreen(display);
    _ = c.XSetForeground(display, gc, c.WhitePixel(display, screen_num));
    _ = c.XSetBackground(display, gc, c.BlackPixel(display, screen_num));

    const line_width = 2;
    const line_style = c.LineSolid;
    const cap_style = c.CapButt;
    const join_style = c.JoinBevel;
    _ = c.XSetLineAttributes(display, gc, line_width, line_style, cap_style, join_style);
    _ = c.XSetFillStyle(display, gc, c.FillSolid);
    return gc;
}

pub fn createWindow(display: *c.Display, root: c.Window, start_x: u32, end_x: u32) !c.Window {
    _ = start_x;
    _ = end_x;
    const screen_num = c.DefaultScreen(display);
    const win = x11.createSimpleWindow(
        display,
        root,
        0,
        0,
        250,
        bar_height,
        0, // border width
        c.BlackPixel(display, screen_num), // border color
        0xff0000 // background color
    );

    const atom_strut = x11.internAtom(display, "_NET_WM_STRUT", false);

    // Set window type (dock)
    // _ = c.XChangeProperty(
    //     wm.display,
    //     win,
    //     atom(.net_wm_window_type),
    //     c.XA_ATOM,
    //     32,
    //     c.PropModeReplace,
    //     @ptrCast([*c]const u8, &atom(.net_wm_window_type_dock)),
    //     1,
    // );

    // TODO WM needs to watch this property and update accordingly
    // Set strut properties
    const width = 200;
    const strut: [12]u64 = .{ 0, 0, 50, 0, 0, 0, 0, 0, 0, width, 0, 0 };
    x11.replaceCardinalProperty(u64, display, win, atom_strut, &strut);

    // const strut: [12]c_long = .{ 0, 0, 50, 0, 0, 0, 0, 0, 0, width, 0, 0 };
    // _ = c.XChangeProperty(
    //     wm.display,
    //     win,
    //     atom(.net_wm_strut),
    //     c.XA_CARDINAL,
    //     32,
    //     c.PropModeReplace,
    //     @ptrCast([*c]const u8, &strut),
    //     4,
    // );
    // _ = c.XChangeProperty(
    //     wm.display,
    //     win,
    //     atom(.net_wm_strut_partial),
    //     c.XA_CARDINAL,
    //     32,
    //     c.PropModeReplace,
    //     @ptrCast([*c]const u8, &strut),
    //     12,
    // );

    x11.mapWindow(display, win);
    x11.flush(display);
    return win;
}

pub fn drawBar(display: *c.Display, win: c.Window, gc: c.GC) void {
//    _ = c.XFillRectangle(display, win, gc, 0, 0, 200, 40);
    const s = "Hello";
    _ = c.XDrawString(display, win, gc, 20, 20, s, s.len);
}

pub fn loadFont(display: *c.Display, gc: c.GC, font_name: [:0]const u8) !void {
    var font_info = c.XLoadQueryFont(display, font_name) orelse {
        return error.FontLoadFailed;
    };

    _ = c.XSetFont(display, gc, font_info.*.fid);
    _ = c.XFlush(display);
}
