usingnamespace @import("../card.zig");
usingnamespace @import("../treasure.zig");

pub const gold = CardClass {
    .name = "Gold",
    .cost = 6,
    .description = "Gain three coins",
    .type = .treasure,
    .action = action(playTreasure(3)),
};

usingnamespace @import("../scenario.zig");

test {
    var scenario = try Scenario.simple(2);
    defer scenario.deinit();

    try scenario.play(&gold);
    try expect(scenario.state.activePlayer().coins == 3);
}
