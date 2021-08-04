usingnamespace @import("../card.zig");
usingnamespace @import("../victory.zig");
usingnamespace @import("../state.zig");

fn victoryPoints(state: *const State) i32 {
    const player = state.activePlayerConst();

    return @intCast(i32, player.totalCards() / 10);
}

pub const gardens = CardClass {
    .name = "Gardens",
    .cost = 4,
    .description = "Worth 1 victory point per 10 cards you have (round down).",
    .type = .victory,
    .action = doNothing,
    .victory_points = victoryPoints,
};

usingnamespace @import("../scenario.zig");

test {
    var scenario = try Scenario.simple(2);
    defer scenario.deinit();

    const copper = @import("copper.zig").copper;

    const player = scenario.state.activePlayer();
    try expect(player.victoryPoints(&scenario.state) == 3);
    try player.deck.append(&gardens);
    try expect(player.totalCards() == 11);
    try expect(player.victoryPoints(&scenario.state) == 4);

    var i: u32 = 0; while (i < 8) : (i += 1) { try player.deck.append(&copper); }
    try expect(player.totalCards() == 19);
    try expect(player.victoryPoints(&scenario.state) == 4);

    try player.deck.append(&copper);
    try expect(player.totalCards() == 20);
    try expect(player.victoryPoints(&scenario.state) == 5);
}
