const scannerLib = @import("scanner.zig");
const std = @import("std");
const chunkLib = @import("chunk.zig");
const valueLib = @import("value.zig");

const Scanner = scannerLib.Scanner;
const Token = scannerLib.Token;
const TokenType = scannerLib.TokenType;
const Chunk = chunkLib.Chunk;
const OpCode = chunkLib.OpCode;
const Value = valueLib.Value;

const print = std.debug.print;

var compilingChunk: *Chunk = undefined;

pub fn compile(source: []const u8, chunk: *Chunk) !bool {
    compilingChunk = chunk;
    var scanner: Scanner = undefined;
    scanner = Scanner.init(source);

    var parser: Parser = undefined;
    parser = Parser.init(&scanner);
    defer parser.endCompiler();

    parser.advance();
    parser.expression();
    parser.consume(.EOF, "Expected end of expression");

    return !parser.hadError;
}

fn currentChunk() *Chunk {
    return compilingChunk;
}

const ParseRule = struct {
    prefix: ?*const fn (*Parser) void = null,
    infix: ?*const fn (*Parser) void = null,
    precedent: Precedence = .NONE,
};

// zig fmt: off
const rules = std.EnumMap(TokenType, ParseRule).init(.{
    .LEFT_PAREN     =   .{ .prefix = Parser.grouping    , .infix = null                 , .precedent = .NONE        },
    .MINUS          =   .{ .prefix = Parser.unary       , .infix = Parser.binary        , .precedent = .TERM        },
    .PLUS           =   .{ .prefix = null               , .infix = Parser.binary        , .precedent = .TERM        },
    .SLASH          =   .{ .prefix = null               , .infix = Parser.binary        , .precedent = .FACTOR      },
    .STAR           =   .{ .prefix = null               , .infix = Parser.binary        , .precedent = .FACTOR      },
    .NUMBER         =   .{ .prefix = Parser.number      , .infix = null                 , .precedent = .NONE        },
    .RIGHT_PAREN    =   .{ .prefix = null               , .infix = null                 , .precedent = .NONE        },
    .EOF            =   .{ .prefix = null               , .infix = null                 , .precedent = .NONE        },
    .NIL            =   .{ .prefix = Parser.literal     , .infix = null                 , .precedent = .NONE        },
    .TRUE           =   .{ .prefix = Parser.literal     , .infix = null                 , .precedent = .NONE        },
    .FALSE          =   .{ .prefix = Parser.literal     , .infix = null                 , .precedent = .NONE        },
    .BANG           =   .{ .prefix = Parser.unary       , .infix = null                 , .precedent = .NONE        },
    .BANG_EQUAL     =   .{ .prefix = null               , .infix = Parser.binary        , .precedent = .EQUALITY    },
    .EQUAL_EQUAL    =   .{ .prefix = null               , .infix = Parser.binary        , .precedent = .EQUALITY    },
    .GREATER        =   .{ .prefix = null               , .infix = Parser.binary        , .precedent = .COMPARISION },
    .GREATER_EQUAL  =   .{ .prefix = null               , .infix = Parser.binary        , .precedent = .COMPARISION },
    .LESS           =   .{ .prefix = null               , .infix = Parser.binary        , .precedent = .COMPARISION },
    .LESS_EQUAL     =   .{ .prefix = null               , .infix = Parser.binary        , .precedent = .COMPARISION },
});
// zig fmt: on

const Precedence = enum(u32) {
    NONE,
    ASSIGNMENT,
    AND,
    OR,
    EQUALITY,
    COMPARISION,
    TERM,
    FACTOR,
    UNARY,
    CALL,
    PRIMARY,

    pub fn next(this: Precedence) Precedence {
        return @enumFromInt(@intFromEnum(this) + 1);
    }
};

const Parser = struct {
    scanner: *Scanner,

    previous: Token,
    current: Token,
    hadError: bool,
    panicMode: bool,

    pub fn init(scanner: *Scanner) Parser {
        return Parser{
            .scanner = scanner,
            .previous = undefined,
            .current = undefined,
            .hadError = false,
            .panicMode = false,
        };
    }

    pub fn advance(this: *Parser) void {
        this.previous = this.current;

        while (true) {
            this.current = this.scanner.scanToken();
            if (this.current.tokenType != .ERROR) {
                break;
            }
            this.errorAtCurrent(this.current.source);
        }
    }

    pub fn consume(this: *Parser, tokenType: TokenType, message: []const u8) void {
        if (this.current.tokenType == tokenType) {
            this.advance();
            return;
        }

        this.errorAtCurrent(message);
    }

    pub fn expression(this: *Parser) void {
        this.parsePrecedence(.ASSIGNMENT);
    }

    pub fn parsePrecedence(this: *Parser, precedence: Precedence) void {
        this.advance();
        const rule = rules.getPtrConst(this.previous.tokenType).?;

        if (rule.prefix == null) {
            this.err("Expected expression");
            return;
        }

        const prefixRule = rule.prefix.?;
        prefixRule(this);

        while (@intFromEnum(precedence) <= @intFromEnum(rules.get(this.current.tokenType).?.precedent)) {
            this.advance();
            const infixRule = rules.get(this.previous.tokenType).?.infix.?;
            infixRule(this);
        }
    }

    pub fn emitByte(this: *Parser, byte: u8) void {
        _ = currentChunk().writeChunk(byte, this.previous.line) catch {};
    }

    pub fn emitBytes(this: *Parser, byte1: u8, byte2: u8) void {
        this.emitByte(byte1);
        this.emitByte(byte2);
    }

    fn number(this: *Parser) void {
        const value = std.fmt.parseFloat(f64, this.previous.source) catch 0;
        this.emitConstant(valueLib.numberVal(value));
    }

    fn literal(this: *Parser) void {
        switch (this.previous.tokenType) {
            .FALSE => this.emitByte(@intFromEnum(OpCode.FALSE)),
            .TRUE => this.emitByte(@intFromEnum(OpCode.TRUE)),
            .NIL => this.emitByte(@intFromEnum(OpCode.NIL)),
            else => unreachable,
        }
    }

    fn grouping(this: *Parser) void {
        this.expression();
        this.consume(.RIGHT_PAREN, "Expected ')' after expression");
    }

    fn unary(this: *Parser) void {
        const opType = this.previous.tokenType;

        this.parsePrecedence(.UNARY);

        switch (opType) {
            .MINUS => this.emitByte(@intFromEnum(OpCode.NEGATE)),
            .BANG => this.emitByte(@intFromEnum(OpCode.NOT)),
            else => unreachable,
        }
    }

    fn binary(this: *Parser) void {
        const opType = this.previous.tokenType;
        const rule = rules.get(opType).?;
        this.parsePrecedence(rule.precedent.next());

        switch (opType) {
            .PLUS => this.emitByte(@intFromEnum(OpCode.ADD)),
            .MINUS => this.emitByte(@intFromEnum(OpCode.SUBTRACT)),
            .STAR => this.emitByte(@intFromEnum(OpCode.MULTIPLY)),
            .SLASH => this.emitByte(@intFromEnum(OpCode.DIVIDE)),

            .EQUAL_EQUAL => this.emitByte(@intFromEnum(OpCode.EQUAL)),
            .BANG_EQUAL => this.emitBytes(@intFromEnum(OpCode.EQUAL), @intFromEnum(OpCode.NOT)),

            .GREATER => this.emitByte(@intFromEnum(OpCode.GREATER)),
            .GREATER_EQUAL => this.emitBytes(@intFromEnum(OpCode.LESS), @intFromEnum(OpCode.NOT)),

            .LESS => this.emitByte(@intFromEnum(OpCode.LESS)),
            .LESS_EQUAL => this.emitBytes(@intFromEnum(OpCode.GREATER), @intFromEnum(OpCode.NOT)),
            else => unreachable,
        }
    }

    pub fn endCompiler(this: *Parser) void {
        _ = this.emitReturn() catch {};
    }

    fn emitReturn(this: *Parser) !void {
        this.emitByte(@intFromEnum(OpCode.RETURN));
    }

    fn emitConstant(this: *Parser, value: Value) void {
        this.emitBytes(@intFromEnum(OpCode.CONSTANT), this.makeConstant(value));
    }

    fn makeConstant(this: *Parser, value: Value) u8 {
        const constID = currentChunk().addConstant(value) catch 1 << 8;

        if (constID > 1 << 8 - 1) {
            this.err("Too many constants in one chunk");
            return 0;
        }

        return @intCast(constID);
    }

    fn errorAtCurrent(this: *Parser, message: []const u8) void {
        this.errorAt(&this.current, message);
    }

    fn err(this: *Parser, message: []const u8) void {
        this.errorAt(&this.previous, message);
    }

    fn errorAt(this: *Parser, token: *Token, message: []const u8) void {
        if (this.panicMode) {
            return;
        }
        this.panicMode = true;
        print("[line {d}] Error", .{token.line});

        if (token.tokenType == .EOF) {
            print(" at end", .{});
        } else if (token.tokenType != .ERROR) {
            print(" at '{s}'", .{token.source});
        }

        print(": {s}\n", .{message});
        this.hadError = true;
    }
};
