const std = @import("std");
const c = @import("c.zig");

pub const KeyMaskFlags = packed struct(u32) {
    shift: bool = false,
    lock: bool = false,
    control: bool = false,
    mod1: bool = false,
    mod2: bool = false,
    mod3: bool = false,
    mod4: bool = false,
    mod5: bool = false,

    button1: bool = false,
    button2: bool = false,
    button3: bool = false,
    button4: bool = false,
    button5: bool = false,

    _padding: u19 = 0,
};

pub fn pressed(display: *c.Display, event: *const c.XKeyEvent, comptime binding: []const u8) bool {
    const b = comptime parseKeyStr(binding) catch |e| {
        switch (e) {
            error.InvalidSyntax => @compileError("Invalid key syntax in \"" ++ binding ++ "\"."),
            error.InvalidModifier => @compileError("Invalid modifier in \"" ++ binding ++ "\"."),
            error.InvalidKey => @compileError("Invalid key in \"" ++ binding ++ "\"."),
        }
    };
    return event.state == @bitCast(c_uint, b.flags) and event.keycode == c.XKeysymToKeycode(display, b.keysym);
}

const KeyBinding = struct {
    flags: KeyMaskFlags,
    keysym: c.KeySym,
};

// TODO: Add all keys
const keysym_map = std.ComptimeStringMap(c.KeySym, .{
    .{ "RET", c.XK_Return },
    .{ "a", c.XK_a },
    .{ "c", c.XK_c },
    .{ "n", c.XK_n },
    .{ "e", c.XK_e },
    .{ "f", c.XK_f },
    .{ "q", c.XK_q },
    .{ "1", c.XK_1 },
    .{ "2", c.XK_2 },
});

pub fn grabKey(display: *c.Display, grab_window: c.Window, comptime binding: []const u8) void {
    const b = comptime parseKeyStr(binding) catch |e| {
        switch (e) {
            error.InvalidSyntax => @compileError("Invalid key syntax in \"" ++ binding ++ "\"."),
            error.InvalidModifier => @compileError("Invalid modifier in \"" ++ binding ++ "\"."),
            error.InvalidKey => @compileError("Invalid key in \"" ++ binding ++ "\"."),
        }
    };
    _ = c.XGrabKey(
        display,
        c.XKeysymToKeycode(display, b.keysym),
        @bitCast(c_uint, b.flags),
        grab_window,
        0,
        c.GrabModeAsync,
        c.GrabModeAsync,
    );
}

pub fn parseKeyStr(key_str: []const u8) error{ InvalidSyntax, InvalidModifier, InvalidKey }!KeyBinding {
    var iter = std.mem.tokenize(u8, key_str, "-");
    var binding = KeyBinding{
        .flags = KeyMaskFlags{},
        .keysym = undefined,
    };

    while (iter.next()) |token| {
        if (iter.peek() != null) {
            // There's more tokens, current character is a modifier
            if (token.len != 1) return error.InvalidSyntax;
            switch (token[0]) {
                'c' => binding.flags.control = true,
                'M' => binding.flags.mod1 = true,
                'S' => binding.flags.shift = true,
                's' => binding.flags.mod4 = true,
                else => return error.InvalidModifier,
            }
        } else {
            binding.keysym = keysym_map.get(token) orelse return error.InvalidKey;
        }
    }

    return binding;
}

test "Keybinding using super modifier" {
    const binding = try parseKeyStr("s-RET");
    try std.testing.expectEqual(KeyBinding{ .flags = .{ .mod4 = true }, .keysym = c.XK_Return }, binding);
}

test "Keybinding using alt modifier" {
    const binding = try parseKeyStr("M-a");
    try std.testing.expectEqual(KeyBinding{ .flags = .{ .mod1 = true }, .keysym = c.XK_a }, binding);
}

test "Invalid syntax" {
    try std.testing.expectError(error.InvalidSyntax, parseKeyStr("LOL-a"));
}

test "Invalid modifier" {
    try std.testing.expectError(error.InvalidModifier, parseKeyStr("X-a"));
}
