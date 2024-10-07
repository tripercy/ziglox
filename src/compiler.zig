const scannerLib = @import("scanner.zig");
const std = @import("std");

const Scanner = scannerLib.Scanner;
const TokenType = scannerLib.TokenType;
const print = std.debug.print;

pub fn compile(source: []const u8) void {
    var scanner: Scanner = undefined;
    scanner = Scanner.initScanner(source);
    var line: u32 = 0;

    while (true) {
        const token = scanner.scanToken();
        if (token.line != line) {
            line = token.line;
            print("{d: >4} ", .{line});
        } else {
            print("{c: >4} ", .{'|'});
        }
        const tokenType = std.enums.tagName(scannerLib.TokenType, token.type).?;
        print("{s: >15} '{s}'\n", .{ tokenType, token.source });

        if (token.type == .EOF or token.type == .ERROR) {
            break;
        }
    }
}
