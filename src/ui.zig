const std = @import("std");

const SizeKind = enum { fixed, fit, grow };
const SizePrefUseKind = enum { none, to_max };
const LayoutKind = enum { vertical, horizontal, stack };
const AlignKind = enum { begin, middle, end };

pub fn compute_align(a: AlignKind, remaining: i32) i32 {
    return switch (a) {
        .begin => 0,
        .middle => remaining >> 1,
        .end => remaining,
    };
}

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
            bound: struct {
                min: i32 = 0,
                max: i32 = 0,
                pref_use: SizePrefUseKind = .none,
            } = .{},
        } = .{ .{}, .{} },
        layout: LayoutKind = .vertical,
        spacing: i32 = 0,
        margin: i32 = 0,
        @"align": struct {
            x: AlignKind = .begin,
            y: AlignKind = .begin,
        } = .{},
        padding: struct {
            left: i32 = 0,
            right: i32 = 0,
            top: i32 = 0,
            bottom: i32 = 0,
        } = .{},
        computed_box: struct {
            x: i32 = 0,
            y: i32 = 0,
            w: i32 = 0,
            h: i32 = 0,
        } = .{},
        children_count: i32 = 0,
        first_children: ?NodeIndex = null,
        last_children: ?NodeIndex = null,
        next: ?NodeIndex = null,

        pub fn fit_width_sizing(el: *@This(), min: i32, max: i32) void {
            el.computed_box.w += el.padding.left + el.padding.right;
            if (el.layout == .horizontal) {
                el.computed_box.w += (el.children_count - 1) * el.margin;
            }
            if (el.computed_box.w < min) {
                el.computed_box.w = min;
            }
            if (el.computed_box.w > max and max > 0) {
                el.computed_box.w = max;
            }
        }
    };
}

const NodeIndex = usize;
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

        pub fn compute(tree: *@This(), head: NodeIndex) !void {
            tree.compute_fit_size_width(head, null);
            tree.compute_shrink_size_width(head);
            tree.compute_grow_size_width(head);
            tree.compute_wrap(head);
            tree.compute_fit_size_height(head, null);
            tree.compute_shrink_size_height(head);
            tree.compute_grow_size_height(head);
            tree.compute_position(head, 0, 0);
            try tree.compute_draw_command(head);
        }

        pub fn link_child(tree: *@This(), parent: NodeIndex, child: NodeIndex) void {
            _ = tree;
            _ = parent;
            _ = child;
        }

        pub fn compute_fit_size_width(tree: *@This(), idx: NodeIndex, parent_idx: ?NodeIndex) void {
            const el = &tree.nodes.items[idx];
            var child_id = tree.nodes.items[idx].first_children;
            while (child_id) |c_id| {
                compute_fit_size_width(tree, c_id, idx);
                child_id = tree.nodes.items[c_id].next;
            }
            const content_width: i32 = 0.0;
            switch (el.size[0].kind) {
                .fixed => el.computed_box.w = el.size[0].size,
                .fit => el.fit_width_sizing(el.size[0].bound.min, el.size[0].bound.max),
                .grow => {
                    //content_width = tree.mesure_content_fn(tree.mesure_content_userdata, el.painter).x;
                    if (el.size[0].bound.pref_use == .to_max) {
                        el.size[0].bound.max = content_width;
                    }
                    el.fit_width_sizing(el.size[0].bound.min, el.size[0].bound.max);
                    el.computed_box.w = @max(el.computed_box.w, content_width);
                },
            }

            const p_id = parent_idx orelse return;

            switch (tree.nodes.items[p_id].layout) {
                .horizontal => tree.nodes.items[p_id].computed_box.w += el.computed_box.w,
                .vertical, .stack => tree.nodes.items[p_id].computed_box.w = @max(el.computed_box.w, tree.nodes.items[p_id].computed_box.w),
            }
        }

        pub fn compute_shrink_size_width(tree: *@This(), idx: NodeIndex) void {
            _ = tree;
            _ = idx;
        }

        pub fn compute_grow_size_width(tree: *@This(), idx: NodeIndex) void {
            _ = tree;
            _ = idx;
        }

        pub fn compute_wrap(tree: *@This(), idx: NodeIndex) void {
            _ = tree;
            _ = idx;
        }

        pub fn compute_fit_size_height(tree: *@This(), idx: NodeIndex, parent_idx: ?NodeIndex) void {
            _ = tree;
            _ = idx;
            _ = parent_idx;
        }
        pub fn compute_shrink_size_height(tree: *@This(), idx: NodeIndex) void {
            _ = tree;
            _ = idx;
        }

        pub fn compute_grow_size_height(tree: *@This(), idx: NodeIndex) void {
            _ = tree;
            _ = idx;
        }

        pub fn compute_position(tree: *@This(), idx: NodeIndex, x: i32, y: i32) void {
            const self = &tree.nodes.items[idx];
            const remaining_across: [2]i32 = tree.get_remaining(idx);
            var remaining_along: i32 = 0;

            var @"align": [2]i32 = .{
                compute_align(self.@"align".x, remaining_across[0]),
                compute_align(self.@"align".y, remaining_across[1]),
            };

            self.computed_box.x = self.pos.x + x;
            self.computed_box.y = self.pos.y + y;

            var offset: [2]i32 = .{
                self.padding.left,
                self.padding.top,
            };
            var child_id: ?NodeIndex = self.first_children;
            while (child_id) |c_id| {
                const child = &tree.nodes.items[c_id];
                switch (self.layout) {
                    .horizontal => {
                        remaining_along =
                            self.computed_box.h - self.padding.top - self.padding.bottom - child.computed_box.h;
                        @"align"[1] = compute_align(self.@"align".y, remaining_along);
                    },
                    .vertical => {
                        remaining_along =
                            self.computed_box.w - self.padding.left - self.padding.right - child.computed_box.w;
                        @"align"[0] = compute_align(self.@"align".x, remaining_along);
                    },
                    .stack => {
                        remaining_along =
                            self.computed_box.h - self.padding.top - self.padding.bottom - child.computed_box.h;
                        @"align"[1] = compute_align(self.@"align".y, remaining_along);
                        remaining_along =
                            self.computed_box.w - self.padding.left - self.padding.right - child.computed_box.w;
                        @"align"[0] = compute_align(self.@"align".x, remaining_along);
                    },
                }
                compute_position(tree, c_id, self.computed_box.x + offset[0] + @"align"[0], self.computed_box.y + offset[1] + @"align"[1]);
                switch (self.layout) {
                    .horizontal => offset[0] += child.computed_box.w + self.margin,
                    .vertical => offset[1] += child.computed_box.h + self.margin,
                    .stack => {},
                }
                child_id = child.next;
            }
        }

        pub fn get_remaining(tree: *@This(), parent_id: NodeIndex) [2]i32 {
            const parent = &tree.nodes.items[parent_id];
            var remaining = .{
                parent.computed_box.w - parent.padding.left - parent.padding.right,
                parent.computed_box.h - parent.padding.top - parent.padding.bottom,
            };

            if (parent.children_count == 0) {
                return remaining;
            }

            var child_id: ?NodeIndex = null;
            switch (parent.layout) {
                .horizontal => {
                    child_id = parent.first_children;
                    while (child_id) |c_id| {
                        remaining[0] -= tree.nodes.items[c_id].computed_box.w;
                        child_id = tree.nodes.items[c_id].next;
                    }
                    remaining[0] -= (parent.children_count - 1) * parent.margin;
                },
                .vertical => {
                    child_id = parent.first_children;
                    while (child_id) |c_id| {
                        remaining[1] -= tree.nodes.items[c_id].computed_box.h;
                        child_id = tree.nodes.items[c_id].next;
                    }
                    remaining[1] -= (parent.children_count - 1) * parent.margin;
                },
                .stack => {},
            }
            return remaining;
        }

        pub fn compute_draw_command(tree: *@This(), idx: NodeIndex) !void {
            try tree.commands.append(.{
                .x = tree.nodes.items[idx].computed_box.x,
                .y = tree.nodes.items[idx].computed_box.y,
                .w = tree.nodes.items[idx].computed_box.w,
                .h = tree.nodes.items[idx].computed_box.h,
                .painter = tree.nodes.items[idx].painter,
            });
            var child_id = tree.nodes.items[idx].first_children;
            while (child_id) |id| {
                try tree.compute_draw_command(id);
                child_id = tree.nodes.items[id].next;
            }
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
        try tree.compute(0);
        try expectEqual(tree.commands.items.len, tt.expected.len, "painter command len", tt.name, 0);
        for (tt.expected, tree.commands.items, 1..) |exp, got, i| {
            try expectEqual(exp.x, got.x, "x", tt.name, i);
            try expectEqual(exp.y, got.y, "y", tt.name, i);
            try expectEqual(exp.w, got.w, "w", tt.name, i);
            try expectEqual(exp.h, got.h, "h", tt.name, i);
            try expectEqual(exp.painter.kind, got.painter.kind, "painter.kind", tt.name, i);
            try expectEqualStrings(exp.painter.source, got.painter.source, "painter.source", tt.name, i);
        }
    }
}

pub inline fn expectEqual(expected: anytype, actual: anytype, name: []const u8, case: []const u8, i: usize) !void {
    std.testing.expectEqual(expected, actual) catch |err| {
        std.debug.print("at {s} on {s}:{d}\n", .{ name, case, i });
        return err;
    };
}

pub inline fn expectEqualStrings(expected: []const u8, actual: []const u8, name: []const u8, case: []const u8, i: usize) !void {
    std.testing.expectEqual(expected, actual) catch |err| {
        std.debug.print("at {s} on {s}:{d}\n", .{ name, case, i });
        return err;
    };
}
