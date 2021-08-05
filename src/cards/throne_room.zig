usingnamespace @import("../card.zig");
usingnamespace @import("../victory.zig");
usingnamespace @import("../state.zig");

fn isAction(card: Card) bool {
    return card.isAction();
}

fn playThroneRoom(self: Card, state: *State) !void {
    const player = state.activePlayer();

    try player.addToPlay(self);

    var cards = try state.selectCards(.{
                        .message = "You may play an Action card from your hand twice.",
                        .location = .hand, .max = 1, .predicate = isAction });
    defer cards.deinit();

    if (cards.findFirstSet()) |index| {
        const card = player.hand.orderedRemove(index);
        try state.playInstant(card);
        try state.playInstant(card);
    }
}

pub const throne_room = CardClass {
    .name = "Throne Room",
    .cost = 4,
    .description = "You may play an Action card from your hand twice.",
    .type = .action_general,
    .action = action(playThroneRoom),
};

usingnamespace @import("../scenario.zig");

test "Throne Room select card" {
    var scenario = try Scenario.simple(2);
    defer scenario.deinit();

    const village = @import("village.zig").village;
    const player = scenario.state.activePlayer();
    try player.hand.append(&village);
    try scenario.pushSelectCards(&.{5});
    try scenario.play(&throne_room);
    try expect(player.hand.items.len == 7);
    try expect(player.actions == 5);
}
