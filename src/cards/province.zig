usingnamespace @import("../card.zig");
usingnamespace @import("../victory.zig");

pub const province = CardClass {
    .name = "Province",
    .cost = 8,
    .description = "Worth 6 victory points",
    .type = .victory,
    .action = action(doNothing),
    .victory_points = staticScore(6),
};

usingnamespace @import("../scenario.zig");

test {
    var scenario = try Scenario.simple(2);
    defer scenario.deinit();

    try expect(scenario.state.activePlayer().victoryPoints(&scenario.state) == 3);
    try scenario.state.activePlayer().deck.append(&province);
    try expect(scenario.state.activePlayer().victoryPoints(&scenario.state) == 9);
}
