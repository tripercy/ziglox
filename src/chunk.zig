const std = @import("std");
const valueLib = @import("value.zig");

pub const OpCode = enum(u8) {
    RETURN,
    CONSTANT,
};

pub const Chunk = struct {
    code: std.ArrayList(u8),
    constants: valueLib.ValueArr,
    lines: std.ArrayList(u32),

    pub fn init(allocator: std.mem.Allocator) Chunk {
        return Chunk{
            .code = std.ArrayList(u8).init(allocator),
            .constants = valueLib.ValueArr.init(allocator),
            .lines = std.ArrayList(u32).init(allocator),
        };
    }

    pub fn deinit(this: *Chunk) void {
        this.code.deinit();
        this.constants.deinit();
        this.lines.deinit();
    }

    pub fn writeChunk(this: *Chunk, byte: u8, line: u32) !void {
        try this.code.append(byte);
        try this.lines.append(line);
    }

    pub fn addConstant(this: *Chunk, value: valueLib.Value) !u8 {
        try this.constants.writeValue(value);
        return @intCast(this.constants.values.items.len - 1);
    }
};
