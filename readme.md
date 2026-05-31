# zui

A small, dependency-free UI **layout engine** written in Zig. `zui` takes a tree
of nodes describing sizes, layout direction, alignment, padding and margins, and
computes a flat list of positioned boxes (draw commands) ready to be handed to a
renderer.

The sizing model and the grow distribution algorithm are inspired by
[Clay](https://github.com/nicbarker/clay).

> Tested against Zig **0.16.0**.

## What it does

`zui` separates *layout* from *rendering*. You describe a hierarchy of nodes;
`zui` resolves every box's final `x`, `y`, `w`, `h` through a series of passes,
then emits one `PainterCommand` per node. How those commands are drawn is left
entirely to your code (the `Painter` type, see below).

It does **not** do: drawing, input handling, text shaping, or animation. It is
the layout core only.

## Core concepts

### Node

A node is one box in the tree. The fields that drive layout:

| Field | Meaning |
|-------|---------|
| `size[0]` / `size[1]` | sizing for the X and Y axes (see *Sizing kinds*) |
| `layout` | `.horizontal`, `.vertical`, or `.stack` |
| `align` | `.begin` / `.middle` / `.end` per axis |
| `padding` | inner spacing (`left`, `right`, `top`, `bottom`) |
| `margin` | gap inserted between children along the layout axis |
| `painter` | your renderer payload, carried through to the output |

Children are stored as an **intrusive linked list of indices** into the tree's
`nodes` array: each node points to `first_children` / `last_children`, and
siblings are chained through `next`. (`link_child` is currently a placeholder, so
these links are populated directly — see *Usage*.)

### Sizing kinds

Each axis is sized independently with one of:

- **`fixed`** — an explicit `size` in pixels.
- **`fit`** — shrink-wrap to the content plus padding, clamped to `[min, max]`
  (a `max` of `0` means "no maximum").
- **`grow`** — expand to fill the parent's remaining space, clamped to
  `[min, max]`. When several siblings grow, the remaining space is distributed
  smallest-first so boxes equalize before any single one overshoots. Setting
  `pref_use = .to_max` ties the axis `max` to the measured content size.

### Layouts

- **`horizontal`** — children laid left to right; the X axis is the *main* axis,
  Y is the *cross* axis.
- **`vertical`** — children laid top to bottom; Y is main, X is cross.
- **`stack`** — children overlap in the same box; both axes behave as cross axes.

`margin` only applies along the main axis. On the cross axis, children are placed
according to the node's `align`.

## The layout algorithm

`compute(head)` runs these passes in order:

1. **fit width** — bottom-up: each node's content width, then clamp.
2. **shrink width** — pull growers down to their minimums where space is tight.
3. **grow width** — distribute leftover width across growers (smallest-first).
4. **wrap** — let the painter recompute height for the resolved width
   (e.g. text wrapping).
5. **fit / shrink / grow height** — the same three passes on the Y axis.
6. **position** — top-down: assign final `x`/`y`, applying padding, margin and
   alignment offsets.
7. **draw commands** — flatten the tree into `tree.commands`.

The result is `tree.commands`: a slice of `PainterCommand { x, y, w, h, painter }`
in tree order.

## The `Painter` interface

`Tree` is generic over a painter type `T` and a default value:
`Tree(T, default_painter)`. Your `T` must provide two methods:

```zig
// Intrinsic content size [width, height].
pub fn measure_content_fn(self: *@This()) [2]i32 { ... }

// Given a resolved width, return the content height (e.g. wrapped text).
pub fn wrap_content_fn(self: *@This(), width: i32) i32 { ... }
```

`zui` never inspects the painter beyond these calls — it copies the painter value
into each draw command and hands control back to you.


## Usage

```zig
const std = @import("std");

const Painter = struct {
    color: u32 = 0,
    pub fn measure_content_fn(_: *@This()) [2]i32 {
        return .{ 0, 0 };
    }
    fn wrap_content_fn(_: *@This(), _: i32) i32 {
        return 0;
    }
};

var tree: Tree(Painter, .{}) = .{};
tree.init(allocator);
defer tree.deinit();

// Build the node list. Children are linked by index:
// node 0 is a 200x200 row containing two growing children (1 and 2).
try tree.nodes.appendSlice(&.{
    .{
        .size = .{ .{ .kind = .fixed, .size = 200 }, .{ .kind = .fixed, .size = 200 } },
        .layout = .horizontal,
        .margin = 10,
        .padding = .{ .left = 10, .right = 10, .top = 10, .bottom = 10 },
        .children_count = 2,
        .first_children = 1,
        .last_children = 2,
    },
    .{ .size = .{ .{ .kind = .grow, .min = 100 }, .{ .kind = .grow } }, .next = 2 },
    .{ .size = .{ .{ .kind = .grow }, .{ .kind = .grow } } },
});

try tree.compute(0);

for (tree.commands.items) |cmd| {
    // hand cmd.x / cmd.y / cmd.w / cmd.h / cmd.painter to your renderer
    std.debug.print("{d},{d} {d}x{d}\n", .{ cmd.x, cmd.y, cmd.w, cmd.h });
}
```

## Building and testing

```sh
zig build          # builds the `zui` executable
zig build test     # runs the test suite
```

Tests are data-driven: cases live in `src/testcase.json` (embedded at compile
time) and assert the full list of resulting draw commands against expected
boxes. To add a case, append an entry with its `nodes` and `expected` commands.
