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
            print("Failed to disassemble code {b:0>4} at offset {d}\n", .{ chunk.code.items[offset], offset });
            return;
        }
    }
}

pub fn disassembleInstruction(chunk: *Chunk, offset: u32) !u32 {
    const code = chunk.code.items[offset];
    print("{b:0>4} ", .{code});

    const currLine = chunk.getLine(offset);
    if (offset > 0 and currLine == chunk.getLine(offset - 1)) {
        print("{c: >6} ", .{'|'});
    } else {
        print("{d: >6} ", .{currLine});
    }

    switch (try std.meta.intToEnum(OpCode, code)) {
        .RETURN => {
            return simpleInstruction("RETURN", offset);
        },
        .CONSTANT => {
            return constantInstruction("CONSTANT", chunk, offset);
        },
        .CONSTANT_LONG => {
            return constantLongInstruction("CONSTANT_LONG", chunk, offset);
        },
        .NEGATE => {
            return simpleInstruction("NEGATE", offset);
        },
        .ADD => {
            return simpleInstruction("ADD", offset);
        },
        .SUBTRACT => {
            return simpleInstruction("SUBTRACT", offset);
        },
        .MULTIPLY => {
            return simpleInstruction("MULTIPLY", offset);
        },
        .DIVIDE => {
            return simpleInstruction("DIVIDE", offset);
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

fn constantLongInstruction(name: []const u8, chunk: *Chunk, offset: u32) u32 {
    var constIndex: u32 = 0;
    inline for (1..4) |i| {
        const byte: u32 = chunk.code.items[offset + i];
        constIndex |= byte << ((3 - i) * 8);
    }
    const constValue = chunk.constants.values.items[constIndex];

    print("{s: <16}{d: <4}'", .{ name, constIndex });
    valueLib.printValue(constValue);
    print("'\n", .{});

    return offset + 4;
}
