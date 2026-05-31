const std = @import("std");
const zui = @import("zui");

fn rectangle(buf: [][]u8, x: usize, y: usize, w: usize, h: usize) void {
    if (w < 2 or h < 2) return;
    const x2 = x + w - 1;
    const y2 = y + h - 1;
    if (y2 >= buf.len or x2 >= buf[0].len) return;

    buf[y][x] = '+';
    buf[y][x2] = '+';
    buf[y2][x] = '+';
    buf[y2][x2] = '+';
    for (x + 1..x2) |i| {
        buf[y][i] = '-';
        buf[y2][i] = '-';
    }
    for (y + 1..y2) |j| {
        buf[j][x] = '|';
        buf[j][x2] = '|';
    }
}

fn text(buf: [][]u8, txt: []const u8, x: usize, y: usize, w: usize, h: usize) void {
    if (txt.len == 0 or w < 3 or h < 2) return;
    const inner_w = w - 2;
    const len = @min(txt.len, inner_w);
    const ty = y + 1 + (h - 2) / 2;
    const tx = x + 1 + (inner_w - len) / 2;
    if (ty >= buf.len or tx + len > buf[ty].len) return;
    @memcpy(buf[ty][tx..][0..len], txt[0..len]);
}

const Painter = struct {
    label: []const u8 = "",
    box: bool = false,
    pub fn measure_content_fn(_: *@This()) [2]i32 {
        return .{ 0, 0 };
    }
    pub fn wrap_content_fn(_: *@This(), _: i32) i32 {
        return 0;
    }
};

pub fn main() !void {
    const alloc = std.heap.page_allocator;

    const ui = zui.Builder.Builder(Painter, .{});

    const root = comptime ui.node("col gap-1 p-1 w-52 h-32", .{ .box = true }, &.{
        ui.node("row gap-1 grow-x", .{}, &.{
            ui.leaf("w-12 h-5", .{ .box = true, .label = "btn-a" }),
            ui.leaf("w-12 h-5", .{ .box = true, .label = "btn-b" }),
        }),
        ui.node("row gap-1 grow-x", .{}, &.{
            ui.leaf("grow h-20", .{ .box = true, .label = "canvas" }),
            ui.leaf("w-15 h-20", .{ .box = true, .label = "sidebar" }),
        }),
    });

    const nodes = ui.build(root);

    var tree: zui.Ui.Tree(Painter, .{}) = .{};
    tree.init(alloc);
    defer tree.deinit();

    try tree.nodes.appendSlice(&nodes);
    try tree.compute(0);

    const COLS = 52;
    const ROWS = 32;
    var raw: [ROWS][COLS]u8 = undefined;
    for (&raw) |*row| @memset(row, ' ');
    var rows: [ROWS][]u8 = undefined;
    for (0..ROWS) |i| rows[i] = &raw[i];

    for (tree.commands.items) |cmd| {
        const x: usize = @intCast(cmd.x);
        const y: usize = @intCast(cmd.y);
        const w: usize = @intCast(cmd.w);
        const h: usize = @intCast(cmd.h);
        if (cmd.painter.box) {
            rectangle(&rows, x, y, w, h);
        }
        text(&rows, cmd.painter.label, x, y, w, h);
    }

    for (&rows) |row| std.debug.print("{s}\n", .{row});
}
