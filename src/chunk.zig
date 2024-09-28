const std = @import("std");

pub const OpCode = enum(u8) {
    RETURN,
};

pub const Chunk = struct {
    code: std.ArrayList(u8),

    pub fn init(allocator: std.mem.Allocator) Chunk {
        return Chunk{
            .code = std.ArrayList(u8).init(allocator),
        };
    }

    pub fn deinit(this: *Chunk) void {
        this.code.deinit();
    }

    pub fn writeChunk(this: *Chunk, byte: u8) !void {
        try this.code.append(byte);
    }
};
