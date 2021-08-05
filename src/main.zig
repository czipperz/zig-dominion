const std = @import("std");
const sdl2 = @import("sdl2");
const sdl2_ttf = @import("sdl2_ttf");
usingnamespace @import("state.zig");
usingnamespace @import("renderer.zig");

pub fn main() anyerror!void {
    try sdl2.init(.{ .video = true });
    defer sdl2.quit();

    try sdl2_ttf.init();
    defer sdl2_ttf.quit();

    const window = try sdl2.createWindow("Dominion", .unspecified, .unspecified, 800, 800,
                                         .{ .shown = true, .resizable = true });
    defer sdl2.destroyWindow(window);

    var state = try State.setup(2);
    defer state.deinit();

    for (state.players) |*player| {
        const cards = @import("cards.zig");
        try player.hand.append(&cards.moneylender);
        try player.hand.append(&cards.throne_room);
        try player.discard.append(&cards.copper);
        try player.discard.append(&cards.silver);
        try player.discard.append(&cards.harbinger);
    }

    var renderer = try Renderer.init();
    defer renderer.deinit();

    var mouse_point: ?sdl2.Point = null;

    while (true) {
        const start_frame = sdl2.getTicks();
        var mouse_down = false;

        while (sdl2.pollEvent()) |event| {
            switch (event.type) {
                .quit => return,
                .key_down => {
                    if (event.key.keysym.sym == .escape)
                        return;
                },
                .mouse_button_down => {
                    if (event.button.button == .left)
                        mouse_down = true;
                },
                .mouse_motion => {
                    mouse_point = .{ .x = event.motion.x, .y = event.motion.y };
                },
                .window => {
                    if (event.window.event == .leave)
                        mouse_point = null;
                },
                else => {},
            }
        }

        const surface = sdl2.getWindowSurface(window)
                        orelse return error.SDL2_Video;
        try renderer.render(&state, surface, mouse_point, mouse_down);
        try sdl2.updateWindowSurface(window);

        const frame_length = 1000 / 60;
        sdl2.delayUntil(start_frame + frame_length);
    }
}

test {
    _ = @import("cards.zig");
}
