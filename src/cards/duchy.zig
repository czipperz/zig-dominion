usingnamespace @import("../card.zig");
usingnamespace @import("../victory.zig");

pub const duchy = CardClass {
    .name = "Duchy",
    .cost = 5,
    .description = "Worth 3 victory points",
    .type = .victory,
    .action = action(doNothing),
    .victory_points = staticScore(3),
};

usingnamespace @import("../scenario.zig");

test {
    var scenario = try Scenario.simple(2);
    defer scenario.deinit();

    try expect(scenario.state.activePlayer().victoryPoints(&scenario.state) == 3);
    try scenario.state.activePlayer().deck.append(&duchy);
    try expect(scenario.state.activePlayer().victoryPoints(&scenario.state) == 6);
}
