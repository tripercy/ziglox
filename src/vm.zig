const chunkLib = @import("chunk.zig");
const valueLib = @import("value.zig");
const std = @import("std");
const debug = @import("debug.zig");
const config = @import("config.zig");

const Chunk = chunkLib.Chunk;
const OpCode = chunkLib.OpCode;
const Value = valueLib.Value;

pub const InterpretResult = enum {
    OK,
    COMPILE_ERROR,
    RUNTIME_ERROR,
};

pub const VM = struct {
    chunk: *Chunk,
    ip: u32,

    pub fn init() VM {
        return VM{
            .chunk = undefined,
            .ip = undefined,
        };
    }

    pub fn deinit(this: *VM) void {
        _ = this;
    }

    pub fn interpret(this: *VM, chunk: *Chunk) InterpretResult {
        this.chunk = chunk;
        this.ip = 0;
        return this.run();
    }

    pub fn run(this: *VM) InterpretResult {
        while (true) {
            if (config.DEBUG_TRACE_EXECUTION) {
                _ = debug.disassembleInstruction(this.chunk, this.ip) catch 0;
            }

            const instruction: OpCode = @enumFromInt(this.readByte());
            switch (instruction) {
                .RETURN => {
                    return .OK;
                },
                .CONSTANT => {
                    const constant: Value = this.readConst();
                    std.debug.print("{d}\n", .{constant});
                },
                .CONSTANT_LONG => {
                    const constant: Value = this.readConstLong();
                    std.debug.print("{d}\n", .{constant});
                },
            }
        }
        return .OK;
    }

    fn readByte(this: *VM) u8 {
        const byte: u8 = this.chunk.code.items[this.ip];
        this.ip += 1;
        return byte;
    }

    fn readConst(this: *VM) Value {
        const constIndex = this.readByte();
        return this.chunk.constants.values.items[constIndex];
    }

    fn readConstLong(this: *VM) Value {
        var constIndex: u32 = 0;
        constIndex |= @as(u32, this.readByte()) << 16;
        constIndex |= @as(u32, this.readByte()) << 8;
        constIndex |= @as(u32, this.readByte());

        return this.chunk.constants.values.items[constIndex];
    }
};
