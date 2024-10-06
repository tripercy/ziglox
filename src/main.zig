const std = @import("std");
const chunkLib = @import("chunk.zig");
const debug = @import("debug.zig");
const vmLib = @import("vm.zig");

const Chunk = chunkLib.Chunk;
const OpCode = chunkLib.OpCode;

const stdin = std.io.getStdIn().reader();
const stdout = std.io.getStdOut().writer();

pub fn main() !void {
    var vm = vmLib.VM.init();
    defer vm.deinit();

    const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len == 1) {
        try repl(&vm);
    } else if (args.len == 2) {
        try runFile(&vm, args[1]);
    } else {
        std.debug.print("Usage: ziglox [path]\n", .{});
    }
}

fn repl(vm: *vmLib.VM) !void {
    var buffer: [1024:'0']u8 = undefined;

    while (true) {
        const line = try stdin.readUntilDelimiter(&buffer, '\n');
        if (line.len == 0) {
            break;
        }
        _ = vm; // autofix
        // _ = vm.interpret(&buffer);
    }
}

fn runFile(vm: *vmLib.VM, path: []const u8) !void {
    const source = try readFile(std.heap.page_allocator, path);
    defer std.heap.page_allocator.free(source);

    std.debug.print("{s}\n", .{source});
    _ = vm; // autofix
    // const result = vm.interpret(source);
    //
    // switch (result) {
    //     .COMPILE_ERROR => std.process.exit(65),
    //     .RUNTIME_ERROR => std.process.exit(70),
    //     else => {},
    // }
}

fn readFile(allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    var cwd = std.fs.cwd();
    var file = try cwd.openFile(path, .{});
    defer file.close();
    const stat = try file.stat();

    const size = stat.size;
    const content: []u8 = try file.readToEndAlloc(allocator, size);
    return content;
}

test "simple test" {
    const allocator = std.testing.allocator;
    const content = try readFile(allocator, "test/test.txt");
    defer allocator.free(content);
}
