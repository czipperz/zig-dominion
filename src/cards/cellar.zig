usingnamespace @import("../card.zig");
usingnamespace @import("../victory.zig");
usingnamespace @import("../state.zig");

fn playCellar(state: *State) !void {
    const player = state.activePlayer();

    player.actions += 1;

    var cards = try state.selectCards(.{
                        .message = "Discard any number of cards, then draw that many",
                        .location = .hand, .max = player.hand.items.len });
    defer cards.deinit();

    const count = cards.count();
    try player.discard.ensureUnusedCapacity(count);

    var it = cards.iterator(.{ .direction = .reverse });
    while (it.next()) |index| {
        const card = player.hand.orderedRemove(index);
        player.discard.appendAssumeCapacity(card);
    }

    try player.draw(state.random(), count);
}

pub const cellar = CardClass {
    .name = "Cellar",
    .cost = 2,
    .description =
        \\+1 actions
        \\Discard any number of cards, then draw that many.
        ,
    .type = .action_general,
    .action = action(playCellar),
};

usingnamespace @import("../scenario.zig");

test {
    var scenario = try Scenario.simple(2);
    defer scenario.deinit();

    try scenario.pushSelectCards(&.{1, 2, 4});
    try scenario.play(&cellar);
    try expect(scenario.inputStackIsEmpty());

    const player = scenario.state.activePlayer();
    try expect(player.hand.items.len == 5);
    try expect(player.discard.items.len == 3);
    try expect(player.actions == 2);
    try expect(player.play.items.len == 1);
}
