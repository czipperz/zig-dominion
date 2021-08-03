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

    var renderer = try Renderer.init();
    defer renderer.deinit();

    while (true) {
        const start_frame = sdl2.getTicks();

        while (sdl2.pollEvent()) |event| {
            switch (event.type) {
                .quit => return,
                .key_down => {
                    if (event.key.keysym.sym == .escape)
                        return;
                },
                else => {},
            }
        }

        const surface = sdl2.getWindowSurface(window)
                        orelse return error.SDL2_Video;
        try renderer.render(&state, surface);
        try sdl2.updateWindowSurface(window);

        const frame_length = 1000 / 60;
        sdl2.delayUntil(start_frame + frame_length);
    }
}

test {
    _ = @import("cards.zig");
}
