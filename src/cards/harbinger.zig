usingnamespace @import("../card.zig");
usingnamespace @import("../victory.zig");
usingnamespace @import("../state.zig");

fn action(self: Card, state: *State) !void {
    const player = state.activePlayer();

    try player.addToPlay(self);

    try player.draw(state.random(), 1);
    player.actions += 1;

    var cards = try state.selectCards(
        .{ .message = "Look through your discard pile. You may put a card from it onto your deck.",
           .location = .discard, .max = 1 });
    defer cards.deinit();

    if (cards.findFirstSet()) |index| {
        try player.deck.ensureUnusedCapacity(1);
        const card = player.discard.orderedRemove(index);
        player.deck.appendAssumeCapacity(card);
    }
}

pub const harbinger = CardClass {
    .name = "Harbinger",
    .cost = 3,
    .description =
        \\+1 Card
        \\+1 Action
        \\Look through your discard pile. You may put a card from it onto your deck.
        ,
    .type = .action_general,
    .action = action,
};

usingnamespace @import("../scenario.zig");

test "Harbinger select card" {
    var scenario = try Scenario.simple(2);
    defer scenario.deinit();

    const cards = @import("../cards.zig");

    const player = scenario.state.activePlayer();
    try player.discard.append(&cards.gold);
    try player.discard.append(&cards.silver);
    try player.discard.append(&cards.copper);

    try scenario.pushSelectCards(&.{0});
    try scenario.play(&harbinger);
    try expect(scenario.inputStackIsEmpty());

    try expect(player.hand.items.len == 6);
    try expect(player.discard.items.len == 2);
    try expect(player.deck.items.len == 5);
    try expect(player.deck.items[player.deck.items.len - 1] == &cards.gold);
}

test "Harbinger don't select card" {
    var scenario = try Scenario.simple(2);
    defer scenario.deinit();

    const cards = @import("../cards.zig");

    const player = scenario.state.activePlayer();
    try player.discard.append(&cards.gold);
    try player.discard.append(&cards.silver);
    try player.discard.append(&cards.copper);

    try scenario.pushSelectCards(&.{});
    try scenario.play(&harbinger);
    try expect(scenario.inputStackIsEmpty());

    try expect(player.hand.items.len == 6);
    try expect(player.discard.items.len == 3);
    try expect(player.deck.items.len == 4);
    try expect(player.play.items.len == 1);
}
