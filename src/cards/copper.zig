usingnamespace @import("../card.zig");
usingnamespace @import("../treasure.zig");

pub const copper = CardClass {
    .name = "Copper",
    .cost = 0,
    .description = "Gain one coin",
    .type = .treasure,
    .action = action(playTreasure(1)),
};

usingnamespace @import("../scenario.zig");

test {
    var scenario = try Scenario.simple(2);
    defer scenario.deinit();

    try scenario.play(&copper);

    const player = scenario.state.activePlayer();
    try expect(player.coins == 1);
}
