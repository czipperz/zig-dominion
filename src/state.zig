const std = @import("std");
usingnamespace @import("card.zig");
usingnamespace @import("cards/copper.zig");
usingnamespace @import("cards/estate.zig");

pub const State = struct {
    players: []Player,
    active_player: usize,

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
            var deck = std.ArrayList(Card).init(allocator);
            try deck.ensureTotalCapacity(10);
            var i: usize = 0; while (i < 7) : (i += 1) {
                deck.appendAssumeCapacity(&copper);
            }
            i = 0; while (i < 3) : (i += 1) {
                deck.appendAssumeCapacity(&estate);
            }
            prng.random.shuffle(Card, deck.items);

            player.* = .{
                .coins = 0,
                .actions = 1,
                .hand = std.ArrayList(Card).init(allocator),
                .deck = deck,
                .discard = std.ArrayList(Card).init(allocator),
            };
            try player.draw(&prng.random, 5);
        }

        return State {
            .players = players,
            .active_player = 0,

            .input_stack = std.ArrayList(MockInput).init(allocator),

            .prng = prng,
        };
    }

    pub fn activePlayer(state: *State) *Player {
        return &state.players[state.active_player];
    }

    pub fn deinit(state: *State) void {
        const allocator = std.heap.c_allocator;
        for (state.players) |*player| player.deinit();
        allocator.free(state.players);

        for (state.input_stack.items) |*mock_input| mock_input.deinit();
        state.input_stack.deinit();
    }

    pub fn selectCards(state: *State, prompt: []const u8, min: usize, max: usize) !std.DynamicBitSet {
        if (state.input_stack.popOrNull()) |mock_input| {
            switch (mock_input) {
                .selected_cards => |bit_set| {
                    const count = bit_set.count();
                    std.debug.assert(count >= min);
                    std.debug.assert(count < max);
                    return bit_set;
                },
                // else => std.debug.panic("Expected MockInput.select_cards, found {}", .{mock_input}),
            }
        }

        _ = prompt;
        std.debug.panic("unimplemented", .{});
    }

    pub fn random(state: *State) *std.rand.Random { return &state.prng.random; }
};

pub const Player = struct {
    coins: u32,
    actions: u32,

    hand: std.ArrayList(Card),
    deck: std.ArrayList(Card),
    discard: std.ArrayList(Card),

    pub fn deinit(player: *Player) void {
        player.hand.deinit();
        player.deck.deinit();
        player.discard.deinit();
    }

    /// Draw the specified number of cards.
    pub fn draw(player: *Player, random: *std.rand.Random, num_in: usize) !void {
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
