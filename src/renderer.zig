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
const info_margin = 10;
const info_spacer = 20;
const scroll_width = 20;

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
    info_font: *sdl2_ttf.Font,
    rendered_name: std.StringHashMap(*sdl2.Surface),
    rendered_description: std.StringHashMap(*sdl2.Surface),
    rendered_prompt: std.StringHashMap(*sdl2.Surface),
    rendered_info_labels: std.StringHashMap(*sdl2.Surface),
    rendered_info_numbers: std.AutoHashMap(u32, *sdl2.Surface),

    hand_anim_state: std.ArrayList(HandAnimState),
    hand_scroll_state: ScrollState,

    prompt_scroll_state: ScrollState,

    const HandAnimState = struct {
        ystate: enum { selected, deselected, none } = .none,
        ystart: u32 = 0,
        xoffset: u32 = 0,
        xstart: u32 = 0,
    };

    const ScrollState = struct {
        scroll: f32 = 0,
        inside_left_since: ?u32 = null,
        inside_right_since: ?u32 = null,
    };

    pub fn init() !Renderer {
        const allocator = std.heap.c_allocator;
        const text_font_path = "C:/Windows/Fonts/georgia.ttf";
        const name_font = sdl2_ttf.openFont(text_font_path, 20, 0) orelse return error.OpenFont;
        const description_font = sdl2_ttf.openFont(text_font_path, 14, 0) orelse return error.OpenFont;
        const prompt_font = sdl2_ttf.openFont(text_font_path, 20, 0) orelse return error.OpenFont;
        const mono_font_path = "C:/Windows/Fonts/DejaVuSansMono.ttf";
        const info_font = sdl2_ttf.openFont(mono_font_path, 14, 0) orelse return error.OpenFont;
        return Renderer{
            .name_font = name_font,
            .description_font = description_font,
            .prompt_font = prompt_font,
            .info_font = info_font,
            .rendered_name = std.StringHashMap(*sdl2.Surface).init(allocator),
            .rendered_description = std.StringHashMap(*sdl2.Surface).init(allocator),
            .rendered_prompt = std.StringHashMap(*sdl2.Surface).init(allocator),
            .rendered_info_labels = std.StringHashMap(*sdl2.Surface).init(allocator),
            .rendered_info_numbers = std.AutoHashMap(u32, *sdl2.Surface).init(allocator),

            .hand_anim_state = std.ArrayList(HandAnimState).init(allocator),
            .hand_scroll_state = .{},
            .prompt_scroll_state = .{},
        };
    }

    pub fn deinit(renderer: *Renderer) void {
        sdl2_ttf.closeFont(renderer.name_font);
        sdl2_ttf.closeFont(renderer.description_font);
        sdl2_ttf.closeFont(renderer.prompt_font);
        sdl2_ttf.closeFont(renderer.info_font);
        renderer.rendered_name.deinit();
        renderer.rendered_description.deinit();
        renderer.rendered_prompt.deinit();
        renderer.rendered_info_labels.deinit();
        renderer.rendered_info_numbers.deinit();

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

            try renderer.renderInfo(state, surface);

            try renderer.renderPlay(state, surface);

            var check_prompt = false;
            if (state.prompt == null) {
                const played_card = try renderer.renderHand(state, surface, mouse_point, &mouse_down, ticks);
                if (played_card) |card| {
                    // Play the card.
                    try state.playCard(card);

                    // Reset the scroll state.
                    if (state.prompt) |prompt| {
                        if (prompt.location == .hand) {
                            renderer.prompt_scroll_state = renderer.hand_scroll_state;
                        } else {
                            renderer.prompt_scroll_state = .{};
                        }
                    }

                    // Check for a prompt.
                    repaint = true;
                    check_prompt = true;
                }
            } else {
                const submitted = try renderer.renderPrompt(state, surface, mouse_point, &mouse_down, ticks);
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

    fn renderInfo(renderer: *Renderer, state: *State, surface: *sdl2.Surface) !void {
        const player = state.activePlayer();

        var point = sdl2.Point{ .x = info_margin, .y = info_margin };

        try renderer.renderInfoStat(surface, &point, "Actions: ", player.actions);
        try renderer.renderInfoStat(surface, &point, "Coins: ", player.coins);
    }

    fn renderInfoStat(renderer: *Renderer, surface: *sdl2.Surface, point: *sdl2.Point,
                      title: [:0]const u8, number: u32) !void {
        const title_surface = try renderText(renderer.info_font, &renderer.rendered_info_labels,
                                             title, @intCast(u32, surface.w));
        _ = try sdl2.blitSurface(title_surface, null, surface, point.*);
        point.x += title_surface.w;

        const number_surface = try renderNumber(renderer.info_font, &renderer.rendered_info_numbers,
                                                number, @intCast(u32, surface.w));
        _ = try sdl2.blitSurface(number_surface, null, surface, point.*);
        point.x += number_surface.w + info_spacer;
    }

    fn renderPrompt(renderer: *Renderer, state: *State, surface: *sdl2.Surface,
                        mouse_point: ?sdl2.Point, mouse_down: *bool, ticks: u32) !bool {
        const player = state.activePlayer();
        const prompt = state.prompt.?;
        const result = &state.prompt_result.?;
        const result_count = result.count();

        calculateScrollState(&renderer.prompt_scroll_state, surface, mouse_point, ticks, player.getLocation(prompt.location).len);

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

        const can_submit = result_count >= prompt.min and result_count <= prompt.max;

        var submit_rect_color = sdl2.mapRGB(surface.format, 0x0d, 0xb8, 0xce);
        if (!can_submit)
            submit_rect_color = sdl2.mapRGB(surface.format, 0xba, 0xcc, 0xcf);

        if (mouse_point) |mouse| {
            if (submit_rect.contains(mouse) and can_submit) {
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
                .x = (card_width + card_margin) * @intCast(c_int, i) + card_margin
                     - @floatToInt(c_int, renderer.prompt_scroll_state.scroll),
                .y = surface.h - card_height,
                .w = card_width,
                .h = card_height,
            };

            if (mouse_point) |mouse| {
                if (card_rect.contains(mouse)) {
                    if (mouse_down.*) {
                        // Always allow toggling off.  Only allow
                        // toggling on for cards matching predicate.
                        if (result.isSet(i)) {
                            result.toggle(i);
                        } else if (prompt.predicate(card)) {
                            // If we can only select one card then do "bullet
                            // point" mode by unsetting the other set indices.
                            if (prompt.max == 1)
                                _ = result.toggleFirstSet();

                            result.toggle(i);
                        }
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

    fn renderHand(renderer: *Renderer, state: *State, surface: *sdl2.Surface,
                      mouse_point: ?sdl2.Point, mouse_down: *bool, ticks: u32) !?Card {
        const player = state.activePlayer();

        try surface.fillRect(.{ .x = 0, .y = surface.h - hand_height,
                                .w = surface.w, .h = hand_height },
                             sdl2.mapRGB(surface.format, 0xcc, 0xcc, 0xcc));

        calculateScrollState(&renderer.hand_scroll_state, surface, mouse_point, ticks, player.hand.items.len);

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
                .x = (card_width + card_margin) * @intCast(c_int, i) + card_margin
                     - @floatToInt(c_int, renderer.hand_scroll_state.scroll),
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
            if (contains_mouse and player.canPlay(player.hand.items[i])) {
                if (mouse_down.*) {
                    const card = player.hand.orderedRemove(i);
                    _ = renderer.hand_anim_state.orderedRemove(i);

                    for (hand_anim_state[i..]) |*anim_state| {
                        if (anim_state.xoffset == 0) {
                            anim_state.xstart = ticks;
                        }
                        anim_state.xoffset += 1;
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

    fn renderCard(renderer: *Renderer, surface: *sdl2.Surface,
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

    fn renderPlay(renderer: *Renderer, state: *State, surface: *sdl2.Surface) !void {
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

fn renderNumber(font: *sdl2_ttf.Font, map: *std.AutoHashMap(u32, *sdl2.Surface),
                number: u32, wrap: u32) !*sdl2.Surface {
    if (map.get(number)) |surface| {
        return surface;
    }

    const text = try std.fmt.allocPrintZ(std.heap.c_allocator, "{}", .{number});
    defer std.heap.c_allocator.free(text);

    const black = sdl2_ttf.Color{ .r = 0, .g = 0, .b = 0, .a = 0xff };
    if (sdl2_ttf.renderTextBlendedWrapped(font, text, black, wrap))
        |surface| {
        try map.put(number, surface);
        return surface;
    } else {
        return error.RenderText;
    }
}

fn ticksInsideRegion(mouse_point: ?sdl2.Point, rect: sdl2.Rect, ticks: u32, tracker: *?u32) u32 {
    var inside_left = false;
    if (mouse_point) |mouse| {
        inside_left = rect.contains(mouse);
    }

    if (inside_left) {
        if (tracker.*) |since| {
            return ticks - since;
        } else {
            tracker.* = ticks;
            return 0;
        }
    } else {
        tracker.* = null;
        return 0;
    }
}

fn calculateScrollState(scroll_state: *Renderer.ScrollState, surface: *sdl2.Surface, mouse_point: ?sdl2.Point, ticks: u32, num_cards: usize) void {
    // Scroll left.
    const left_rect = sdl2.Rect{ .x = 0, .y = surface.h - hand_height,
                                 .w = scroll_width, .h = hand_height };
    scroll_state.scroll -=
        @intToFloat(f32, ticksInsideRegion(mouse_point, left_rect, ticks,
                                           &scroll_state.inside_left_since))
                / 20;

    // Scroll right.
    var right_rect = left_rect;
    right_rect.x = surface.w - right_rect.w;
    scroll_state.scroll +=
        @intToFloat(f32, ticksInsideRegion(mouse_point, right_rect, ticks,
                                           &scroll_state.inside_right_since))
                / 20;

    // Bound scroll.
    scroll_state.scroll = @minimum(scroll_state.scroll, @intToFloat(f32, (card_width + card_margin) * (@intCast(c_int, num_cards) + 1) + card_margin - surface.w));
    scroll_state.scroll = @maximum(scroll_state.scroll, -(card_width + card_margin));
}
