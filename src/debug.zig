const std = @import("std");
const chunkLib = @import("chunk.zig");

const Chunk = chunkLib.Chunk;
const OpCode = chunkLib.OpCode;

const print = std.debug.print;

pub fn disassembleChunk(chunk: *Chunk, chunkName: []const u8) void {
    print("== {s} ==\n", .{chunkName});

    var offset: u32 = 0;

    while (offset < chunk.code.items.len) {
        if (disassembleInstruction(chunk, offset)) |actualOffset| {
            offset = actualOffset;
        } else |_| {
            print("Failed to disassemble code {b:04} at offset {d}\n", .{ chunk.code.items[offset], offset });
            return;
        }
    }
}

fn disassembleInstruction(chunk: *Chunk, offset: u32) !u32 {
    const code = chunk.code.items[offset];
    print("{b:0^4} ", .{code});

    switch (try std.meta.intToEnum(OpCode, code)) {
        .RETURN => {
            return simpleInstruction("RETURN", offset);
        },
    }
}

fn simpleInstruction(chunkName: []const u8, offset: u32) u32 {
    print("{s}\n", .{chunkName});
    return offset + 1;
}
