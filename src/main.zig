const std = @import("std");
const chunkLib = @import("chunk.zig");
const debug = @import("debug.zig");

const Chunk = chunkLib.Chunk;
const OpCode = chunkLib.OpCode;

pub fn main() !void {
    var chunk = Chunk.init(std.heap.page_allocator);
    defer chunk.deinit();
    defer debug.disassembleChunk(&chunk, "test");

    try chunk.writeChunk(@intFromEnum(OpCode.RETURN), 123);
    const constant = try chunk.addConstant(3);
    try chunk.writeChunk(@intFromEnum(OpCode.CONSTANT), 125);
    try chunk.writeChunk(@intCast(constant), 125);
    try chunk.writeConstant(69.42, 420);
}

test "simple test" {
    var chunk = Chunk.init(std.testing.allocator);
    defer chunk.deinit();

    try chunk.writeChunk(@intFromEnum(OpCode.RETURN));
}
