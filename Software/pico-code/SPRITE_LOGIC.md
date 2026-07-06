# Sprite Logic Flow: Single-Buffer vs Double-Buffer

## Core Mechanism

Each sprite stores:

- `bitmap[chunk][oddeven][row]` -- pre-shifted sprite pixels (uint64_t per scanline chunk)
- `invmask[chunk][oddeven][row]` -- inverted transparency mask (0xF = opaque nibble, 0x0 = transparent nibble)
- `opaque[chunk][oddeven]` -- uint64_t bitmask; bit j=1 means row j is fully opaque (no transparent pixels)
- `bgrnd[chunk][row]` -- saved background pixels captured at draw time
- `x`, `y` -- current screen position
- `bgValid` -- whether `bgrnd` holds valid data that can be restored

**drawSprite** composites onto the framebuffer: reads screen -> saves to `bgrnd` -> applies `bgrnd ^ ((bgrnd ^ bitmap) & invmask)` -> writes back. For fully opaque rows (all invmask nibbles = 0xF), the bitmap is written directly without masking.

**eraseSprite** restores `bgrnd` to the framebuffer, effectively "unpainting" the sprite.

The z-order is maintained in `draw_order[]` -- lower indices are below higher indices. A sprite keeps its slot for its whole lifetime (added on first draw, removed only by `freeSprite`), so hiding/off-screen/on-screen transitions never disturb layering.

### Known limitation: odd-X rightmost column

Pixels are packed 2-per-byte, so a 16- or 32-wide sprite is stored as one/two 64-bit chunks plus an odd-X variant shifted right one pixel. On an **odd-X** draw the sprite's rightmost column would land in the framebuffer byte just past the last chunk -- unreachable by the fixed 8-byte chunk writes -- so it is dropped (forced transparent). In practice sprites carry a transparent border column, so this is invisible; if the last column matters, keep sprites on **even** X-coordinates.

(A "spill" mechanism that rendered that column by writing one pixel past the chunk was implemented and then reverted: that extra pixel's byte could be aliased by an *adjacent* odd-X sprite's word, and because the overlap test keys off logical bounding boxes it missed the dependency -- corrupting the neighbor's saved background. The dropped column is the safe behavior.)

---

## Case 1: Single Frame Buffer (RP2040)

The display DMA is continuously scanning `vga_data_array[0]` while the CPU modifies it. Any pixel written is immediately visible on the next scanline pass. Sprites must be erased before redrawing to avoid leaving ghost trails.

### Best Logic Flow

```
+----------------------------------------------------------+
| INIT                                                     |
|   loadSprite(sn, width, height, data) for each sprite    |
|   drawSprite(sn, x, y, false) in z-order (bottom->top)  |
+----------------------------------------------------------+
                           |
                           v
+----------------------------------------------------------+
| ANIMATION LOOP                                           |
|                                                          |
|   for each sprite that moved this frame:                 |
|       moveSprite(sn, newX, newY)                         |
|                                                          |
|   // moveSprite internally:                              |
|   //  1. Fast path (no source overlap AND no higher-z    |
|   //     sprite at destination):                         |
|   //     - eraseSprite(sn)  [restore bgrnd]              |
|   //     - drawSprite(sn, newX, newY, false)             |
|   //  2. Full path (overlaps exist at source or dest):   |
|   //     - seed erase_set with sn                        |
|   //     - add higher-z sprites overlapping destination  |
|   //     - compute transitive closure (any sprite that   |
|   //       overlaps something in set gets added)         |
|   //     - erase all in set (reverse z-order)            |
|   //     - update position                               |
|   //     - redraw all in set (forward z-order)           |
|                                                          |
|   sleep / pace to desired frame rate                     |
+----------------------------------------------------------+
```

### Key Constraints (Single Buffer)

- **Tearing is unavoidable** -- erase/redraw happens while DMA scans out the buffer.
- Erase must happen BEFORE draw (you cannot defer erase to next frame since the old pixels are already visible).
- `bgrnd` represents the true background at the moment of draw -- this is the **only** state that allows clean erase.
- Sprites must be erased in **reverse z-order** (top first, peeling away layers) and redrawn in **forward z-order** (bottom first, building layers back up). Otherwise a lower sprite's `bgrnd` captures an upper sprite's pixels as "background."
- `moveSprite` handles all of this automatically. Calling `eraseSprite`/`drawSprite` manually risks corrupting `bgrnd` if z-ordering is not respected.

---

## Case 2: Double Buffering (RP2350)

Two buffers exist: `db_show` (index 0, always scanned by PIO DMA) and `db_draw` (index 1, modified by CPU). Both buffers are initialized to the same content when DB is enabled. At VBlank, calling `switchDB()` triggers the IRQ handler to **copy** the draw buffer into the show buffer (not swap pointers). The draw buffer retains its contents after the copy, allowing incremental updates across frames.

**Key difference from a traditional pointer-swap:** because the copy goes draw→show, the draw buffer is never replaced. Sprite `bgrnd` data in the draw buffer remains valid across frames without needing `show2drawDB()`.

### Best Logic Flow

```
+----------------------------------------------------------+
| INIT                                                     |
|   enableDB()                    // db_show=0, db_draw=1  |
|                                 // both buffers start    |
|                                 // identical (show→draw  |
|                                 // copy done internally) |
|   loadSprite(sn, ...) for each sprite                    |
|   drawSprite(sn, x, y, false) in z-order (bottom->top)  |
|   switchDB()                    // present first frame   |
|   waitForVBlank()                                        |
+----------------------------------------------------------+
                           |
                           v
+----------------------------------------------------------+
| ANIMATION LOOP                                           |
|                                                          |
|   // --- Option A: Full redraw (simplest) ---            |
|   // Call show2drawDB() to re-seed draw from show.       |
|   // This INVALIDATES all bgrnd data since draw buffer   |
|   // was replaced. Mark all sprites as bgValid=false,    |
|   // then redraw:                                        |
|   show2drawDB()                                          |
|   for each visible sprite (forward z-order):             |
|       sprites[sn]->bgValid = false                       |
|       drawSprite(sn, newX, newY, false)                  |
|                                                          |
|   // --- Option B: Persistent draw buffer (optimized) -- |
|   // Skip show2drawDB(). The draw buffer persists with   |
|   // sprites composited. bgrnd remains valid.            |
|   for each sprite that moved:                            |
|       moveSprite(sn, newX, newY)                         |
|                                                          |
|   switchDB()                    // request draw→show copy|
|   waitForVBlank()               // block until complete  |
+----------------------------------------------------------+
```

### Option A -- Full Redraw Per Frame (Tear-Free, Simplest)

- Call `show2drawDB()` to overwrite the draw buffer with the current show buffer contents -- a pristine copy with no sprites drawn.
- All `bgrnd` data is stale (it references the *old* draw buffer contents which are now gone).
- Invalidate all `bgValid` flags, then draw each sprite in z-order. Each captures its fresh background from the clean buffer.
- No erase step needed -- the copy *is* the erase.
- **Do NOT use `refreshSprites()` here.** It calls `eraseSprite` first, which would write stale `bgrnd` data into the clean buffer. Instead, manually invalidate `bgValid` and redraw.
- **Trade-off:** `show2drawDB()` costs ~150KB DMA copy, plus redrawing all sprites every frame. But zero tearing and zero overlap bugs.

### Option B -- Persistent Draw Buffer (Faster, Recommended)

- Do NOT call `show2drawDB()`. The draw buffer persists between frames with sprites already composited.
- Because `switchDB()` copies draw→show (not a swap), the draw buffer is never replaced. `bgrnd` data remains valid across frames.
- Use `moveSprite()` exactly as in single-buffer mode.
- **Trade-off:** faster (only touched sprites are erased/redrawn), but the draw buffer accumulates the same potential for multi-sprite overlap complexity. The win over single-buffer is that all the erase/redraw happens invisibly on the draw buffer, then appears atomically via the VBlank copy -- **no tearing**.

### Timing

The VBlank copy (draw→show) is performed by a dedicated ISR DMA channel during the vertical blanking interval:
- VBlank duration: ~1,440µs (45 lines × 32µs/line)
- Copy time: ~256µs (153,600 bytes as 38,400 word transfers at 150MHz)
- Margin: >1ms remaining for other VBlank work

---

## Recommendation

| Scenario | Approach |
|----------|----------|
| Few sprites, simple motion (no overlaps) | Single-buffer + `moveSprite` (fast path fires) |
| Many overlapping sprites, RP2040 | Single-buffer + `moveSprite` (full path handles correctness) |
| RP2350, tear-free needed, few sprites | Double-buffer Option A (full redraw) |
| RP2350, tear-free needed, many sprites | Double-buffer Option B (persistent draw buf + `moveSprite`) |

Option B is the sweet spot for RP2350 -- it gives tear-free display with the same incremental update cost as single-buffer mode.  Because `switchDB()` copies draw→show (rather than swapping pointers), the draw buffer is never replaced and `bgrnd` remains valid across frames.  `moveSprite`'s overlap logic keeps backgrounds correct without needing a per-frame `show2drawDB()` copy.

---

## API Contract & Invariants

The whole scheme rests on `bgrnd` always describing exactly what is under a
sprite's current `(x, y)`. The functions enforce this so callers don't have to
juggle it manually:

- **`moveSprite(sn, x, y)` is the preferred way to move a sprite.** It picks a
  fast path (lone sprite over static background) or a full path (transitive
  overlap closure, erase top-down, redraw bottom-up) and keeps every affected
  sprite's `bgrnd` correct. It also correctly **brings a sprite back** from
  off-screen or from `hideSprite()` UNDER any higher sprite it now overlaps
  (the old `!bgValid → plain draw` shortcut painted it on top -- fixed by
  routing everything except a brand-new sprite through the overlap-aware path).
- **`drawSprite(sn, x, y, erase)` self-protects.** It restores its previously
  saved background *before* capturing a new one whenever the new footprint
  overlaps the old (or when `erase=true`). This makes the classic footgun --
  re-drawing a moving sprite each frame with `erase=false` -- safe: it can no
  longer snapshot its own pixels as "background." Non-overlapping repeated
  draws still act as stamps (each leaves a copy), matching the old behavior.
- **Partially-off-screen sprites keep their TRUE position.** A sprite drawn at,
  say, `x = -5` renders at a clamped position but stores `x = -5`, so a later
  `moveSprite`/`refreshSprites` redraw puts it back where it belongs instead of
  teleporting it to the screen edge. Because the *rendered* footprint spans
  `[clamp(x), clamp(x)+width)` rather than the true bbox, the overlap tests key
  off that clamped footprint (`clamp_drawx`) so no real pixel overlap is missed.
- **Fully off-screen is a safe state.** When a draw target is entirely
  off-screen, `bgValid` is cleared but the draw-order slot is kept; the next
  on-screen `moveSprite` composites it back at its z-layer.
- **`hideSprite(sn)` keeps z-order and is overlap-aware.** It unpaints the
  sprite (erasing + rebuilding any higher sprite it was under, so no hole) but
  retains its draw-order slot, so re-showing it (via `drawSprite`/`moveSprite`)
  returns it to the same layer. `refreshSprites()` only repaints sprites that
  were actually visible when it was called, so hidden sprites stay hidden.
- **`freeSprite(sn)` releases a sprite** with an **overlap-aware** unpaint
  (erases sn plus the transitive set of sprites overlapping it, drops sn, then
  redraws the survivors -- the same closure `moveSprite`/`hideSprite` use), so
  it leaves no hole in a higher sprite, then frees all buffers and drops the
  draw-order slot. Calling **`loadSprite` on an occupied slot replaces** it.
- **Odd-X sprites drop their rightmost column** (see the Known-limitation note
  in the Core Mechanism section); keep sprites on even X if that column matters.

Erasing must still happen in **reverse z-order** and redrawing in **forward
z-order** -- `moveSprite`/`hideSprite`/`freeSprite`/`refreshSprites` all do this
via the shared `overlap_closure` / `erase_set_top_first` /
`redraw_set_bottom_first` helpers. If you hand-roll a sequence of
`eraseSprite`/`drawSprite` calls, respect that ordering.
