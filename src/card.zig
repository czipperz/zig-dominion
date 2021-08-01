usingnamespace @import("state.zig");
usingnamespace @import("error.zig");

pub const Card = *const CardClass;

pub const CardClass = struct {
    name: []const u8,
    cost: u8,
    description: []const u8,
    type: CardType,
    action: fn(state: *State) Error!void,
};

pub const CardType = enum {
    treasure,
    curse,
    victory,
    action_general,
    action_attack,
    action_reaction,
};
