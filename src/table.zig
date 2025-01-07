const std = @import("std");
const config = @import("config.zig");
const objLib = @import("object.zig");
const valLib = @import("value.zig");

const ObjString = objLib.ObjString;
const Value = valLib.Value;

const Entry = struct {
    value: Value,
    key: ?*ObjString,
};

pub const Table = struct {
    entries: []Entry,
    count: u32,

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !Table {
        return Table{
            .entries = try allocator.alloc(Entry, 0),
            .count = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(this: *const Table) void {
        this.allocator.free(this.entries);
    }

    pub fn get(this: *Table, key: *ObjString, value: *Value) bool {
        if (this.count == 0) {
            return false;
        }

        const entry = this.findEntry(key);
        if (entry.key == null) {
            return false;
        }

        value.* = entry.value;

        return true;
    }

    pub fn set(this: *Table, key: *ObjString, value: Value) bool {
        if (@as(f32, @floatFromInt(this.count + 1)) > config.TABLE_MAX_LOAD * @as(f32, @floatFromInt(this.entries.len))) {
            const capacity = if (this.entries.len < 8) 8 else this.entries.len * config.TABLE_GROW_RATE;
            this.adjustCapacity(capacity);
        }

        const entry = this.findEntry(key);
        const isNewKey = entry.key == null;
        if (isNewKey and entry.value == .nil) {
            this.count += 1;
        }

        entry.key = key;
        entry.value = value;

        return isNewKey;
    }

    pub fn delete(this: *Table, key: *ObjString) bool {
        if (this.count == 0) {
            return false;
        }

        var entry = this.findEntry(key);
        if (entry.key == null) {
            return false;
        }

        // Tombstone value
        entry.key = null;
        entry.value = valLib.boolVal(true);
    }

    pub fn findString(this: *Table, chars: []const u8, length: usize, hash: u32) ?*Entry {
        if (this.count == 0) {
            return null;
        }

        var index = hash % this.entries.len;

        while (true) : (index = (index + 1) % this.entries.len) {
            const entry = &this.entries[index];
            if (entry.key == null) {
                if (entry.value == .nil) {
                    return null;
                }
                continue;
            }

            if (entry.key.?.hash == hash and entry.key.?.length == length) {
                if (std.mem.eql(u8, chars, std.mem.span(entry.key.?.chars))) {
                    return entry;
                }
            }
        }
        return null;
    }

    fn findEntry(this: *const Table, key: *ObjString) *Entry {
        var index = key.hash % this.entries.len;
        var tombstone: ?*Entry = null;

        while (true) : (index = (index + 1) % this.entries.len) {
            const entry = &this.entries[index];
            if (entry.key == null) {
                if (entry.value == .nil) {
                    return if (tombstone == null) entry else tombstone.?;
                } else if (tombstone == null) {
                    tombstone = entry;
                }
            } else if (entry.key.? == key) {
                return entry;
            }
        }
        return tombstone.?;
    }

    fn adjustCapacity(this: *Table, capacity: usize) void {
        const oldEntries = this.entries;
        defer this.allocator.free(oldEntries);
        this.entries = this.allocator.alloc(Entry, capacity) catch unreachable;

        for (this.entries) |*entry| {
            entry.key = null;
            entry.value = valLib.nilVal();
        }

        this.count = 0;
        for (oldEntries) |*entry| {
            if (entry.key == null) {
                continue;
            }

            var dest = this.findEntry(entry.key.?);
            dest.key = entry.key;
            dest.value = entry.value;
            this.count += 1;
        }
    }

    fn tableAddAll(this: *Table, from: *Table) void {
        for (from.entries) |*entry| {
            if (entry.key != null) {
                this.set(entry.key, entry.value);
            }
        }
    }
};

// TESTING
test "table init" {
    const allocator = std.testing.allocator;
    const table = try Table.init(allocator);
    defer table.deinit();

    try std.testing.expect(table.entries.len == 0);
}

test "table basic set" {
    const allocator = std.testing.allocator;
    var table = try Table.init(allocator);
    defer table.deinit();
    defer objLib.freeObjects(allocator);

    _ = table.set(objLib.castFromObj(ObjString.copyString("abc", allocator), *ObjString), valLib.boolVal(true));

    try std.testing.expect(table.count == 1);
    try std.testing.expect(table.entries.len == 8);
}

test "table basic get" {
    const allocator = std.testing.allocator;
    var table = try Table.init(allocator);

    defer table.deinit();
    defer objLib.freeObjects(allocator);

    const key = objLib.castFromObj(ObjString.copyString("abc", allocator), *ObjString);
    const value = valLib.numberVal(123);

    _ = table.set(key, value);
    var result = valLib.nilVal();
    const found = table.get(key, &result);

    try std.testing.expect(table.count == 1);
    try std.testing.expect(found);
    try std.testing.expect(valLib.valuesEqual(value, result));
}
