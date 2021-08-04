usingnamespace @import("card.zig");
usingnamespace @import("state.zig");
usingnamespace @import("error.zig");

pub fn playTreasure(comptime num: u32) fn(Card, *State)Error!void {
    return struct {
        fn action(self: Card, state: *State) !void {
            const player = state.activePlayer();

            try player.play.append(self);

            player.coins += num;
        }
    }.action;
}
