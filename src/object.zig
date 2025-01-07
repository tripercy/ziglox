const std = @import("std");
const tableLib = @import("table.zig");
const valLib = @import("value.zig");

pub var strings: ?*tableLib.Table = null;
pub var objects: ?*Obj = null;

pub const ObjType = enum(u8) {
    STRING,
};

pub fn freeObjects(allocator: std.mem.Allocator) void {
    if (objects == null) {
        return;
    }
    while (objects != null) {
        const obj = objects.?;
        const next = obj.next;
        destroyObj(obj, allocator);
        objects = next;
    }
}

pub const Obj = extern struct {
    type: ObjType,
    next: ?*Obj,
};

pub const ObjString = extern struct {
    obj: Obj,
    length: usize,
    chars: [*:0]u8,
    hash: u32,

    pub fn init(chars: [*:0]u8, allocator: std.mem.Allocator) *Obj {
        const length = std.mem.span(chars).len;
        const hash = hashSTr(chars);

        const interned = strings.?.findString(std.mem.span(chars), length, hash);
        if (interned != null) {
            allocator.free(std.mem.span(chars));
            return &interned.?.key.?.obj;
        }

        const obj = newObj(ObjString, allocator);
        obj.obj.type = .STRING;
        obj.length = length;
        obj.chars = chars;
        obj.hash = hash;

        _ = strings.?.set(obj, valLib.nilVal());
        return &obj.obj;
    }

    pub fn copyString(string: []const u8, allocator: std.mem.Allocator) *Obj {
        return ObjString.init((allocator.dupeZ(u8, string) catch unreachable).ptr, allocator);
    }

    pub fn deinit(this: *ObjString, allocator: std.mem.Allocator) void {
        allocator.free(std.mem.span(this.chars));
    }
};

pub fn castToObj(obj: anytype) *Obj {
    return @as(*Obj, @ptrCast(@alignCast(obj)));
}

pub fn castFromObj(obj: *Obj, to: type) to {
    return @as(to, @ptrCast(@alignCast(obj)));
}

fn newObj(comptime objType: type, allocator: std.mem.Allocator) *objType {
    const obj = allocator.create(objType) catch unreachable;

    const asObj = castToObj(obj);
    asObj.next = objects;
    objects = asObj;

    return obj;
}

fn destroyObj(obj: *Obj, allocator: std.mem.Allocator) void {
    switch (obj.type) {
        .STRING => {
            const strObj = castFromObj(obj, *ObjString);
            strObj.deinit(allocator);
            allocator.destroy(strObj);
        },
    }
}

fn hashSTr(string: [*:0]u8) u32 {
    const key = std.mem.span(string);
    var hash: u32 = 2166136261;

    for (key) |c| {
        hash ^= c;
        hash = @mulWithOverflow(hash, 16777619).@"0";
    }
    return hash;
}
