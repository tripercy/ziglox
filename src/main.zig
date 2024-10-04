const std = @import("std");
const chunkLib = @import("chunk.zig");
const debug = @import("debug.zig");
const vmLib = @import("vm.zig");

const Chunk = chunkLib.Chunk;
const OpCode = chunkLib.OpCode;

pub fn main() !void {
    var chunk = Chunk.init(std.heap.page_allocator);
    defer chunk.deinit();

    try chunk.writeConstant(1.2, 1);
    try chunk.writeConstant(3.4, 1);
    try chunk.writeChunk(@intFromEnum(OpCode.ADD), 1);
    try chunk.writeConstant(5.6, 1);
    try chunk.writeChunk(@intFromEnum(OpCode.DIVIDE), 1);
    try chunk.writeChunk(@intFromEnum(OpCode.RETURN), 132);

    var vm = vmLib.VM.init();
    defer vm.deinit();

    _ = vm.interpret(&chunk);
}

test "simple test" {
    var chunk = Chunk.init(std.testing.allocator);
    defer chunk.deinit();

    try chunk.writeChunk(@intFromEnum(OpCode.RETURN));
}
