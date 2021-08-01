usingnamespace @import("state.zig");
usingnamespace @import("error.zig");

pub fn playTreasure(comptime num: u32) fn(*State)Error!void {
    return struct {
        fn action(state: *State) !void {
            state.activePlayer().coins += num;
        }
    }.action;
}
