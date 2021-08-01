usingnamespace @import("../card.zig");
usingnamespace @import("../treasure.zig");

pub const copper = CardClass {
    .name = "Copper",
    .cost = 0,
    .description = "Gain one coin",
    .type = .treasure,
    .action = playTreasure(1),
};

usingnamespace @import("../scenario.zig");

test {
    var scenario = try Scenario.simple(2);
    defer scenario.deinit();

    try scenario.play(&copper);
    try expect(scenario.state.activePlayer().coins == 1);
}
