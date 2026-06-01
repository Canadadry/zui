# zui

A small, dependency-free UI **layout engine** written in Zig. `zui` takes a tree
of nodes describing sizes, layout direction, alignment, padding and margins, and
computes a flat list of positioned boxes (draw commands) ready to be handed to a
renderer.

The sizing model and the grow distribution algorithm are inspired by
[Clay](https://github.com/nicbarker/clay).

> Tested against Zig **0.16.0**.

## Install

just run

```bash
zig fetch --save https://github.com/Canadadry/zui/archive/refs/heads/master.tar.gz
```

and add this to your `build.zig`

```zig
const zui_dep = b.dependency("zui", .{
    .target = target,
    .optimize = optimize,
});

exe.root_module.addImport("zui", zui_dep.module("zui"));
```


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
when you build nodes by hand these links must be populated directly — see
*Building nodes manually*. The `Builder` does this for you.)

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

### With the `Builder` (recommended)

The `Builder` lets you describe the tree declaratively with Tailwind-inspired
class strings, instead of allocating node indices and wiring
`first_children` / `next` by hand. `ui.build(root)` flattens the declared tree
into the flat node array that `Tree` expects.

The example below builds a tiny UI — a column holding a row of two buttons and a
row with a growing canvas next to a fixed sidebar — and renders it to the
terminal as ASCII boxes. Run it with `zig build example`.

```zig
pub fn main() !void {
    const alloc = std.heap.page_allocator;

    // Declare the tree with class strings.
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

    // Feed the flat node array to the layout engine.
    var tree: zui.Ui.Tree(Painter, .{}) = .{};
    tree.init(alloc);
    defer tree.deinit();
    try tree.nodes.appendSlice(&nodes);
    try tree.compute(0);

    // Render the resolved boxes to an ASCII buffer.
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
```

which render

```bash
> zig build example
+--------------------------------------------------+
|+----------+ +----------+                         |
||          | |          |                         |
||  btn-a   | |  btn-b   |                         |
||          | |          |                         |
|+----------+ +----------+                         |
|                                                  |
|+--------------------------------+ +-------------+|
||                                | |             ||
||                                | |             ||
||                                | |             ||
||                                | |             ||
||                                | |             ||
||                                | |             ||
||                                | |             ||
||                                | |             ||
||                                | |             ||
||             canvas             | |   sidebar   ||
||                                | |             ||
||                                | |             ||
||                                | |             ||
||                                | |             ||
||                                | |             ||
||                                | |             ||
||                                | |             ||
||                                | |             ||
|+--------------------------------+ +-------------+|
|                                                  |
|                                                  |
|                                                  |
|                                                  |
+--------------------------------------------------+
```

#### Builder API

- `zui.Builder.Builder(T, default_painter)` — returns a builder bound to your
  painter type `T` and a default painter value.
- `ui.node(classes, painter, children)` — a node with children (a slice of nodes
  produced by other `node` / `leaf` calls).
- `ui.leaf(classes, painter)` — a node with no children.
- `ui.build(root)` — flattens the declared tree into the flat node array,
  populating the `first_children` / `last_children` / `next` indices for you.

Declarations are done at `comptime`, so the whole tree shape is resolved at
compile time before being appended to `tree.nodes`.

#### Class reference

These are the classes used in the example above. The `Builder` is
Tailwind-inspired; this table reflects what the example exercises rather than the
full vocabulary — adjust it to match the `Builder` source.

| Class | Effect |
|-------|--------|
| `row` | `layout = .horizontal` |
| `col` | `layout = .vertical` |
| `w-N` | fixed width of `N` |
| `h-N` | fixed height of `N` |
| `grow` | grow on both axes |
| `grow-x` | grow on the X axis only |
| `p-N` | padding of `N` on all sides |
| `gap-N` | margin (gap between children) of `N` |

When several classes touch the same axis, the later one wins — e.g. `grow h-20`
grows both axes, then pins the height to `20`.

## Building and testing

```sh
zig build          # builds the `zui` executable
zig build example  # builds and runs the ASCII Builder example above
zig build test     # runs the test suite
```

Tests are data-driven: cases live in `src/testcase.json` (embedded at compile
time) and assert the full list of resulting draw commands against expected
boxes. To add a case, append an entry with its `nodes` and `expected` commands.
