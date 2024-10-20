const chunkLib = @import("chunk.zig");
const valueLib = @import("value.zig");
const std = @import("std");
const debug = @import("debug.zig");
const config = @import("config.zig");
const compiler = @import("compiler.zig");

const Chunk = chunkLib.Chunk;
const OpCode = chunkLib.OpCode;
const Value = valueLib.Value;

const STACK_MAX = 256;

pub const InterpretResult = enum {
    OK,
    COMPILE_ERROR,
    RUNTIME_ERROR,
};

pub const VM = struct {
    chunk: *Chunk,
    ip: u32,
    stack: [STACK_MAX]Value,
    stackTop: u32,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) VM {
        return VM{
            .chunk = undefined,
            .ip = undefined,
            .stack = [_]Value{0} ** STACK_MAX,
            .stackTop = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(this: *VM) void {
        _ = this;
    }

    pub fn interpret(this: *VM, source: []const u8) InterpretResult {
        var chunk = Chunk.init(this.allocator);
        defer chunk.deinit();
        this.chunk = &chunk;

        const compiled = compiler.compile(source, this.chunk) catch false;
        if (!compiled) {
            return .COMPILE_ERROR;
        }

        if (config.DEBUG_PRINT_CODE) {
            debug.disassembleChunk(this.chunk, "Interpreted chunk");
        }

        this.ip = 0;
        const result = this.run();

        return result;
    }

    pub fn push(this: *VM, value: Value) void {
        this.stack[this.stackTop] = value;
        this.stackTop += 1;
    }

    pub fn pop(this: *VM) Value {
        if (this.stackTop > 0) {
            this.stackTop -= 1;
            return this.stack[this.stackTop];
        }
        return 0;
    }

    pub fn run(this: *VM) InterpretResult {
        if (this.chunk.code.items.len == 0) {
            return .OK;
        }

        while (true) {
            if (config.DEBUG_TRACE_EXECUTION) {
                std.debug.print("{c: >8}", .{' '});
                for (0..this.stackTop) |slot| {
                    std.debug.print("[ ", .{});
                    valueLib.printValue(this.stack[slot]);
                    std.debug.print(" ]", .{});
                }
                std.debug.print("\n", .{});
                _ = debug.disassembleInstruction(this.chunk, this.ip) catch 0;
            }

            const instruction: OpCode = @enumFromInt(this.readByte());
            switch (instruction) {
                .RETURN => {
                    valueLib.printValue(this.pop());
                    std.debug.print("\n", .{});
                    return .OK;
                },
                .CONSTANT => {
                    const constant: Value = this.readConst();
                    this.push(constant);
                },
                .CONSTANT_LONG => {
                    const constant: Value = this.readConstLong();
                    this.push(constant);
                },
                .NEGATE => {
                    this.push(-this.pop());
                },
                .ADD, .SUBTRACT, .MULTIPLY, .DIVIDE => {
                    this.binaryOp(instruction);
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

    fn binaryOp(this: *VM, op: OpCode) void {
        const b = this.pop();
        const a = this.pop();
        const c: Value = switch (op) {
            .ADD => a + b,
            .SUBTRACT => a - b,
            .MULTIPLY => a * b,
            .DIVIDE => a / b,
            else => unreachable,
        };
        this.push(c);
    }
};
