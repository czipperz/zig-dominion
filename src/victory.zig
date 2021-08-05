usingnamespace @import("card.zig");
usingnamespace @import("state.zig");
usingnamespace @import("error.zig");

pub fn doNothing(state: *State) !void {
    _ = state;
}

pub fn staticScore(comptime num: i32) fn(*const State)i32 {
    return struct {
        fn victoryPoints(state: *const State) i32 {
            _ = state;
            return num;
        }
    }.victoryPoints;
}
