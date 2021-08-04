usingnamespace @import("../card.zig");
usingnamespace @import("../victory.zig");

pub const estate = CardClass {
    .name = "Estate",
    .cost = 2,
    .description = "Worth 1 victory point",
    .type = .victory,
    .action = doNothing,
    .victory_points = staticScore(1),
};

usingnamespace @import("../scenario.zig");

test {
    var scenario = try Scenario.simple(2);
    defer scenario.deinit();

    const player = scenario.state.activePlayer();
    try expect(player.victoryPoints(&scenario.state) == 3);
    try player.deck.append(&estate);
    try expect(player.victoryPoints(&scenario.state) == 4);

    try scenario.play(&estate);
    try expect(player.play.items.len == 1);
}
