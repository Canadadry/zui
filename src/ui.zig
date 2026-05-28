const std = @import("std");

const PainterKind = enum {
    none,
    img,
};

const SizeKind = enum {
    fixed,
    fit,
    grow,
};
const SizePrefUseKind = enum {
    none,
    to_max,
};

const LayoutKind = enum {
    vertical,
    horizontal,
    stack,
};

const AlignXKind = enum { begin, middle, end };
const AlignYKind = enum { begin, middle, end };

const Node = struct {
    painter: struct {
        kind: PainterKind = .none,
        source: []const u8 = "",
    } = .{},
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

const UITestCase = struct {
    name: []const u8,
    nodes: []Node,
    expected: []struct {
        x: i32 = 0,
        y: i32 = 0,
        w: i32 = 0,
        h: i32 = 0,
        painter: struct {
            kind: PainterKind = .none,
            source: []const u8 = "",
        },
    },
};

test "test case has enough default value" {}

test "ui end2end test" {
    var diagnostics = std.json.Diagnostics{};
    var reader: std.Io.Reader = .fixed(@embedFile("testcase.json"));
    var json_reader = std.json.Reader.init(std.testing.allocator, &reader);
    json_reader.enableDiagnostics(&diagnostics);
    const tests = std.json.parseFromTokenSource([]UITestCase, std.testing.allocator, &json_reader, .{}) catch |err| {
        std.debug.print("{d}:{d} : {}\n", .{ diagnostics.getLine(), diagnostics.getColumn(), err });
        return err;
    };
    defer tests.deinit();
    for (tests.value) |p| {
        try std.testing.expectEqualStrings(p.name, "");
    }
}
