const std = @import("std");
const c = @import("c.zig");

/// Check X11 status for success
pub fn check(status: c.Status) !void {
    if (status == 0) {
        return error.XlibError;
    }
}

// /// Get unqualified type name for provided XEvent type
// pub fn eventTypeName(comptime Event: type) []const u8 {
//     var split = std.mem.splitBackwards(u8, @typeName(Event), ".");
//     const last = split.next().?;
//     return last;
// }

// fn eventField(t: c_int) []const u8 {
//     return switch (t) {
//         c.KeyPress => "xkey",
//         c.KeyRelease => "xkey",
//         c.ButtonPress => "xbutton",
//         c.ButtonRelease => "xbutton",
//         c.MotionNotify => "xmotion",
//         c.EnterNotify => "xcrossing",
//         c.LeaveNotify => "xcrossing",
//         c.FocusIn => "xfocus",
//         c.FocusOut => "xfocus",
//         c.KeymapNotify => "xkeymap",
//         c.Expose => "xexpose",
//         c.GraphicsExpose => "xgraphicsexpose",
//         c.NoExpose => "xnoexpose",
//         c.VisibilityNotify => "xvisibility",
//         c.CreateNotify => "xcreatewindow",
//         c.DestroyNotify => "xdestroywindow",
//         c.UnmapNotify => "xunmap",
//         c.MapNotify => "xmap",
//         c.MapRequest => "xmaprequest",
//         c.ReparentNotify => "xreparent",
//         c.ConfigureNotify => "xconfigure",
//         c.ConfigureRequest => "xconfigurerequest",
//         c.GravityNotify => "xgravity",
//         c.ResizeRequest => "xresizerequest",
//         c.CirculateNotify => "xcirculate",
//         c.CirculateRequest => "xcirculaterequest",
//         c.PropertyNotify => "xproperty",
//         c.SelectionClear => "xselectionclear",
//         c.SelectionRequest => "xselectionrequest",
//         c.SelectionNotify => "xselection",
//         c.ColormapNotify => "xcolormap",
//         c.ClientMessage => "xclient",
//         c.MappingNotify => "xmapping",
//         c.GenericEvent => "xgeneric",
//         else => @compileError("Unknown X11 event type " ++ t ++ "."),
//     };
// }

// fn eventType(comptime t: c_int) type {
//     return switch (t) {
//         c.KeyPress => c.XKeyEvent,
//         c.KeyRelease => c.XKeyEvent,
//         c.ButtonPress => c.XButtonEvent,
//         c.ButtonRelease => c.XButtonEvent,
//         c.MotionNotify => c.XMotionEvent,
//         c.EnterNotify => c.XCrossingEvent,
//         c.LeaveNotify => c.XCrossingEvent,
//         c.FocusIn => c.XFocusChangeEvent,
//         c.FocusOut => c.XFocusChangeEvent,
//         c.KeymapNotify => c.XKeymapEvent,
//         c.Expose => c.XExposeEvent,
//         c.GraphicsExpose => c.xExposeEvent,
//         c.NoExpose => c.XExposeEvent,
//         c.VisibilityNotify => c.XVisibilityEvent,
//         c.CreateNotify => c.XCreateWindowEvent,
//         c.DestroyNotify => c.XDestroyWindowEvent,
//         c.UnmapNotify => c.XUnmapEvent,
//         c.MapNotify => c.XMapEvent,
//         c.MapRequest => c.XMapRequestEvent,
//         c.ReparentNotify => c.XReparentEvent,
//         c.ConfigureNotify => c.XConfigureEvent,
//         c.ConfigureRequest => c.XConfigureRequestEvent,
//         c.GravityNotify => c.XGravityEvent,
//         c.ResizeRequest => c.XResizeRequestEvent,
//         c.CirculateNotify => c.XCirculateEvent,
//         c.CirculateRequest => c.XCirculateRequestEvent,
//         c.PropertyNotify => c.XPropertyEvent,
//         c.SelectionClear => c.XSelectionClearEvent,
//         c.SelectionRequest => c.XSelectionRequestEvent,
//         c.SelectionNotify => c.XSelectionEvent,
//         c.ColormapNotify => c.XColormapEvent,
//         c.ClientMessage => c.XClientMessageEvent,
//         c.MappingNotify => c.XMappingEvent,
//         c.GenericEvent => c.GenericEvent,
//         else => @compileError("Unknown event type " ++ std.fmt.comptimePrint("{}", t) ++ ""),
//     };
// }

// fn eventField(comptime Event: type) []const u8 {
//     return switch (Event) {
//         c.XKeyEvent => "xkey",
//         c.XButtonEvent => "xbutton",
//         c.XMotionEvent => "xmotion",
//         c.XCrossingEvent => "xcrossing",
//         c.XFocusChangeEvent => "xfocus",
//         c.XExposeEvent => "xexpose",
//         c.XGraphicsExposeEvent => "xgraphicsexpose",
//         c.XNoExposeEvent => "xnoexpose",
//         c.XVisibilityEvent => "xvisibility",
//         c.XCreateWindowEvent => "xcreatewindow",
//         c.XDestroyWindowEvent => "xdestroywindow",
//         c.XUnmapEvent => "xunmap",
//         c.XMapEvent => "xmap",
//         c.XMapRequestEvent => "xmaprequest",
//         c.XReparentEvent => "xreparent",
//         c.XConfigureEvent => "xconfigure",
//         c.XGravityEvent => "xgravity",
//         c.XResizeRequestEvent => "xresizerequest",
//         c.XConfigureRequestEvent => "xconfigurerequest",
//         c.XCirculateEvent => "xcirculate",
//         c.XCirculateRequestEvent => "xcirculaterequest",
//         c.XPropertyEvent => "xproperty",
//         c.XSelectionClearEvent => "xselectionclear",
//         c.XSelectionRequestEvent => "xselectionrequest",
//         c.XSelectionEvent => "xselection",
//         c.XColormapEvent => "xcolormap",
//         c.XClientMessageEvent => "xclient",
//         c.XMappingEvent => "xmapping",
//         c.XErrorEvent => "xerror",
//         c.XKeymapEvent => "xkeymap",
//         c.XGenericEvent => "xgeneric",
//         else => @compileError("Unknown X11 event type " ++ @typeName(Event) ++ "."),
//     };
// }
