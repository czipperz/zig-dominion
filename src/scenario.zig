pub const expect = @import("std").testing.expect;
usingnamespace @import("state.zig");
usingnamespace @import("card.zig");

pub const Scenario = struct {
    state: State,

    pub fn simple(players: usize) !Scenario {
        return Scenario{
            .state = try State.setup(players),
        };
    }

    pub fn deinit(scenario: *Scenario) void {
        scenario.state.deinit();
    }

    pub fn play(scenario: *Scenario, card: *const CardClass) !void {
        return card.action(&scenario.state);
    }
};
