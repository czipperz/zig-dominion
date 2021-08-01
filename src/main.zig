const std = @import("std");
const sdl2 = @import("sdl2");
usingnamespace @import("state.zig");

pub fn main() anyerror!void {
    try sdl2.init(.{ .video = true });
    defer sdl2.quit();

    const window = try sdl2.createWindow("Dominion", .unspecified, .unspecified, 800, 800,
                                         .{ .shown = true, .resizable = true });
    defer sdl2.destroyWindow(window);

    var state = try State.setup(2);
    defer state.deinit();

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

        const frame_length = 1000 / 60;
        sdl2.delayUntil(start_frame + frame_length);
    }
}

test {
    _ = @import("cards.zig");
}
