const std = @import("std");
usingnamespace @import("card.zig");
usingnamespace @import("cards/copper.zig");
usingnamespace @import("cards/estate.zig");
usingnamespace @import("error.zig");

pub const State = struct {
    players: []Player,
    active_player: usize,
    trash: std.ArrayList(Card),

    prompt: ?Prompt,
    prompt_result: ?std.DynamicBitSet,
    prompt_frame: ?anyframe,
    card_stack: ?[]align(8) u8,
    card_frame: ?anyframe->Error!void,

    /// Input stack is only used for testing.
    input_stack: std.ArrayList(MockInput),

    prng: std.rand.DefaultPrng,

    pub fn setup(num_players: usize) !State {
        const allocator = std.heap.c_allocator;

        const seed = std.crypto.random.int(u64);
        var prng = std.rand.DefaultPrng.init(seed);

        std.debug.assert(num_players > 0);
        const players = try allocator.alloc(Player, num_players);
        for (players) |*player| {
            player.* = Player.init(allocator);

            try player.deck.ensureTotalCapacity(10);
            var i: usize = 0; while (i < 7) : (i += 1) {
                player.deck.appendAssumeCapacity(&copper);
            }
            i = 0; while (i < 3) : (i += 1) {
                player.deck.appendAssumeCapacity(&estate);
            }
            prng.random.shuffle(Card, player.deck.items);

            try player.draw(&prng.random, 5);
        }

        return State {
            .players = players,
            .active_player = 0,
            .trash = std.ArrayList(Card).init(allocator),

            .prompt = null,
            .prompt_result = null,
            .prompt_frame = null,
            .card_stack = null,
            .card_frame = null,

            .input_stack = std.ArrayList(MockInput).init(allocator),

            .prng = prng,
        };
    }

    pub fn activePlayer(state: *State) *Player {
        return &state.players[state.active_player];
    }
    pub fn activePlayerConst(state: *const State) *const Player {
        return &state.players[state.active_player];
    }

    pub fn deinit(state: *State) void {
        const allocator = std.heap.c_allocator;
        for (state.players) |*player| player.deinit();
        allocator.free(state.players);

        for (state.input_stack.items) |*mock_input| mock_input.deinit();
        state.input_stack.deinit();

        state.trash.deinit();
    }

    pub fn playCard(state: *State, card: Card) !void {
        const zone = tracy.startZone(@src());
        zone.text(card.name);
        defer zone.end();

        const player = state.activePlayer();
        if (card.isAction())
            player.actions -= 1;
        try player.addToPlay(card);

        state.card_stack = try std.heap.c_allocator.allocWithOptions(u8, card.action.frame_size, 8, null);
        state.card_frame = @asyncCall(state.card_stack.?, {}, card.action.func, .{state});
    }

    pub fn playInstant(state: *State, card: Card) !void {
        const zone = tracy.startZone(@src());
        zone.text(card.name);
        defer zone.end();

        if (@import("builtin").is_test) {
            try card.action.func(state);
        } else {
            const card_stack = try std.heap.c_allocator.allocWithOptions(u8, card.action.frame_size, 8, null);
            defer std.heap.c_allocator.free(card_stack);
            try await @asyncCall(card_stack, {}, card.action.func, .{state});
        }
    }

    pub const Prompt = struct {
        message: [:0]const u8,
        location: CardLocation,
        predicate: fn(Card)bool = struct { pub fn accept(_: Card) bool { return true; } }.accept,
        min: usize = 0,
        max: usize,
    };

    pub fn selectCards(state: *State, prompt: Prompt) !std.DynamicBitSet {
        const zone = tracy.startZone(@src());
        defer zone.end();

        if (@import("builtin").is_test) {
            switch (state.input_stack.pop()) {
                .selected_cards => |bit_set| {
                    const count = bit_set.count();
                    std.debug.assert(count >= prompt.min);
                    std.debug.assert(count <= prompt.max);

                    var xxx: *const std.DynamicBitSet = &bit_set;
                    _ = xxx;
                    var it = xxx.iterator(.{});
                    while (it.next()) |index| {
                        const player = state.activePlayer();
                        const slice = player.getLocation(prompt.location);
                        std.debug.assert(prompt.predicate(slice[index]));
                    }

                    return bit_set;
                },
                // else => std.debug.panic("Expected MockInput.select_cards, found {}", .{mock_input}),
            }
        } else {
            std.debug.assert(state.prompt == null);
            std.debug.assert(state.prompt_result == null);

            const size = state.activePlayer().getLocation(prompt.location).len;
            var bit_set = try std.DynamicBitSet.initEmpty(size, std.heap.c_allocator);

            state.prompt = prompt;
            state.prompt_result = bit_set;

            suspend { state.prompt_frame = @frame(); }

            const result = state.prompt_result.?;
            state.prompt = null;
            state.prompt_result = null;
            return result;
        }
    }

    pub fn random(state: *State) *std.rand.Random { return &state.prng.random; }
};

pub const Player = struct {
    coins: u32,
    actions: u32,
    buys: u32,

    hand: std.ArrayList(Card),
    deck: std.ArrayList(Card),
    discard: std.ArrayList(Card),
    play: std.ArrayList(Card),

    pub fn init(allocator: *std.mem.Allocator) Player {
        return .{
            .coins = 0,
            .actions = 1,
            .buys = 1,
            .hand = std.ArrayList(Card).init(allocator),
            .deck = std.ArrayList(Card).init(allocator),
            .discard = std.ArrayList(Card).init(allocator),
            .play = std.ArrayList(Card).init(allocator),
        };
    }

    pub fn deinit(player: *Player) void {
        player.hand.deinit();
        player.deck.deinit();
        player.discard.deinit();
        player.play.deinit();
    }

    pub fn totalCards(player: *const Player) usize {
        return player.hand.items.len + player.deck.items.len
             + player.discard.items.len + player.play.items.len;
    }

    pub fn getLocation(player: *const Player, location: CardLocation) []const Card {
        return switch (location) {
            .hand    => player.hand.items,
            .deck    => player.deck.items,
            .discard => player.discard.items,
            .play    => player.play.items,
        };
    }

    pub fn addToPlay(player: *Player, card: Card) !void {
        const zone = tracy.startZone(@src());
        defer zone.end();

        for (player.play.items) |pc, i| {
            if (pc == card) {
                var j = i + 1; while (j < player.play.items.len) : (j += 1) {
                    if (player.play.items[j] != card) break;
                }

                try player.play.insert(j, card);
                return;
            }
        }
        try player.play.append(card);
    }

    pub fn canPlay(player: *const Player, card: Card) bool {
        return if (card.isAction()) player.actions >= 1 else true;
    }

    /// Draw the specified number of cards.
    pub fn draw(player: *Player, random: *std.rand.Random, num_in: usize) !void {
        const zone = tracy.startZone(@src());
        defer zone.end();

        var num = num_in;
        try player.hand.ensureUnusedCapacity(num);

        // Draw from the deck.
        while (num > 0 and player.deck.items.len > 0) {
            player.hand.appendAssumeCapacity(player.deck.pop());
            num -= 1;
        }

        // Drew all the cards we need to.
        if (num == 0) return;

        // No more cards left to draw.
        if (player.discard.items.len == 0) return;

        // Shuffle discards into the deck.
        try player.deck.appendSlice(player.discard.items);
        player.discard.items.len = 0;
        random.shuffle(Card, player.deck.items);

        // Draw from the deck.
        while (num > 0 and player.deck.items.len > 0) {
            player.hand.appendAssumeCapacity(player.deck.pop());
            num -= 1;
        }
    }

    /// Get the total number of victory points for the player.
    pub fn victoryPoints(player: *const Player, state: *const State) i32 {
        var num: i32 = 0;
        for (player.hand.items) |card| num += card.victory_points(state);
        for (player.deck.items) |card| num += card.victory_points(state);
        for (player.discard.items) |card| num += card.victory_points(state);
        return num;
    }
};

pub const MockInput = union(enum) {
    selected_cards: std.DynamicBitSet,

    pub fn deinit(mock_input: *MockInput) void {
        switch (mock_input.*) {
            .selected_cards => |*bit_set| bit_set.deinit(),
        }
    }
};

pub const CardLocation = enum {
    hand,
    deck,
    discard,
    play,
};

const expect = std.testing.expect;

test "addToPlay does in order" {
    const cards = @import("cards.zig");

    var player = Player.init(std.heap.c_allocator);
    defer player.deinit();
    try expect(player.play.items.len == 0);

    try player.addToPlay(&cards.chapel);
    try expect(player.play.items.len == 1);

    try player.addToPlay(&cards.copper);
    try expect(player.play.items.len == 2);
    try expect(player.play.items[0] == &cards.chapel);
    try expect(player.play.items[1] == &cards.copper);

    try player.addToPlay(&cards.chapel);
    try expect(player.play.items.len == 3);
    try expect(player.play.items[0] == &cards.chapel);
    try expect(player.play.items[1] == &cards.chapel);
    try expect(player.play.items[2] == &cards.copper);
}
