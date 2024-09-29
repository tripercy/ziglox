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
    var constant = try chunk.addConstant(3);
    try chunk.writeChunk(@intFromEnum(OpCode.CONSTANT), 125);
    try chunk.writeChunk(constant, 125);
    constant = try chunk.addConstant(1.4);
    try chunk.writeChunk(@intFromEnum(OpCode.CONSTANT), 125);
    try chunk.writeChunk(constant, 125);
}

test "simple test" {
    var chunk = Chunk.init(std.testing.allocator);
    defer chunk.deinit();

    try chunk.writeChunk(@intFromEnum(OpCode.RETURN));
}
