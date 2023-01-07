const std = @import("std");
const c = @import("c.zig");

pub const Event = struct {
    const Type = enum(u8) {
        key_press = c.KeyPress,
        key_release = c.KeyRelease,
        button_press = c.ButtonPress,
        button_release = c.ButtonRelease,
        motion_notify = c.MotionNotify,
        enter_notify = c.EnterNotify,
        leave_notify = c.LeaveNotify,
        focus_in = c.FocusIn,
        focus_out = c.FocusOut,
        keymap_notify = c.KeymapNotify,
        expose = c.Expose,
        graphics_expose = c.GraphicsExpose,
        no_expose = c.NoExpose,
        visibility_notify = c.VisibilityNotify,
        create_notify = c.CreateNotify,
        destroy_notify = c.DestroyNotify,
        unmap_notify = c.UnmapNotify,
        map_notify = c.MapNotify,
        map_request = c.MapRequest,
        reparent_notify = c.ReparentNotify,
        configure_notify = c.ConfigureNotify,
        configure_request = c.ConfigureRequest,
        gravity_notify = c.GravityNotify,
        resize_request = c.ResizeRequest,
        circulate_notify = c.CirculateNotify,
        circulate_request = c.CirculateRequest,
        property_notify = c.PropertyNotify,
        selection_clear = c.SelectionClear,
        selection_request = c.SelectionRequest,
        selection_notify = c.SelectionNotify,
        colormap_notify = c.ColormapNotify,
        client_message = c.ClientMessage,
        mapping_notify = c.MappingNotify,
        generic_event = c.GenericEvent,
    };

    const Data = union(Type) {
        key_press: c.XKeyEvent,
        key_release: c.XKeyEvent,
        button_press: c.XButtonEvent,
        button_release: c.XButtonEvent,
        motion_notify: c.XMotionEvent,
        enter_notify: c.XCrossingEvent,
        leave_notify: c.XCrossingEvent,
        focus_in: c.XFocusChangeEvent,
        focus_out: c.XFocusChangeEvent,
        keymap_notify: c.XKeymapEvent,
        expose: c.XExposeEvent,
        graphics_expose: c.XGraphicsExposeEvent,
        no_expose: c.XNoExposeEvent,
        visibility_notify: c.XVisibilityEvent,
        create_notify: c.XCreateWindowEvent,
        destroy_notify: c.XDestroyWindowEvent,
        unmap_notify: c.XUnmapEvent,
        map_notify: c.XMapEvent,
        map_request: c.XMapRequestEvent,
        reparent_notify: c.XReparentEvent,
        configure_notify: c.XConfigureEvent,
        configure_request: c.XConfigureRequestEvent,
        gravity_notify: c.XGravityEvent,
        resize_request: c.XResizeRequestEvent,
        circulate_notify: c.XCirculateEvent,
        circulate_request: c.XCirculateRequestEvent,
        property_notify: c.XPropertyEvent,
        selection_clear: c.XSelectionClearEvent,
        selection_request: c.XSelectionRequestEvent,
        selection_notify: c.XSelectionEvent,
        colormap_notify: c.XColormapEvent,
        client_message: c.XClientMessageEvent,
        mapping_notify: c.XMappingEvent,
        generic_event: c.XGenericEvent,
    };

    serial: u64,
    send_event: bool,
    display: ?*c.Display,
    window: c.Window,
    type: Data,

    pub fn fromNative(ev: c.XEvent) Event {
        return Event{
            .serial = ev.xany.serial,
            .send_event = ev.xany.send_event != 0,
            .display = ev.xany.display,
            .window = ev.xany.window,
            .type = switch (@intToEnum(Type, ev.type)) {
                .key_press => Data{ .key_press = ev.xkey },
                .key_release => Data{ .key_release = ev.xkey },
                .button_press => Data{ .button_press = ev.xbutton },
                .button_release => Data{ .button_release = ev.xbutton },
                .motion_notify => Data{ .motion_notify = ev.xmotion },
                .enter_notify => Data{ .enter_notify = ev.xcrossing },
                .leave_notify => Data{ .leave_notify = ev.xcrossing },
                .focus_in => Data{ .focus_in = ev.xfocus },
                .focus_out => Data{ .focus_out = ev.xfocus },
                .keymap_notify => Data{ .keymap_notify = ev.xkeymap },
                .expose => Data{ .expose = ev.xexpose },
                .graphics_expose => Data{ .graphics_expose = ev.xgraphicsexpose },
                .no_expose => Data{ .no_expose = ev.xnoexpose },
                .visibility_notify => Data{ .visibility_notify = ev.xvisibility },
                .create_notify => Data{ .create_notify = ev.xcreatewindow },
                .destroy_notify => Data{ .destroy_notify = ev.xdestroywindow },
                .unmap_notify => Data{ .unmap_notify = ev.xunmap },
                .map_notify => Data{ .map_notify = ev.xmap },
                .map_request => Data{ .map_request = ev.xmaprequest },
                .reparent_notify => Data{ .reparent_notify = ev.xreparent },
                .configure_notify => Data{ .configure_notify = ev.xconfigure },
                .configure_request => Data{ .configure_request = ev.xconfigurerequest },
                .gravity_notify => Data{ .gravity_notify = ev.xgravity },
                .resize_request => Data{ .resize_request = ev.xresizerequest },
                .circulate_notify => Data{ .circulate_notify = ev.xcirculate },
                .circulate_request => Data{ .circulate_request = ev.xcirculaterequest },
                .property_notify => Data{ .property_notify = ev.xproperty },
                .selection_clear => Data{ .selection_clear = ev.xselectionclear },
                .selection_request => Data{ .selection_request = ev.xselectionrequest },
                .selection_notify => Data{ .selection_notify = ev.xselection },
                .colormap_notify => Data{ .colormap_notify = ev.xcolormap },
                .client_message => Data{ .client_message = ev.xclient },
                .mapping_notify => Data{ .mapping_notify = ev.xmapping },
                .generic_event => Data{ .generic_event = ev.xgeneric },
            },
        };
    }

    pub fn toString(self: @This(), allocator: std.mem.Allocator) ![]const u8 {
        return std.fmt.allocPrint(allocator, "{?}", .{self});
    }
};
