usingnamespace @import("state.zig");
usingnamespace @import("error.zig");

pub const Card = *const CardClass;

pub const CardClass = struct {
    name: [:0]const u8,
    cost: u8,
    description: [:0]const u8,
    type: CardType,
    action: fn(card: Card, state: *State) Error!void,
    victory_points: fn(state: *const State) i32 = noVictoryPoints,
};

fn noVictoryPoints(state: *const State) i32 {
    _ = state;
    return 0;
}

pub const CardType = enum {
    treasure,
    curse,
    victory,
    action_general,
    action_attack,
    action_reaction,
};
