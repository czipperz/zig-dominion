usingnamespace @import("../card.zig");
usingnamespace @import("../victory.zig");
usingnamespace @import("../state.zig");

fn playChapel(state: *State) !void {
    const player = state.activePlayer();

    var cards = try state.selectCards(.{ .message = "Trash up to 4 cards from your hand.",
                                         .location = .hand, .max = 4 });
    defer cards.deinit();

    const count = cards.count();
    try state.trash.ensureUnusedCapacity(count);

    var it = cards.iterator(.{ .direction = .reverse });
    while (it.next()) |index| {
        const card = player.hand.orderedRemove(index);
        state.trash.appendAssumeCapacity(card);
    }
}

pub const chapel = CardClass {
    .name = "Chapel",
    .cost = 2,
    .description = "Trash up to 4 cards from your hand.",
    .type = .action_general,
    .action = action(playChapel),
};

usingnamespace @import("../scenario.zig");

test {
    var scenario = try Scenario.simple(2);
    defer scenario.deinit();

    try scenario.pushSelectCards(&.{1, 2, 4});
    try scenario.play(&chapel);
    try expect(scenario.inputStackIsEmpty());

    const player = scenario.state.activePlayer();
    try expect(player.hand.items.len == 2);
    try expect(scenario.state.trash.items.len == 3);
}
