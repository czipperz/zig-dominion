usingnamespace @import("state.zig");
usingnamespace @import("error.zig");

pub fn doNothing(state: *State) !void {
    _ = state;
}

pub fn staticScore(comptime num: u32) fn(*const State)u32 {
    return struct {
        fn victoryPoints(state: *const State) u32 {
            _ = state;
            return num;
        }
    }.victoryPoints;
}
