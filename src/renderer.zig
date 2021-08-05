const std = @import("std");
const sdl2 = @import("sdl2");
const sdl2_ttf = @import("sdl2_ttf");
usingnamespace @import("card.zig");
usingnamespace @import("state.zig");
usingnamespace @import("error.zig");

pub const RenderError = error {
    OpenFont,
    RenderText,
};

const hand_height = card_height + card_margin;
const card_width = 150;
const card_height = 200;
const card_padding = 5;
const card_margin = 10;
const name_bottom_margin = 10;
const prompt_margin = 10;
const submit_padding = 4;

fn lerp(ticks_now: u32, ticks_end: u32, fstart: f32, fend: f32) f32 {
    var result = fend;
    if (ticks_now < ticks_end)
        result -= ((fend - fstart) * @intToFloat(f32, ticks_end - ticks_now)) / @intToFloat(f32, ticks_end);
    return result;
}

pub const Renderer = struct {
    name_font: *sdl2_ttf.Font,
    description_font: *sdl2_ttf.Font,
    prompt_font: *sdl2_ttf.Font,
    rendered_name: std.StringHashMap(*sdl2.Surface),
    rendered_description: std.StringHashMap(*sdl2.Surface),
    rendered_prompt: std.StringHashMap(*sdl2.Surface),

    hand_anim_state: std.ArrayList(HandAnimState),
    const HandAnimState = struct {
        ystate: enum { selected, deselected, none } = .none,
        ystart: u32 = 0,
        xoffset: u32 = 0,
        xstart: u32 = 0,
    };

    pub fn init() !Renderer {
        const allocator = std.heap.c_allocator;
        const path = "C:/Windows/Fonts/georgia.ttf";
        const name_font = sdl2_ttf.openFont(path, 20, 0) orelse return error.OpenFont;
        const description_font = sdl2_ttf.openFont(path, 14, 0) orelse return error.OpenFont;
        const prompt_font = sdl2_ttf.openFont(path, 20, 0) orelse return error.OpenFont;
        return Renderer{
            .name_font = name_font,
            .description_font = description_font,
            .prompt_font = prompt_font,
            .rendered_name = std.StringHashMap(*sdl2.Surface).init(allocator),
            .rendered_description = std.StringHashMap(*sdl2.Surface).init(allocator),
            .rendered_prompt = std.StringHashMap(*sdl2.Surface).init(allocator),

            .hand_anim_state = std.ArrayList(HandAnimState).init(allocator),
        };
    }

    pub fn deinit(renderer: *Renderer) void {
        sdl2_ttf.closeFont(renderer.name_font);
        sdl2_ttf.closeFont(renderer.description_font);
        sdl2_ttf.closeFont(renderer.prompt_font);
        renderer.rendered_name.deinit();
        renderer.rendered_description.deinit();
        renderer.rendered_prompt.deinit();

        renderer.hand_anim_state.deinit();
    }

    pub fn render(renderer: *Renderer, state: *State, surface: *sdl2.Surface,
                  mouse_point: ?sdl2.Point, mouse_down_in: bool) !void {
        var mouse_down = mouse_down_in;
        const ticks = sdl2.getTicks();

        var repaint = true;
        while (repaint) {
            repaint = false;

            try surface.fill(sdl2.mapRGB(surface.format, 0xff, 0xff, 0xff));

            try renderer.renderPlay(state, surface);

            var check_prompt = false;
            if (state.prompt == null) {
                const played_card = try renderer.renderHand(state, surface, mouse_point, &mouse_down, ticks);
                if (played_card) |card| {
                    // Play the card.
                    state.card_stack = try std.heap.c_allocator.allocWithOptions(u8, card.action.frame_size, 8, null);
                    state.card_frame = @asyncCall(state.card_stack.?, {}, card.action.func, .{card, state});

                    // Check for a prompt.
                    repaint = true;
                    check_prompt = true;
                }
            } else {
                const submitted = try renderer.renderPrompt(state, surface, mouse_point, &mouse_down);
                if (submitted) {
                    // Submit the prompt.
                    resume state.prompt_frame.?;

                    // Check for another prompt.
                    repaint = true;
                    check_prompt = true;
                }
            }

            if (check_prompt and state.prompt == null) {
                // No prompt needed; process any errors that were encountered then deinit.
                try nosuspend await state.card_frame.?;
                std.heap.c_allocator.free(state.card_stack.?);

                state.card_stack = null;
                state.card_frame = null;
            }
        }
    }

    pub fn renderPrompt(renderer: *Renderer, state: *State, surface: *sdl2.Surface,
                        mouse_point: ?sdl2.Point, mouse_down: *bool) !bool {
        const player = state.activePlayer();
        const prompt = state.prompt.?;

        const submit = try renderText(renderer.prompt_font, &renderer.rendered_prompt,
                                      "Submit", @intCast(u32, surface.w));

        // Render message.
        const submit_rect_w = submit.w + submit_padding * 2;
        const message = try renderText(renderer.prompt_font, &renderer.rendered_prompt,
                                       prompt.message, @intCast(u32, surface.w - (submit_rect_w + prompt_margin) * 2));
        const above_hand = surface.h - hand_height - message.h - prompt_margin;
        _ = try sdl2.blitSurface(message, null, surface,
                                 sdl2.Point{ .x = @divFloor(surface.w -% message.w, 2),
                                             .y = above_hand });


        // Render submit button.
        const submit_point = .{ .x = surface.w - submit.w - prompt_margin, .y = above_hand };
        const submit_rect = sdl2.Rect{ .x = submit_point.x - submit_padding, .y = submit_point.y - submit_padding,
                                       .w = submit_rect_w, .h = submit.h + submit_padding * 2, };

        var submit_rect_color = sdl2.mapRGB(surface.format, 0x0d, 0xb8, 0xce);
        if (mouse_point) |mouse| {
            if (submit_rect.contains(mouse)) {
                if (mouse_down.*) {
                    mouse_down.* = false;
                    return true;
                }
                submit_rect_color = sdl2.mapRGB(surface.format, 0x4d, 0xe0, 0xf4);
            }
        }

        try surface.fillRect(submit_rect, submit_rect_color);
        _ = try sdl2.blitSurface(submit, null, surface, submit_point);

        // Render card selection background.
        try surface.fillRect(.{ .x = 0, .y = surface.h - hand_height,
                                .w = surface.w, .h = hand_height },
                             sdl2.mapRGB(surface.format, 0xbb, 0x5a, 0xd4));

        // Render cards to choose from.
        for (player.getLocation(prompt.location)) |card, i| {
            const card_rect = sdl2.Rect{
                .x = (card_width + card_margin) * @intCast(c_int, i) + card_margin,
                .y = surface.h - card_height,
                .w = card_width,
                .h = card_height,
            };

            const result = &state.prompt_result.?;
            if (mouse_point) |mouse| {
                if (card_rect.contains(mouse)) {
                    if (mouse_down.*) {
                        result.toggle(i);
                        mouse_down.* = false;
                    }
                }
            }

            if (result.isSet(i)) {
                const background_rect = .{
                    .x = card_rect.x - card_margin / 2,
                    .y = surface.h - hand_height,
                    .w = card_width + card_margin,
                    .h = hand_height,
                };
                try surface.fillRect(background_rect, sdl2.mapRGB(surface.format, 0x95, 0x14, 0xb6));
            }

            const shadow_height = 1;
            try renderer.renderCard(surface, card, card_rect, shadow_height);
        }

        return false;
    }

    pub fn renderHand(renderer: *Renderer, state: *State, surface: *sdl2.Surface,
                      mouse_point: ?sdl2.Point, mouse_down: *bool, ticks: u32) !?Card {
        const player = state.activePlayer();

        try surface.fillRect(.{ .x = 0, .y = surface.h - hand_height,
                                .w = surface.w, .h = hand_height },
                             sdl2.mapRGB(surface.format, 0xcc, 0xcc, 0xcc));

        // Add empty elements for drawn cards.
        if (renderer.hand_anim_state.items.len < player.hand.items.len) {
            try renderer.hand_anim_state.ensureTotalCapacity(player.hand.items.len);
            while (renderer.hand_anim_state.items.len < player.hand.items.len) {
                renderer.hand_anim_state.appendAssumeCapacity(.{});
            }
        }
        // Truncate off other elements.
        renderer.hand_anim_state.items.len = player.hand.items.len;

        const yanimtime = 100;
        const xanimtime = 100;

        var i: usize = 0; while (i < player.hand.items.len) : (i +%= 1) {
            ////////////////// UPDATE /////////////////
            const hand_anim_state = renderer.hand_anim_state.items;

            var card_rect = .{
                .x = (card_width + card_margin) * @intCast(c_int, i) + card_margin,
                .y = surface.h - card_height,
                .w = card_width,
                .h = card_height,
            };

            const ystart = hand_anim_state[i].ystart;

            // Deselect animations complete by changing to no animation.
            if (hand_anim_state[i].ystate == .deselected) {
                if (ticks - ystart >= yanimtime) {
                    hand_anim_state[i].ystate = .none;
                }
            }

            // Note: negative is up.
            const y_offset = switch (hand_anim_state[i].ystate) {
                .selected   => -@floatToInt(c_int, lerp(ticks - ystart, yanimtime, 0, 50)),
                .deselected => -@floatToInt(c_int, lerp(ticks - ystart, yanimtime, 50, 0)),
                .none       => 0,
            };
            card_rect.y += y_offset;

            // Process x offset (card was removed).
            if (hand_anim_state[i].xoffset > 0) {
                while (ticks - hand_anim_state[i].xstart > xanimtime and
                       hand_anim_state[i].xoffset > 0) {
                    hand_anim_state[i].xstart += xanimtime;
                    hand_anim_state[i].xoffset -= 1;
                }

                if (hand_anim_state[i].xoffset > 0) {
                    const x_offset = (lerp(ticks - hand_anim_state[i].xstart, xanimtime, 0, -1)
                                      + @intToFloat(f32, hand_anim_state[i].xoffset))
                                   * @intToFloat(f32, card_width + card_margin);
                    card_rect.x += @floatToInt(c_int, x_offset);
                }
            }

            // Test if the current or default region for the card contains the cursor.
            var contains_mouse = false;
            if (mouse_point) |mouse| {
                var intersect_rect: sdl2.Rect = card_rect;
                intersect_rect.h -= y_offset;
                contains_mouse = intersect_rect.contains(mouse);
            }

            // Update state based on mouse intersection.
            if (contains_mouse) {
                if (mouse_down.*) {
                    const card = player.hand.orderedRemove(i);
                    _ = renderer.hand_anim_state.orderedRemove(i);

                    var j: usize = i; while (j < hand_anim_state.len) : (j += 1) {
                        if (hand_anim_state[j].xoffset == 0) {
                            hand_anim_state[j].xstart = ticks;
                        }
                        hand_anim_state[j].xoffset += 1;
                    }

                    mouse_down.* = false;
                    i -%= 1;
                    return card;
                }

                switch (hand_anim_state[i].ystate) {
                    .selected   => {},
                    .deselected => {
                        hand_anim_state[i].ystate = .selected;
                        hand_anim_state[i].ystart = ticks - (yanimtime - @minimum(yanimtime, ticks - ystart));
                    },
                    .none       => {
                        hand_anim_state[i].ystate = .selected;
                        hand_anim_state[i].ystart = ticks;
                    },
                }
            } else {
                if (hand_anim_state[i].ystate == .selected) {
                    hand_anim_state[i].ystate = .deselected;
                    hand_anim_state[i].ystart = ticks - (yanimtime - @minimum(yanimtime, ticks - ystart));
                }
            }

            /////////////// RENDER ///////////////
            const card = player.hand.items[i];

            const shadow_height = switch (hand_anim_state[i].ystate) {
                .selected   => @floatToInt(c_int, lerp(ticks - hand_anim_state[i].ystart, yanimtime, 3, 9)),
                .deselected => @floatToInt(c_int, lerp(ticks - hand_anim_state[i].ystart, yanimtime, 9, 3)),
                .none       => 3,
            };

            try renderer.renderCard(surface, card, card_rect, shadow_height);
        }

        return null;
    }

    pub fn renderCard(renderer: *Renderer, surface: *sdl2.Surface,
                      card: Card, card_rect: sdl2.Rect, shadow_height: c_int) !void {
        const shadow_rect = .{
            .x = card_rect.x + shadow_height,
            .y = card_rect.y + shadow_height,
            .w = card_rect.w,
            .h = card_rect.h,
        };

        const shadow_color = .{ .r = 0x33, .g = 0x33, .b = 0x33 };
        try surface.fillRect(shadow_rect, sdl2.mapColorRGB(surface.format, shadow_color));

        const border: sdl2.ColorRGB = switch (card.type) {
            .treasure => .{ .r = 0x53, .g = 0x33, .b = 0x04 },
            .curse    => .{ .r = 0x3f, .g = 0x0b, .b = 0x52 },
            .victory  => .{ .r = 0x04, .g = 0x97, .b = 0x02 },
            .action_general, .action_attack, .action_reaction
                      => .{ .r = 0x4d, .g = 0x4d, .b = 0x4d },
        };
        try surface.fillRect(card_rect, sdl2.mapColorRGB(surface.format, border));

        const background: sdl2.ColorRGB = switch (card.type) {
            .treasure => .{ .r = 0xe6, .g = 0x8e, .b = 0x0b },
            .curse    => .{ .r = 0xa6, .g = 0x1d, .b = 0xd7 },
            .victory  => .{ .r = 0x39, .g = 0xfc, .b = 0x35 },
            .action_general, .action_attack, .action_reaction
                      => .{ .r = 0xcb, .g = 0xcb, .b = 0xcb },
        };
        try surface.fillRect(.{ .x = card_rect.x + 1, .y = card_rect.y + 1,
                                .w = card_rect.w - 2, .h = card_rect.h - 2 },
                             sdl2.mapColorRGB(surface.format, background));

        const name = try renderCardText(renderer.name_font, &renderer.rendered_name, card.name);
        const description = try renderCardText(renderer.description_font, &renderer.rendered_description,
                                           card.description);

        var point = sdl2.Point{ .x = card_rect.x + card_padding,
                                .y = card_rect.y + card_padding };

        _ = try sdl2.blitSurface(name, null, surface, point);
        point.y += name.h + name_bottom_margin;

        _ = try sdl2.blitSurface(description, null, surface, point);
    }

    pub fn renderPlay(renderer: *Renderer, state: *State, surface: *sdl2.Surface) !void {
        const player = state.activePlayer();

        var previous_card: ?Card = null;
        var xoffset: usize = 0;
        var yoffset: c_int = 0;

        for (player.play.items) |card, i| {
            if (card == previous_card) {
                xoffset += 1;
                yoffset += 1;
            } else {
                yoffset = 0;
            }
            previous_card = card;

            const card_rect = .{
                .x = (card_width + card_margin) * @intCast(c_int, i - xoffset) + card_margin,
                .y = 100 + 35 * yoffset,
                .w = card_width,
                .h = card_height,
            };

            const shadow_height = 1;

            try renderer.renderCard(surface, card, card_rect, shadow_height);
        }
    }
};

fn renderCardText(font: *sdl2_ttf.Font, map: *std.StringHashMap(*sdl2.Surface),
                  text: [:0]const u8) !*sdl2.Surface {
    return renderText(font, map, text, card_width - card_padding * 2);
}

fn renderText(font: *sdl2_ttf.Font, map: *std.StringHashMap(*sdl2.Surface),
              text: [:0]const u8, wrap: u32) !*sdl2.Surface {
    if (map.get(text)) |surface|
        return surface;

    const black = sdl2_ttf.Color{ .r = 0, .g = 0, .b = 0, .a = 0xff };
    if (sdl2_ttf.renderTextBlendedWrapped(font, text, black, wrap))
        |surface| {
        try map.put(text, surface);
        return surface;
    } else {
        return error.RenderText;
    }
}
