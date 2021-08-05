usingnamespace @import("../card.zig");
usingnamespace @import("../victory.zig");
usingnamespace @import("../state.zig");

fn playSmithy(self: Card, state: *State) !void {
    const player = state.activePlayer();

    try player.draw(state.random(), 3);
}

pub const smithy = CardClass {
    .name = "Smithy",
    .cost = 4,
    .description = "+3 Cards",
    .type = .action_general,
    .action = action(playSmithy),
};

usingnamespace @import("../scenario.zig");

test "Smithy select card" {
    var scenario = try Scenario.simple(2);
    defer scenario.deinit();

    const player = scenario.state.activePlayer();
    try scenario.play(&smithy);
    try expect(player.hand.items.len == 8);
}
