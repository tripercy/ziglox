const std = @import("std");
const valueLib = @import("value.zig");

pub const OpCode = enum(u8) {
    RETURN,
    CONSTANT,
    CONSTANT_LONG,
    NEGATE,
    ADD,
    SUBTRACT,
    MULTIPLY,
    DIVIDE,
    NIL,
    TRUE,
    FALSE,
    NOT,
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

        if (this.lines.items.len == 0) {
            try this.lines.append(line);
            try this.lines.append(0);
        }
        const linesSize = this.lines.items.len;
        if (this.lines.items[linesSize - 2] == line) {
            this.lines.items[linesSize - 1] += 1;
        } else {
            try this.lines.append(line);
            try this.lines.append(1);
        }
    }

    pub fn writeConstant(this: *Chunk, value: valueLib.Value, line: u32) !void {
        const constantIndex = try this.addConstant(value);

        try this.writeChunk(@intFromEnum(OpCode.CONSTANT_LONG), line);

        inline for (0..3) |i| {
            const byte = constantIndex >> (2 - i) * 8;
            try this.writeChunk(@intCast(byte), line);
        }
    }

    pub fn getLine(this: *Chunk, opIndex: u32) u32 {
        var i: u32 = 0;
        var indexPassed = this.lines.items[1];
        while (indexPassed <= opIndex) {
            i += 2;
            indexPassed += this.lines.items[i + 1];
        }
        // std.debug.print("{d} - {d}\n", .{ opIndex, i });
        return this.lines.items[i];
    }

    pub fn addConstant(this: *Chunk, value: valueLib.Value) !u32 {
        try this.constants.writeValue(value);
        return @intCast(this.constants.values.items.len - 1);
    }
};
