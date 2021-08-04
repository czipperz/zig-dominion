usingnamespace @import("../card.zig");
usingnamespace @import("../victory.zig");
usingnamespace @import("../state.zig");

fn playVillage(self: Card, state: *State) !void {
    const player = state.activePlayer();

    try player.addToPlay(self);

    try player.draw(state.random(), 1);
    player.actions += 2;
}

pub const village = CardClass {
    .name = "Village",
    .cost = 3,
    .description =
        \\+1 Card
        \\+2 Actions
        ,
    .type = .action_general,
    .action = action(playVillage),
};

usingnamespace @import("../scenario.zig");

test "Village select card" {
    var scenario = try Scenario.simple(2);
    defer scenario.deinit();

    const player = scenario.state.activePlayer();
    try scenario.play(&village);
    try expect(player.hand.items.len == 6);
    try expect(player.actions == 3);
}
