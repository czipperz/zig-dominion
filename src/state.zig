const std = @import("std");
usingnamespace @import("card.zig");
usingnamespace @import("cards/copper.zig");
usingnamespace @import("cards/estate.zig");

pub const State = struct {
    players: []Player,
    active_player: usize,
    trash: std.ArrayList(Card),

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

    pub fn selectCards(state: *State, prompt: []const u8, comptime cardLocation: CardLocation,
                       min: usize, max: usize) !std.DynamicBitSet {
        if (state.input_stack.popOrNull()) |mock_input| {
            switch (mock_input) {
                .selected_cards => |bit_set| {
                    const count = bit_set.count();
                    std.debug.assert(count >= min);
                    std.debug.assert(count <= max);
                    return bit_set;
                },
                // else => std.debug.panic("Expected MockInput.select_cards, found {}", .{mock_input}),
            }
        }

        _ = prompt;
        _ = cardLocation;
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
    play: std.ArrayList(Card),

    pub fn init(allocator: *std.mem.Allocator) Player {
        return .{
            .coins = 0,
            .actions = 1,
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

    pub fn addToPlay(player: *Player, card: Card) !void {
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

pub const CardLocation = enum {
    hand,
    discard,
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
