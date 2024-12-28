const std = @import("std");

pub const Value = union(enum) {
    boolean: bool,
    number: f64,
    nil,
};

pub fn boolVal(value: bool) Value {
    return Value{ .boolean = value };
}

pub fn nilVal() Value {
    return Value{ .nil = {} };
}

pub fn numberVal(value: f64) Value {
    return Value{ .number = value };
}

pub fn valuesEqual(a: Value, b: Value) bool {
    return std.meta.eql(a, b);
}

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
    switch (value) {
        .number => |num| std.debug.print("{d}", .{num}),
        .boolean => |boolean| std.debug.print("{s}", .{if (boolean) "TRUE" else "FALSE"}),
        .nil => std.debug.print("NIL", .{}),
    }
}
