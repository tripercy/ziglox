const chunkLib = @import("chunk.zig");
const valueLib = @import("value.zig");
const std = @import("std");
const debug = @import("debug.zig");
const config = @import("config.zig");
const compiler = @import("compiler.zig");
const objLib = @import("object.zig");
const tableLib = @import("table.zig");

const Chunk = chunkLib.Chunk;
const OpCode = chunkLib.OpCode;
const Value = valueLib.Value;
const Table = tableLib.Table;

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
    strings: *Table,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) VM {
        const strings = allocator.create(Table) catch unreachable;
        strings.* = Table.init(allocator) catch unreachable;
        objLib.strings = strings;
        return VM{
            .chunk = undefined,
            .ip = undefined,
            .stack = [_]Value{.{ .nil = {} }} ** STACK_MAX,
            .stackTop = 0,
            .strings = strings,
            .allocator = allocator,
        };
    }

    pub fn deinit(this: *VM) void {
        objLib.freeObjects(this.allocator);
        this.strings.deinit();
        this.allocator.destroy(this.strings);
    }

    pub fn interpret(this: *VM, source: []const u8) InterpretResult {
        var chunk = Chunk.init(this.allocator);
        defer chunk.deinit();
        this.chunk = &chunk;

        const compiled = compiler.compile(source, this.chunk, this.allocator) catch false;
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
        return .{ .nil = {} };
    }

    pub fn peek(this: *VM, distance: u32) Value {
        return this.stack[this.stackTop - 1 - distance];
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
                    if (this.peek(0) != .number) {
                        this.runtimeError("Operand must be number.", .{});
                        return .RUNTIME_ERROR;
                    }
                    this.push(valueLib.numberVal(-this.pop().number));
                },
                .ADD, .SUBTRACT, .MULTIPLY, .DIVIDE, .GREATER, .LESS => {
                    const success = this.binaryOp(instruction);
                    if (!success) {
                        return .RUNTIME_ERROR;
                    }
                },
                .NIL => this.push(valueLib.nilVal()),
                .TRUE => this.push(valueLib.boolVal(true)),
                .FALSE => this.push(valueLib.boolVal(false)),
                .NOT => this.push(valueLib.boolVal(isFalsey(this.pop()))),
                .EQUAL => {
                    const b = this.pop();
                    const a = this.pop();
                    this.push(valueLib.boolVal(valueLib.valuesEqual(a, b)));
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

    fn concatenate(this: *VM) void {
        const b = this.pop().obj;
        const a = this.pop().obj;

        const strObjA = objLib.castFromObj(a, *objLib.ObjString);
        const strObjB = objLib.castFromObj(b, *objLib.ObjString);

        const strA = std.mem.span(strObjA.chars);
        const strB = std.mem.span(strObjB.chars);

        const strRes = this.allocator.allocSentinel(u8, strA.len + strB.len, 0) catch unreachable;
        std.mem.copyForwards(u8, strRes, strA);
        std.mem.copyForwards(u8, strRes[strA.len..], strB);

        const resObj = objLib.ObjString.init(strRes, this.allocator);

        this.push(valueLib.objVal(resObj));
    }

    fn binaryOp(this: *VM, op: OpCode) bool {
        if (this.peek(0).isString() and this.peek(1).isString() and op == .ADD) {
            this.concatenate();
            return true;
        }
        if (this.peek(0) != .number or this.peek(1) != .number) {
            this.runtimeError("Operands must be numbers.", .{});
            return false;
        }

        const b = this.pop().number;
        const a = this.pop().number;

        var mathRes: f64 = 0;
        var boolRes: bool = false;
        switch (op) {
            // zig fmt: off
            .ADD        => mathRes = a + b,
            .SUBTRACT   => mathRes = a - b,
            .MULTIPLY   => mathRes = a * b,
            .DIVIDE     => mathRes = a / b,
            .GREATER    => boolRes = a > b,
            .LESS       => boolRes = a < b,
            else        => unreachable,
            // zig fmt: on
        }

        switch (op) {
            .GREATER, .LESS => this.push(valueLib.boolVal(boolRes)),
            else => this.push(valueLib.numberVal(mathRes)),
        }
        return true;
    }

    fn runtimeError(this: *VM, comptime format: []const u8, args: anytype) void {
        std.debug.print(format, args);
        std.debug.print("\n", .{});

        const line = this.chunk.getLine(this.ip);
        std.debug.print("[line {}] in script\n", .{line});
        this.stackTop = 0;
    }
};

fn isFalsey(value: Value) bool {
    return value == .nil or (value == .boolean and !value.boolean);
}
