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

fn lerp(ticks_now: u32, ticks_end: u32, fstart: f32, fend: f32) f32 {
    var result = fend;
    if (ticks_now < ticks_end)
        result -= ((fend - fstart) * @intToFloat(f32, ticks_end - ticks_now)) / @intToFloat(f32, ticks_end);
    return result;
}

pub const Renderer = struct {
    name_font: *sdl2_ttf.Font,
    description_font: *sdl2_ttf.Font,
    rendered_name: std.StringHashMap(*sdl2.Surface),
    rendered_description: std.StringHashMap(*sdl2.Surface),

    hand_anim_state: std.ArrayList(HandAnimState),
    const HandAnimState = struct {
        state: enum { selected, deselected, none },
        start: u32,
    };

    pub fn init() !Renderer {
        const allocator = std.heap.c_allocator;
        const path = "C:/Windows/Fonts/georgia.ttf";
        const name_font = sdl2_ttf.openFont(path, 20, 0) orelse return error.OpenFont;
        const description_font = sdl2_ttf.openFont(path, 14, 0) orelse return error.OpenFont;
        return Renderer{
            .name_font = name_font,
            .description_font = description_font,
            .rendered_name = std.StringHashMap(*sdl2.Surface).init(allocator),
            .rendered_description = std.StringHashMap(*sdl2.Surface).init(allocator),

            .hand_anim_state = std.ArrayList(HandAnimState).init(allocator),
        };
    }

    pub fn deinit(renderer: *Renderer) void {
        sdl2_ttf.closeFont(renderer.name_font);
        sdl2_ttf.closeFont(renderer.description_font);
        renderer.rendered_name.deinit();
        renderer.rendered_description.deinit();

        renderer.hand_anim_state.deinit();
    }

    pub fn render(renderer: *Renderer, state: *State, surface: *sdl2.Surface,
                  mouse_point: ?sdl2.Point) !void {
        const ticks = sdl2.getTicks();

        const player = state.activePlayer();

        // Add empty elements for drawn cards.
        if (renderer.hand_anim_state.items.len < player.hand.items.len) {
            try renderer.hand_anim_state.ensureTotalCapacity(player.hand.items.len);
            while (renderer.hand_anim_state.items.len < player.hand.items.len) {
                renderer.hand_anim_state.appendAssumeCapacity(.{ .state = .none, .start = 0, });
            }
        }
        // Truncate off other elements.
        renderer.hand_anim_state.items.len = player.hand.items.len;

        const hand_anim_state = renderer.hand_anim_state.items;

        const white = sdl2.mapRGB(surface.format, 0xff, 0xff, 0xff);
        try surface.fillRect(null, white);

        var hand_card_rects = try std.heap.c_allocator.alloc(sdl2.Rect, player.hand.items.len);
        defer std.heap.c_allocator.free(hand_card_rects);
        for (player.hand.items) |_, i| {
            hand_card_rects[i] = .{
                .x = (card_width + card_margin) * @intCast(c_int, i) + card_margin,
                .y = surface.h - card_height,
                .w = card_width,
                .h = card_height,
            };

            const start = hand_anim_state[i].start;

            // Deselect animations complete by changing to no animation.
            if (hand_anim_state[i].state == .deselected) {
                if (ticks - start >= 100)
                    hand_anim_state[i] = .{ .state = .none, .start = 0 };
            }

            // Note: negative is up.
            const y_offset = switch (hand_anim_state[i].state) {
                .selected   => -@floatToInt(c_int, lerp(ticks - start, 100, 0, 50)),
                .deselected => -@floatToInt(c_int, lerp(ticks - start, 100, 50, 0)),
                .none       => 0,
            };
            hand_card_rects[i].y += y_offset;

            // Test if the current or default region for the card contains the cursor.
            var contains_mouse = false;
            if (mouse_point) |mouse| {
                var intersect_rect = hand_card_rects[i];
                intersect_rect.h -= y_offset;
                contains_mouse = intersect_rect.contains(mouse);
            }

            // Update state based on mouse intersection.
            if (contains_mouse) {
                switch (hand_anim_state[i].state) {
                    .selected   => {},
                    .deselected => hand_anim_state[i] = .{ .state = .selected,
                                                           .start = ticks - (100 - @minimum(100, ticks - start)), },
                    .none       => hand_anim_state[i] = .{ .state = .selected, .start = ticks, },
                }
            } else {
                switch (hand_anim_state[i].state) {
                    .selected => hand_anim_state[i] = .{ .state = .deselected,
                                                         .start = ticks - (100 - @minimum(100, ticks - start)), },
                    .deselected, .none => {},
                }
            }
        }

        for (player.hand.items) |card, i| {
            const card_rect = hand_card_rects[i];

            const shadow_height = switch (hand_anim_state[i].state) {
                .selected   => @floatToInt(c_int, lerp(ticks - hand_anim_state[i].start, 100, 3, 9)),
                .deselected => @floatToInt(c_int, lerp(ticks - hand_anim_state[i].start, 100, 9, 3)),
                .none       => 3,
            };

            const shadow_rect = .{
                .x = card_rect.x + shadow_height,
                .y = card_rect.y + shadow_height,
                .w = card_rect.w,
                .h = card_rect.h,
            };

            const shadow_color = .{ .r = 0x33, .g = 0x33, .b = 0x33 };
            try surface.fillRect(shadow_rect, sdl2.mapColorRGB(surface.format, shadow_color));

            const background: sdl2.ColorRGB = switch (card.type) {
                .treasure => .{ .r = 0xe6, .g = 0x8e, .b = 0x0b },
                .curse    => .{ .r = 0x3f, .g = 0x0b, .b = 0x52 },
                .victory  => .{ .r = 0xc0, .g = 0xff, .b = 0xee },
                .action_general, .action_attack, .action_reaction
                          => .{ .r = 0xcb, .g = 0xcb, .b = 0xcb },
            };
            try surface.fillRect(card_rect, sdl2.mapColorRGB(surface.format, background));

            const name = try renderText(renderer.name_font, &renderer.rendered_name, card.name);
            const description = try renderText(renderer.description_font, &renderer.rendered_description,
                                               card.description);

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
