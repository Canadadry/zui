const std = @import("std");
const ui = @import("ui");

fn argOf(comptime tok: []const u8, comptime prefix: []const u8) ?[]const u8 {
    if (std.mem.startsWith(u8, tok, prefix)) return tok[prefix.len..];
    return null;
}
fn numOf(comptime tok: []const u8, comptime prefix: []const u8) ?i32 {
    if (argOf(tok, prefix)) |rest|
        return std.fmt.parseInt(i32, rest, 10) catch
            @compileError("nombre invalide dans la classe '" ++ tok ++ "'");
    return null;
}

fn applyToken(comptime tok: []const u8, n: anytype) void {
    if (std.mem.eql(u8, tok, "row")) {
        n.layout = .horizontal;
        return;
    }
    if (std.mem.eql(u8, tok, "col")) {
        n.layout = .vertical;
        return;
    }
    if (std.mem.eql(u8, tok, "stack")) {
        n.layout = .stack;
        return;
    }

    if (std.mem.eql(u8, tok, "grow")) {
        n.size[0].kind = .grow;
        n.size[1].kind = .grow;
        return;
    }
    if (std.mem.eql(u8, tok, "grow-x")) {
        n.size[0].kind = .grow;
        return;
    }
    if (std.mem.eql(u8, tok, "grow-y")) {
        n.size[1].kind = .grow;
        return;
    }

    if (std.mem.eql(u8, tok, "center")) {
        n.@"align".x = .middle;
        n.@"align".y = .middle;
        return;
    }
    if (std.mem.eql(u8, tok, "ax-start")) {
        n.@"align".x = .begin;
        return;
    }
    if (std.mem.eql(u8, tok, "ax-center")) {
        n.@"align".x = .middle;
        return;
    }
    if (std.mem.eql(u8, tok, "ax-end")) {
        n.@"align".x = .end;
        return;
    }
    if (std.mem.eql(u8, tok, "ay-start")) {
        n.@"align".y = .begin;
        return;
    }
    if (std.mem.eql(u8, tok, "ay-center")) {
        n.@"align".y = .middle;
        return;
    }
    if (std.mem.eql(u8, tok, "ay-end")) {
        n.@"align".y = .end;
        return;
    }

    // width — l'ordre compte : fit/grow puis min/max puis fixed
    if (std.mem.eql(u8, tok, "w-fit")) {
        n.size[0].kind = .fit;
        return;
    }
    if (std.mem.eql(u8, tok, "w-grow")) {
        n.size[0].kind = .grow;
        return;
    }
    if (numOf(tok, "min-w-")) |v| {
        n.size[0].min = v;
        return;
    }
    if (numOf(tok, "max-w-")) |v| {
        n.size[0].max = v;
        return;
    }
    if (numOf(tok, "w-")) |v| {
        n.size[0].kind = .fixed;
        n.size[0].size = v;
        return;
    }

    // height
    if (std.mem.eql(u8, tok, "h-fit")) {
        n.size[1].kind = .fit;
        return;
    }
    if (std.mem.eql(u8, tok, "h-grow")) {
        n.size[1].kind = .grow;
        return;
    }
    if (numOf(tok, "min-h-")) |v| {
        n.size[1].min = v;
        return;
    }
    if (numOf(tok, "max-h-")) |v| {
        n.size[1].max = v;
        return;
    }
    if (numOf(tok, "h-")) |v| {
        n.size[1].kind = .fixed;
        n.size[1].size = v;
        return;
    }

    // padding
    if (numOf(tok, "px-")) |v| {
        n.padding.left = v;
        n.padding.right = v;
        return;
    }
    if (numOf(tok, "py-")) |v| {
        n.padding.top = v;
        n.padding.bottom = v;
        return;
    }
    if (numOf(tok, "pl-")) |v| {
        n.padding.left = v;
        return;
    }
    if (numOf(tok, "pr-")) |v| {
        n.padding.right = v;
        return;
    }
    if (numOf(tok, "pt-")) |v| {
        n.padding.top = v;
        return;
    }
    if (numOf(tok, "pb-")) |v| {
        n.padding.bottom = v;
        return;
    }
    if (numOf(tok, "p-")) |v| {
        n.padding = .{ .left = v, .right = v, .top = v, .bottom = v };
        return;
    }

    // gap inter-enfants → ton champ `margin` (au passage : `spacing` n'est jamais lu dans compute)
    if (numOf(tok, "gap-")) |v| {
        n.margin = v;
        return;
    }

    @compileError("classe ui inconnue : '" ++ tok ++ "'");
}

fn parseClasses(comptime s: []const u8, n: anytype) void {
    comptime {
        var it = std.mem.tokenizeScalar(u8, s, ' ');
        while (it.next()) |tok| applyToken(tok, n);
    }
}

pub fn Builder(comptime T: type, comptime default_painter: T) type {
    const N = ui.Node(T, default_painter);
    return struct {
        pub const Spec = struct {
            classes: []const u8,
            painter: T = default_painter,
            children: []const @This() = &.{},
        };

        /// conteneur (painter par défaut)
        pub fn node(comptime classes: []const u8, comptime children: []const Spec) Spec {
            comptime {
                var tmp = N{};
                parseClasses(classes, &tmp);
            } // valide les classes ici
            return .{ .classes = classes, .children = children };
        }

        /// feuille avec painter, sans enfants
        pub fn leaf(comptime classes: []const u8, comptime painter: T) Spec {
            comptime {
                var tmp = N{};
                parseClasses(classes, &tmp);
            }
            return .{ .classes = classes, .painter = painter };
        }

        /// aplatit l'arbre de Spec en tableau de Node avec les index câblés
        pub fn build(comptime root: Spec) [count(root)]N {
            return comptime blk: {
                var nodes: [count(root)]N = undefined;
                var cursor: usize = 0;
                _ = fill(root, &nodes, &cursor);
                break :blk nodes;
            };
        }

        fn count(comptime s: Spec) usize {
            var total: usize = 1;
            inline for (s.children) |c| total += count(c);
            return total;
        }

        fn fill(comptime s: Spec, nodes: []N, cursor: *usize) usize {
            const me = cursor.*;
            cursor.* += 1;
            var n = N{ .painter = s.painter };
            parseClasses(s.classes, &n);
            n.children_count = @intCast(s.children.len);
            var prev: ?usize = null;
            inline for (s.children) |c| {
                const cid = fill(c, nodes, cursor);
                if (prev) |p| nodes[p].next = cid else n.first_children = cid;
                prev = cid;
            }
            n.last_children = prev;
            nodes[me] = n;
            return me;
        }
    };
}

// test

const DslPainterKind = enum { none, img };
const DslPainter = struct {
    kind: DslPainterKind = .none,
    source: []const u8 = "",
    fn parseSize(s: []const u8) [2]i32 {
        var it = std.mem.splitScalar(u8, s, 'x');
        const xs = it.next() orelse return .{ 0, 0 };
        const ys = it.next() orelse return .{ 0, 0 };
        return .{
            std.fmt.parseInt(i32, xs, 10) catch 0,
            std.fmt.parseInt(i32, ys, 10) catch 0,
        };
    }
    pub fn measure_content_fn(p: *@This()) [2]i32 {
        if (p.kind == .img) return parseSize(p.source);
        return .{ 0, 0 };
    }
    fn wrap_content_fn(p: *@This(), width: i32) i32 {
        const c = p.measure_content_fn();
        const h = c[0] + c[1] - width;
        return if (h < 0) 0 else h;
    }
};

test "ui dsl: structure et parsing des classes" {
    const t = std.testing;
    const b = Builder(DslPainter, .{});

    //  0 root ─┬─ 1 A ─┬─ 2 A1
    //          │       └─ 3 A2
    //          └─ 4 B ──── 5 B1
    const root = comptime b.node("row gap-8 p-16 grow", &.{
        b.node("col gap-4 w-200", &.{
            b.leaf("w-100 h-50", .{ .kind = .img, .source = "100x50" }),
            b.node("grow h-fit", &.{}),
        }),
        b.node("ax-center ay-center grow", &.{
            b.leaf("w-64 h-64", .{ .kind = .img, .source = "64x64" }),
        }),
    });
    const layout = b.build(root);

    // pré-ordre + comptage
    try t.expectEqual(@as(usize, 6), layout.len);

    // liens d'arbre
    try t.expectEqual(@as(i32, 2), layout[0].children_count);
    try t.expectEqual(@as(?ui.NodeIndex, 1), layout[0].first_children);
    try t.expectEqual(@as(?ui.NodeIndex, 4), layout[0].last_children);
    try t.expectEqual(@as(?ui.NodeIndex, 4), layout[1].next); // A -> B
    try t.expectEqual(@as(?ui.NodeIndex, 3), layout[2].next); // A1 -> A2
    try t.expectEqual(@as(?ui.NodeIndex, null), layout[3].next); // A2 dernier
    try t.expectEqual(@as(?ui.NodeIndex, null), layout[4].next); // B dernier
    try t.expectEqual(@as(i32, 1), layout[4].children_count);
    try t.expectEqual(@as(?ui.NodeIndex, 5), layout[4].first_children);
    try t.expectEqual(@as(i32, 0), layout[3].children_count);

    // root: "row gap-8 p-16 grow"
    try t.expectEqual(ui.LayoutKind.horizontal, layout[0].layout);
    try t.expectEqual(@as(i32, 8), layout[0].margin);
    try t.expectEqual(@as(i32, 16), layout[0].padding.left);
    try t.expectEqual(@as(i32, 16), layout[0].padding.bottom);
    try t.expectEqual(ui.SizeKind.grow, layout[0].size[0].kind);
    try t.expectEqual(ui.SizeKind.grow, layout[0].size[1].kind);

    // A: "col gap-4 w-200" (hauteur reste .fit par défaut)
    try t.expectEqual(ui.LayoutKind.vertical, layout[1].layout);
    try t.expectEqual(@as(i32, 4), layout[1].margin);
    try t.expectEqual(ui.SizeKind.fixed, layout[1].size[0].kind);
    try t.expectEqual(@as(i32, 200), layout[1].size[0].size);
    try t.expectEqual(ui.SizeKind.fit, layout[1].size[1].kind);

    // A1: feuille fixe + painter
    try t.expectEqual(ui.SizeKind.fixed, layout[2].size[0].kind);
    try t.expectEqual(@as(i32, 100), layout[2].size[0].size);
    try t.expectEqual(@as(i32, 50), layout[2].size[1].size);
    try t.expectEqual(DslPainterKind.img, layout[2].painter.kind);
    try t.expectEqualStrings("100x50", layout[2].painter.source);

    // A2: "grow h-fit"
    try t.expectEqual(ui.SizeKind.grow, layout[3].size[0].kind);
    try t.expectEqual(ui.SizeKind.fit, layout[3].size[1].kind);

    // B: alignement
    try t.expectEqual(ui.AlignKind.middle, layout[4].@"align".x);
    try t.expectEqual(ui.AlignKind.middle, layout[4].@"align".y);
}

test "ui dsl: bout-a-bout build + compute (noeud unique fixe)" {
    const t = std.testing;
    const b = Builder(DslPainter, .{});

    const root = comptime b.leaf("w-100 h-50", .{ .kind = .img, .source = "100x50" });
    const layout = b.build(root);

    var tree: ui.Tree(DslPainter, .{}) = .{};
    tree.init(t.allocator);
    defer tree.deinit();
    try tree.nodes.appendSlice(&layout);
    try tree.compute(0);

    try t.expectEqual(@as(usize, 1), tree.commands.items.len);
    const cmd = tree.commands.items[0];
    try t.expectEqual(@as(i32, 0), cmd.x);
    try t.expectEqual(@as(i32, 0), cmd.y);
    try t.expectEqual(@as(i32, 100), cmd.w);
    try t.expectEqual(@as(i32, 50), cmd.h);
    try t.expectEqual(DslPainterKind.img, cmd.painter.kind);
    try t.expectEqualStrings("100x50", cmd.painter.source);
}
