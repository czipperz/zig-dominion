const std = @import("std");
const sdl2 = @import("sdl2");
const sdl2_ttf = @import("sdl2_ttf");
usingnamespace @import("state.zig");

pub const RenderError = error {
    OpenFont,
    RenderText,
};

const card_width = 150;
const card_height = 200;
const card_padding = 5;
const card_margin = 10;
const name_bottom_margin = 10;

pub const Renderer = struct {
    font: *sdl2_ttf.Font,
    rendered_name: std.StringHashMap(*sdl2.Surface),
    rendered_description: std.StringHashMap(*sdl2.Surface),

    pub fn init() !Renderer {
        const allocator = std.heap.c_allocator;
        const path = "C:/Windows/Fonts/georgia.ttf";
        const font = sdl2_ttf.openFont(path, 12, 0) orelse return error.OpenFont;
        return Renderer{
            .font = font,
            .rendered_name = std.StringHashMap(*sdl2.Surface).init(allocator),
            .rendered_description = std.StringHashMap(*sdl2.Surface).init(allocator),
        };
    }

    pub fn deinit(renderer: *Renderer) void {
        sdl2_ttf.closeFont(renderer.font);
        renderer.rendered_name.deinit();
        renderer.rendered_description.deinit();
    }

    pub fn render(renderer: *Renderer, state: *State, surface: *sdl2.Surface) !void {
        const white = sdl2.mapRGB(surface.format, 0xff, 0xff, 0xff);
        try surface.fillRect(null, white);

        const player = state.activePlayer();
        for (player.hand.items) |*card, i| {
            const card_rect = .{ .x = (card_width + card_margin) * @intCast(c_int, i) + card_margin,
                                 .y = surface.h - card_height,
                                 .w = card_width,
                                 .h = card_height, };
            const gray = sdl2.mapRGB(surface.format, 0xc0, 0xff, 0xee);
            try surface.fillRect(card_rect, gray);

            const name = try renderText(renderer.font, &renderer.rendered_name, card.*.name);
            const description = try renderText(renderer.font, &renderer.rendered_description,
                                               card.*.description);

            var point = sdl2.Point{ .x = card_rect.x + card_padding,
                                    .y = card_rect.y + card_padding };

            _ = try sdl2.blitSurface(name, null, surface, point);
            point.y += name.h + name_bottom_margin;

            _ = try sdl2.blitSurface(description, null, surface, point);
        }
    }
};

fn renderText(font: *sdl2_ttf.Font, map: *std.StringHashMap(*sdl2.Surface),
              text: [:0]const u8) !*sdl2.Surface {
    if (map.get(text)) |surface|
        return surface;

    const black = sdl2_ttf.Color{ .r = 0, .g = 0, .b = 0, .a = 0xff };
    if (sdl2_ttf.renderTextBlendedWrapped(font, text, black, card_width - card_padding * 2))
        |surface| {
        try map.put(text, surface);
        return surface;
    } else {
        return error.RenderText;
    }
}
