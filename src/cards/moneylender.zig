usingnamespace @import("../card.zig");
usingnamespace @import("../victory.zig");
usingnamespace @import("../state.zig");
usingnamespace @import("copper.zig");

fn isCopper(card: Card) bool {
    return card == &copper;
}

fn playMoneylender(self: Card, state: *State) !void {
    const player = state.activePlayer();

    try player.addToPlay(self);

    var cards = try state.selectCards(
        .{ .message = "You may trash a Copper from your hand for +3 coins.",
           .location = .hand, .max = 1, .predicate = isCopper, });
    defer cards.deinit();

    if (cards.findFirstSet()) |index| {
        try state.trash.ensureUnusedCapacity(1);
        const card = player.hand.orderedRemove(index);
        state.trash.appendAssumeCapacity(card);

        player.coins += 3;
    }
}

pub const moneylender = CardClass {
    .name = "Moneylender",
    .cost = 4,
    .description = "You may trash a Copper from your hand for +3 coins.",
    .type = .action_general,
    .action = action(playMoneylender),
};

usingnamespace @import("../scenario.zig");

test "Moneylender select card" {
    var scenario = try Scenario.simple(2);
    defer scenario.deinit();

    const player = scenario.state.activePlayer();
    try player.hand.append(&copper);
    try expect(player.hand.items.len == 6);
    try scenario.pushSelectCards(&.{player.hand.items.len - 1});

    try scenario.play(&moneylender);
    try expect(scenario.inputStackIsEmpty());

    try expect(player.hand.items.len == 5);
    try expect(scenario.state.trash.items.len == 1);
    try expect(player.coins == 3);
}

test "Moneylender don't select card" {
    var scenario = try Scenario.simple(2);
    defer scenario.deinit();

    const player = scenario.state.activePlayer();
    try player.hand.append(&copper);
    try expect(player.hand.items.len == 6);
    try scenario.pushSelectCards(&.{});

    try scenario.play(&moneylender);
    try expect(scenario.inputStackIsEmpty());

    try expect(player.hand.items.len == 6);
    try expect(scenario.state.trash.items.len == 0);
    try expect(player.coins == 0);
}
