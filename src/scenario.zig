const std = @import("std");
pub const expect = std.testing.expect;
usingnamespace @import("state.zig");
usingnamespace @import("card.zig");

pub const Scenario = struct {
    prng: std.rand.DefaultPrng,
    state: State,

    pub fn simple(players: usize) !Scenario {
        const seed = std.crypto.random.int(u64);
        var prng = std.rand.DefaultPrng.init(seed);

        return Scenario{
            .prng = prng,
            .state = try State.setup(&prng.random, players),
        };
    }

    pub fn deinit(scenario: *Scenario) void {
        scenario.state.deinit();
    }

    pub fn play(scenario: *Scenario, card: *const CardClass) !void {
        return card.action(&scenario.state);
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
