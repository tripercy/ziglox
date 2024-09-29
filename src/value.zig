const std = @import("std");

pub const Value = f32;

pub const ValueArr = struct {
    values: std.ArrayList(Value),

    pub fn init(allocator: std.mem.Allocator) ValueArr {
        return ValueArr{ .values = std.ArrayList(Value).init(allocator) };
    }

    pub fn deinit(this: *ValueArr) void {
        this.values.deinit();
    }

    pub fn writeValue(this: *ValueArr, value: Value) !void {
        try this.values.append(value);
    }
};

pub fn printValue(value: Value) void {
    std.debug.print("{d}", .{value});
}
