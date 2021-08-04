const std = @import("std");
pub const expect = std.testing.expect;
usingnamespace @import("state.zig");
usingnamespace @import("card.zig");

pub const Scenario = struct {
    state: State,

    pub fn simple(players: usize) !Scenario {
        return Scenario{
            .state = try State.setup(players),
        };
    }

    pub fn deinit(scenario: *Scenario) void {
        scenario.state.deinit();
    }

    pub fn play(scenario: *Scenario, card: *const CardClass) !void {
        try card.action.func(card, &scenario.state);
    }

    pub fn pushSelectCards(scenario: *Scenario, cards: []const usize) !void {
        try scenario.state.input_stack.ensureUnusedCapacity(1);

        const hand_size = scenario.state.activePlayer().hand.items.len;
        var bit_set = try std.DynamicBitSet.initEmpty(hand_size, std.heap.c_allocator);
        for (cards) |card| bit_set.set(card);

        scenario.state.input_stack.appendAssumeCapacity(.{ .selected_cards = bit_set });
    }

    pub fn inputStackIsEmpty(scenario: *Scenario) bool {
        return scenario.state.input_stack.items.len == 0;
    }
};

test "Scenario.simple 2 players" {
    var scenario = try Scenario.simple(2);
    defer scenario.deinit();

    try expect(scenario.state.activePlayer() == &scenario.state.players[0]);
    for (scenario.state.players) |player| {
        try expect(player.coins == 0);
        try expect(player.deck.items.len == 5);
        try expect(player.hand.items.len == 5);
    }
}
