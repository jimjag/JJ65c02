# Sprite Logic Flow: Single-Buffer vs Double-Buffer

## Core Mechanism

Each sprite stores:

- `bitmap[chunk][oddeven][row]` -- pre-shifted sprite pixels (uint64_t per scanline chunk)
- `mask[chunk][oddeven][row]` -- transparency mask (inverse: 0xF = transparent nibble)
- `bgrnd[chunk][row]` -- saved background pixels captured at draw time
- `x`, `y` -- current screen position
- `bgValid` -- whether `bgrnd` holds valid data that can be restored

**drawSprite** composites onto the framebuffer: reads screen -> saves to `bgrnd` -> applies `(screen & mask) | (~mask & bitmap)` -> writes back.

**eraseSprite** restores `bgrnd` to the framebuffer, effectively "unpainting" the sprite.

The z-order is maintained in `draw_order[]` -- lower indices are below higher indices.

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
