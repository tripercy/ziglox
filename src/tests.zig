comptime {
    _ = @import("table.zig");
}

test {
    @import("std").testing.refAllDecls(@This());
}
