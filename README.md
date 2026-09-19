# g9-gui — "modern UI & stats"

A full-screen modern menu suite for **Gen 1** (Red / Blue / Yellow) on the
gen1recomp engine. It replaces the START screen, the POKéMON screen, the
POKéMON summary **and every page the START menu opens** (bag, Pokédex, Options,
trainer card, mod manager) with one design drawn on a **540×360** UI surface,
plus the START screen's SAVE/QUIT prompts, the boot **title menu** and the
**LOAD REPORT**.

Ships as a mod folder (`manifest.json` + `main.lua` + `ui/*.lua` +
`assets/fonts/*.ttf`), id `g9-gui`, `games: ["gen1"]`. Gen 2 is untouched by
design (see *Scope*).

---

## What the player sees

| Engine screen | Replaced by | Look |
| --- | --- | --- |
| `StartMenu` | `ui/start_menu.lua` | The vanilla word list in a left rail, the live party roster filling the right column |
| `PartyMenu` | `ui/party_menu.lua` | **The same page** — same header, same rail, same roster — with the engine's own submenu as a modern popup |
| `SummaryMenu` | `ui/summary.lua` | Adv.Stats in a 486×324 panel (90% of 540×360) floated **over** the POKéMON screen |
| `BagMenu` | `ui/bag.lua` | ITEM: the same page, one full-width list with `×N` counts (left classic while a battle owns the surface) |
| `PokedexMenu` | `ui/pokedex.lua` | POKéDEX: `num name`, an owned-ball marker, unseen entries dimmed, `SEEN n OWN n` in the header |
| `DexEntryMenu` | `ui/dex_entry.lua` | A species page: portrait panel, `HEIGHT`/`WEIGHT` figures, the re-wrapped description (paged) |
| `OptionsMenu` | `ui/options.lua` | OPTION and its group sub-pages: label + value rows, a synthetic `BACK` row |
| `TrainerCard` | `ui/trainer_card.lua` | The player card: portrait panel, NAME/MONEY/TIME figures and eight badge slots drawn from the game's own badge tiles |
| `ManagerState` | `ui/manager.lua` | MODS: a MODS/PROFILES/ERRORS tab strip over the manager's own rows, plus its options and confirm/notice overlay |
| `TitleState` | `ui/title.lua` | The boot title screen keeps its logo/cinematic; its own `CONTINUE / NEW GAME / OPTION / EXIT GAME` menu and the `CONTINUE` save-data window become this mod's rail + SAVE DATA emblem |
| `QuarantineReport` | `ui/load_report.lua` | LOAD REPORT: the one-shot validation digest, as a sectioned scrollable page |

The START screen's **SAVE** and **QUIT** rows open this mod's own modals
(`ui/dialogs.lua`) instead of the classic `TextBox` + `ChoiceBox`: a save-data
card, a YES/NO confirmation and an auto-advancing notice, so the save prompt is
the same page as the menu that opened it.

Every one of those is a **view takeover**: the engine's own object stays on the
stack and keeps its navigation, and only the page is redrawn at 540×360, so
they are all the same size and type as the START screen. The START and POKéMON
screens are the *same page* (`ui/shell.lua` owns its size, header, footer and
left rail), which is why they cannot drift apart: the START screen shows the
word list with a cursor, the POKéMON screen shows that **same rail** with the
party roster filling the right column and no cursor.

**The rail omits the POKéMON row.** The party is always on the right of both
pages, so a rail row that only re-showed it was redundant; instead **LEFT/RIGHT
pages between the START menu and the POKéMON screen** (the removed row's own
`onSelect` is what the arrow fires, so Oak's gift gate and the
`ui.start_menu.items` hook still decide whether the page opens at all). The old
left-hand detail card on the POKéMON screen is gone — level, HP figures, the HP
gauge and status are all already on the member's own row.

Layout of the page:

```
[ *  RED's menu ......................... BADGES 0  17:46  DEX 120 ]
[    Assign members to the party. .................... MONEY: 2244 ]
[ POKéDEX  ]  [ portrait ] BULBASAUR    12   30/38
[ ITEM     ]  [  head    ] #####HP####   #####EXP#####
[ RED      ]  ...                       (six party rows)
[ hints ..............................................  PARTY 6/6 ]
```

The roster row (the heart of the design) is, left to right: the selection band
with a modernised **double chevron** (alone — no accent bar beside it, and
centred in the row), a **56×34 portrait card**, the mon's name **beside** the
card (never printed over it), `hp/max` right-aligned in the column next to the
name, then the level — gold and SemiBold, at the row's right edge, with a
**small `Lv`** sat on the digits' baseline ahead of them — a colour-coded HP
gauge under them and an EXP bar in the right-hand column. The name is cut to
the pixels the HP figures actually leave (`210/210` is much wider than
`63/63`), so a long name stops short of them instead of running underneath. A
status flag is a small chip in the card's top-right corner (`FNT`, `PSN`, …); a
fainted mon's row is washed dark. There is no column-heading row: at the 22px
body a heading would push the sixth slot past the footer rule, and the `30/38`
/ `Lv 63` figures read without titles.

The player's wallet is **not** a column: it is one `MONEY: 2244` readout on the
header's second line, directly under the `BADGES … DEX …` readout.

### Summary panel

Four pages, `←`/`→` (or `A`) to turn, `B` to close:

1. `STATS` — the six combat stats with bars, plus identity rows
   (`ABIL` `NAT` `TYPE` `ITEM` `TERA` `DMAX`)
2. `EVS` — EV spread, each bar against the real 252-per-stat cap
3. `IVS` — IV spread, bars against 0–31
4. `MOVES` — the four moves with category and PP, plus the EXP situation

When the screen under it is one of ours, the summary is **non-opaque** and the
panel floats over the still-drawn menu; `StateStack:visibleBase()` stops at the
party menu because of it. Over anything else (a battle, Bill's PC) it draws its
own backdrop instead, so nothing that was never designed for this surface is
left half-drawn underneath.

### Options (`options.lua`, mirrored in `manifest.options_schema`)

| key | default | effect |
| --- | --- | --- |
| `modern_ui` | ON | Master switch. OFF installs nothing at all — every screen is left exactly as the engine drew it |
| `ui_background` | ON | ON: the layered backdrop (gradient, glows, vignette, weave). OFF: a flat dark field |
| `ui_embellishment` | ON | ON: corner brackets, rules, header emblem, pulsing chevrons. OFF: the same layout, undecorated |
| `ui_portraits` | `sprites` | `sprites`: the head space of the pack's **front battle sheet** (`assets/front/<STEM>.png`), at the pack's own 1:1 pixels. `icons`: the pack's **16×16 party-icon atlas** (`assets/icons/party_icons.png`) fitted into the same card |

Choice rows carry their value as a **string** (`"true"` / `"false"` /
`"sprites"` / `"icons"`); every read in the mod compares against a string and a
missing row reads as ON.

---

## File map

```
manifest.json       id/name/version, games=["gen1"], priority 100,
                    optional_dependencies=[g9-battle-engine, g9-battle-sprites],
                    options_schema
main.lua            entry chunk: helpers esc()/loadSibling()/attempt()
                    (per-piece failure isolation), option reads, Gen 1 gate,
                    sibling loading, screen registration
options.lua         the Mod Manager option schema (shared with the manifest)
ui/theme.lua        palette, Saira font factory (mod TTF -> FileData, Plain
                    Pixel fallback), METRIC/ink-offset metrics, Theme.fit,
                    drawing primitives (panel, bar, chevrons, brackets, hints,
                    hpFrac)
ui/shell.lua        THE PAGE: its 540x360 size, header (title + readout +
                    MONEY), footer hints, the shared left rail of START-menu
                    rows, and Shell.list -- the generic modern list panel every
                    list page (bag, POKeDEX, OPTION, MODS) draws through.
ui/backdrop.lua     the layered background
ui/portraits.lua    portrait art: the pack's front-sheet head crop, or its
                    16x16 icon atlas, or the engine's own art
ui/roster.lua       the shared party table (used by START and POKéMON)
ui/start_menu.lua   StartMenu view takeover (+ the LEFT/RIGHT party paging)
ui/party_menu.lua   PartyMenu view takeover
ui/summary.lua      SummaryMenu replacement, 90% panel, 4 pages
ui/bag.lua          BagMenu view takeover (ITEM)
ui/pokedex.lua      PokedexMenu view takeover (POKéDEX)
ui/dex_entry.lua    DexEntryMenu view takeover (a species' dex entry page)
ui/options.lua      OptionsMenu view takeover (OPTION and its group pages)
ui/trainer_card.lua TrainerCard view takeover (the player-name row: portrait,
                    figures, and the badge row drawn from the engine's own
                    trainer_card/badges.png tiles -- earned ones in colour
                    behind a gold ring, unearned ones ghosted)
ui/manager.lua      ManagerState view takeover (MODS); its ERRORS tab and a
                    mod's own errors page carry an EXPORT LOG row that writes
                    the whole error log to a .txt (see *Error log export*)
ui/dialogs.lua      the shared modals: the save-data card (also the title's
                    CONTINUE window), the YES/NO confirmation and the
                    auto-advancing notice the SAVE flow uses
ui/title.lua        TitleState view takeover (the boot menu + CONTINUE window)
ui/load_report.lua  QuarantineReport view takeover (LOAD REPORT)
assets/fonts/Saira-Regular.ttf    body copy (SIL OFL 1.1)
assets/fonts/Saira-SemiBold.ttf   titles, levels, stat values
assets/fonts/OFL.txt              Saira's licence - must ship beside the TTFs
```

---

## Design notes

### View takeover, not reimplementation

`main.lua` never reimplements a screen. It asks the engine for the real object
(`require("src.ui.StartMenu")` etc.), lets the engine build it, and then amends
**the instance**: `draw`, `uiSize`, `isWideBattleLayout`, `wantsFillScale`,
`sgbPalettes` and the opacity flag move onto the instance, and the engine's own
`update` keeps running (wrapped only to tick an animation counter).

That is what keeps every shipped behaviour working unchanged: which rows exist
and when (POKéDEX only after Oak's gift), the SAVE panel and its prompt, the
cursor that survives closing, the `ui.start_menu.items` /
`ui.party.submenu` hooks other mods insert through, FLY / SURF / CUT / STRENGTH
/ SOFTBOILED, the medicine HP-fill animation, the swap animation, TM/HM and
evolution-stone ABLE/NOT ABLE views, item targeting and battle switching.

The POKéMON screen's left rail is built through the engine's own `StartMenu`
(`Shell.startRows`), so the POKéDEX row, the MODS row and the
`ui.start_menu.items` hook decide what that rail contains — it is literally the
same list the START screen shows (minus the POKéMON row, which both screens
hide), and it is cached per game table.

Each of the START menu's other pages is the same shape of takeover: `ui/bag.lua`,
`ui/pokedex.lua`, `ui/options.lua` (which also patches the engine's own group
sub-page factory, so `OPTION`'s nested pages get the modern page too),
`ui/trainer_card.lua`, `ui/manager.lua` and `ui/dex_entry.lua` (the page
POKéDEX opens on a species) each wrap their engine object's `draw`/surface and
keep its `update`.

### Failure isolation

The mod loader journals every registration a chunk makes and **rolls the whole
journal back if the chunk throws**, so a single bad sibling file used to take
the entire suite down — every screen silently reverting to the classic UI with
one log line to explain it. `main.lua` therefore builds each piece inside
`attempt(label, fn, ...)` (a `pcall` that logs `g9-gui: <label> failed: <err>`
and returns `nil`) and installs each screen through it:

* `options.lua` failing leaves the mod enabled with default options.
* A shared `ui/*.lua` module (theme, backdrop, shell, portraits, roster) that
  does not load or initialise stops the mod cleanly with a log line rather than
  half-installing.
* `ui/dialogs.lua` failing leaves the screens installed and SAVE/QUIT on the
  engine's classic prompts (`title.lua` also keeps the engine's own
  `ContinueInfo` window in that case).
* Any single screen factory (`ui/start_menu.lua`, `ui/title.lua`, …) failing is
  skipped by itself, so the builtin screen stays for that id and every other
  screen still installs.

The boot `info` line always reports what installed and ends
`(modals on, background …, embellishments …, portraits …, modern stats …)` or
`(modals CLASSIC, …)`, so a failure is visible in START → MODS without a crash.
`ui/dialogs.lua`'s `harden(s)` wraps each modal's `draw`/`update` in a `pcall`
too: a draw that throws logs once and steps the modal aside, so the page
beneath returns instead of leaving a blank frame.

### Error log export

The manager's ERRORS tab (and a mod's own errors page, reached from its detail
screen) carries an **EXPORT LOG** row ahead of the engine's error lines. It
writes the **whole** log — every `status.errors` entry verbatim, then every mod
whose `state` is not `loaded` with its `error`/`note`, plus a header naming the
game/engine versions and the counts — to **`g9-gui-error-log.txt`**. It matters
because the manager's own page can only show a handful of 16-character-wrapped
lines at once, so a long boot log is unreadable there.

Two engine constraints shape how it writes:

* a mod chunk cannot name a file at all — `love.filesystem` is blocked by the
  loader's sandbox, and `io`/`package` are absent;
* `mod.storage` can only produce `.lua` (a serialized data table) or `.bin`
  (opaque bytes) files, under keys restricted to letters/digits/`_`/`-`
  segments — **no dots**, so it cannot make a `.txt`.

The write therefore goes through `src.import.CacheFs`, an **engine** module
required from the sandboxed chunk: the require is allowed (only `io`, `os`,
`debug`, `package`, `ffi` and `love.*` are denied) and the module runs in the
engine's own environment, where `love`/`io` are the real ones. `CacheFs.write`
routes to the OS save directory, or to the game folder itself in a portable
install, and creates parent directories as needed. The action `pcall`s the whole
write and rides the manager's own notice slot — `SAVED g9-gui-error-log.txt` on
success, `EXPORT FAILED` otherwise. The row is injected by wrapping
`rowsForScreen` (a fresh copy, never mutating the base list) so the cursor,
`focusedRow` and `activate()` all see it.

### The 540×360 surface

Each screen answers `:uiSize()` with `Shell.W, Shell.H` = `540, 360`.

540×360 is the one shape that divides **1080×720** evenly: a 1080×720 window
blits this page at a whole 2× with no letterbox at all (`Renderer:fitScale =
min(1080/540, 720/360) = 2`). The page cannot simply *be* 1080×720 — the
engine's `Renderer:setUISize` rejects a surface over `MAX_UI_WIDTH/MAX_UI_HEIGHT`
(640×576) and falls all the way back to 160×144 — so 540×360 (3:2) is the
largest page that divides 1080×720 whole, and it is 1.7× the classic page in
width and 2.5× in height.

**The type is proportional, so the page is laid out in measured pixels.** The
body is **22** (Saira — see *Type*) and the secondary size is **13**, used for
chips, the small `hp/max` and `ABLE` figures, header readouts and the summary's
identity block. At 22 px Saira's capitals stand **15.1** px tall, so at the
page's 2× blit a capital reaches **30 screen pixels** on a 1080×720 window —
larger than the old 320×180 page's 15 px cell managed at its 3.375× blit —
which is what makes the menu genuinely fill the surface instead of floating in
it. Saira is proportional, so there is no cell grid to snap to: every column in
`ui/shell.lua`, `ui/roster.lua` and `ui/summary.lua` is a measured pixel
budget, and strings are trimmed with `Theme.fit(str, font, px)` — which cuts on
a UTF-8 boundary and appends `…` — rather than by character count.

`Game:draw` calls `Renderer:setUISize` with the top wide state's size and
centres classic states in the extra width (`classicOffset`), so 160×144 art
still lands in the middle of the bigger canvas.

**Nothing in this mod ever calls `Renderer:setUISize` or
`love.graphics.setCanvas` itself** — doing that from inside a state's `draw` is
the documented silent-crash hazard (see `stats/train_screen.lua`'s own note).
It answers `:uiSize()` and lets `Game:draw` size the surface, which is how the
TRAIN and MOVE screens in `g9-battle-engine` do it too.

`:isWideBattleLayout()` returns false while an opaque *classic* screen sits
above the menu, so the surface falls back to 160×144 while, say, the BAG is up.

### Filling the window (why the START screen matches the POKéMON screen)

`fitScale` is `max(1, floor(min(pw/uw, ph/uh)))` — a **whole** number. In any
window that is not a whole multiple of 540×360 the page therefore drops to the
next scale down: in a 1022×727 window `floor(min(1.893, 2.019)) = 1`, so the
page blits at a **tiny 540×360** in the middle of the window. The engine's
`Renderer:frameRects` has a second scale for exactly this case: when
`Renderer.uiFill` is set it uses `min(ph/uh, pw/uw)` — the *fractional*
window-fill scale, aspect preserved, bars on the long axis. The engine sets
`uiFill` from `Game.fillScaleInStack(stack)`, which is true when **any state on
the stack** answers `:wantsFillScale()`. The title screen, the intro and a
BATTLE SIZE "fill" battle are the engine's own users of it.

The POKéMON screen was getting that scale *by accident*: `g9-battle-sprites`
installs `wantsFillScale` on the engine's `src.ui.PartyMenu` **class**, and this
mod's party instance inherits it through its metatable. The START screen does
not — nothing patches `src.ui.StartMenu` — so the two pages of the same design
came out at different physical sizes (the party page at 1022×681, the START
page at 540×360, in that 1022×727 window). **Each screen now declares
`:wantsFillScale()` itself** (`start_menu.lua` and every START-menu page gate it
on the same whole-stack test as `isWideBattleLayout`, via `Shell.wide`;
`summary.lua` returns true since it is always wide), so the request is this
mod's own rather than a side effect of another mod being installed, and the
START and POKéMON pages — and the bag, PokéDEX, Options, trainer card and mod
manager — are the same size at every window size.

The bag is the one exception: its `wantsFillScale` is gated on
`Shell.wide`, and the bag is also reachable mid-battle, where the wide battle
owns the surface — so `ui/bag.lua` checks `Shell.inBattle` and leaves the
engine's classic bag exactly as shipped there.

In a 1080×720 window the fill scale is `min(720/360, 1080/540) = 2`, which is
also the integer `fitScale` — so the page is unchanged where it was already
perfect, and grows to fill everywhere else.

**Known limit.** The engine centres a *classic* 160×144 state pushed over a wide
surface **horizontally only**. A non-opaque overlay — a TextBox, the SAVE panel
— therefore draws at the TOP of this page rather than at its bottom. The SAVE
panel lives at the top of the classic page already, so it is unaffected; a
bottom dialogue box reads high. Putting a classic overlay where a tall page
wants it needs engine support for vertical centring.

### Type (the FFXII match)

The menus are set in **Saira** (Regular for body copy, SemiBold for titles,
levels and stat values) — a free, close stand-in for the **Final Fantasy XII:
The Zodiac Age** party-screen face. The real FFXII font is a commercial
typeface and cannot be redistributed, so this mod ships its own: Saira is a
humanist sans with the same low-stress, slightly squared bowls, a tall x-height
and narrow-ish caps, and at 22 px it reads as the same kind of type without
being a copy. The scale is one body size (22), one secondary size (13) and one
caption size (10 — the roster's `Lv`), exposed by `Theme.fonts` as
`body`/`bold`/`small`/`tiny`. The two TTFs (plus SIL OFL 1.1) live in
`assets/fonts/` and ship
with the mod — `assets/fonts/OFL.txt` **must** stay beside them, since Saira is
licensed under the SIL Open Font License 1.1. If the faces cannot be loaded the
mod falls back to the engine's own Plain Pixel, so the design still opens.

### Text metric (the "ink offset")

Every g9-gui layout is written in **ink coordinates**: `Theme.text(str, x, y)`
takes the y of the *top of the glyph ink*, not the top of the font's line box.

This exists because plain `love.graphics.print` puts the line's ascent line at
`y`. `Theme` therefore keeps a `METRIC` table — one row per shipped face
(ascender, cap height, descender as fractions of the em) — and derives each
font object's offset from it (`Theme.inkOffset`), subtracting it inside
`Theme.text`; `Theme.capOf(font)` gives the cap height the row layouts measure
against. This is the same trick the engine's own `Font.draw` performs when it
anchors the TTF baseline to the tile font's (`yOffset = 7 −
font:getBaseline()`).

| face | em | ascent | cap | descent |
| --- | --- | --- | --- | --- |
| Saira Regular / SemiBold | 1000 | 1135 | 688 | 439 |
| Plain Pixel (fallback) | 15 | 19 | 11 | 9 |

`Theme` resolves the face per font object, so the Saira numbers drive every
layout in the mod while the Plain Pixel row keeps the fallback laying out
correctly too.

### Palette / shaders

`Theme` makes its own `love.graphics.newFont` objects rather than going through
the engine's tile Font, because the engine Font is laid out for the 8×8 tile
grid and because `love.graphics.print` takes the current colour — which is what
lets the palette put gold on levels and accent blue on values. The faces come
from the mod's own `assets/fonts/*.ttf` (Saira Regular + SemiBold), read as
bytes through `mod:read` and wrapped in a `FileData` before
`love.graphics.newFont` (with `mod.assets:path` as a second attempt), and fall
back to the engine's Plain Pixel `data.font.ttf.file` if the TTFs cannot be
loaded. Fonts draw with a **linear** filter (they are vector-scaled, unlike the
nearest-filtered tile art).

Every screen answers `:sgbPalettes()` with an **empty zone list**, so the
engine's SGB shade-remap shader never runs over these surfaces and the colours
above reach the screen unchanged.

### Portraits

`ui/portraits.lua` draws the **g9-battle-sprites** pack's own art, picked by
the `ui_portraits` option, and falls back to the engine's own, so the modern UI
still works without that mod. The pack's art comes from two **always-on**
exports (they do not depend on that mod's battle options, so the portraits show
the pack's art even with BATTLE SPRITES off):

| mode | source | export |
| --- | --- | --- |
| `sprites` | the pack's front battle sheet `assets/front/<STEM>.png`, baked to a trimmed frame | `frontArt(mon)` → `(image, w, h)` |
| `icons` | the pack's 16×16 party-icon atlas `assets/icons/party_icons.png` | `iconArt16(mon)` → `(quads, image, cell)` |

* `sprites` mode draws the **head space** of the trimmed front frame: the
  card's own window of it (a 56×34 card → 56×34 frame pixels), **anchored to
  the creature** and drawn at the pack's **own pixels, 1:1**. The export trims
  to the whole animation's union box, so frame 1 can sit inside that box with
  spare rows above its head; `contentBox` reads the frame's pixels back
  (`Image:newImageData` → `getPixel`, cached) to find frame 1's own opaque box
  and anchors the window to its top, centred across it. A frame narrower or
  shorter than the card is centred in it at its own size. **Nothing is ever
  zoomed**: the sheets are trimmed per species, so 1:1 is what keeps their
  relative sizes reading true (a Weedle stays a Weedle beside an Amoonguss) —
  the same natural size the battle screen draws — and the old per-frame whole
  multiple (`ceil(w / frameW)`) was what blew the *smallest* sheets up hardest.
  The bake is asynchronous (that mod's `core.update` budget), so the first call
  answers `nil, pending` and the next frame gets the art. `pending` is kept
  through the call, so those frames leave the card to the pack art rather than
  flashing the engine's own pic; the engine fallback only covers a species the
  pack has no sheet for (which answers `nil` with no `pending`).
* `icons` mode fits the whole 16×16 atlas cell into the card at the largest
  whole multiple that fits.
* **older copies of the sprites mod** (no `frontArt` / `iconArt16`) still work:
  the module falls back to `iconArtHD(mon)` — the pack's **true-colour,
  high-resolution 64×64 frames** (`assets/icons/party_icons_hd.png`, bundled
  with that mod) — cropped for `sprites` mode (the same 1:1 head window) and
  fitted for `icons` mode. `iconArtHD` answers `(quads, image, cellPixels,
  box)`; `box` is the `{x, y, w, h}` bounding box of the frame's opaque pixels,
  and the crop anchors to `box.y` for the same reason the front frame needs
  `contentBox`.
* **engine fallback** — `sprites` mode draws the front pic at a whole multiple
  anchored to its TOP (the head-and-shoulders reading); `icons` mode draws the
  engine's 16×16 icon frame at the largest whole multiple that fits. Both come
  through `Sprites.path` / `Sprites.iconPath` → `Assets.resolve`, so a mod that
  swaps battle art changes what this UI shows too.
* **the fall-back is announced, once** — a mod cannot read another mod's files
  (`love.filesystem` is closed to mods and `mod:read` only sees its own
  folder), so these exports are the ONLY channel between the two mods. All three
  are looked up through one `peerEx()`, which counts consecutive misses and
  logs a single line after a second of roster drawing: `g9-battle-sprites
  <version> has no portrait art exports -- party portraits use the game's own
  art (update that mod to 3.0.8+, keeping your downloaded assets/front and
  assets/back sheets)` — or `<id> is not installed` at `info` level. That is why
  a pre-3.0.8 sprites mod (or a 3.0.9 `main.lua` copied over an older folder
  without the new `data/icon_data.lua`) shows the game's own art AND says so,
  instead of only looking broken. Note `iconArtHD` is fed by the **bundled**
  `assets/icons/party_icons_hd.png`, so any complete 3.0.8+ install paints the
  cards in colour even with no downloaded sheets.

Everything is clipped to the card with `love.graphics.setScissor`, so a
mismatched atlas can never spill into the next column.

### Optional dependencies

* **`g9-battle-engine`** — the summary's modern fields (split special stats,
  ability, nature, Tera type, Dynamax level) come from its exported
  `ModernStats` / `MoveCategory` / `getTeraType` / `getDynamaxLevel`. Every read
  is `pcall`-guarded, so the panel still opens with a correct vanilla stat block
  and blank modern rows without it. As of engine 4.3.0 the engine mod no longer
  draws a summary screen of its own — that is this mod's job.
* **`g9-battle-sprites`** — the roster portraits (see *Portraits*). Optional:
  without it the engine's own art is used, and the log says so once. **3.0.8 or
  newer is what makes the portraits the pack's own art** (that is where
  `frontArt` / `iconArtHD` / `iconArt16` were added); install it as a FULL
  update — replacing `main.lua` alone over an older folder leaves
  `data/icon_data.lua` behind and every export answers `nil`.

---

## Scope / not done yet

* **Gen 1 only.** The manifest declares `games: ["gen1"]` and `main.lua` also
  checks `GameVersion.generation(GameVersion.get())` at boot.
* The **START menu tree** is modernised: START, POKéMON, the summary, the bag
  (ITEM), the Pokédex and its species entry pages, OPTION and its group pages,
  the trainer card and the mod manager — plus the SAVE/QUIT modals, the boot
  title menu with its CONTINUE window, and the LOAD REPORT. Still drawn by the
  engine: the battle HUD, the text boxes, and the lists that are not opened
  from the START menu (shops, the PC, the Pokédex CONTENTS menu).
* A classic non-opaque overlay (a TextBox) draws high on the tall page — see
  *Known limit*.
