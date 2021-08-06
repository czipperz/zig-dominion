const std = @import("std");
const enable = !std.builtin.is_test and @import("build_options").tracy_enable;
pub usingnamespace @import("tracy").instance(enable);
