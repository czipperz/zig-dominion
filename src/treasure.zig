usingnamespace @import("card.zig");
usingnamespace @import("state.zig");
usingnamespace @import("error.zig");

pub fn playTreasure(comptime num: u32) fn(*State)Error!void {
    return struct {
        fn action(state: *State) !void {
            const player = state.activePlayer();

            player.coins += num;
        }
    }.action;
}
