const std = @import("std");
const chunkLib = @import("chunk.zig");
const valueLib = @import("value.zig");

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
            print("Failed to disassemble code {b:0^4} at offset {d}\n", .{ chunk.code.items[offset], offset });
            return;
        }
    }
}

fn disassembleInstruction(chunk: *Chunk, offset: u32) !u32 {
    const code = chunk.code.items[offset];
    print("{b:0^4} ", .{code});

    if (offset > 0 and chunk.lines.items[offset] == chunk.lines.items[offset - 1]) {
        print("{c: >4} ", .{'|'});
    } else {
        print("{d: >4} ", .{chunk.lines.items[offset]});
    }

    switch (try std.meta.intToEnum(OpCode, code)) {
        .RETURN => {
            return simpleInstruction("RETURN", offset);
        },
        .CONSTANT => {
            return constantInstruction("CONSTANT", chunk, offset);
        },
    }
}

fn simpleInstruction(name: []const u8, offset: u32) u32 {
    print("{s}\n", .{name});
    return offset + 1;
}

fn constantInstruction(name: []const u8, chunk: *Chunk, offset: u32) u32 {
    const constIndex = chunk.code.items[offset + 1];
    const constValue = chunk.constants.values.items[constIndex];

    print("{s: <16}{d: <4}'", .{ name, constIndex });
    valueLib.printValue(constValue);
    print("'\n", .{});

    return offset + 2;
}
