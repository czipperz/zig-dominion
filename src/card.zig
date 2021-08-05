usingnamespace @import("state.zig");
usingnamespace @import("error.zig");

pub const Card = *const CardClass;

pub const CardClass = struct {
    name: [:0]const u8,
    cost: u8,
    description: [:0]const u8,
    type: CardType,
    action: CardAction,
    victory_points: fn(state: *const State) i32 = noVictoryPoints,

    pub fn isAction(card: Card) bool {
        return switch (card.type) {
            .treasure, .curse, .victory => false,
            .action_general, .action_attack, .action_reaction => true,
        };
    }
};

pub const CardAction =
    if (@import("builtin").is_test)
        struct {
            func: fn(state: *State) Error!void,
        }
    else
        struct {
            func: fn(state: *State) callconv(.Async) Error!void,
            frame_size: usize,
        };

pub const action =
    if (@import("builtin").is_test)
        struct {
            pub fn action(comptime func: fn(state: *State) Error!void) CardAction {
                return .{
                    .func = func,
                };
            }
        }.action
    else
        struct {
            pub fn action(comptime func: fn(state: *State) callconv(.Async) Error!void) CardAction {
                return .{
                    .func = func,
                    .frame_size = @sizeOf(@Frame(func)),
                };
            }
        }.action;

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
