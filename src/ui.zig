const std = @import("std");

const SizeKind = enum { fixed, fit, grow };
const SizePrefUseKind = enum { none, to_max };
const LayoutKind = enum { vertical, horizontal, stack };
const AlignXKind = enum { begin, middle, end };
const AlignYKind = enum { begin, middle, end };

fn Node(comptime T: type, comptime default_painter: T) type {
    return struct {
        painter: T = default_painter,
        pos: struct {
            x: i32 = 0,
            y: i32 = 0,
        } = .{},
        size: [2]struct {
            kind: SizeKind = .fit,
            size: i32 = 0,
            min: i32 = 0,
            max: i32 = 0,
            pref_use: SizePrefUseKind = .none,
        } = .{ .{}, .{} },
        layout: LayoutKind = .vertical,
        spacing: i32 = 0,
        margin: i32 = 0,
        @"align": struct {
            x: AlignXKind = .begin,
            y: AlignYKind = .begin,
        } = .{},
        padding: struct {
            left: i32 = 0,
            right: i32 = 0,
            top: i32 = 0,
            bottom: i32 = 0,
        } = .{},
        children_count: i32 = 0,
        first_children: i32 = -1,
        last_children: i32 = -1,
        next: i32 = -1,
    };
}

const NodeIndex = i32;
const Growable = struct {
    id: NodeIndex,
    val: i32,
    min: i32,
    max: i32,
    to_remove: bool,
};

fn PainterCommand(comptime T: type, comptime default_painter: T) type {
    return struct {
        x: i32 = 0,
        y: i32 = 0,
        w: i32 = 0,
        h: i32 = 0,
        painter: T = default_painter,
        // char id[ID_LEN];
        // char onClick[DATA_LEN];
    };
}

fn Tree(comptime T: type, comptime default_painter: T) type {
    return struct {
        nodes: std.array_list.Managed(Node(T, default_painter)) = undefined,
        commands: std.array_list.Managed(PainterCommand(T, default_painter)) = undefined,
        growables: std.array_list.Managed(Growable) = undefined,
        sorted_growables: std.array_list.Managed(*Growable) = undefined,

        pub fn init(tree: *@This(), allocator: std.mem.Allocator) void {
            tree.nodes = std.array_list.Managed(Node(T, default_painter)).init(allocator);
            tree.commands = std.array_list.Managed(PainterCommand(T, default_painter)).init(allocator);
            tree.growables = std.array_list.Managed(Growable).init(allocator);
            tree.sorted_growables = std.array_list.Managed(*Growable).init(allocator);
        }

        pub fn deinit(tree: *@This()) void {
            tree.nodes.deinit();
            tree.commands.deinit();
            tree.growables.deinit();
            tree.sorted_growables.deinit();
        }

        pub fn compute(tree: *@This(), head: NodeIndex) void {
            _ = tree;
            _ = head;
        }
        pub fn link_child(tree: *@This(), parent: NodeIndex, child: NodeIndex) void {
            _ = tree;
            _ = parent;
            _ = child;
        }
    };
}

test "ui end2end test" {
    const PainterKind = enum { none, img };
    const Painter = struct {
        kind: PainterKind = .none,
        source: []const u8 = "",
        // pub fn mesure_content_fn() [2]i32 {
        //     return [2]i32{ 0, 0 };
        // }
        // fn wrap_content_fn(w: i32) i32 {
        //     return w;
        // }
    };
    const UITestCase = struct {
        name: []const u8,
        nodes: []Node(Painter, .{}),
        expected: []PainterCommand(Painter, .{}),
    };
    var diagnostics = std.json.Diagnostics{};
    var reader: std.Io.Reader = .fixed(@embedFile("testcase.json"));
    var json_reader = std.json.Reader.init(std.testing.allocator, &reader);
    json_reader.enableDiagnostics(&diagnostics);
    const tests = std.json.parseFromTokenSource([]UITestCase, std.testing.allocator, &json_reader, .{}) catch |err| {
        std.debug.print("{d}:{d} : {}\n", .{ diagnostics.getLine(), diagnostics.getColumn(), err });
        return err;
    };
    defer tests.deinit();

    for (tests.value) |tt| {
        var tree: Tree(Painter, .{}) = .{};
        tree.init(std.testing.allocator);
        defer tree.deinit();
        try tree.nodes.appendSlice(tt.nodes);
        tree.compute(0);
        try expectEqual(tree.commands.items.len, tt.expected.len, "painter command len", tt.name);
        for (tt.expected, tree.commands.items) |exp, got| {
            try expectEqual(exp.x, got.x, "x", tt.name);
            try expectEqual(exp.y, got.y, "y", tt.name);
            try expectEqual(exp.w, got.w, "w", tt.name);
            try expectEqual(exp.h, got.h, "h", tt.name);
            try expectEqual(exp.painter.kind, got.painter.kind, "painter.kind", tt.name);
            try expectEqualStrings(exp.painter.source, got.painter.source, "painter.source", tt.name);
        }
    }
}

pub inline fn expectEqual(expected: anytype, actual: anytype, name: []const u8, case: []const u8) !void {
    std.testing.expectEqual(expected, actual) catch |err| {
        std.debug.print("at {s} on {s}\n", .{ name, case });
        return err;
    };
}

pub inline fn expectEqualStrings(expected: []const u8, actual: []const u8, name: []const u8, case: []const u8) !void {
    std.testing.expectEqual(expected, actual) catch |err| {
        std.debug.print("at {s} on {s}\n", .{ name, case });
        return err;
    };
}
