const std = @import("std");
const c = @import("c.zig");

pub const Window = c.Window;
pub const Display = c.Display;
pub const Event = c.XEvent;
pub const ErrorEvent = c.XErrorEvent;
pub const Drawable = c.Drawable;
pub const CurrentTime = c.CurrentTime;

pub fn openDisplay(display_name: ?[:0]const u8) !*Display {
    const name: [*c]const u8 = display_name orelse null;
    return c.XOpenDisplay(name) orelse error.X11OpenDisplayFailed;
}

pub fn closeDisplay(display: *Display) void {
    _ = c.XCloseDisplay(display);
}

pub fn defaultRootWindow(display: *Display) Window {
    return c.DefaultRootWindow(display);
}

pub fn sync(display: *Display, discard: bool) void {
    _ = c.XSync(display, @boolToInt(discard));
}

pub fn displayString(display: *Display) []const u8 {
    return std.mem.sliceTo(c.XDisplayString(display), 0);
}

// * Events

pub fn nextEvent(display: *Display) Event {
    var e: Event = undefined;
    _ = c.XNextEvent(display, &e);
    return e;
}

pub fn flush(display: *Display) void {
    _ = c.XFlush(display);
}

// * Windows

// #define CWX		(1<<0)
// #define CWY		(1<<1)
// #define CWWidth		(1<<2)
// #define CWHeight	(1<<3)
// #define CWBorderWidth	(1<<4)
// #define CWSibling	(1<<5)
// #define CWStackMode	(1<<6)

// typedef struct {
// 	int x, y;
// 	int width, height;
// 	int border_width;
// 	Window sibling;
// 	int stack_mode;
// } XWindowChanges;

pub const StackMode = enum(c_int) {
    above = c.Above,
    below = c.Below,
    top_if = c.TopIf,
    bottom_if = c.BottomIf,
    opposite = c.Opposite,
};
pub const WindowChanges = c.XWindowChanges;

// const WindowChanges = struct {
//     x: ?i32 = null,
//     y: ?i32 = null,
//     width: ?u32 = null,
//     height: ?u32 = null,
//     border_width: ?u32 = null,
//     sibling: ?Window = null,
//     stack_mode: ?StackMode = null,
// };

pub const ConfigureWindowFlags = packed struct(c_uint) {
    x: bool = false,
    y: bool = false,
    width: bool = false,
    height: bool = false,
    border_width: bool = false,
    sibling: bool = false,
    stack_mode: bool = false,

    _padding: u25 = 0,
};

pub fn createSimpleWindow(
    display: *Display,
    parent: Window,
    x: i32,
    y: i32,
    width: u32,
    height: u32,
    border_width: u32,
    border: u64,
    background: u64,
) Window {
    return c.XCreateSimpleWindow(display, parent, x, y, width, height, border_width, border, background);
}

pub fn destroyWindow(display: *Display, w: Window) void {
    _ = c.XDestroyWindow(display, w);
}

pub fn configureWindow(display: *Display, w: Window, value_mask: ConfigureWindowFlags, values: *WindowChanges) void {
    // var value_mask: c_uint = 0;
    // if (values.x != null) value_mask = value_mask | c.CWX;
    // if (values.y != null) value_mask = value_mask | c.CWY;
    // if (values.width != null) value_mask = value_mask | c.CWWidth;
    // if (values.height != null) value_mask = value_mask | c.CWHeight;
    // if (values.border_width != null) value_mask = value_mask | c.CWBorderWidth;
    // if (values.sibling != null) value_mask = value_mask | c.CWSibling;
    // if (values.stack_mode != null) value_mask = value_mask | c.CWStackMode;

    // var c_changes = c.XWindowChanges{
    //     .x = @intCast(c_int, values.x orelse 0),
    //     .y = @intCast(c_int, values.y orelse 0),
    //     .width = @intCast(c_int, values.width orelse 0),
    //     .height = @intCast(c_int, values.height orelse 0),
    //     .border_width = @intCast(c_int, values.border_width orelse 0),
    //     .sibling = values.sibling orelse undefined,
    //     .stack_mode = @enumToInt(values.stack_mode orelse .above),
    // };

    _ = c.XConfigureWindow(display, w, @bitCast(c_uint, value_mask), values);
}

pub fn moveResizeWindow(display: *Display, w: Window, x: i32, y: i32, width: u32, height: u32) void {
    _ = c.XMoveResizeWindow(
        display,
        w,
        @intCast(c_int, x),
        @intCast(c_int, y),
        @intCast(c_uint, width),
        @intCast(c_uint, height),
    );
}

pub fn mapWindow(display: *Display, w: Window) void {
    _ = c.XMapWindow(display, w);
}

pub fn setWindowBorder(display: *Display, w: Window, color: u64) void {
    _ = c.XSetWindowBorder(display, w, @intCast(c_ulong, color));
}

// * Atoms

pub const Atom = c.Atom;
pub const BuiltinAtom = enum(Atom) {
    primary = 1,
    secondary = 2,
    arc = 3,
    atom = 4,
    bitmap = 5,
    cardinal = 6,
    colormap = 7,
    cursor = 8,
    cut_buffer0 = 9,
    cut_buffer1 = 10,
    cut_buffer2 = 11,
    cut_buffer3 = 12,
    cut_buffer4 = 13,
    cut_buffer5 = 14,
    cut_buffer6 = 15,
    cut_buffer7 = 16,
    drawable = 17,
    font = 18,
    integer = 19,
    pixmap = 20,
    point = 21,
    rectangle = 22,
    resource_manager = 23,
    rgb_color_map = 24,
    rgb_best_map = 25,
    rgb_blue_map = 26,
    rgb_default_map = 27,
    rgb_gray_map = 28,
    rgb_green_map = 29,
    rgb_red_map = 30,
    string = 31,
    visualid = 32,
    window = 33,
    wm_command = 34,
    wm_hints = 35,
    wm_client_machine = 36,
    wm_icon_name = 37,
    wm_icon_size = 38,
    wm_name = 39,
    wm_normal_hints = 40,
    wm_size_hints = 41,
    wm_zoom_hints = 42,
    min_space = 43,
    norm_space = 44,
    max_space = 45,
    end_space = 46,
    superscript_x = 47,
    superscript_y = 48,
    subscript_x = 49,
    subscript_y = 50,
    underline_position = 51,
    underline_thickness = 52,
    strikeout_ascent = 53,
    strikeout_descent = 54,
    italic_angle = 55,
    x_height = 56,
    quad_width = 57,
    weight = 58,
    point_size = 59,
    resolution = 60,
    copyright = 61,
    notice = 62,
    font_name = 63,
    family_name = 64,
    full_name = 65,
    cap_height = 66,
    wm_class = 67,
    wm_transient_for = 68,
};

/// Replace a cardinal property for the specified window.
///
/// Possible errors:
/// - BadAlloc:   The server failed to allocate the requested source or server memory.
/// - BadAtom:    A value for an Atom argument does not name a defined Atom.
/// - BadMatch:   An InputOnly window is used as a Drawable.
/// - BadMatch:   Some argument or pair of arguments has the correct type and range but
///               fails to match in some other way required by the request.
/// - BadPixmap:  A value for a Pixmap argument does not name a defined Pixmap.
/// - BadValue:   Some numeric value falls outside the range of values accepted by the request.
///               Unless a specific range is specified for an argument, the full range
///               defined by the argument's type is accepted. Any argument defined as a set
///               of alternatives can generate this error.
/// - BadWindow:  A value for a Window argument does not name a defined Window.
pub fn replaceCardinalProperty(
    comptime T: type,
    display: *Display,
    win: Window,
    atom: Atom,
    data: []const T,
) void {
    const format = switch (@bitSizeOf(T)) {
        8 => 8,
        16 => 16,
        64 => 32,
        else => @compileError("Unsupported data type " ++ @typeName(T)),
    };

    _ = c.XChangeProperty(
        display,
        win,
        atom,
        c.XA_CARDINAL,
        format,
        c.PropModeReplace,
        @ptrCast([*c]const u8, data.ptr),
        @intCast(c_int, data.len),
    );
}

pub fn internAtom(display: *Display, atom_name: [:0]const u8, only_if_exists: bool) Atom {
    return c.XInternAtom(display, atom_name, @boolToInt(only_if_exists));
}

// * Geometry

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
pub fn getGeometry(display: *Display, d: Drawable) XGeometry {
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

// * Input

pub const EventMask = packed struct(c_long) {
    key_press: bool = false,
    key_release: bool = false,
    button_press: bool = false,
    button_release: bool = false,
    enter_window: bool = false,
    leave_window: bool = false,
    pointer_motion: bool = false,
    pointer_motion_hint: bool = false,
    button1_motion: bool = false,
    button2_motion: bool = false,
    button3_motion: bool = false,
    button4_motion: bool = false,
    button5_motion: bool = false,
    button_motion: bool = false,
    keymap_state: bool = false,
    exposure: bool = false,
    visibility_change: bool = false,
    structure_notify: bool = false,
    resize_redirect: bool = false,
    substructure_notify: bool = false,
    substructure_redirect: bool = false,
    focus_change: bool = false,
    property_change: bool = false,
    colormap_change: bool = false,
    owner_grab_button: bool = false,

    _padding: u39 = 0,
};

pub fn selectInput(display: *Display, w: Window, event_mask: EventMask) void {
    _ = c.XSelectInput(display, w, @bitCast(c_long, event_mask));
}

pub fn getInputFocus(display: *Display) c.Window {
    var win: c.Window = undefined;
    var revert_to: c_int = undefined;
    _ = c.XGetInputFocus(display, &win, &revert_to);
    return win;
}

const RevertToOption = enum(c_int) {
    revert_to_parent = c.RevertToParent,
    revert_to_pointer_root = c.RevertToPointerRoot,
    revert_to_none = c.RevertToNone,
};

pub fn setInputFocus(display: *Display, focus: Window, revert_to: RevertToOption, time: c_ulong) void {
    _ = c.XSetInputFocus(display, focus, @enumToInt(revert_to), time);
}

// * Error handling

const ErrorHandler = fn (display: *Display, e: *ErrorEvent) void;
var error_handler: *const ErrorHandler = undefined;

pub fn setErrorHandler(handler: *const ErrorHandler) void {
    error_handler = handler;
    _ = c.XSetErrorHandler(onXError);
}

fn onXError(display: ?*Display, e: [*c]ErrorEvent) callconv(.C) c_int {
    error_handler(display.?, e);
    return 0;
}

pub fn getErrorText(display: *Display, error_code: c_int, buf: []u8) []const u8 {
    _ = c.XGetErrorText(display, error_code, buf.ptr, @intCast(c_int, buf.len));
    return std.mem.sliceTo(buf, 0);
}

const XlibError = error{
    BadRequest, // bad request code
    BadValue, // int parameter out of range
    BadWindow, // parameter not a Window
    BadPixmap, // parameter not a Pixmap
    BadAtom, // parameter not an Atom
    BadCursor, // parameter not a Cursor
    BadFont, // parameter not a Font
    BadMatch, // parameter mismatch
    BadDrawable, // parameter not a Pixmap or Window

    // depending on context:
    // - key/button already grabbed
    // - attempt to free an illegal cmap entry
    // - attempt to store into a read-only color map entry.
    // - attempt to modify the access control list from other than the local host.
    BadAccess,

    BadAlloc, // insufficient resources
    BadColor, // no such colormap
    BadGC, // parameter not a GC
    BadIDChoice, // choice not in range or already used
    BadName, // font or color name doesn't exist
    BadLength, // Request length incorrect
    BadImplementation, // server is defective
};

/// Convert Xlib error status to a Zig error.
fn check(status: c_int) XlibError!void {
    if (status == 0) return;
    return switch (status) {
        c.BadRequest => error.BadRequest,
        c.BadValue => error.BadValue,
        c.BadWindow => error.BadWindow,
        c.BadPixmap => error.BadPixmap,
        c.BadAtom => error.BadAtom,
        c.BadCursor => error.BadCursor,
        c.BadFont => error.BadFont,
        c.BadMatch => error.BadMatch,
        c.BadDrawable => error.BadDrawable,
        c.BadAccess => error.BadAccess,
        c.BadAlloc => error.BadAlloc,
        c.BadColor => error.BadColor,
        c.BadGC => error.BadGC,
        c.BadIDChoice => error.BadIDChoice,
        c.BadName => error.BadName,
        c.BadLength => error.BadLength,
        c.BadImplementation => error.BadImplementation,
        else => unreachable,
    };
}
