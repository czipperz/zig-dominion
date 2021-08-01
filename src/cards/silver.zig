usingnamespace @import("../card.zig");
usingnamespace @import("../treasure.zig");

pub const silver = CardClass {
    .name = "Silver",
    .cost = 3,
    .description = "Gain two coins",
    .type = .treasure,
    .action = playTreasure(2),
};

usingnamespace @import("../scenario.zig");

test {
    var scenario = try Scenario.simple(2);
    defer scenario.deinit();

    try scenario.play(&silver);
    try expect(scenario.state.activePlayer().coins == 2);
}
