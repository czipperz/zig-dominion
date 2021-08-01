const std = @import("std");

pub const State = struct {
    players: []Player,
    active_player: usize,

    pub fn setup(num_players: usize) !State {
        const allocator = std.heap.c_allocator;

        std.debug.assert(num_players > 0);
        const players = try allocator.alloc(Player, num_players);
        for (players) |*player| {
            player.* = .{
                .coins = 0,
            };
        }

        return State {
            .players = players,
            .active_player = 0,
        };
    }

    pub fn activePlayer(state: *State) *Player {
        return &state.players[state.active_player];
    }

    pub fn deinit(state: *State) void {
        const allocator = std.heap.c_allocator;
        allocator.free(state.players);
    }
};

pub const Player = struct {
    coins: u32,
};


const expect = @import("std").testing.expect;

test "State.setup 2 players" {
    var state = try State.setup(2);
    defer state.deinit();

    try expect(state.activePlayer() == &state.players[0]);
    for (state.players) |player| {
        try expect(player.coins == 0);
    }
}
