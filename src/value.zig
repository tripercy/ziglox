const std = @import("std");
const objLib = @import("object.zig");

const Obj = objLib.Obj;
const ObjString = objLib.ObjString;

pub const Value = union(enum) {
    boolean: bool,
    number: f64,
    obj: *Obj,
    nil,

    pub fn isString(this: *const Value) bool {
        if (this.* != .obj) {
            return false;
        }
        return this.obj.type == .STRING;
    }
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

pub fn objVal(obj: *Obj) Value {
    return Value{ .obj = obj };
}

pub fn valuesEqual(a: Value, b: Value) bool {
    if (std.meta.activeTag(a) != std.meta.activeTag(b)) {
        return false;
    }
    switch (a) {
        .obj => |obj| {
            switch (obj.type) {
                .STRING => return a.obj == b.obj,
                // else => unreachable,
            }
        },
        else => return std.meta.eql(a, b),
    }
    unreachable;
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
        .obj => |obj| printObj(obj),
    }
}

fn printObj(obj: *Obj) void {
    switch (obj.type) {
        .STRING => {
            const string = @as(*ObjString, @ptrCast(@alignCast(obj)));
            std.debug.print("{s}", .{string.chars});
        },
    }
}
