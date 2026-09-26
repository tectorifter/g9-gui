# g9-gui — "modern UI & stats"

A full-screen modern menu suite for the gen1recomp engine. It replaces the
START screen, the POKéMON screen, the
POKéMON summary **and every page the START menu opens** (bag, Pokédex, Options,
trainer card, mod manager) with one design drawn on a **540×360** UI surface,
plus the START screen's SAVE/QUIT prompts, the boot **title menu** and the
**LOAD REPORT**. It also **re-skins three things this mod does not own** while
they are on screen — g9-battle-engine's party-submenu **TRAIN** editor,
g9-battle-sample's OPTIONS **BLACKLIST** window and the engine's own **dialogue
windows** (`src.render.TextBox`, the box every conversation, sign and battle
message prints through) — without touching any of them.

Ships as a mod folder (`manifest.json` + `main.lua` + `ui/*.lua` +
`assets/fonts/*.ttf`), id `g9-gui`, `games: ["gen1", "gen2"]`.

**Gen 2 (Gold/Silver/Crystal) support is complete** — see
[`GEN2-PORT.md`](GEN2-PORT.md) for the phase plan, the screen-id mapping and
the per-phase status. Since **2.5.0** the manifest loads on both games and the
shared modules are generation-aware; since **2.5.1** the **START**, **POKéMON**
and **summary** screens are Gen 2 takeovers; since **2.5.2** the **PACK** (bag)
and the **POKéDEX** — its listing and its species entry pages — are too; since
**2.5.3** the **OPTION** screen (and its group sub-pages), the **trainer card**
(card + Johto/Kanto badge boards) and the **MOD MANAGER** are as well; since
**2.5.4** the boot **MAIN MENU** is too, so every screen the START menu opens is
a Gen 2 takeover and the boot menu matches; and since **2.5.5** the three
re-skinned screens this mod does not own — the TRAIN editor, the BLACKLIST
window and the engine's own dialogue windows — are re-skinned on Gold too, so
the whole suite runs on both generations; and since **2.5.6** the POKéDEX's
national_dex additions are drawn on Gold as well — the entry screen's
alternate-form browsing (the form named in the header and the `↑↓ FORM` hint),
the action bar extended to the peer's own six slots (PAGE / AREA / CRY / PRNT /
STAT / LVL) as a sliding window, and the peer's STAT and LVL views painted on
the suite's own page from the data it publishes through its exports, mirroring
the Gen 1 arm; and since **2.5.7** the port is closed by its verification
sweep — every page of the suite on both generations is rendered through the
studio's Lua harness with no draw error, no off-page geometry and no
overlapping text, the physical blit each page answers is computed at the
recorded 1022×727 window and at 1080p and 720p, and a representative page from
every Gen 2 takeover was checked by eye against its intended design; and since
**2.5.8** a Gen 2 START crash is fixed — the portrait handover from
g9-battle-sprites is unwrapped **by shape** rather than by Lua type, because
LÖVE returns a Quad as **userdata** (a table-only unwrap left the sprites mod's
per-cell wrapper table where `love.graphics.draw` expected a Quad, and the Gen 2
portrait path always resolves through that icon export). Since **2.5.9** four
more Gen 2 defects are repaired: the START ↔ POKéMON LEFT/RIGHT paging now posts
through the engine's own POKéMON row path (so the START menu stays beneath the
page) and returns through the engine's own `storeCursor`/`onCancel`, with a hint
on each footer; the POKéDEX entry's species picture draws a true-colour frame
raw instead of reduced to the GBC four shades; party portraits clip through a
page→window transform-aware scissor (see *Party portraits*); and the rail,
header, list text and captions expand the cart's own print-time glyph macros, so
the Gen 2 rail reads `POKéGEAR` rather than the raw `<PO><KE>GEAR`. Since
**2.6.0** the START menu owns its own transitions on Gold: the mod answers both
of `Game2`'s start-menu entry points with the engine's own push/pop and no fade,
because the cart's `Gen2MenuFade` composited the engine's own START screen under
a white sheet while paging to the POKéMON page — so the swap is now an instant,
same-layout cut. Since
**2.6.1** Gold's Adv.Stats panel shows the **same four pages** the Gen 1 panel
does: its trainer-data page gives way to the **EVS and IVS** spreads (read from
the engine mod's modern `evs`/`ivs`, or from Gold's own stat experience / DVs
without it, each against its own real cap and totalled like Gen 1's), and the
g9-battle-sprites pack's **animated battle sprite** is drawn in the window's
top-left corner of every page — the slot, size and art Gen 1's summary wears —
through that mod's new `drawSummaryFrame` export. Since
**2.6.2** the Gen 1 rail and portrait rules hold on Gold too: the START menu's
rail omits the **POKéMON** row there exactly as it does on Gen 1 (the party is
already the right column of both screens and LEFT/RIGHT pages between them),
matched by the row's engine id and with the cursor mapped both ways through
Gold's own module-level `StartMenu.lastIndex` memory — re-mapped across the
removed row when the menu is built and written back in full-row units after
every update, so reopening the menu or returning from the POKéMON page still
lands the cursor on the row the player left it on — and Gen 2 party portraits
show the g9-battle-sprites pack's **front battle art** exactly as Gen 1's do:
`ui/portraits.lua` no longer forces the icon presentation on a Gold boot, so
`sprites` mode asks the pack's `frontArt` first and Gold's own party icon is now
only the engine fallback for a species the pack has no sheet for. Since
**2.6.3** that crop is right for **big** sprites: the card's head space is
anchored to the pack's own **frame-1 content box** — g9-battle-sprites 3.1.2's
`frontArt` bakes frame 1 alone, trimmed to that frame, and answers that box as
a fourth value — and a frame whose head would overflow the card is **stepped
down by an integer divisor** until the head fills it (never a zoom), so
Dragonite's Mega, Eternatus and the other big sheets read as themselves instead
of coming out blank or mis-placed; before that the card cropped the pack's
whole-animation union box at 1:1, so a frame with dozens of spare rows above
it landed on blank pixels. Since
**2.6.4** no Gen 2 takeover leaks the native screen underneath it, and Gold's
own GIVE/TAKE item flow and YES/NO input boxes wear this suite's cards: every
page the suite takes over now answers a **no-op `:draw`** as well as its
widescreen draw, because `Game2:drawScene` blits the taken-over page's own
classic `:draw()` as the visible base whenever a non-wide state sits above it,
so a message card pushed over the POKéMON page used to paint the cart's native
roster under it — the held-item screen and the other taken-over pages can no
longer draw themselves; the engine's `Gen2HeldItemMenu` (the cart's GIVE/TAKE
flow the POKéMON page opens on an ITEM press) is taken over by new
`ui/held_item.lua`, drawn as the POKéMON page under a modal wash with the
suite's own GIVE/TAKE, message and YES/NO popups while the engine object and all
of its behaviour are kept; and the engine's `src.ui.ChoiceBox` is dressed by new `ui/choice.lua` on
**both** generations since 2.6.7, so the YES/NO boxes the give/take and other
flows push read as this suite's card in the same window space the dialogue card
uses. Since
**2.6.5** the BLACKLIST re-skin follows g9-battle-sample 1.1.0's window: the
generation grid is joined by the sample's own **`MEGA` / `GIGA`** row (grid row
4, each cell flipping that whole form group at once and carrying the group's
complete check) with the `RESET ALL` bar pushed below it (row 5) and the legend
moved under that, so a Mega or Gigantamax form can be delisted on both
generations and by the whole group at once — the sample seeds both groups
delisted by default. Since
**2.6.6** the MOD MANAGER's EXPORT LOG row files the same log in the same place
on both generations: that one write pins `CacheFs`' version prefix to the save
root (the boot leaves it at `red/` or `gold/`, which filed the same export under
a different subtree per generation, so on a Gold boot the file was not where the
notice or the Gen 1 export put it) and falls back to the engine's
version-agnostic `mod.cache` store when that seam is unavailable, so the log
lands at the save folder's root rather than inside the version's cache tree.
Since **2.6.7** the window-space density and the modern prompts reach Gold, and
the Gold SAVE flow is modernised: the dialogue card and the YES/NO skin paint
at **native window resolution on Gen 2 as well** (reading Gold's own `render.hud`
viewport payload — the transform `Game2:drawScene` uses to blit the classic UI
canvas — instead of composing into the 160×144 canvas and letting Gold blit that
upscaled); `ui/choice.lua` is **generation-agnostic**, so YES/NO and labelled
two-option boxes are modernised on **both** generations with the engine's own
`setUIAnchor` kept for a Gen 1 DYNAMIC layout and LEFT/RIGHT toggling the rows
alongside UP/DOWN; the START screen's SAVE row and the MAIN MENU's CONTINUE
window open this suite's own save-data card / confirmation / notices on Gold
(`ui/dialogs.lua` is now generation- and shape-aware), and the save confirmation
and Gold's QUIT confirm answer **LEFT → YES, RIGHT → NO** as well as up/down; and
the blank portrait cards for **tiny species** (TOTODILE and its kin) are fixed
by **g9-battle-sprites 3.2.6**, which repairs that pack's `frontArt` portrait
bake (it passed 16 arguments to a 15-parameter function, so the `portrait` flag
was `nil` and the bake was the whole-animation union box — right for big sheets,
wrong for a species whose frame 1 is small).
Since **3.0.3** the POKéDEX listing is the **whole roster in number order** —
every entry the game defines, 001 upward to the last one, whatever that number
is. The engine's highest-seen frontier and national_dex's SELECT view modes are
both ignored, so the order can never be overridden (see *The POKéDEX's number
order*).
Since **3.0.4** every Pokemon is shown under its **real species name**: an alternate form's id (`PONYTA_GALAR`) is a system identifier, so `ui/display_names.lua` patches each form record's `name` back to its base species' name at load, and the POKéDEX, party, summary, PC, battle HUD and the engine's own screens print **PONYTA** (the form is still shown as a descriptor). Only **mega forms** (`Mega Charizard X`), **Zygarde** (`Zygarde 10%`, `Zygarde Complete`) and **White/Black Kyurem** keep a name of their own; regional words (Galarian, Alolan, Hisuian, Paldean, ...) are descriptors, never namings. See *Species display names* in `ui/display_names.lua`.
Since **3.1.0** the **move learner** is a page of the suite as well: `ui/move_learn.lua` takes the engine's own `src.ui.MoveLearnMenu` (the four-move forget screen a level-up opens) over on both generations and paints the suite's opaque 540×360 page, keeping the engine's whole state machine and its own messages (which the suite's dialogue/YES-NO skins draw as its cards). Because this screen is routinely opened **mid-battle** — by the native battle queue, the bag's TM use, the evolution's learn run and g9-Battle-Scene's in-battle pause — it draws a full page rather than a floating card, so nothing shows the battle underneath it. The mod publishes `mod.exports.moveLearnScreenId` for the peer mod that pushes it (see *The move learner*); since **3.1.3** the engine's own closing narration rides that page too, because `ui/move_learn.lua` wraps the engine's `:finish` — which otherwise pops the page *before* it pushes "1, 2 and... Poof!". Since **3.2.0** Gold's *out-of-battle* learns — a TM used from the PACK, a RARE CANDY's level moves, an evolution's new move and the tutor's — reach that page as well: Gold opens no learner screen for them (they all run `Game2:learnMoveOn`, which draws the classic cart boxes), so `ui/gold_learner.lua` wraps that one entry point and pushes the suite's page for the four-slots-full case (see *Gold's out-of-battle learn*).
Gold has no
`:uiSize()`, so a Gen 2 arm answers `:drawsWidescreen()` and paints the whole
window in `:drawWidescreen()`, scaling the very same 540×360 page; the POKéMON
page builds Gold's own `src.ui.gen2.PartyMenu`, the summary builds
`src.ui.gen2.SummaryMenu`, the pack builds `src.ui.gen2.PackMenu`, the
Pokédex builds `src.ui.gen2.PokedexMenu`, OPTION builds
`src.ui.gen2.OptionsMenu` (and dresses its class, so the engine's own
`setmetatable`-built group pages inherit the page too), the card builds
`src.ui.gen2.TrainerCard` and the boot menu builds `src.ui.gen2.MainMenu`, so
the engine's navigation keeps
running while only the drawing changes. The MOD MANAGER is the engine's
generation-agnostic `ManagerState` on both games, so only its surface is
swapped, and Gold's `Gen2TitleState` cinematic is left to the engine — its
A/START only pushes `Gen2MainMenu`, which is the screen taken over. A screen
with no Gen 2 arm yet is simply
not installed on Gold, so the engine's native screen stays in place — a Gold
boot is never left half-drawn.

---

## What the player sees

| Engine screen | Replaced by | Look |
| --- | --- | --- |
| `StartMenu` | `ui/start_menu.lua` | The vanilla word list in a left rail, the live party roster filling the right column |
| `PartyMenu` | `ui/party_menu.lua` | **The same page** — same header, same rail, same roster — with the engine's own submenu as a modern popup. Gen 2: builds Gold's `Gen2PartyMenu` and draws the same page over Gold's save/mon shape |
| `SummaryMenu` | `ui/summary.lua` | Adv.Stats in a 486×324 panel (90% of 540×360) floated **over** the POKéMON screen. Gen 2: builds Gold's `Gen2SummaryMenu` and floats the same panel, its four pages (STATS / EVS / IVS / MOVES) plus the move manager and the egg page |
| `BagMenu` | `ui/bag.lua` | ITEM: the same page, one full-width list with `×N` counts (left classic while a battle owns the surface). Gen 2: builds Gold's `Gen2PackMenu` and draws the same page — the four-pocket tab strip, the item list with `×N` counts and CANCEL, and the engine's message / toss-quantity / YES-NO / submenu as modern popups |
| `ShopMenu` (Gen 1) / `Gen2MartMenu` (Gen 2) | `ui/shop.lua` | The POKéMART as the same page: the header, a `BUY` / `SELL` / `QUIT` rail beside the clerk's own line in a speech card, then the buy list (each row's price + the selected item's description) and the sell list — **the sell list IS this suite's bag page** (`ui/bag.lua`'s `drawPage`), so it matches the modern PACK Gold's sell flow already opened. Gen 2: builds Gold's `Gen2MartMenu` and draws each phase (top rail, buy list, sell list through the modern PACK, the quantity stepper and the engine's message / YES-NO as cards) |
| `PokedexMenu` | `ui/pokedex.lua` | POKéDEX: `num name`, an owned-ball marker, unseen entries dimmed, `SEEN n OWN n` in the header — and the **whole roster in number order**, 001 up to the last entry the game defines, with no sort overrides (the engine's highest-seen frontier and national_dex's SELECT modes are both ignored; see *The POKéDEX's number order*). **A opens a species' entry page directly** — one confirm, no DATA/CRY/AREA side menu. Gen 2: builds Gold's `Gen2PokedexMenu` (one screen holding both the listing and the entry), pins it to the number order (Gold's NEW / A-Z modes and its OPTION screen are masked out) and draws the listing plus the species entry page — portrait, kind, HT/WT gated on caught, the wrapped description and the PAGE/AREA/CRY/PRNT bar |
| `DexEntryMenu` | `ui/dex_entry.lua` | A species page: portrait panel, `HEIGHT`/`WEIGHT` figures, the re-wrapped description (paged). With national_dex installed it also gains that mod's own pages: a STATS page and the evolution/learnset strip (see *National Dex compatibility*) |
| `OptionsMenu` | `ui/options.lua` | OPTION and its group sub-pages: label + value rows, a synthetic `BACK` row. Gen 2: dresses Gold's `Gen2OptionsMenu` **class** (not just the instance) so the engine's own `setmetatable` group pages inherit the page, then draws the same header/rows/footer off the port's `frame` / `values`+`display` / `value(game)` row vocabulary |
| `TrainerCard` | `ui/trainer_card.lua` | The player card: portrait panel, NAME/MONEY/TIME figures and eight badge slots drawn from the game's own badge tiles. Gen 2: builds Gold's `Gen2TrainerCard` and draws its three pages — the card (portrait through the engine's nested translate/scale so the sheet's per-cell colours stay with their tiles, plus the Johto badge row) and the Johto / Kanto eight-slot badge boards, labelled from the engine's `JOHTO_BADGES` / `KANTO_BADGES` exports |
| `ManagerState` | `ui/manager.lua` | MODS: a MODS/PROFILES/ERRORS tab strip over the manager's own rows, plus its options and confirm/notice overlay. Gen 2: the engine's `ManagerState` is generation-agnostic, so the same instance is simply dressed for the Gold surface — same rows, same EXPORT LOG |
| `TitleState` | `ui/title.lua` | The boot title screen keeps its logo/cinematic; its own `CONTINUE / NEW GAME / OPTION / EXIT GAME` menu and the `CONTINUE` save-data window become this mod's rail + SAVE DATA emblem. Gen 2: Gold splits the two — `Gen2TitleState` keeps its engine cinematic and `Gen2MainMenu` is the takeover, drawn as the same rail + emblem page with its confirm phase as the same SAVE card |
| `QuarantineReport` | `ui/load_report.lua` | LOAD REPORT: the one-shot validation digest, as a sectioned scrollable page |
| `MoveLearnMenu` (both generations — no Gen2 prefix; Gold's own in-battle learning lives inside `Gen2BattleState`, so on Gold the id is reached by g9-Battle-Scene's learn pause, and — since 3.2.0 — by `ui/gold_learner.lua`'s wrap of `Game2:learnMoveOn` for the out-of-battle flows) | `ui/move_learn.lua` | The four-move forget screen a level-up opens ("X is trying to learn Y! ... Delete an older move to make room?") as the same page: the learner and the move being learned in the header, the four moves in the suite's list with the selection chevron, the engine's forgotten-move prompt and the `A FORGET` / `B GIVE UP` hints. Deliberately an **opaque full page** (this screen is opened mid-battle by the native queue, the bag's TM use, the evolution's learn run and the battle scene's pause, so a classic 160px menu would leave the battle, its HUD and the Pokemon behind the question); the engine keeps the TryingToLearn YES/NO, the HM refusal, the Abandon-learning confirm and every write, and its messages stay the suite's own dialogue/YES-NO cards |
| `EvolutionState` (Gen 1) / `Gen2EvolutionAnim` (Gen 2) | `ui/evolution.lua` | The evolution movie as the same page: the **g9-battle-sprites pack's front battle sheet** (through `ui/portraits.lua`'s `drawFront`, real size, never zoomed) on a lit stage — or the engine's own front pic for a species the pack has no sheet for — with the level and the current form's name under it (gold once the new form settles, red after a `B`-press stop) and a twelve-segment progress rule. The header prints the engine's own line (`What? X is evolving!` / `stopped evolving!` / `Congratulations!` / `evolved into X!`) with an `EVOLVING` / `COMPLETE` / `STOPPED` status, and the footer offers `B CANCEL` while the engine still allows a stop and `A OK` once it has settled |

Three more things are **re-skinned in place** — the screens belong to other mods
(or, in the last case, the engine) and are left completely whole; g9-gui only
dresses the instance while it is on the stack (see *Re-skinning screens this mod
does not own*):

| Screen (owner) | Re-skinned by | Look |
| --- | --- | --- |
| `G9Train` (g9-battle-engine, the party-submenu TRAIN editor) | `ui/train.lua` | The IV/EV/NAT/gender/ability/moves editor on the shared page: a tab strip, the nudge row, the six-row STAT/IV/EV/CUR table, an ability panel and a COST/APPLY bar |
| `G9Blacklist` (g9-battle-sample, the OPTIONS BLACKLIST window) | `ui/blacklist.lua` | The 9-row name list with a gold `HELD` tag, the 3×3 generation grid, a `MEGA` / `GIGA` row, a RESET ALL bar below it and a short legend |
| every `TextBox` (`isTextBox`; the engine's own dialogue window) | `ui/textbox.lua` | The classic white window becomes the suite's dark card — **the suite's own Saira for the body** on every engine, an accent cap, corner brackets and a pulsing down-cursor — in the same 160×144 footprint, drawn natively in window space through `render.hud` at the engine's own origin (letterbox when centred, the docked origin under DYNAMIC) (see below). Native window space on **both** generations since 2.6.7 (Gold through its own `render.hud` viewport payload) |
| `Gen2HeldItemMenu` (the engine's own GIVE/TAKE item flow, opened from the POKéMON page's ITEM row) | `ui/held_item.lua` | Gen 2 only: the POKéMON page under a modal wash with the suite's own GIVE/TAKE list, message and YES/NO popups, in place of the cart's classic party list + item window. The engine object is kept whole (every give/take, swap and held-item write still runs through it) |
| every `ChoiceBox` (`src.ui.ChoiceBox`; the engine's YES/NO box) | `ui/choice.lua` | The suite's two-choice (and labelled two-option) card in the same window space the dialogue card uses, dressing the class while it sits over a conversation (or the item flow) this suite already dressed. On **both** generations since 2.6.7 (Gen 1 included), with the engine's own `setUIAnchor` kept for a DYNAMIC layout and LEFT/RIGHT toggling the rows. Draw-only; the engine keeps the cursor and the answer |
| every `QuantityBox` (`src.ui.QuantityBox`; the engine's "how many?" stepper) | `ui/quantity.lua` | The suite's stepper card (the shared `Shell.card`): a `HOW MANY?` title, the engine's own count and (in a mart) price, the stacked up/down arrows and the `CHANGE` hint — drawn in the **page's own space** over one of this suite's pages (the engine's classic overlay origin undone). On a classic 160×144 surface it leaves the engine's own box alone. Draw-only; the engine keeps the count and the buttons |
| `LeaguePC` (the engine's own HALL OF FAME viewer) | `ui/pc.lua` | Gen 1 only: a bespoke classic screen with no `Menu`/`ListMenu`, recognised by its stamped `screenId` and drawn as the mon RECORD page — the front art at REAL 1:1 size, `Lv` and name, and a NAME / LEVEL / TYPE 1 / TYPE 2 card beside the header's `No N`. The engine keeps its own A/B flow and cry |

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

Since **3.3.4** both of this page pair's lists **cap and wrap instead of running
under the footer**. The START menu's rail gains rows as the save unlocks them
(the MODS row, the optional `ui_pc_row` PC row) and as mods hook
`ui.start_menu.items` in, so a rail long enough to reach the footer's hint row
(a report named QUIT sitting on SELECT/OK) is normal; the engine's own answer is
to **scroll** the window, which needs a cursor, and the POKéMON page shows that
same rail as a **static mirror** with no cursor at all. `Shell.rows` therefore
takes an `opts.columns` mode: at most **eight** rows a column — 8×30+4 = 244px
ends exactly on the footer rule — each further column its own panel beside the
last, its rows starting at the TOP of the band. The columns on screen are the
ones the **cursor** has reached, so pressing DOWN off the eighth row grows the
rail by a column and lands on the next row, and a right-pointing accent marker
sits at the last drawn column while later ones are still hidden; the engine's
own menu wrap then takes the cursor from the last row back to the first. On the
START screen the party preview is still behind the rail and the panel is
translucent, so a wrapped **cluster** dims what is behind it first (`C.black`
over the columns' footprint) — a single column is byte-for-byte the old look.
The POKéMON page's mirror passes `cols = 1`: it has no cursor of its own and
sits 8px from the roster, so a second column there would land on the first
member's portrait and read as a rendering bug — it shows the section's own
column, with the rows past the eighth one DOWN away on the START screen. The
action popup wraps the same way at **seven** rows a column (7×34+16 = 254px,
the number the report named): the cursor crossing the seventh row grows the
popup by a column — a shared panel with a 1px rule between them — and shows the
rest of the list at the top of it, and the engine's own `subIndex` wrap closes
the loop (last option → the real first row). Both arms (Gen 1 and Gold) use it.
Since **3.3.5** that popup's frame is clamped so its **drop shadow** (3px below
the fill) stops on the footer's RULE rather than the hint row: the frame used to
end at `H-40` (320), which is where the hints' key chips and their text ink sit,
so a tall popup's bottom border and shadow ran through them. There is also no
right-edge accent marker any more — on either the rail or the popup — so a
wrapped list is read purely from the columns themselves.

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
fainted mon's row is washed dark. An **egg is never drawn as fainted**: it is
carried at 0 HP so no battle path can send it out (g9-battle-engine's
`stats/egg_normalize.lua` pins it), but that zero is a battle-team rule, not a
status — `ui/roster.lua`'s `R.status` answers nil for any record marked
`isEgg`, so the party roster and the summary's `STATUS` row both show an egg
plain while a genuinely fainted mon keeps its chip and wash. There is no
column-heading row: at the 22px
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

The panel asks g9-battle-sprites for the live animation frame itself, through
that mod's `drawSummaryFrame(mon, box)` export, because it paints its own page
and so is reached by neither of that mod's summary hooks. An **egg** gets the
same request and that mod answers it with its one egg picture (its own EGGS
section), so an egg wears the same art on the summary page as it does in the
party roster — never a species frame. With a copy of the sprites mod older than
3.1.1 (no such export) the corner stays clear and one log line says so.

### Options (`options.lua`, mirrored in `manifest.options_schema`)

| key | default | effect |
| --- | --- | --- |
| `modern_ui` | ON | Master switch. OFF installs nothing at all — every screen is left exactly as the engine drew it |
| `ui_background` | ON | ON: the layered backdrop (gradient, glows, vignette, weave). OFF: a flat dark field |
| `ui_embellishment` | ON | ON: corner brackets, rules, header emblem, pulsing chevrons. OFF: the same layout, undecorated |
| `ui_portraits` | `sprites` | `sprites`: the **head space** of the pack's **front battle sheet** (`assets/front/<STEM>.png`), anchored to frame 1's own content box and shown at the pack's own **1:1** pixels — a creature bigger than the card is **cropped to the card's band** (its head fills it, sides cropped as needed), never scaled down (never zoomed). `icons`: the pack's **party-icon art at its real size** — the **64×64 HD cells** (`assets/icons/party_icons_hd.png`, the pack's own frames) at their own 1:1 pixels, cropped to the card the same way (an older copy of that mod with no HD cell gets the **16×16 atlas**, fitted, which is the small-scale art that read as shrunken) |
| `ui_pc_row` | OFF | ON: one extra row, **PC**, joins the START rail right after the bag row (and the POKéMON page's mirrored rail), opening the POKéMON storage system exactly as the PC in a POKéMON CENTER does. OFF (default): neither rail changes. See *The PC row* below |
| `color_protection` | ON | ON (default): keeps gen1recomp's OPTIONS > GRAPHICS > COLORS display mode off every **modern** screen on **both** generations — this suite's own pages **and** the modern screens sibling g9 mods draw (g9-evolutions' trade / inspector / trade-anim pages, g9-Battle-Scene's battle scene), which opt in with the shared `__g9modern` flag. The modern pages are true colour (Saira type and a hand-picked palette), so a mono / OG / CLASSIC ramp would otherwise repaint every panel, portrait and label. The engine's `render.zones` seam is hooked so each modern page is blitted with the palette shader switched off, while the world and every engine screen keep their native colour. OFF: the native palette applies to the modern screens exactly as it does to the rest of the game. See *Colour protection* below |
| `short_heal_chat` | ON | Controls the **g9-battle-engine** PokéMON CENTER nurse conversation (the engine mod reads it, the screens in this mod do not). ON: after the heal the nurse prints only *"We restore your tired Pokémon to full health."*, dropping the welcome / HEAL-CANCEL / "we'll need your POKéMON" / "fighting fit" / goodbye; PokéRUS is still reported first (with its flag and Elm phone call) when she spots it. OFF: the full original conversation is kept. The row is published as `mod.exports.shortHealChatEnabled` (since `mod.options:get` only sees a mod's own bucket) and is set **before** the `modern_ui` gate, so it still answers with this mod's screens off |
| `translation` | ON | Adapts the modern screens to a **game-translation mod**. Two families are recognised: the generator output (`translation-<lang>`, plus a `-gen2` / `-gen3` suffix) and the **Brazilian Portuguese** community mods `gen1_pt-br_mod` (Red/Blue/Yellow), `versaodourada` (Gold/Silver) and `versaocristal` (Crystal), which report as `pt-br`. ON (default): the suite detects the translation mod, reads its language off the id, and folds a modern-content catalog — French, German, both Spanish regions, Italian, Japanese, Korean and Brazilian Portuguese all ship — into national_dex's expanded-dex species (national dex 152+) and their moves and items (the content the translation mod itself cannot reach), rewrites the engine's HM `Strings(...)` entries it leaves English, and localizes this mod's **own** chrome (footer hints, the MONEY/BADGES/DEX/PARTY readouts, the START captions, the appended party-submenu rows) through a per-language `ui` lexicon. Gen 1/2 spellings are left to the translation mod and never overwritten. OFF: no detection, no adaptation, every modern name and every label stays English. See *Translation* below |
| `translation_spanish` | `la` | Which Spanish the adaptation uses, when the detected translation mod is Spanish: `la` (LATAM, default) = Latin American Spanish (PokeAPI `es-419`), `esp` = European Spanish (PokeAPI `es`, matching the Spanish ROM the translation mod is built from). Affects only the names this mod fills in and the UI lexicon; the translation mod's own Gen 1/2 spellings are untouched either way. Ignored for any other language |

Choice rows carry their value as a **string** (`"true"` / `"false"` /
`"sprites"` / `"icons"`); every read in the mod compares against a string and a
missing row reads as ON.

### Colour protection (`color_protection`)

gen1recomp's own OPTIONS > GRAPHICS > **COLORS** row (Gen 1) and **COLOR** row
(Gold) repaint the finished frame through a 4-shade palette
(`src/render/PaletteFX.lua` on Gen 1, `src/render/GbcPalette.lua` on Gold). This
suite's pages are **true colour** — Saira type and a hand-picked palette — so a
mono / OG / CLASSIC ramp destroys them. Every screen here already answers
`:sgbPalettes()` with an empty list, which keeps the per-zone SGB shade-remap
shader off a page, but two engine paths still reached it:

* Gen 1's `PaletteFX.ensureZones` forces **one whole-screen GRAYS zone** for the
  mono / OG / CLASSIC modes whenever the palette-owning state exposes no zones,
  and the blit then shades the whole UI canvas with it;
* Gold's CLASSIC *present* pass tints the **whole frame** whatever the state
  says, because Gold's colour lives inside the picture and its present pass has
  no per-state opt-out.

Both are decided through the one **`render.zones`** seam — raised by `Game:draw`
on Gen 1 just before the blit and by `Game2:drawViewportFrame` on Gold. So
`ui/color_protection.lua` wraps that seam: whenever the state that **owns the
palette** this frame is one of this suite's own pages, the zone list is replaced
with one whole-screen `colors = false` zone — the engine's own true-colour
opt-out, which blits that region with the shader switched off. The engine's real
zones are consulted first (`next` runs the vanilla list), so the world and every
engine screen keep their native colourization untouched.

**Who owns the palette** is the engine's own rule: Gen 1 takes the topmost
**visible** state that exposes `:sgbPalettes`; Gold takes its widescreen layer
(the stack's top when it paints one, else the visible base). A screen is "ours"
when it carries a modern marker: the suite's own (`__g9gui`, or the
`__g9guiBox` / `__g9guiChoice` / `__g9guiQty` the dressed overlays set) **or the
shared `__g9modern` flag a sibling g9 mod sets on its own modern screens** —
g9-evolutions' trade / inspector / trade-anim pages and g9-Battle-Scene's battle
scene — so the one toggle protects every modern UI, not only this suite's. The
flag is read only here, so a sibling needs no dependency on g9-gui and a boot
without g9-gui simply ignores it. The non-opaque
overlays — the dialogue card, YES/NO and the "How many?" box — are drawn in
**window space** by the `render.hud` hook *after* the palette pass, so they
already reach the screen unshaded and need no entry here; the map a dialogue
sits over therefore keeps its colour. The row is read live, so flipping it in
the Mod Manager takes effect on the next frame. On Gold the wrapper stands down
entirely when no tint is present — that engine computes a zone list for the
CLASSIC mode alone, so in GEN 2 / DMG the modern page is left untouched rather
than forced down its present-canvas path for nothing. With the row **OFF** (or
with the hook API missing) the wrapper returns the engine's own list, exactly as
if the file were not installed.

---

## File map

```
LICENSE             GNU GPLv3 (the mod's licence, copyright tectorifter)
manifest.json       id/name/version, games=["gen1","gen2"], priority 100,
                    optional_dependencies=[g9-battle-engine, g9-battle-sprites,
                    national_dex, every translation-* id and the three Brazilian
                    mods (ordering edge for ui/translation.lua)], options_schema
main.lua            entry chunk: helpers esc()/loadSibling()/attempt()
                    (per-piece failure isolation), option reads, the generation
                    gate (which id set a boot installs), sibling loading,
                    screen registration
GEN2-PORT.md        the Gen 2 port plan: engine differences, the screen-id
                    mapping, the phase list and the per-screen adapter notes.
                    Read this before touching a Gen 2 arm
options.lua         the Mod Manager option schema (shared with the manifest)
ui/translation.lua  the translation layer: detects a translation-<lang> mod,
                    folds its catalog into the pokemon/moves/items content
                    registries and the field-move `strings` before the freeze
                    (ability names resolve at draw time), localizes this mod's
                    own chrome through the catalog's `ui` lexicon and the
                    engine's own `strings` catalog (M.engineString, so a label
                    the ROM also carries translates with its official wording),
                    resolves the suite's own battle/field sentences through
                    `messages` / `messageTemplates` (M.line, its compiled
                    templates sorted most-specific-first so a short template
                    cannot swallow a longer match), and publishes
                    mod.exports.translation for peer g9 UI mods
data/lang/de.lua    generated catalogs, one per shipped language: species by
data/lang/es-419.lua  national dex; moves/items/abilities by folded English
data/lang/es.lua    name; the UI `ui` lexicon; and the battle/field `messages`
data/lang/fr.lua    / `messageTemplates` (es-419 = Latin America, es = Spain).
data/lang/it.lua    data/lang/pt-br.lua is the one HAND-AUTHORED catalog (the
data/lang/ja-hrkt.lua  Brazilian mods): PokeAPI has no pt-BR names, so its
data/lang/ko.lua    species/moves/items come from Pokemon GO's official pt-BR
data/lang/pt-br.lua  text dump plus the suite's own Brazilian wording
assets/fonts/g9-symbols.ttf  the character supplement attached to every baked
                    face as a Font:setFallbacks fallback: U+2640/U+2642/U+2605,
                    kana and Hangul (from Noto Sans JP/KR/Symbols 2); also
                    shipped, with the same wiring, by g9-Battle-Scene and
                    g9-evolutions
ui/theme.lua        palette, Saira font factory (mod TTF -> FileData, Plain
                    Pixel fallback), METRIC/ink-offset metrics, Theme.fit,
                    drawing primitives (panel, bar, chevrons, brackets, hints,
                    hpFrac), and Theme.scrub -- the UTF-8 guard every text
                    entry point (w/text/fit/wrap) runs before it measures or
                    draws
ui/shell.lua        THE PAGE: its 540x360 size, header (title + readout +
                    MONEY), footer hints, the shared left rail of START-menu
                    rows, and Shell.list -- the generic modern list panel every
                    list page (bag, POKeDEX, OPTION, MODS) draws through.
                    Also the Gen 2 surface: Shell.gen2Fit / Shell.gen2Page /
                    Shell.gen2Surface paint the page into Game2's window
                    (drawsWidescreen + wantsFillScale + a scoped translate/
                    scale), and Shell.money reads save.player.money on Gold.
ui/backdrop.lua     the layered background
ui/portraits.lua    portrait art: the pack's front-sheet head crop (anchored
                    to frame 1's content box, at the pack's own 1:1 pixels --
                    a creature bigger than the card is cropped to the card's
                    band, never stepped down, since 3.8.0),
                    or its 16x16 icon atlas, or the engine's own art (the
                    pack's front art is asked for first on BOTH generations
                    since 2.6.2; Gold's own party icon is only the fallback for
                    a species the pack has no sheet for)
ui/roster.lua       the shared party table (used by START and POKéMON). Gen
                    aware: max HP reads mon.maxHp (Gold) or mon.stats.hp (Gen
                    1), the EXP curve reads src.battle.gen2.Mon on Gold, and
                    the status chip maps Gold's lowercase effect ids through
                    data.gen2Statuses
ui/start_menu.lua   StartMenu view takeover (+ the LEFT/RIGHT party paging, on
                    both generations since 2.5.9).  Gen 2 arm: builds Gold's
                    src.ui.gen2.StartMenu and swaps only :drawWidescreen; the
                    engine's rows (incl. POKeGEAR, minus the POKeMON row since
                    2.6.2), unlocks, cursor memory (mapped both ways around that
                    hidden row), ui.start_menu.items hook and QUIT confirm all
                    keep running, and this module draws the confirm as its own
                    modal
ui/party_menu.lua   PartyMenu view takeover (+ the Gen 2 arm: builds Gold's
                    src.ui.gen2.PartyMenu and draws the whole page in
                    :drawWidescreen, reading Gold's maxHp / status / experience
                    and its own submenu state; since 2.5.9 LEFT/RIGHT returns to
                    the START menu when the page was opened from it)
ui/summary.lua      SummaryMenu replacement, 90% panel, 4 pages (+ the Gen 2
                    arm: builds Gold's src.ui.gen2.SummaryMenu and floats the
                    same panel -- the same four pages (EVS / IVS replacing
                    Gold's trainer-data page), the move manager and the egg
                    page -- over the re-drawn, dimmed party page, with the
                    sprites mod's animated frame asked for the window's
                    top-left corner of every page)
ui/bag.lua          BagMenu view takeover (ITEM).  On Gen 1 the bag is drawn
                    as the six auto-sorted pockets ui/bag_util.lua projects
                    (tab strip, L/R cycling, the TAB/R3 sort card); a battle
                    bag keeps the engine's flat classic rows.  Gen 2 arm:
                    builds Gold's src.ui.gen2.PackMenu and draws the whole page
                    in :drawWidescreen -- the four-pocket tab strip, the item
                    list with xN counts and CANCEL, the pocket
                    name/description and the money readout -- with the
                    engine's message, toss-qty, YES/NO and submenu drawn as
                    this suite's popups
ui/bag_util.lua     the bag's capacity, its guards and its Gen 1 pockets,
                    adapted from the "Useful Bag" mod (see *The bag* below):
                    300 distinct slots and x999 per item (constants.bagSize /
                    constants.itemStackCap / field.pcItemCap plus a Bag.add
                    shim that repairs an engine build's hard-coded 99 and
                    refuses anything past the ceiling), the six-pocket
                    classification / projection / sort / pocket-safe SELECT
                    swap, and the TAB / R3 / touch-SELECT sort edge.  Stands
                    down entirely when Useful Bag is installed
ui/shop.lua         ShopMenu (Gen 1) / Gen2MartMenu (Gen 2) view takeover:
                    the mart as the same page -- the BUY/SELL/QUIT rail beside
                    the clerk's line, the buy list, and (Gen 1) the sell list
                    drawn as this suite's bag page through ui/bag.lua's
                    drawPage.  Gen 2 arm: builds Gold's src.ui.gen2.MartMenu and
                    draws each phase in :drawWidescreen, its message / quantity
                    stepper / YES-NO as this suite's cards
ui/pokedex.lua      PokedexMenu view takeover (POKéDEX); the listing is the
                    whole roster in number order, 001 to the last entry, with
                    SELECT masked so no view mode can reorder it (see *The
                    POKéDEX's number order*); A pushes the entry page directly
                    (one confirm — see *One-confirm A*).
                    Gen 2 arm: builds Gold's src.ui.gen2.PokedexMenu, pins it
                    to the OLD (number) order and draws its listing and species
                    entry pages in :drawWidescreen
                    (portrait, kind, HT/WT gated on caught, the wrapped
                    description and the PAGE/AREA/CRY/PRNT bar); with
                    national_dex installed the entry gains its Gen 2 additions
                    too -- the browsed form named in the header, the UP/DOWN
                    FORM hint, the six-slot extended action bar and its STAT /
                    LVL views (see *National Dex compatibility*); AREA/SEARCH/
                    UNOWN keep the engine's own widescreen drawing
ui/dex_entry.lua    DexEntryMenu view takeover (a species' dex entry page,
                    and -- with national_dex installed -- its STATS page and
                    the evolution/learnset strip pages behind it)
ui/national_dex.lua the national_dex compatibility layer: finds the peer
                    through mod.find, reads its public exports
                    (statsBySpecies / evolutionsOf) and turns a species record
                    into the stat, ability, evolution and move rows the pages
                    draw (see *National Dex compatibility*). Pure data, draws
                    nothing. ROUND 315 removed its listing-mode helpers: the
                    POKéDEX no longer follows the peer's view modes
ui/options.lua      OptionsMenu view takeover (OPTION and its group pages).
                    Gen 2: dresses Gold's Gen2OptionsMenu class and draws the
                    same page; the class dressing is what gives the engine's
                    own setmetatable group pages the widescreen draw
ui/trainer_card.lua TrainerCard view takeover (the player-name row: portrait,
                    figures, and the badge row drawn from the engine's own
                    trainer_card/badges.png tiles -- earned ones in colour
                    behind a gold ring, unearned ones ghosted). Gen 2: builds
                    Gold's Gen2TrainerCard; the card + its Johto/Kanto badge
                    boards, the portrait through the engine's nested
                    translate/scale and the badges from its own OAM frames
ui/manager.lua      ManagerState view takeover (MODS); its ERRORS tab and a
                    mod's own errors page carry an EXPORT LOG row that writes
                    the whole error log to a .txt (see *Error log export*).
                    Gen 2: the engine's ManagerState is generation-agnostic,
                    so only the surface is swapped
ui/dialogs.lua      the shared modals: the save-data card (also the title's
                    CONTINUE window), the YES/NO confirmation and the
                    auto-advancing notice the SAVE flow uses. Since 2.6.7 it is
                    generation- and shape-aware: on Gold it paints as a
                    widescreen page (Shell.gen2Surface) and floats over the
                    page that owns it (the START screen publishes
                    __g9guiPage), saveRows reads Gold's { hours, minutes }
                    clock / badges / caught count, and the confirm answers
                    LEFT -> YES / RIGHT -> NO (as well as up/down)
ui/title.lua        TitleState view takeover (the boot menu + CONTINUE window).
                    Gen 2: Gold's Gen2TitleState cinematic is left to the
                    engine and Gen2MainMenu is the takeover -- the same rail +
                    SAVE DATA emblem page (reading Gold's party/playTime and
                    MainMenu's hasSave) with the confirm phase as the same SAVE
                    card
ui/load_report.lua  QuarantineReport view takeover (LOAD REPORT)
ui/evolution.lua    EvolutionState (Gen 1) / Gen2EvolutionAnim (Gen 2) view
                    takeover: the evolution movie drawn as the suite's page --
                    the pack's FRONT battle sheet (ui/portraits.lua's
                    drawFront) real size on a lit stage, with the engine's own
                    front pic the fallback for a species the pack has no sheet
                    for; the level, the current form's name (gold when the new
                    form settles, red after a B-press stop) and a twelve-segment
                    progress rule under the stage; the header prints the
                    engine's own line (the ROM's _IsEvolvingText on Gen 1,
                    Gold's own per-phase `lines` on Gen 2) with an
                    EVOLVING / COMPLETE / STOPPED status, and the footer offers
                    B CANCEL while the engine still allows a stop and A OK once
                    it has settled.  The engine keeps the whole state machine --
                    the accelerating flash, the cry, the B-press cancel and the
                    post-evolution learn run
ui/move_learn.lua   MoveLearnMenu view takeover (the four-move forget screen a
                    level-up opens).  Registered under the ENGINE's id on both
                    generations (Gold's own learning lives inside
                    Gen2BattleState, so on Gold the id is only reached by
                    g9-Battle-Scene's in-battle learn pause).  The engine's
                    builtin object is built and kept whole (the TryingToLearn
                    YES/NO, the HM refusal, the Abandon-learning confirm and
                    every slot write) and only the surface and the draw move
                    onto the instance: an OPAQUE full page, so a mid-battle
                    learn never shows the battle, its HUD or the Pokemon behind
                    the question.  Its messages stay the engine's own TextBoxes,
                    which the suite's dialogue/YES-NO skins draw as its cards in
                    the page's coordinates
ui/gold_learner.lua Gold's OUT-OF-BATTLE learner router.  Gold opens no learner
                    screen: a TM from the PACK (the party screen picks the mon),
                    a RARE CANDY's level moves, an evolution's new move and the
                    tutor's all run Game2:learnMoveOn, which draws the exchange
                    as engine TextBoxes plus the native forget list -- so the
                    registered MoveLearnMenu id was never reached there.  This
                    wraps that one entry point and, for the four-slots-full
                    case, pushes the suite's page with the caller's onDone
                    threaded through; a free slot or a known move stays the
                    engine's own flow, and a build failure falls back to it.
                    Also raises pokemon.move_learned and stamps the new slot's
                    maxPp as the engine's own Gold forget arm does
ui/train.lua        G9Train re-skin (g9-battle-engine's party-submenu TRAIN
                    editor; draw-only, the engine keeps its state machine,
                    fees and ModernStats commit)
ui/blacklist.lua    G9Blacklist re-skin (g9-battle-sample's OPTIONS BLACKLIST
                    window; draw-only, the sample keeps its filters, cursor
                    and every write).  Since 2.6.5 it draws the sample's own
                    [MEGA] / [GIGA] row (grid row 4) with its per-group check,
                    the RESET ALL bar below it (row 5) and the legend under
                    that, and computes the group-complete mark from the same
                    persisted set the sample toggles
ui/textbox.lua      the dialogue-window skin: every src.render.TextBox -- the
                    box all NPC chat, signs and battle messages print through
                    -- draws as the suite's card (Saira body drawn natively by
                    this module at the window's own size, accent cap, corner
                    brackets, pulsing down-cursor).  Draw-only and in the SAME
                    160x144 footprint -- the surface for a wide backdrop or as
                    the fail-open fallback, window space via render.hud
                    otherwise, at the engine's own origin -- the letterbox
                    when the UI is centred, the docked origin under DYNAMIC:
                    the engine keeps typing, waiting for A and
                    running the money box / YES-NO.  The module re-pages the
                    text at Saira's width so the smaller body fits more per
                    line (the engine's own 18-cell pagination is only kept for
                    instant or pause-marked boxes)
ui/held_item.lua    the Gen 2 GIVE/TAKE item-flow takeover: takes over the
                    engine's src.ui.gen2.HeldItemMenu on a Gold boot and draws
                    the POKeMON page under a modal wash, with the suite's own
                    GIVE/TAKE list, message and YES/NO popups. The engine
                    object is kept whole, so every give/take, swap and
                    held-item write still runs through the cart's own code
ui/choice.lua       the YES/NO skin (both generations since 2.6.7): dresses
                    the engine's src.ui.ChoiceBox class while a conversation
                    (or the Gold held-item flow) owns the screen, so its
                    two-choice and labelled two-option boxes draw as the
                    suite's card in the same window space the dialogue card
                    uses (native density), with the engine's own setUIAnchor
                    kept for a Gen 1 DYNAMIC layout and LEFT/RIGHT toggling the
                    rows. Draw-only; the engine keeps the cursor and the answer
ui/color_protection.lua  the COLOR PROTECTION row (3.9.0): wraps the engine's
                    `render.zones` seam so that, whenever the state owning the
                    frame's palette is one of this suite's own pages, the zone
                    list is replaced with one whole-screen `colors = false`
                    zone -- the true-colour opt-out -- keeping the native
                    COLORS / COLOR ramp off every modern screen on both
                    generations (the world and every engine screen are
                    untouched). Draws nothing; OFF is a byte-for-byte no-op.
ui/pc.lua           the PC suite. Gen 1: the PlayerPC takeover (the whose-PC
                    menu, the storage / item / box pages and the CHANGE BOX
                    picker, installed through the engine's own openPC). Gen 2
                    (2.7.0): every Gold PC screen's arm -- the five bespoke
                    Gold classes (`Gen2CenterPcMenu`, `Gen2PcMenu`,
                    `Gen2ItemPcMenu`, `Gen2BoxMenu`, `Gen2MailboxMenu`) are
                    recognised by screen id and dressed on push, and each is
                    drawn as one 540x360 page: header, left rail, a bracketed
                    right-hand card (the active box and its occupants, the PC
                    store's stacks, the player's record on the whose-PC page),
                    and the engine's own messages, questions, quantity stepper
                    and YES/NO as this suite's popups. The item PC's DEPOSIT
                    phase hands the whole page to `ui/bag.lua`'s own PACK
                    painter (the engine's `drawPanel` drew the pack window
                    inside the item PC too). BoxMenu's mon submenu (a bare
                    `Menu`, recognised by its three-row pose) and the HALL OF
                    FAME viewer (`LeaguePC`, recognised by screen id, 2.8.3)
                    are drawn here too. See *The PC* below
ui/quantity.lua     the number-picker skin (2.8.3): dresses a pushed
                    src.ui.QuantityBox (the item PC's / a shop's "how many?")
                    and draws it as the shared Shell.card stepper in the page's
                    own space, with the engine's own count and price; on a
                    classic 160x144 surface it leaves the engine's own box
                    alone. Draw-only; the engine keeps the count and buttons
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
hide — the START rail since 2.6.2), and it is cached per game table.

Each of the START menu's other pages is the same shape of takeover: `ui/bag.lua`,
`ui/pokedex.lua`, `ui/options.lua` (which also patches the engine's own group
sub-page factory, so `OPTION`'s nested pages get the modern page too),
`ui/trainer_card.lua`, `ui/manager.lua` and `ui/dex_entry.lua` (the page
POKéDEX opens on a species) each wrap their engine object's `draw`/surface and
keep its `update`.

### The Gen 2 (Gold) arm

Gold is a different engine (`src/core/Game2.lua`), so a screen module branches
on `ctx.gen` (set by `main.lua`) and builds the Gen 2 object instead:
`require("src.ui.gen2.<Name>").new(game, opts)` — Gold's ctors take exactly one
`opts` table, and its registry names the ids with a `Gen2` prefix
(`Gen2StartMenu`, …). The engine object is still what drives; the module amends
**only drawing**:

```lua
Shell.gen2Surface(Theme, screen, function(self) M.drawGen2(self) end)
```

which installs `:drawsWidescreen()` (true), `:wantsFillScale()` (true) and a
`:drawWidescreen(winW, winH)` that fills the window with the suite's void,
computes the FILL scale for the 540×360 page, and draws the page under a
`translate`/`scale` — the same math the Gen 1 `uiFill` blit uses, so the page is
the same physical size on both engines. Because `Game2:drawScene` blits the
160×144 state panel **only when the widescreen layer is not the top state**, a
Gen 2 g9-gui screen that is on top paints the whole window and nothing else —
the suite's full-page look with no engine box underneath.

The shared modules are generation-aware rather than forked:

* `Shell.money` reads `save.player.money` (Gold) or `save.money` (Gen 1).
* `ui/roster.lua` reads max HP from `mon.maxHp` (Gold `Mon.refreshStats`) or
  `mon.stats.hp`, the EXP curve through `src.battle.gen2.Mon` on Gold and
  `src.pokemon.Growth` on Gen 1, and the status chip through
  `data.gen2Statuses` with `src.battle.Status.GEN2_ID_ALIASES`.
* `ui/portraits.lua` reads Gold's `data.gen2Icons` (the same `{species, icons}`
  shape `PartyMenu.iconFor` uses) **only for the engine's fallback** — the
  pack's own art is asked for first on both generations since 2.6.2, because its
  front sheets answer for a Gold species exactly as they do for a Gen 1 one, so
  `sprites` mode shows the pack's front art on Gold too; the `data.gen2Icons`
  path is reached only for a species the pack has no sheet for (or with no
  sprites mod at all), where Gold's own party icon is the honest picture rather
  than a `?`.

Screens are ported and shipped one phase at a time; each phase extends the
harness (`scratch/sim/gui_harness.lua`) with a Gen 2 fixture and renders the
page at 1:1 so the layout checks are the same ones the Gen 1 shots get.

**Phase two (2.5.1) — the POKéMON screen and the summary.** `ui/party_menu.lua`
gains `M.newGen2`, which builds Gold's `src.ui.gen2.PartyMenu` and drives it:
the engine's own cursor, submenu, switch and SOFTBOILED flows, field-move use,
TM/HM views and `onCancel` all keep running, and this module only ticks an
animation counter on top. `M.drawGen2` then draws the whole page through the
shared `Shell` / `Roster` modules — the same header (`PARTY n/6`, the money
readout), the same left rail (built through `Shell.startRows`, which now takes a
`gen` argument and loads Gold's `src.ui.gen2.StartMenu`), the six-row roster
with portrait cards, the `hp/max` figures beside the name, the gold `Lv`, the
HP/EXP gauges and the `FNT` wash — with the engine's own submenu drawn as the
modern popup. `Roster.expFrac` reads Gold's `experience` field (Gen 1's `exp`),
and the roster already reads `maxHp` and Gold's lowercase status ids. The
summary's `M.newGen2` builds Gold's `src.ui.gen2.SummaryMenu` and `M.drawGen2`
floats the same 486×324 panel: it re-draws the party page beneath
(`__g9guiPage`, set on the party instance) and dims it 0.62, so the Gold float
reads as the same lift it is on Gen 1. Its four pages are the Gen 1 four: STATS
(the six combat stats with bars beside the HP / status / type / item / EXP
column), EVS and IVS (the same bar rows, reading the engine mod's modern
`evs`/`ivs` — or, without it, Gold's own stat experience 0-65535 and DVs 0-15
with the HP DV derived from the other four, each against its own real cap and
totalled like Gen 1's) and MOVES (the held item and the four moves with PP);
Gold's trainer-data page gives way to the two spreads, which is why its page
count is re-pointed from the engine's three to four (A walks on from IVS to
MOVES rather than quitting, and SELECT opens the move manager from MOVES rather
than from the EVS page). The g9-battle-sprites pack's animated frame is drawn in
the window's top-left corner of every page, through that mod's
`drawSummaryFrame` export. The move manager draws the four slots with a
cursor and the selected move's TYPE, attack power and a two-line description;
the egg page shows the Gold egg text. Every engine read goes through the same
`pcall`-guarded `safe()` helper the module already used, so a Gold accessor that
moves costs one row rather than the page.

**Phase three (2.5.2) — the PACK and the POKéDEX.** `ui/bag.lua` gains
`M.newGen2`, which builds Gold's `src.ui.gen2.PackMenu` and drives it, and a
`M.new` branch that routes a Gen 2 boot to it. The engine's pocket switching,
cursor and scroll, the use/give/toss/select/quit submenu, the toss-quantity
state, the YES/NO confirmation, the message flow and every item action keep
running; the module adds a lazy `builtin()` (Gold's `src.ui.gen2.PackMenu`) so a
Gen 1 boot never requires a Gold module. `M.drawGen2` draws the pocket page:
the four-pocket tab strip (`ITEM` / `BALL` / `KEY ITEM` / `TM-HM`, the current
pocket lit and carrying its own pocket icon), the item list with a highlight
band, `×N` counts and the `CANCEL` row, the pocket's name and description, the
header and the `MONEY:` readout, and the footer. The engine's own instance
fields are then drawn as this suite's popups over the page — the message line,
the toss-quantity stepper, the YES/NO confirmation and the submenu — so a
quantity prompt or a confirmation is the same card every other modal uses.

`ui/pokedex.lua` gains `M.newGen2` in the same shape: it builds Gold's
`src.ui.gen2.PokedexMenu` and installs a custom `:drawWidescreen` that records
the window size and dispatches on the engine's own `mode`. ROUND 315 pins that
mode to `OLD` (the number order) and masks SELECT, so Gold's NEW / A-Z
orderings cannot reorder the page. Gold keeps the
listing and the species entry in **one** screen (where Gen 1 had `PokedexMenu`
plus a separate `DexEntryMenu`), so `M.drawGen2` draws the listing for the
list/results views — `num name` rows, the caught-ball marker, unseen entries
dimmed, `SEEN` / `OWN` / `SORT` / `MONEY` in the header — the species entry for
the entry view (the portrait panel over `No.` and the kind, the `HEIGHT` /
`WEIGHT` figures shown only when the species is caught and drawn as `?` when it
is not, the wrapped `entry.text` / `entry.text2` description, or the catch hint
in its place, and the `PAGE` / `AREA` / `CRY` / `PRNT` action bar), and the
option side-menu for the option view. The portrait goes through
`src.world.gen2.Palettes` + `src.render.GbcPalette` when they are available, so
the species art (or the engine's `questionMark`) draws in its own Game Boy
Colour palette; the Gold `AREA` map view, the `SEARCH` screen and the `UNOWN`
view are handed straight back to the engine's own `drawWidescreen`, so those
keep the engine's drawing rather than a half-drawn page.

**Phase four (2.5.3) — OPTION, the trainer card and the MOD MANAGER.**
`ui/options.lua` gains `M.installGen2` + `M.drawGen2`. The engine's
`src.ui.gen2.OptionsMenu` builds its own rows and drives them (LEFT/RIGHT
cycling, the STEP nudges, the `ui.options` hook and the group sub-pages it
pushes); this mod only draws. A new `g2value(self, row)` resolves a row's value
through the port's full vocabulary — a `text` row (a literal or a function), a
`frame` row (the animation number), a `values` + `display` row (the current
value mapped through the display table) and a `value(game)` row — and
`M.drawGen2` paints the header, the rows with the label at the left and the
resolved value at the right, the cursor marker, `dim` for a `group` row and the
`SELECT` / `CHANGE` / `B` footer. Crucially `M.installGen2` dresses the
**class**, not just the instance: Gold builds a group page with a plain
`setmetatable({}, OptionsMenu)` rather than through this mod's constructor, so
only a class-level arm gives those sub-pages the same page. There are no
built-in-setting reads here the way Gen 1 has: the port's rows already carry
their own values, so the value resolution is all that is needed.

`ui/trainer_card.lua` gains `M.decorateGen2` + `M.drawGen2`. Gold's
`src.ui.gen2.TrainerCard` is built and driven (its page cycling and animation
frame are the engine's); this mod draws three pages. Page 1 is the card: the
left portrait panel draws the engine's own 5×7 portrait out of the card sheet
through a **nested** `translate`/`scale` around the cart's tile `(14,1)` — the
sheer keeps its raw cell coordinates under the transform, because the sheet
picks each tile's colours by its cell, so drawing the block at the origin would
give it the wrong palette — beside the `NAME` / `MONEY` / `TIME` / `POKéDEX`
figures and the Johto badge row (the row and the `BADGES n / 8` figure agree,
because the card page owns the Johto eight). Pages 2 and 3 are the Johto and
Kanto badge boards: eight slots each, the engine's own badge sprites drawn from
its `badgeOam` frames and 2×2 `BADGE_CELLS`, earned badges lit behind a gold
ring and unearned ones ghosted, labelled from the engine's `JOHTO_BADGES` /
`KANTO_BADGES` exports, with the Kanto board reading `player.kantoBadges`.

`ui/manager.lua` needed no Gen 2 arm of its own: the engine ships `ManagerState`
generation-agnostic, so `M.decorateGen2` is the same surface swap the Gen 1
`M.decorate` does (the EXPORT-LOG row injection is now the shared `wrapRows`),
and the same list / profile / options-overlay / notice / ERRORS rows run on
both.

**Phase five (2.5.4) — the boot MAIN MENU.** `ui/title.lua` gains
`M.newGen2` + `M.drawGen2`. Gold splits what Gen 1 keeps in one object:
`src.ui.gen2.TitleState` is only the boot cinematic (Ho-Oh, Suicune, clouds, the
gem entrance; its A/START just calls `onContinue`), and the
CONTINUE / NEW GAME / OPTION / EXIT GAME list its `onContinue` opens lives in a
**separate** screen, `src.ui.gen2.MainMenu` — which also owns the CONTINUE save
panel its `phase == "confirm"` state shows. So the Gen 2 takeover is
`Gen2MainMenu` and `Gen2TitleState` is deliberately **not** registered: its
cinematic is engine art this mod has no business redrawing, and its only output
is pushing the screen that *is* ours. MainMenu is built and driven as before
(its `Chrome.List` rows — CONTINUE only when a save exists, then NEW GAME /
OPTION / EXIT GAME — the `ui.title_menu.items` hook, the wrap-around cursor and
the menu/confirm phase split are all the engine's; `update` is only wrapped to
tick the animation counter), and `M.drawGen2` draws the whole page in Gold's own
`:drawWidescreen`: the same left rail (`Shell.rows` over `list.items`, so a
Gold boot gets the same row treatment) and the same SAVE DATA **emblem** panel
as the Gen 1 page, through `M.emblemGen2`, which reads Gold's save shape — the
party table and the `{ hours, minutes, ... }` clock — and MainMenu's own
`hasSave` flag, so a no-save boot reads `EMPTY` and `----`. The confirm phase
becomes `M.drawCardGen2`, the same SAVE card the Gen 1 CONTINUE window is,
whose figures come from Gold's own `src.core.gen2.Save.summary` (so `BADGES`
counts both the Johto and the Kanto sets and `POKéDEX` counts the dex, exactly
as the cart's `DisplaySaveInfoOnContinue` prints). The Gen 1 arm is untouched:
`M.new` branches on `ctx.gen` before it ever asks for the Gen 1 `TitleState`
module — which is now a lazy require, so a Gold boot cannot pull it in.

**Phase six (2.5.5) — the three re-skinned screens, on Gen 2.**
Phases one to five ported the screens this mod *owns*; the three it *dresses in
place* were still Gen 1-only, because `main.lua` wrapped their install in an
`if gen ~= 2 then`. That wrapper is removed, so **`ui/train.lua`**,
**`ui/blacklist.lua`** and **`ui/textbox.lua`** now load on both games — and so
does the `StateStack.push` takeover that dresses them. `ui/train.lua` and
`ui/blacklist.lua` each gain `local Gen2 = ctx.gen == 2` and branch in their
dress function: on Gen 2 they take the page over through
`Shell.gen2Surface(Theme, state, function(s) M.draw(s) end)` — the same
Gen 2 surface seam every owned screen uses — and on Gen 1 they keep the old
trio (`uiSize`, the wide-battle `isWideBattleLayout` and `wantsFillScale`). The
Gen 2 arm deliberately does **not** install those three: they are the Gen 1
fill-scale contract, and Gold has no `:uiSize()` to answer. Everything else in
both modules is common — the `sgbPalettes` / `isOpaque` / `letterboxWhite`
class methods, the `update` wrap that ticks the animation counter, and the
whole `draw` body — so the two skins paint the **identical** 540×360 page on
either generation (a harness byte-compare of the Gen 1 and Gen 2 shots is
exact). `ui/textbox.lua` needed no behavioural change at all: `src.render.TextBox`
is a **single shared class** on both games, so the same skin applies. Gold's
`Game2` has no `self.renderer` table, so through 2.6.6 the dialogue card took the
**surface path** there (drawn on the mod's own surface at the engine's box
origin) instead of the window-space `render.hud` path Gen 1 uses — the same card,
but blitted through the surface rather than drawn at native resolution. **2.6.7**
closes that gap: the card now reads Gold's own `render.hud` **viewport payload**
(`{gameX, gameY, scale, dpiX, dpiY}`, the transform `Game2:drawScene` uses to
blit the classic UI canvas) and paints in window space on Gold too, so the
dialogue card and the YES/NO skin are native-resolution on both generations. A
`GEN 2` paragraph was added to the module header to record that, and the choice
skin was rewritten generation-agnostic in the same patch. With this
phase the GEN 2 port's screen list is complete; `GEN2-PORT.md` tracks the
remaining non-screen parity item (national_dex's Gen 2 dex features) as its own
phase.

**2.6.4 — a taken-over page can no longer be blitted by the engine, and the
cart's own item flow wears the suite.** Two leaks survived the port because
they are not screens this mod registers:

* `Game2:drawScene` chooses the widescreen layer as the top state *or*, when a
  non-wide state (a Gold `TextBox` message card) sits above it, the wide state
  that is beneath as the visible **base** — and it blits that state through its
  own classic `:draw()`. A takeover replaced `:drawWidescreen` but left the
  classic `:draw` alone, so a "You can't SURF here."-style message card over the
  POKéMON page painted the cart's native roster under it. Fix: every Gen 2
  takeover now installs a **no-op `:draw`** — `Shell.gen2Surface` sets it, and
  the modules that build their surface by hand (`ui/pokedex.lua`,
  `ui/options.lua`, `ui/title.lua`) set it in their own Gen 2 arm too. A blanket
  guard in the `StateStack.push` wrapper enforces it for any dressed state that
  answers `:drawsWidescreen()` and carries the `__g9gui` flag, and
  `ui/train.lua` / `ui/blacklist.lua` only bind their own `state.draw` on Gen 1
  so they cannot clobber it.
* The POKéMON page's ITEM press opens `src.ui.gen2.HeldItemMenu` — a native
  cart screen whose GIVE/TAKE list and its own message / YES-NO phases drew in
  the cart's classic style over the native party list. `ui/held_item.lua`
  (registered as `Gen2HeldItemMenu`) now takes it over: it draws the POKéMON
  page under a modal wash and paints the suite's GIVE/TAKE list, message and
  YES/NO popups, while keeping the engine object and every one of its
  give/take, swap and held-item writes.
* The YES/NO boxes are the engine's shared `src.ui.ChoiceBox`, pushed over a
  conversation (or the item flow) — a screen this mod never registers. New
  `ui/choice.lua` dresses that **class** while it sits over a conversation the
  suite already dressed; 2.6.4 shipped it Gen 2 only, and **2.6.7** made it
  generation-agnostic so it now dresses Gen 1 too, drawing the suite's
  two-choice and labelled two-option cards in the same **window space** the
  dialogue card uses (native density, the engine's own `setUIAnchor` kept for a
  Gen 1 DYNAMIC layout, LEFT/RIGHT toggling the rows). The engine keeps the
  cursor and the answer.

### The evolution screen (`ui/evolution.lua`)

The evolution movie is the one screen the engine plays *without* a `Menu`: on Red
/ Blue / Yellow `src.pokemon.Evolution` pushes `src.ui.EvolutionState`, and on
Gold the same beat pushes `src.ui.gen2.EvolutionAnim`. Both are registered ids, so
`main.lua` takes them over the ordinary way, and both are view takeovers — the
engine's object is built, kept and driven; only `draw` and the surface move.

The two states disagree about how the message is carried, and the page follows
each one rather than inventing its own:

* **Gen 1** prints `What? X is evolving!` in a separate `TextBox` pushed
  *underneath* the state, and its own `:draw` only wipes rows 0–11 to reveal it.
  The page is therefore **opaque** and prints the line itself, read from the same
  ROM string the engine reads (`src.core.RomText`'s `_IsEvolvingText`, with an
  English fallback if that module is unavailable). Once the flash ends, the
  engine's own result box (`X evolved into Y!` / `Huh? X stopped evolving!`) is
  pushed on TOP, and `ui/textbox.lua` already paints a box over one of this
  suite's pages as the centred card — so the page clears its caption and the card
  is the only message on screen.
* **Gold** keeps its message in the state itself: `self.lines` holds a different
  pair of lines per phase, and it is never cleared through the whole flash
  (`What? X is evolving!` stays under the picture, exactly as on the cart). The
  page prints `table.concat(self.lines, " ")` as the header caption, so every
  beat — the evolving line, `stopped evolving!`, `Congratulations!`,
  `evolved into X!` — arrives without this mod knowing any of the text.

The **sprite** is the point of the screen, and it comes from the same place as
every other picture in the suite: `ui/portraits.lua`'s `drawFront`, i.e.
g9-battle-sprites' always-on `frontArt` export, drawn at the pack's own 1:1
pixels (stepped down by a whole integer divisor only when a frame outgrows the
stage, never zoomed). A species the pack has no sheet for — or a boot without
that mod — falls back to the engine's own front pic (`self.oldSprite` /
`self.newSprite` on Gen 1, `Sprites.path` + `Assets.image` on Gold) in the very
same slot, so the stage is never empty. Which form is showing follows the
engine's own schedule: Gen 1's accelerating flash is reproduced with the exact
hold/swap frame counts from `EvolutionState.lua` (so a `B` press settles on the
form that was on screen), and Gold's is read straight off its `showNew` flag.
Only `:sgbPalettes()` is replaced — with an empty zone list, like every other
screen here — so the pack's true colour art is not run through the SGB
shade-remap shader (the cart's silhouette effect); the flash timing that made
that effect read is untouched.

The footer follows the engine's own permissions: `B CANCEL` is offered only
while the engine itself would honour a `B` (never for a stone evolution or a
trade — the state's own `cancelable` / `force`), and once the animation settles
`A OK` advances whatever the engine puts up next. The header status reads
`EVOLVING`, `COMPLETE` (settled on the new form) or `STOPPED` (cancelled).

### The move learner (`ui/move_learn.lua`)

`src.ui.MoveLearnMenu` is the screen the game opens when a Pokemon with four
moves levels into a fifth: the `_TryingToLearnText` question with its YES/NO,
then the list of the four moves to replace, the HM refusal, the
Abandon-learning confirm and the `1, 2 and... Poof!` narration. It is a **view
takeover**, exactly like every other page here: the engine's own object is built
and kept whole (`selecting`, `index`, the HM guard, the abandon flow and every
slot write all still run), and only the surface and the draw move onto the
instance — `:isOpaque`, `:uiSize()` 540×360, `:isWideBattleLayout` /
`:wantsFillScale` via `Shell.wide`, and an empty `:sgbPalettes()`.

**Why it is an OPAQUE page, not a floating card.** Unlike the menus the START
screen opens, this one is routinely pushed **mid-battle** — the engine's own
battle queue (`BattleState:learnMove`), the bag's TM use, the evolution's
post-evolution learn run, and **g9-Battle-Scene's in-battle learn pause**. A
classic 160px menu there would leave the battle, its HUD and the Pokemon sitting
behind the question; as an opaque wide page, `Game.wideBattleInStack` resolves
the surface to this page and `Game:draw` starts from it, so nothing under it is
drawn at all. It is registered under the **engine's own id on both
generations** — the id carries no Gen2 prefix, because Gold handles move
learning inside `Gen2BattleState`, so on Gold the id is reached by
g9-Battle-Scene's in-battle pause and, since **3.2.0**, by
`ui/gold_learner.lua`'s wrap of `Game2:learnMoveOn` for the **out-of-battle**
flows (see *Gold's out-of-battle learn* below).

**The messages stay the engine's.** The page draws only the furniture the
builtin `:draw` used to paint (the four-move list with its chevron and the
`Which move should be forgotten?` line). The question, the abandon confirm, the
HM notice and the narration remain the engine's own `TextBox`es, and the suite's
dialogue/YES-NO skins already paint those as its cards in this page's
coordinates — `ui/textbox.lua`'s `surfaceIsWide` refuses only a battle's or
another mod's wide surface, and every instance here is stamped `__g9gui`.

**The published id.** `main.lua` sets `mod.exports.moveLearnScreenId` only when
the screen actually registered, so a peer mod that pushes the learner can tell
the modern page is live and skip its own fallback chrome. g9-Battle-Scene is
that peer: with the export present it pushes this screen and leaves the battle
alone; without it, it pushes the engine's classic learner and paints a plain
WHITE field instead of the battle (see that mod's `FN.drawLearnSheet`).

**Gold wants the same two markers (3.1.1).** The Gen 1 arm installs
`:isOpaque` and `:isWideBattleLayout`; Gold's surface contract
(`Shell.gen2Surface`) installs `:drawsWidescreen` / `:wantsFillScale` instead,
which is right over the overworld but **not** over the custom battle scene:
that scene is itself a wide, OPAQUE state, so `Game2:drawScene` resolved the
wide layer to the *scene* — it painted the battle and never called this page's
`:drawWidescreen`, leaving the engine's plain `TextBox` floating over a live
battlefield with no modern page under it. The Gen 2 arm now installs
`:isOpaque` (the page becomes the stack's visible base, so Game2 paints it and
the battle stays underneath) and `:isWideBattleLayout` (so
`Game.wideBattleInStack` finds the page rather than the battle under it, which
is what `ui/textbox.lua`'s `surfaceIsWide` reads to draw the engine's own
messages as the suite's cards in this page's coordinates). This is scoped to
the learner — the other Gen 2 pages are opened over the overworld, where the
`drawsWidescreen` contract already resolves them as the top.

**...and on Gold the card itself needs the page's own scale (3.1.2).** The Gen 1
page card works because the engine blits the page into a real 540×360 surface and
then shifts a pushed `TextBox`'s classic rectangle into it by `classicOffset`,
which `ui/textbox.lua` undoes before drawing `ui/shell.lua`'s `S.card` in page
pixels. Gold has neither: `:drawWidescreen` paints the page straight into the
window through `Shell.gen2Fit`, and the engine THEN re-runs the stack over it at
Chrome's own integer letterbox (`Game2:drawScene` → `panelBlit` →
`Chrome.fitScale/fitOrigin`) — the pass a pushed `TextBox` draws in. Two scales in
one frame: for a 1080×720 window the page blits at **2x** and the overlay pass at
**5x**, so the question, the abandon confirm, the HM notice and the narration
were composed at the *classic* scale, in the cart's white window and the cart's
face, several times the size of the page they sat on (the user's screenshot).
`Shell.gen2Page` now publishes the fit it just drew with, and `ui/textbox.lua`'s
`M.inPageSpace` maps the **page's** coordinates into that classic pass, so the
same `S.card` lands on exactly the pixels `gen2Fit` put the page on. `ui/choice.lua`
uses the same mapping, so a YES/NO the engine pushes over such a message is still
**one** card carrying the question and the two rows (as on Gen 1), and both skins
stand down together. Fail-open as everywhere else: no published fit, a fit left
over from another page, or an engine without `Chrome` leaves the box on the
classic surface card — chunkier, never missing.

**...and the narration stays on the page (3.1.3).** `MoveLearnMenu:finish` pops
the screen and *only then* pushes the closing narration (`1, 2 and... Poof!`, or
`X did not learn Y!` when the player gives up) — so the one beat the card above
was written for was the one beat with no page under it: the learner came down on
the battle and the cart's white 20×6 window was composited over the fight (the
user's screenshot: the raw cart box over the fantasy combat band). `build` now
wraps the engine's `:finish` (`installFinish`) rather than reimplementing it:
the engine's own body still builds the message, pops and pushes the narration,
but the one pop it makes — its self-removal — is swallowed, so the page stays
**under** the narration, which is the same arrangement the question, the abandon
confirm and the HM notice are already in. Dismissing the narration then brings
the page down with it, so the caller's own completion (the battle queue's resume
through `onDone`) still sees the stack it always saw. The harness drives the
whole sequence — question, YES/NO, forget list, HM refusal, abandon confirm and
both endings — through the engine's faithful stub, asserting the page card at
every beat (`gen2_move_learn_narration`, `move_learn_narration`, and the
"the Gold learner keeps its page through every beat" check).

### Gold's out-of-battle learn (3.2.0)

On Gold, `MoveLearnMenu` is not a screen the engine ever opens outside
battle. A TM used from the PACK opens the **party screen** to pick the mon
(`PackMenu.lua`), the RARE CANDY runs its level moves (`Game2:afterRareCandy`),
an evolution's new move runs after `EvolutionAnim`, and the Goldenrod tutor
(`MoveTutor.lua`) each finish by calling **`Game2:learnMoveOn(mon, moveId,
onDone)`** — which draws the whole exchange itself as engine `TextBox`es (the
trying-to-learn question, the stop-learning confirm, the `Which move should be
forgotten?` prompt) plus the native `Gen2MoveDeleter` forget list. Registering
the `MoveLearnMenu` id therefore did **nothing** for any of them, and a move
learned from the party flow came up on the cart's classic boxes instead of this
suite's page — the report this fixes, on PC and mobile alike.

`ui/gold_learner.lua` is the router. `main.lua` installs it on Gold only (Gen
1's engine already pushes the screen above). It wraps the **class method**
`Game2.learnMoveOn` — `Game2.__index = Game2`, so wrapping the class covers
every instance and all four callers above, which all dispatch
`game:learnMoveOn(...)` — and then:

- **four slots full and the move not already known** → it resolves this
  suite's registered record (`src.ui.Screens.get`, and only a factory the
  engine itself stamped `__modOwned`, so a MODERN UI: OFF boot or a peer's
  builder can never be mistaken for ours), builds the page with `(self, mon,
  moveId, finish, "Sfx_DexFanfare5079")` and pushes it. It threads the caller's
  own `onDone` into `finish`, so every continuation — the TM's consumption and
  happiness, the candy's remaining level queue, the evolution's next move step,
  the tutor's fee — runs exactly as the engine's own flow ran it.
- **every other case** → straight to the engine's method: a free slot learns
  outright and prints the engine's own "… learned X!" line (through the same
  `Mon.learnMove` the engine always used), a move the mon already knows finishes
  silently, and anything the engine refuses keeps its behaviour.
- **a page that will not build** → one `warn`, then the engine's own flow, so a
  mod that cannot paint one page can never cost the player a move.

Because the engine's Gold forget arm writes the slot itself and raises
`pokemon.move_learned`, the router does both too after a learned page
(`M.afterLearn`: stamps the new slot's `maxPp` from the move's real PP and emits
the event), so a mod counting learned moves (g9-evolutions, the battle scene)
sees the four-slot case. Gold's two extra HMs (**WATERFALL, WHIRLPOOL**) are
refused by `ui/move_learn.lua`'s own update wrapper (`GOLD_HM_ONLY` +
`goldHmBlocked`) — the engine's own Gold `HM_MOVES` table lists seven, the
builtin `MoveLearnMenu`'s lists five, so without this the page would happily
delete one. Install is idempotent (`Game2.__g9uiLearner` guards the wrap). The
harness drives the wrap end to end (the "Gold's out-of-battle learn routes
through the suite's learner" check): the four-slot case pushes exactly one page
whose `screenId` is the registered id and leaves the engine's own flow
untouched, while a free slot and an already-known move both fall through to it.

### The screen registry refresh (3.1.4)

`src.ui.Screens` **memoises** every factory it hands out (`resolve` keeps a
module-level `cache[id]`), and a mod's `mod.content.screens:register` is folded
into `game.data.screens` only **after every enabled mod has initialised**
(`src/mods/Registry.lua`). So an id resolved during the load phase — by an
earlier-loading mod, or by a boot step whose order differs by platform —
caches the ENGINE's builtin, and that stale entry shadows this suite's record
for the whole session: the native battle queue's move learner, the bag's TM use
and the evolution's post-evolution learn run all got the classic screen instead
of this suite's page. A desktop boot that resolves nothing early works; a boot
that does falls back — the **"works on PC, falls to the native screen on
Android"** report, and the same class of platform-shaped routing fault
g9-Battle-Scene's `FN.pushLearner` already works around for its in-battle
learner (that peer *can* drop the cache before it pushes; the engine's own
callers cannot).

`main.lua` now drops the cache once while installing and again on
`game.ready` — which fires once every registry has been folded in and just
before the boot pushes its first screen (`src/core/Game.lua`) — so the next
resolve of every id re-reads the live data. Dropping the cache is always safe:
it holds factories, never state. The `game.ready` handler also logs one line
naming the learner record (`registered` at info, `MISSING` at warn), so a
platform whose boot still cannot reach a modern screen says so in the log
instead of failing silently. Fail-open: an engine without `Screens.invalidate`
leaves the cache exactly as it was before this existed.

### Reading a boolean option row (3.1.4)

The same Android report showed a Mod Manager row handed back as the choice's
own **LABEL** ("ON") rather than its stored value ("on"/"true"), which is why
g9-Battle-Scene's exact `value == "on"` compare flipped its learner row. This
suite reads its option rows through one normaliser in `main.lua` (`opt` →
`normalise`): the stored value, a boolean, a number and the choice's label all
read as the same `"true"`/`"false"` string, so every screen's
`opt("ui_background") ~= "false"` reader — some seventy call sites — is right
without each one carrying its own compare. Only the rows declared as straight
ON/OFF booleans (`modern_ui`, `ui_background`, `ui_embellishment`, `ui_pc_row`,
`short_heal_chat`) have their string spellings mapped; the other rows (the
portrait mode, the HP guard's `catch`/`log`/`off`) keep their own values
untouched, because `"off"` there is a real mode, not a synonym for `"false"`.
`ui/shell.lua` reads `mod.options` directly (it is built from the mod alone),
so it carries the same reader for its two reads — `ui_embellishment` and
`ui_pc_row`.

### The PC

Gen 1's PCs (the player's own PC, the item/storage boxes) were the first half of
the PC round: `main.lua`'s `installOpenPc` wraps the engine's own `openPC`, so
the pages it pushes are dressed, and the whose-PC menu, the storage / item / box
screens and the CHANGE BOX picker draw on the 540×360 page.

Gold is different in one important way: its five PC screens are **bespoke
classes**, not the generic `Menu` / `ListMenu` the other Gen 2 screens share, so
no per-id takeover table could reach them without reimplementing their state
machines. Instead **each screen stamps its own id** (`Screens.build` sets
`screenId` before the push), so `ui/pc.lua`'s `isPc` recognises a Gold PC screen
by id alone and dresses it at the same `StateStack.push` wrapper:

```lua
G2_SCREENS = { Gen2CenterPcMenu = "center", Gen2PcMenu = "storage",
               Gen2ItemPcMenu = "items", Gen2BoxMenu = "box",
               Gen2MailboxMenu = "mail" }
```

Each has a painter in `G2_DRAW`. The engine object is untouched: its
`confirm` / `message` page counters, the storage's `picking` / `savePhase` /
`saveChoice` / `savePages` save prompt, the item PC's `phase` / `qtyState` /
`conflict` / `cantToss`, BILL's `mode` / `boxIndex` / insert cursor and its
timed hold, and the mailbox's submenu all keep running; `M.dress` only wraps
`update` to tick a `__t` counter (then still calls the engine's own update) and
swaps the surface (`Shell.gen2Surface`).

BILL's PC's left **mon panel** draws the g9-battle-sprites pack's **own front
art** (through `ui/portraits.lua`'s `drawFront`, the same source the party
portraits use, including that mod's single **egg picture** for an egg) instead
of the engine's native pic; the engine pic is only the fallback for a species
the pack answers no sheet for, or when that mod is not installed.

**Since 3.3.6 every box page is the MODERN GRID.** Bill's PC's box -- Gen 1's
WITHDRAW / DEPOSIT / RELEASE POKéMON lists and Gold's BILL's PC -- used to draw
the classic column of nickname rows (Gold's beside a mon panel). Both now draw
the page every game from Generation III on draws: a six-column **wall of
cells**, one per storage slot, each holding the creature's own **mini-icon**
from the g9-battle-sprites pack (`ui/portraits.lua`'s `drawIcon` -- the pack's
true-colour party-icon cell, the 16×16 atlas as a fallback, the engine's own
sheet only as a last resort), never the engine's native icon. The left third is
the PKMN DATA card: the selected creature's **front art** (the same pack source
the mon panel already used), its name (stepping down one type size rather than
being cut), `/SPECIES`, `LvNN` and its gender glyph and type names; the right
two thirds are the grid, with a rounded **BOX banner** (the box's own name, its
`n/12` place and, where the engine's dpad is free, live switch triangles) above
it. Six columns is the modern PC's own count and a Gen 1/2 box holds 20
(`src/pokemon/Boxes.CAPACITY`, Gold's `MONS_PER_BOX`), so the wall is **6 × 4**
-- the engine's trailing CANCEL row is simply one more cell; a mod that
enlarges a box grows rows. `Shell.top` still carries the screen title, the
`n/N` count and the caption, and the footer still draws the hint chips. Both
arms call the one painter (`drawBoxGrid`, reached from `M.drawBoxList` on Gen 1
and `M.g2DrawBox` on Gold), so they cannot drift.

Gold's BILL's PC also **switches boxes on LEFT/RIGHT with no save in between**
(`M.g2StepBox`): the modern page flips straight from the banner, so the skin
takes the pair the engine leaves free (Gold's `BoxMenu` reaches its `stepBox`
only from MOVE's dpad) and lets the save's active box follow through
`src/core/gen2/Boxes.setCurrent`, exactly as the CHANGE BOX picker would --
minus the save prompt the modern page drops. INSERT (MOVE's destination cursor)
keeps the dpad, so the walk stands down there. Gen 1's box pages keep their own
CHANGE BOX picker: the engine's Gen 1 box lists close over the box table when
the list is built (`src/ui/BoxMenu.lua`'s `withdraw` / `release` capture
`Boxes.active(save)` for their `onChoose`), so a mid-list switch would need the
engine's whole list re-pushed -- out of this round's scope, and the page the
report named ("BILL's PC") is Gold's.

**Since 3.4.0 Gold's BILL's PC is a SLOT page.** A box is a fixed
**six-column by five-row wall of 30 always-visible cells** (g9-boxes raises
Gold's `Save.MONS_PER_BOX` / `Boxes.MONS_PER_BOX` to 30), so cells no longer
collapse to the number of mons stored. The page owns its cursor and its writes:
`M.dress` replaces the engine's `BoxMenu:update` for the box screen with
`M.g2BoxUpdate`, so the engine's packed list, insert cursor and CANCEL row are
no longer driven. A mon's cell rides the mon itself as **`mon.boxSlot`**
(1..30) -- the field g9-boxes' save guard scrubs on load -- so a hole in the
middle of a box survives a save while the engine's array stays a plain packed
list. A on a mon opens the menu in the order **MOVE / STATS / RELEASE /
CANCEL**; MOVE picks the mini-icon up (drawn lifted over the cursor cell, with
a shadow beneath it) and A on an empty cell drops it there, saving the cell,
while A on an occupied cell asks **"Swap POKéMON?"** and, on YES, the two mons
trade cells -- and, when they are in different arrays, their arrays too -- the
displaced mon becoming the one in hand. LEFT/RIGHT wrap inside the wall and
step to the previous / next array (the boxes and the PARTY, box 0) only at the
wall's own first / last cell, so a mon can be carried between a box and the
party; the save's active box follows through `Boxes.setCurrent`. B is the
page's cancel: it asks **"Cancel box operations?"** with YES/NO, and while a mon
is in hand it refuses with "You can't leave while holding a POKéMON." instead,
so the boxes stay open. Gen 1's own box lists use this same page since 3.6.0
(see below); this paragraph described Gold only.

**Since 3.5.0 the BOX banner is a cursor row.** UP off the wall's top row puts
the cursor on the banner (`row == 0`), where LEFT/RIGHT change BOX and DOWN
returns to the wall -- so a mon held in the cursor can be carried from one BOX
to another and dropped (or swapped) there, the cross-box half of MOVE. The
arrays run **PARTY, BOX 1, ..., BOX N** and wrap both ways: the last BOX's right
step lands on the PARTY and the PARTY's right on BOX 1 (left is the mirror),
so the order reads `...50 > PARTY > 1 >...` and back. Inside the wall LEFT/RIGHT
now just walk the 30 cells and wrap (a right at the last cell returns to the
first); the banner is the only box switch. Dropping a held mon on an occupied
cell of ANOTHER box asks "Swap POKéMON?" and, on YES, the two mons trade boxes
and cells (each keeps its own `mon.boxSlot`), a cross-box replace; a same-box
swap still hands the displaced mon back. The banner lights up while it holds
the cursor, and a carried mon's mini-icon rides it. Bill's PC's own row that
opens the boxes is renamed **MOVE POKéMON** (was WITHDRAW POKéMON) on Gen 1 and
Gen 2 -- the page is a move page -- while the item PC's WITHDRAW ITEM is left
alone.

**Since 3.6.0 Gen 1's BILL's PC is the same SLOT page.** Gen 1's three box
lists (Bill's PC's **MOVE** / **DEPOSIT** / **RELEASE** rows, the engine's
`pc_box_withdraw` / `pc_box_deposit` / `pc_box_release` `ListMenu`s) are drawn
and driven by one controller, `M.g1BoxUpdate`, which replaces the engine's
packed `ListMenu:update` exactly as `M.g2BoxUpdate` does on Gold -- the engine's
rows, its cursor and its trailing CANCEL row are no longer driven. The arrays
are Gen 1's own: **the PARTY (0) and BOX 1 .. `Boxes.COUNT`**, wrapping in the
same `...50 > PARTY > 1 >...` order, with the banner row switching between them
and `save.currentBox` following. A box is the same fixed six-column wall of
`Boxes.CAPACITY` cells (30 with g9-boxes, 20 without), a mon's cell rides
`mon.boxSlot`, and A / MOVE / swap / carry / release / B all behave exactly as
the Gold page documents above -- including the same-array swap that leaves the
displaced mon in hand and the cross-box swap that trades both arrays. The
DEPOSIT list simply starts the cursor on the PARTY. Entering a box from the
party runs the engine's own `Stats.ensure` on the withdrawn mon (a Gen 1 box mon
carries no stat block), which is what the engine's `BoxMenu.withdraw` does; the
engine's own `monSubmenu` card is still understood for any pushed instance
(`isMonSubmenu`), but the slot page draws its own card through `pcCard`.

**Since 3.7.0 Bill's PC's MOVE row never asks for a free party slot, and
DEPOSIT is gone from both generations' Bill's PC.** The engine's own Gen 1
`BoxMenu.withdraw` refuses outright when the party is full (`#party >=
Party.MAX`) *before* it pushes its list, because on the cart that list could
only pull a mon OUT to the party. The slot page MOVES a mon anywhere -- box to
box included -- so that gate has no business on it. `M.g1TameBoxMenu` (called
from `M.dress` for the `BoxMenu` screen) rewrites the first row's `onSelect` to
`M.g1openMoveList`, which pushes the very same `pc_box_withdraw` `ListMenu` the
engine does (empty-box message and all) minus the party gate; the suite dresses
that list into the slot page as before (this is Gen 1's half of "fix it like
gen 2", whose `PcMenu:choose` has no such push-time check). The same pass
removes the **DEPOSIT POKéMON** row: the slot page's PARTY array is the deposit
route now (pick a party mon up, drop it in a box), so the row had nothing left
to do. Gold's storage menu loses its **DEPOSIT POKéMON** row the same way,
through `M.g2TameStorage`, which drops the `deposit` entry from the `Gen2PcMenu`
screen's `entries` before the page is dressed -- that one list drives both the
drawn rail (`M.g2DrawStorage`) and the engine's own cursor/`choose`, so the row
is gone from the page and from the engine's model at once. The item PC's
DEPOSIT ITEM is untouched (it is a different screen and kind).

**Since 3.7.1 the PARTY is browsed on the same wall a box uses, and the box
icons fill their slots.** Two box-page bugs off the same screenshots. (1) The
PARTY array was drawn as **one row of six tall cells** -- `drawBoxGrid` sized
its wall from `#items` and each caller sized `spec.cellH` from the array on
screen, so six party mons made one 214px-tall row. The wall's row count now
comes from a **BOX's** capacity (`spec.rows`, computed by each caller from
`boxCapacity` on Gen 1 and `g2boxCap` on Gold), so the party is six filled
cells on the same six-by-five grid a box is and the rest of the wall is simply
empty -- a party cell is the size of a box cell. (2) The g9-battle-sprites
**HD party icon** was drawn by `drawReal`, whose one-species-one-size rule
steps a frame down a WHOLE divisor when it does not fit: a 64x64 pack cell in
the 52x38 slot became `d = 3`, leaving the creature about a quarter of its
slot (the "hard to recognize" report). `ui/portraits.lua`'s `drawIcon` now
**crops the pack cell to its own opaque-pixel box** (`croppedArt`) and **fits
that box to the slot** (`drawFit`) with its aspect kept -- the creature fills
the slot instead of its transparent margins -- and the cell's own inset
(`CELL_PAD`) is tightened from 5 to 3 so the icon keeps a couple more pixels.
The 16x16-atlas and engine-sheet fallbacks are unchanged (older copies of the
sprites mod). Measured on the harness render: the icon now fills ~84% of the
slot's height (it was ~40%) and ~64% of its width (aspect-limited). Portraits
are untouched -- `drawReal` still drives the card art.

**Since 3.8.0 the party portrait shows the pack's own pixels, cropped to the
card, instead of being scaled down into it.** The card's head-space window
(`ui/portraits.lua`'s `drawHeadSpace`) used to step the whole frame down by a
whole integer divisor (`d = ceil(ch · HEAD_SHARE / h)`, plus a `ceil(cw / (w · 2))`
width cap) so the creature's head fit the band. That was needless reduction:
the card is a **window**, so a creature bigger than it should be **cropped**,
not resampled. The window is now the card's own `min(cw, 56) × min(ch, 34)` of
the pack's **1:1** pixels (still anchored to the creature's top row and centred
across it), which makes a big sprite fill the band at full resolution and drops
the `HEAD_SHARE` machinery (and the whole-divisor rule) from the module. The
worst case was a **wide** creature (an Aegislash, an Escavalier): its width was
more than twice the card, so the width cap forced a second step and shrank the
HEIGHT too, leaving a small sprite floating in a mostly-empty band — the
reported *"bigger sized Pokemon are being scaled down ... show it without
reducing it"*. Sprites that fit the card are unchanged (drawn whole at 1:1), so
the roster still shows one species at one natural size.

**Since 3.8.1 a portrait card starts BELOW a big head decoration.** Some frames
are topped by a large decoration rather than by the head — Kingambit's blade,
Sirfetchd's leek, Aegislash's hilt — and a window anchored to the frame's top
filled with the decoration and cut the face off. g9-battle-sprites **3.5.1**
now measures that decoration from the art and answers it as `frontArt`'s fifth
value (`head`, in the frame's own rows), and `drawHeadSpace` slides its window
down by it. The measurement is agnostic — a leading run of rows that is taller
than it is wide, and at least a fifth of the frame's own height — so short
narrow tips (Pikachu's 6-row ear tips, Onix's 7-row rock tip) are rejected, and
so is every genuinely TALL creature, whose head reaches a real share of its
width within a few rows (Eternatus, Lapras, Wailord, Dragonite, Milotic, Lugia,
Giratina, Alakazam, Samurott). Against the real pack it fires on exactly
Sirfetchd, Kingambit and both Aegislash forms. `head` being `0` — no
decoration, or a copy of that mod older than 3.5.1, which answers no fifth value
— is exactly the 3.8.0 crop.

**Since 3.9.0 every modern screen is protected from the native COLORS / COLOR
display mode.** gen1recomp's OPTIONS > GRAPHICS palette row repaints the whole
finished frame through a 4-shade ramp (Gen 1 through `src/render/PaletteFX.lua`,
Gold through `src/render/GbcPalette.lua`), which destroys this suite's true
colour; the screens here answer `:sgbPalettes()` with an empty list, but two
engine paths still reached them — Gen 1's `ensureZones` fabricates a whole-screen
GRAYS zone whenever the palette owner exposes no zones (the mono / OG / CLASSIC
modes), and Gold's CLASSIC *present* pass tints the frame regardless of what the
state says. Both run through the one `render.zones` seam, so the new
`ui/color_protection.lua` wraps it: when the frame's palette **owner** is a
modern screen — by the engine's own rule, the topmost visible
`:sgbPalettes()` state on Gen 1 and the widescreen layer on Gold, marked with
`__g9gui` / `__g9guiBox` / `__g9guiChoice` / `__g9guiQty` by this suite, or with
the shared `__g9modern` flag a sibling g9 mod sets on its own modern pages
(g9-evolutions' trade / inspector / trade-anim, g9-Battle-Scene's scene) — the
list becomes one whole-screen `colors = false` zone, the engine's true-colour
opt-out, so the page blits with the shader off. `next` still runs the vanilla list first, so the world
and every engine screen are untouched, and the dressed overlays (dialogue card,
YES/NO, quantity) draw in window space *after* the palette pass, so they need no
entry. The **COLOR PROTECTION** row (ON by default) reads live, so flipping it in
the Mod Manager takes effect on the next frame; OFF returns the engine's own list
untouched.

One hand-off matters: the item PC's **DEPOSIT** phase holds a Gold `PackMenu` as
its chooser and the engine's own `drawPanel` drew the pack window **inside** the
item PC. The suite's PACK page is the same idea, so `ui/bag.lua` publishes its
painter (`ctx.Bag.drawGen2`) and the item PC hands the whole page to it, adding
only its own popups on top — painting its own header, storage card and footer
under the pack page doubled the title, the caption and the money readout.

**The storage lists are one page long, and the page only shows the engine's own
window (2.8.2).** Bill's PC's WITHDRAW / DEPOSIT / RELEASE and the item PC's
WITHDRAW / DEPOSIT / TOSS are the engine's `ItemBox` `ListMenu`s, whose cursor
stays in the top **three** rows of its four-row window while `self.scroll`
walks down the list. The skin used to reveal every item from row 1 and mark
`index - scroll`, so a box of 20 mons drew a 634px panel on the 360px page —
the panel and its rows ran off the bottom edge, over the footer — and the
cursor sat on whichever of the first rows `index - scroll` landed on rather
than the selected Pokémon, so A acted on a different entry than the one
highlighted. The lists now use `ui/bag.lua`'s idiom: rows run from
`self.scroll`, the cursor is marked at `index - scroll`, and a **more-arrow**
shows when rows remain. The content band (`Shell.CONTENT_Y` 66 →
`Shell.FOOT_RULE_Y` 314) holds **eight** rows at `row` 30, so `VISIBLE` is 8
(was 9 and unused) and the panel always clears the footer. Gold's item PC list
and mailbox are drawn with the same eight-row budget — their nine-row panels
reached y=340 and painted the footer out. The harness's PC long-list shots
assert the panel's bottom edge clears the footer rule instead of running past
it.

**The window follows the CURSOR, not the engine's `self.scroll` (2.8.3).**
Revealing only the engine's own window (2.8.2) fixed the off-page panel but
pinned the arrow to its third row: the PC lists are the engine's `ItemBox`
`ListMenu`s, whose cursor stays in the top **three** rows (`ListMenu.cursorRows
= 3`, `syncScroll`) while `self.scroll` walks down the list — so the rows slid
beneath a cursor that never appeared to move, and A acted on whichever entry the
arrow sat on. The drawn window is the whole eight-row band now: it follows the
cursor (`win = max(0, index - VISIBLE)`, clamped to `n - VISIBLE`), the arrow
walks all eight rows, and the list only turns over when the cursor reaches the
bottom — the way every other list in the game behaves. The content band
(`Shell.CONTENT_Y` 66 → `Shell.FOOT_RULE_Y` 314) still holds **eight** rows at
`row` 30, so the panel always clears the footer; the harness's long-list shots
assert both the band's position and the panel's bottom edge.

**Every PC window is a page of this suite now (2.8.3).** Three classic windows
remained on Gen 1 and now read as the same page/card as the rest:

* **BoxMenu's mon submenu** — the ACTION / STATS / CANCEL box the engine pushes
  over a box list. It is a bare `Menu` (no id, no kind), so `ui/pc.lua`
  recognises it by its pose — exactly three rows whose second is the `keepOpen`
  `STATS` row and whose third is `CANCEL` — repaints the list page beneath it
  and draws the suite's centred card over it (a menu that adds or drops a row
  simply stops matching and is left to the engine).
* **`QuantityBox`** — the pushed "how many?" stepper (the item PC's WITHDRAW /
  DEPOSIT / TOSS, and a shop's). `ui/quantity.lua` dresses the instance and
  draws the same `Shell.card` in the **page's own space** (the engine's classic
  overlay origin is undone), with the engine's own count; on a classic 160×144
  surface it steps aside and lets the engine draw its own box.
* **`LeaguePC`** — the HALL OF FAME viewer. A bespoke classic screen with no
  menu and no list, so it is recognised by its `screenId` and given its own
  painter (`M.drawLeague`): the recorded mon's front art at its REAL 1:1 size,
  `Lv` and name, and a RECORD card of NAME / LEVEL / TYPE 1 / TYPE 2 beside the
  header's `No N` — the same data `HallOfFame.drawMonInfo` prints on the cart.
  The engine keeps its own A/B flow and cry.

The YES/NO the PC pushes over a page (the item PC's toss confirm) is the
engine's shared `ChoiceBox`, dressed by `ui/choice.lua` like every other one.
(`PicBox` is a generic ModUI picture/text helper — not a PC window.)

### The PC row (`ui_pc_row`)

With the `ui_pc_row` option ON, `ui/start_menu.lua` inserts one synthetic row,
labelled **PC**, into the START rail right after the bag row (`ITEM` on Red,
`PACK` on Gold). Pressing A opens the POKéMON storage system exactly as the PC
standing in a POKéMON CENTER does, so the whole session runs through the pages
described above:

| generation | entry point | what it pushes |
| --- | --- | --- |
| Gen 1 | `game.overworld:openPC()` | the engine's inline whose-PC `Menu` (already claimed by `installOpenPc`) |
| Gen 2 | `game.world:openPc({})` | `Gen2CenterPcMenu`, one of `G2_SCREENS` |

The row is a **mod row**, so it carries no engine id. Gen 1's generic `Menu`
pops the rail before a row's `onSelect` runs (QUIT's flow), so the PC's own
`{PLAYER} turned on the PC.` beat lands over the overworld; Gold's
`StartMenu:choose` does **not** pop a mod row, so the Gold row closes the rail
itself (`M.openPcFrom`) first. The row joins the START rail **and** the POKéMON
page's mirrored rail: the START arm records the label it follows on the game
(`game.__g9guiPcRowAfter`) and `Shell.startRows` mirrors it, so the two halves
of the spread stay identical. The cursor write-back skips the row (it has no
full-row cursor of its own). With the option OFF — the shipped default — neither
rail changes. A build with no PC entry point only logs (the row is a
convenience, never a crash).

### The bag: capacity, guards and pockets (`ui/bag_util.lua`)

The engine's bag is deliberately tiny: 20 distinct slots and a 99-per-stack
ceiling, both straight out of the save format. This suite owns a bigger bag on
top of it, adapted from the **Useful Bag** mod (2.6.4) so the suite does not
have to depend on it.

* **Capacity / guards (both generations).** 300 distinct slots, x999 per item,
  300 PC item stacks. Three registry patches carry it --
  `constants.bagSize` (the distinct-slot count), `constants.itemStackCap` (the
  per-stack ceiling, an unlisted key the engine merges as-is) and
  `field.pcItemCap` (Bill's PC item storage, up from 50) -- plus a `Bag.add`
  shim, because a launched engine build that still hard-codes 99 inside
  `Bag.add` would otherwise refuse the growth the constants already advertise.
  The two `constants` patches apply on both generations; `field.pcItemCap` is
  applied on Gen 1 only (3.2.1) -- a Gold boot's field registry has no Gen 2
  target, so the registration could never apply there and only produced the
  loader's `the field registry has no Gen 2 target` warning, so
  `ui/bag_util.lua` skips it when the context's generation is 2.
  The shim calls the engine's own `Bag.add` FIRST and only repairs the one
  rejection it owns (an existing, positive stack the engine refused for its old
  99 ceiling, or a NEW stack the engine refused for the same reason while its
  own pocket still has room); a genuinely full pocket is left to fail, exactly
  as shipped. A request whose quantity is past 999 adds **nothing** -- the whole
  stack stays where it is, which is the rule the user asked for. `Bag.capacity`
  is also overridden so every pocket reports 300 (Gen 2's per-pocket table
  otherwise keeps BALLs at 12, KEY ITEMS at 25 and the TM/HM case at 57).
* **Six pockets (Gen 1 only).** Gen 1's engine has ONE flat bag; Gen 2's engine
  already has four pockets of its own, so the six-pocket projection is Gen 1's.
  The pockets -- ITEMS, MEDICINE, POKé BALLS, TMs/HMs, BATTLE ITEMS, KEY ITEMS
  -- are *views* of the same hidden bag (`save.inventory` + `save.bagOrder`),
  never a second store: key items, scripted `CheckItem`, the PC deposit and the
  HM gates all keep reading the real inventory. An item is classified by its
  ROM flags first (`def.keyItem`, `def.machine`) with fallback id sets for
  fixture / mod items; the POKé FLUTE is the one contextual exception (BATTLE
  ITEMS in battle, KEY ITEMS outside).
* **Input.** LEFT/RIGHT cycles the pockets and wraps at both ends. SELECT still
  reorders -- but pocket-safely: the two visible rows are translated back onto
  the hidden order before the swap (`Bag.move`'s list indices would only be
  correct if the list WERE the whole bag). TAB (aliased to SELECT by the input
  map), R3 / right-stick click and the touchscreen SELECT overlay open the sort
  card (SORT BY NAME / SORT BY COUNT), which rewrites that same hidden order;
  the presses are swallowed by an `Input` wrap installed at `game.ready` so they
  cannot ALSO swap an item. The bag re-projects itself whenever the engine
  rebuilds its rows (the TOSS flow's `itemMenuLoop` writes the full bag back),
  so a pocket can never silently widen.
* **Battle bags are left alone.** `Shell.inBattle` already tells `ui/bag.lua`
  that the wide battle owns the surface; the pockets are not applied there, so
  the classic in-battle bag keeps its flat rows and its own item flows.
* **Useful Bag wins.** If `mod.find("useful_bag")` answers, the module logs the
  decision and stands down completely -- no capacity patch, no `Bag.add` shim,
  no pocket projection -- so installing both mods can never leave two patches
  fighting over one constant or two pocket views stacked on one list.
* **Layout.** The pocket strip is 24px tall at the top of the content band
  (`Shell.CONTENT_Y`), with the same chip language as the Gen 2 PACK's tabs; a
  pocketed bag then draws seven rows at 30px instead of seven at 34 so the list
  still clears the footer rule, and the header title becomes the pocket's name.
  The sort prompt is `Shell.card`, the suite's shared popup, not a pushed engine
  menu.

Verified in a fengari harness (`scratch/bagutil-probe.lua`) against the REAL
`src/inventory/Bag.lua`: 61 checks, 0 failures -- classification of every
category (key item / TM / ball / medicine / battle / generic, and the POKé
FLUTE's in-battle exception),
the three patches, the pocket caps, the shim's repair and its refusals (x1000,
a 1201-item request, a full 300-slot pocket), the sort and swap writes, the
projection, L/R wrapping, the self-heal and the whole sort flow.

### Text safety (the UTF-8 scrub)

A player crash report -- `ui/theme.lua: UTF-8 decoding error: Not enough space`,
raised while scrolling the Gen 2 PACK's pocket tabs -- came down to LÖVE's text
engine: `Font:getWidth` and `love.graphics.print` raise the moment a string is
not valid UTF-8, and every measurement and draw in this suite goes through one
of those two. A label can arrive from anywhere (a save, a mod's own item name, a
ROM string that was cut mid-glyph upstream); `Theme.scrub` now runs in all four
text entry points -- `Theme.w`, `Theme.text`, `Theme.fit`, `Theme.wrap` -- before
anything reaches LÖVE. A malformed byte becomes U+FFFD and an incomplete tail is
closed off, so the worst case is one replacement glyph instead of a crashed
screen. The same byte rules the engine's own `Manifest.scrubUtf8` uses (no
overlongs, no surrogates, nothing past U+10FFFF) are applied, and an ASCII-only
fast path keeps the common case free. The fengari probe
(`scratch/theme-probe.lua`, 16 checks, 0 failures) runs the module against a
stand-in font that RAISES on malformed input exactly like LÖVE's, and proves
every entry point survives a mangled label while the ellipsis cut still lands on
a whole UTF-8 boundary.

### Fitting the text

Five rules keep a page from showing half a sentence. Four were prompted by the
PC screens and all are suite-wide.

* **A footer notice is never the thing that gives way.** `Shell.footer`'s `right`
  readout is cut to whatever the hint chips leave, so the PC's own mode keys
  became chips of their own (and `Shell.footer` now takes a `gap`).
* **A header caption steps down a rung before it is cut** (`Shell.top`: body →
  small → tiny → `Theme.fit`). The bag's "Choose another item to swap with."
  used to read "…swap …". A screen that wants **no** caption at all (the MOD
  MANAGER's list screen — the tab strip takes that line — the scrolled START
  rail, the PC box release screen) passes `nil`, and `Shell.top` coerces that to
  the empty string before it measures: `Theme.w` measures through the real font,
  and a nil string is an argument error in LÖVE, not a zero-width measurement
  (2.8.1 — the nil caption used to crash the MOD MANAGER on open in every game).
* **A list label steps down a rung before it is cut** (`Shell.list`), so the
  BLACKLIST's `MEGA CHARIZARD X` rows are whole.
* **A label/value pair in a narrow card steps BOTH parts down**, so the
  whose-PC RECORD card's `MONEY` is not cut to `MON…` beside `¥12500` (that card
  also grew to fit its five rows).
* **A popup body wraps inside its card** (`Theme.wrap`, used by both modal
  painters) instead of being cut — the Gold change-box question reads in full on
  two lines.

The harness enforces all of it: *no footer string ends in a truncation
ellipsis*, *no label anywhere is cut with one*, *no page paints a literal `nil`
label*, *no string reaching `Theme.w`/`Theme.fit` is nil* (the stand-in font
raises on a nil string exactly as LÖVE's `Font:getWidth` does — with the 2.8.1
guard removed the harness reports eight failing shots), *the item PC's DEPOSIT
page draws the PACK exactly once*, and *the RECORD card's five rows stay inside
their card*.

### One-confirm A (the Pokédex listing)

Reading a species used to take **two** confirms even though this page's footer
has always said `A VIEW`: the engine's own chooser (`PokedexMenu.onChoose`) is
the **DATA / CRY / AREA / PRNT / QUIT side menu**, so A opened that unstyled
GB popup and A again opened the entry from its DATA row. `ui/pokedex.lua` now
sets the **instance's** `onChoose` to the first row of that menu — it pushes the
very `DexEntryMenu` the engine's DATA pushed — so a species is one confirm
away. The three actions that side menu had and this page does not are covered
already: the cry plays on the entry's own opening beat, and B is the QUIT row's
close (the header/caption hints still name every key the page uses). An unseen
row carries no species id and still answers nothing, exactly as the engine's
chooser did.

The override is set on the **instance only** — never on `PokedexMenu` itself —
so the engine's class keeps its own chooser for any other screen that shares it,
and national_dex's search screen, which calls `list.onChoose(item, list)`, opens
its results in one confirm too.

### The POKéDEX's number order

The POKéDEX listing is **the whole roster in number order, 001 upward to the
last entry the game defines, whatever that number is** — and nothing can
override that order. Two things used to decide which rows you saw and in what
order, and both are now ignored:

* **The engine's highest-seen frontier.** `src/ui/PokedexMenu` builds its list
  only up to `wDexMaxSeenMon` (`engine/menus/pokedex.asm:200-216`), so a save
  that had seen up to #30 listed thirty rows. `ui/pokedex.lua`'s
  `numericItems(game)` rebuilds the array from `game.data.pokemon` itself:
  every record whose `def.dex` sits inside `constants.dexSize`, numbered
  `%0Nd` with the same `dexDigits` the engine uses, each row carrying the same
  `{ num, name, label, ball, value }` shape the constructor built, and the
  unseen ones still printed as `----------`. Form records are excluded on
  purpose — national_dex numbers them far above the roster (`FORM_DEX_BASE`),
  so the roster stops at the last real entry. The SEEN/OWN tallies are the
  engine's own and stay untouched.
* **national_dex's SELECT view modes.** The peer reorders the engine's item
  array underneath this page (`num` / `A-Z` / `SEEN`). The listing's update
  wraps the game's input in `noSortInput`, a pass-through that reports
  `wasPressed("select")` as never pressed, so the peer's view-mode wrapper —
  which rides that one key — never runs and the array is never reordered.
  Every other key (the cursor's UP/DOWN, the page jump's LEFT/RIGHT, A, B,
  START's search) reaches the real input untouched. There is no mode left to
  name, so the header shows only `SEEN n OWN n`; the caption states the order
  and the key the peer still keeps (`Listed by number   START: SEARCH`).

**On Gen 2 (Gold)** the same rule is enforced against Gold's own three modes.
Its listing opens in whatever `save.lastDexMode` held — `NEW` is *Johto* order
and prints the numbers out of sequence — and its SELECT opens an OPTION screen
that changes it. `M.newGen2` pins `self.modeIndex` to whichever index answers
`OLD` (the national / number order) and rebuilds before the first draw, and the
same `noSortInput` wrapper hides SELECT, so the OPTION screen is never entered
and the order cannot change. `drawOption2` is kept as a fallback for anything
that sets the view directly. `g2header` right readout keeps its `SORT OLD`
label; the caption is now `START: SEARCH`.

### Re-skinning screens this mod does not own

The TRAIN editor belongs to **g9-battle-engine** and the BLACKLIST window to
**g9-battle-sample**. Neither mod is edited, and neither is reimplemented here:
`main.lua` wraps `src.core.StateStack.push` (the one choke point every state
goes through) and, when the pushed state's `screenId` is `G9Train` or
`G9Blacklist`, calls that skin module's `dress(state)`. The engine's own
dialogue window (`src.render.TextBox`) has no screen id at all — it identifies
itself with `isTextBox` — so the same wrapper catches it on that marker and
calls `ui/textbox.lua`'s `dress(state)`. The Gold item flow
(`src.ui.gen2.HeldItemMenu`, screen id `Gen2HeldItemMenu`) is caught the same
way and handed to `ui/held_item.lua`, and the engine's YES/NO box
(`src.ui.ChoiceBox`, identified by its own class) to `ui/choice.lua` while it
sits over a conversation this suite already dressed.

Dressing amends the
**instance only** — `draw`, `uiSize`, `isWideBattleLayout`, `wantsFillScale`,
`sgbPalettes` and the opacity flag — so the owner's own `update`, state machine
and data writes keep running untouched. The TRAIN's staged-vs-committed diff,
its fee arithmetic, `ModernStats.recalcAll` and its move-teaching rules are
still the engine's; the BLACKLIST's filters, cursor and every
`blacklistToggle` / `blacklistGenToggle` / `blacklistReset` are still the
sample's. The wrapper is installed once (guarded by a marker on `StateStack`)
and each skin fails independently through `attempt()`. On a Gen 2 boot the same
wrapper dresses the Gold side: `ui/train.lua`, `ui/blacklist.lua` and
`ui/textbox.lua` each branch on the generation and swap the surface seam
(`:uiSize` on Gen 1 vs `Shell.gen2Surface` on Gold), while `ui/held_item.lua`
is Gen 2 only (it keys off the `Gen2HeldItemMenu` id, which does not exist on
Gen 1) and `ui/choice.lua` dresses the shared `ChoiceBox` class on **both**
generations since 2.6.7. Since **2.6.4** the
wrapper also forces a **no-op `:draw`** onto any dressed state that answers
`:drawsWidescreen()` and carries the `__g9gui` flag, so `Game2:drawScene` can
never blit a taken-over page's own classic draw under a message card. See
`GEN2-PORT.md` for the port plan.

`ui/textbox.lua` is deliberately the one skin that does **not** grow its
surface, and since 2.2.0 it does not draw in that surface either unless it has
to. A dialogue box is pushed over the overworld or over a battle, and both draw
their own pass at the classic scale: declaring `uiSize` here would either send
the overworld's world pass through `Game:draw`'s `classicOffset` or blit the UI
at a different scale than the map under it — and, worse, a bigger UI surface
lowers `Renderer:fitScale` (it is `floor(min(pw/uw, ph/uh))`), which the WORLD
pass sizes itself from, so the map would visibly zoom out. The card's geometry
is therefore still written in the box's own 20×6-tile rect in 160×144 UI
pixels. Since **2.3.4 its body is the suite's own face**, drawn by this module
at the window's own size on **every** engine — Saira 10 on the surface, Saira
built at the renderer's scale (30 at 3×) in window space. (2.3.3 had briefly
handed the body back to the engine's `src.render.Font.draw` when the engine
reported a TTF; that printed gen1recomp's 8 px Plain Pixel as an upscaled
bitmap — low density, visibly blocky — and is deliberately gone.) The body is
Saira 10 — a 7 px cap, a touch under the engine's vanilla 8 px tile glyph; it
shipped at 11 through 2.2.0, was raised to 13 in 2.3.0 and settled at 12 in
2.3.1 — stepping down to `boxSmall` (9) if a page still will not fit. Saira 10
fits **more of each message per line**, not just smaller type, because the skin
**re-pages** the box at Saira's own width instead of the engine's 18 tile cells
(`TextBox.paginate` budgets `maxCols × 8 px` for the vanilla 8 px glyph, so it
would hand back the same 18 glyphs at any size, leaving a third of the card's
text width empty under Saira). `installWrap` wraps the engine class at load, capturing the clean
display text (tokens resolved, `{PAUSE}` stripped) that `TextBox.new` hands to
`paginate`; `reflowBox` then re-runs the engine's **own** pagination — same
`\n`/`\v`/`\f` split, same glyph-boundary soft-wrap with last-space preference,
same `pages.contBefore` scroll flags, same trailing-empty-line trim — with each
span measured through `Theme.w` in the face that will actually draw. A line the
engine broke at 18 glyphs runs to about 29 at Saira 10, so the two-line card
shows roughly half again as much text. It is skipped (engine pages kept) for
`instant` boxes and any box carrying pause markers, whose `pauseAt`
`[page][line][charIndex]` table is timed against the engine's own code stream,
and it fails open — no engine class, no font, or a `pcall` error keeps the
engine's pages and the card still draws.

What changed is WHERE those pixels are rasterised. `paint` renders the card
through a *space* — an origin plus a per-UI-pixel scale plus the font set built
for it — and there are two:

- the **surface** space (identity, `Theme.fonts`), used for a box over a wide
  surface and as the always-available fallback;
- the **window** space, subscribed through the engine's `render.hud` hook
  (`M.installHook`), which paints the card after the frame's composite at the
  renderer's own scale, from fonts rebuilt at that scale by `Theme.fontsAt`.
  The panel rect lands in exactly the same screen pixels as before (same UI
  geometry × the same scale), so the box is the same size against the
  background — but the hairline border, the corner brackets and the type are
  drawn at native resolution instead of being composed as a 160×144 bitmap and
  upscaled several times.

The window path is *enabled* whenever the engine's own placement of the region
can be reproduced exactly — which is now both UI layouts, not just the centred
one. `spaceOrigin(r, R)` asks `letterboxed(r)` (`r.uiCentered == true`, or
`r.uiAnchorHold == true`, the two cases where `setUIAnchor` is a no-op) whether
the region still sits in the classic letterbox and answers with the letterbox
origin `uox, uoy`; otherwise it answers with the docked origin
`uox, vuy + vuh - uih*Uy`. (Under a DYNAMIC layout the engine docks the box
region to the window's bottom edge; the derivation is the engine's own anchor
math — for a `"bottom"` anchor the box is flush to the UI canvas bottom, so
`gapB = 0` and canvas pixel `(a.x, a.y)` lands at `dx = uox + a.x*Ux`,
`dy = vuy + vuh - a.h*Uy`, leaving the canvas origin at `uox, vuy + vuh - uih*Uy`.)
Both also require no wide surface on the stack, and that the box is the stack's
own drawn box (the top, or the box directly under its YES/NO `ChoiceBox`).
Before 2.3.5 only the letterbox case qualified, so a DYNAMIC layout fell back to
the 160×144 surface card and every glyph was upscaled several times — the
"low quality text" the card is meant to avoid. The **MONEY** card is never
anchored (the engine blits it in the letterbox), so `hudDraw` gives it its own
space at the letterbox origin while the dialogue card travels down with the
docked region. The latch is fail-open: the surface draw is only skipped once the
engine has actually called the hook, so on an engine without `render.hud` — or if
the subscription fails — every box keeps the (chunkier) surface card rather than
disappearing. The YES/NO box is re-skinned by `ui/choice.lua` (Gen 2 since
2.6.4, both generations since 2.6.7), which reads this card's own space through
the exported `M.hudSpace` and draws its rows in the same window space; a bare
prompt or a battle's switch offer is left to the engine.

The skin dresses a box over a wide surface **when that surface is one of this
suite's own pages** (2.8.4) and refuses everywhere else. Both used to be one
case: `Game:draw` derives its classic offset — `floor((Renderer:uiSize() - 160)
/ 2)` — from `Game.wideBattleInStack(stack)`, which matches ANY state answering
`:isWideBattleLayout()`, and this suite's pages answer it. A box pushed over a
page was therefore read as "a wide surface → keep the classic box", the white
160×144 window landed mid-page, and under a DYNAMIC layout the engine's
`Renderer:endFrame` additionally `subtractRect`-ed that box's classic rect out of
the page's blit and re-blit it against the window edge, punching a white hole
where the box had been. `Textbox.surfaceIsWide` now asks the wide state under the
box whether it is ours (the `__g9gui` marker each takeover's surface carries), so
a real battle's 304 px surface and other mods' wide pages still keep the
engine's drawing, while one of ours gets the card below.

**A box over one of our pages (2.8.4).** With the box dressed, the card must be
painted in the PAGE's own space rather than in window space: the page is a
540×360 surface the renderer blits at the window-fill scale, so a card drawn at
the window origin would land in the wrong place. `Textbox.pageOffset(game)`
reads the engine's own classic offset through `Shell.pageOffset` and, when it is
exactly the suite's page offset (`(Shell.W - 160)/2` = 190), the box's own draw
translates by `-off` and paints `paintPageCard` — the same `Shell.card` the
START and PC pages wear, sized 420 wide, carrying the box's non-empty visible
lines plus the breathing down-chevron when more text follows — then returns,
with `Theme.set(C.white)`. That offset is also the signal for the rest of the
module: `hudSpace` and `hudWillPaint` answer `nil`/`false` while `pageOffset > 0`
(so the window-space card can never double-draw over a page), and the classic
`r:setUIAnchor(boxTx*8, ...)` edge anchor is declared **only** when the offset is
zero — that anchor is what made `Renderer:endFrame` carve the box's rect out of
the page's blit, so suppressing it is the other half of the white-hole fix. A box
over a battle or over the engine's classic surface keeps the previous paths
untouched. `ui/choice.lua` takes the same offset into account, so a YES/NO pushed
over a message pushed over a page draws ONE card: it reads the question lines
from the dressed TextBox beneath it (`Textbox.pageLines`, the visible lines with
blanks dropped) instead of re-rendering the message, exactly as Gold's own PC
`g2modal` does.

`ui/train.lua` reads the engine screen's public fields (`mode`, `page`, `focus`,
`row`/`col`, `ivs`/`evs`, `nature`/`gender`, the move pool, `pending` /
`pickingSlot` / `abilityConfirm`, `status`) and its methods (`preview`,
`pendingCost`, `abilitySlot`, `abilitySwapInfo`) through `pcall`, so a future
engine tweak degrades a row instead of breaking the page. The staged total comes
from the engine's own `:pendingCost()` and the ability prices from
`:abilitySwapInfo()`, so the displayed figures are the engine's. Since **3.3.3**
the page marks exactly ONE button as selected at a time -- the one under the
cursor, drawn in the accent ink with the lit fill, lit border and a shadow.
Every other pill is plain: the current tab once the cursor leaves the strip, the
nudge row when the cursor is elsewhere, the NAT/gender value, APPLY and the move
categories. That is the engine's own rule (its native strip double-frames ONLY
the cursor) and it matters because the first cut of the skin dressed the cursor
AND the current page/value in the same accent, so putting the cursor on the nudge
row left the tab, the nudge column and APPLY all lit at once. The page's current
tab is not colour-marked, exactly as the native strip does not mark it: the
page's own body says which one is open (the IV/EV nudge sets differ, NAT and the
gender page print their value, and the moves page prints `CATEGORY` in its detail
panel). Because the
sample does not export its blacklist accessors, `ui/blacklist.lua` reads the
persisted set directly from `game.save.modData["g9-battle-sample"].blacklist`
(the `mod.save` backing) and rebuilds the same gen-complete computation over
`game.data.pokemon` — plus, since 2.6.5, the same per-form-group complete
computation for the `MEGA` / `GIGA` row — read-only; every write still goes
through the sample's own update path.

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
install.

**The prefix is pinned to the root for the one call.** `CacheFs` carries a
process-global `prefix` that the boot sets to the active version's cache folder
(`"red/"` on Red, `"gold/"` on Gold), so a bare `CacheFs.write` files the same
export under a different subtree per generation — the file does not land where
the notice, this README, or the Gen 1 export put it, which reads as a broken
export on Gold. Stepping the prefix to `""` for the call is the engine's own
idiom for a tree that is shared, or that is not cache data at all:
`src/mods/LauncherMods.lua` pins it before touching the shared `mods/` tree, and
`src/mods/RequiredImports.lua` before writing its receipts ("the mods tree is
shared by Red and Blue, so pin the prefix to the root"). Pinned, the name has no
directory part, so the call is a plain root-level write and the log lands in the
save folder beside the engine's own `profiles/` and `exports/` folders — the
same place on both generations. `M.writeLog` saves the previous prefix, writes
inside a `pcall`, and **always restores it** (also in the `pcall`), so a throw
cannot leak the global state into the rest of the run.

If an engine has no usable `CacheFs` — or the write is refused — the export
falls back to `mod.cache:write`, the engine's documented installation-scoped
byte store (`mod_cache/<mod-id>/`), which is deliberately **not** scoped to a
game version, so the file is still in one place on every boot. Only when both
seams fail does the action report `EXPORT FAILED`.

`M.errorLogText` is built inside a `pcall` as well (it reads the loader's status
tables, and a malformed status must not take the manager's update down with it),
and every failure is logged with its reason through `mod.log` before the short
notice is shown. The action rides the manager's own notice slot —
`SAVED g9-gui-error-log.txt` on success, `EXPORT FAILED` otherwise. The row is
injected by wrapping `rowsForScreen` (a fresh copy, never mutating the base
list) so the cursor, `focusedRow` and `activate()` all see it.

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
wants it needs engine support for vertical centring. Since **2.8.4** that no
longer matters for this suite's own pages: the box is dressed and its card is
painted in the PAGE's own space with the classic offset undone, so it lands
where the page wants it instead of where the engine's horizontal-only centring
puts it. Over a BATTLE's wide surface — or another mod's wide page — the skin
still declines and the engine's drawing stands.

### Type (the FFXII match)

The menus are set in **Saira** (Regular for body copy, SemiBold for titles,
levels and stat values) — a free, close stand-in for the **Final Fantasy XII:
The Zodiac Age** party-screen face. The real FFXII font is a commercial
typeface and cannot be redistributed, so this mod ships its own: Saira is a
humanist sans with the same low-stress, slightly squared bowls, a tall x-height
and narrow-ish caps, and at 22 px it reads as the same kind of type without
being a copy. The scale is one body size (22), one secondary size (13) and one
caption size (10 — the roster's `Lv`), exposed by `Theme.fonts` as
`body`/`bold`/`small`/`tiny`, plus a `smallBold` (SemiBold at 13) for figure
text on small cards and a `box` (10, with a `boxSmall` at 9) for the dialogue
window's body — the one surface that is not the 540×360 page, where 22 would
not fit two lines, and the only rung also built at a *multiple* of its size
(`Theme.fontsAt`) for the window-space card. That dialogue body is drawn on
every engine: the box paints its own Saira at the window's own size (2.3.4 —
2.3.3 had briefly borrowed the host engine's TTF, which printed its 8 px pixel
face upscaled and blocky). The two TTFs
(plus SIL OFL 1.1) live in
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

Every card body — including the dialogue box's — goes through `Theme.text`,
so the ink-offset path places the dialogue ink on exactly the rows the
layouts intend; the window-space body measures the same offset in window
units. (2.3.3's `Font.draw` handoff, which delegated that placement to the
engine for a TTF host, was removed in 2.3.4.)

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
| `sprites` | the pack's front battle sheet `assets/front/<STEM>.png`, baked to frame 1 trimmed to itself | `frontArt(mon)` → `(image, w, h, box)` |
| `icons` | the pack's own 64×64 HD party-icon cells `assets/icons/party_icons_hd.png`, the pack's frames at their natural 1:1 size | `iconArtHD(mon, frame)` → `(quads, image, cell, box)` |
| `icons` (older pack) | the pack's 16×16 party-icon atlas `assets/icons/party_icons.png`, a 4:1 point-sampled copy of those frames | `iconArt16(mon, frame)` → `(quads, image, cell)` |

* `sprites` mode draws the **head space** of the pack's frame 1, **anchored to
  the creature** through the content box the export answers: `frontArt` bakes
  frame 1 **alone**, trimmed to that frame's own pixels (g9-battle-sprites
  **3.1.2+**), so the frame's top IS the creature's top, and it answers that
  frame's own content box as a fourth value. A frame that fits the card is
  drawn whole at the pack's **own pixels, 1:1**, centred; a frame **bigger than
  the card is cropped** to the card's own 56×34 band — its head fills the band,
  its sides cropped as needed — and is **never shrunk** (see *The head crop*
  below). **Nothing is ever zoomed or resampled**, and 1:1 is what keeps the
  sheets' relative sizes reading true (a Weedle stays a Weedle beside an
  Amoonguss) — the same natural size the battle screen draws — so the old
  per-frame whole multiple (`ceil(w / frameW)`) that blew the *smallest* sheets
  up hardest stays gone. The bake is asynchronous (that mod's `core.update`
  budget), so the first call answers `nil, pending` and the next frame gets the
  art. `pending` is kept through the call, so those frames leave the card to the
  pack art rather than flashing the engine's own pic; the engine fallback only
  covers a species the pack has no sheet for (which answers `nil` with no
  `pending`).
* `icons` mode draws the pack's **party-icon art at its REAL size**: the
  **64×64 HD cell** (`assets/icons/party_icons_hd.png`, the pack's own frames —
  the 16×16 atlas is a 4:1 point-sampled copy of exactly those frames) at its
  own **1:1 pixels**, cropped to the card through the same `drawHeadSpace` rule
  the front sheets use: anchored to the creature through `iconArtHD`'s own
  content box (those frames are bottom-anchored, with spare transparent rows
  above the creature), centred across the card, integer divisors only. The
  cells' own content is 30–60px against a 34px card, so in practice the window
  is the card's own 56×34 at 1:1 — **the whole icon, at its natural size**. It
  used to fit the 16×16 atlas into the card instead, which — even at the card's
  largest whole multiple — drew every party icon at **half** the pack's own
  pixel scale, so the creature sat as a small figure in a big card beside the
  battle-sprite portraits (the reported *"icons come out shrunken"*). A cell
  whose whole 64×64 IS opaque answers no box (there is no box to speak of); the
  cell itself is the box then.
* **ICON portraits are STILLS** (3.3.2). The pack (and the game's own icon
  sheets) carry two frames per icon, and the card always shows the **resting
  frame**: it is asked for explicitly — `iconArtHD(mon, 0)` /
  `iconArt16(mon, 0)`, g9-battle-sprites **3.4.0+** — so the card cannot inherit
  that mod's own `SPRITE FPS` icon animation either. An older g9-battle-sprites
  ignores the argument and keeps answering its live frame. (A `PORTRAIT
  ANIMATION` choice row shipped in 3.3.0/3.3.1 and was **removed in 3.3.2**;
  there is no animation option.)
* **older copies of the sprites mod** still work: a copy with no `frontArt`
  falls back to `iconArtHD(mon)` — the pack's **true-colour, high-resolution
  64×64 frames** (`assets/icons/party_icons_hd.png`, bundled with that mod) —
  cropped for `sprites` mode (the same head crop); and a copy with no HD cell
  either gets the **16×16 atlas** fitted into the card for `icons` mode, which
  is the best that copy can offer. `iconArtHD` answers
  `(quads, image, cellPixels, box)`; `box` is the `{x, y, w, h}` bounding box
  of the frame's opaque pixels, and the crop anchors to `box.y` because those
  HD icon frames are bottom-anchored with spare rows above the creature (the
  front sheet's own box is the whole image, because its trim already IS the
  content).

**The head crop.** A portrait is a head-and-shoulders reading of a creature
that may be several times the card's height, so `drawHeadSpace` takes only what
it must. With the frame's content box it pins the window to the box's **top**
and centres it horizontally, and takes the card's own `min(cw, 56) × min(ch, 34)`
of the pack's **1:1** pixels. A creature bigger than the card is therefore
**cropped to the band, never scaled down**: its head fills the card at the
pack's own resolution, and its sides may be cropped — exactly right for a head
portrait (an 87px Wailord reads perfectly as a centred 56px window of itself).
A creature that fits is drawn **whole**, so the roster keeps one species at one
natural size (a Weedle stays a Weedle beside an Amoonguss). Nothing is ever
resampled: 1:1 in, 1:1 out, so pixel edges stay hard. **3.8.0** replaced the
whole-*divisor* step-down that used to live here (the smallest `d` with
`d = ceil(ch · HEAD_SHARE / h)` — `HEAD_SHARE = 0.45` — and a `ceil(cw / (w · 2))`
width cap): a big frame was drawn at `1/d`, and because a width heavier than
twice the card forced a *second* step that shrank the HEIGHT too, a wide sprite
(an Aegislash, an Escavalier) landed as a small figure in a half-empty band —
the reported *"bigger sized Pokemon are being scaled down ... show it without
reducing it"*. Every big sprite now fills the band at the pack's own pixels.
**3.8.1** adds the head **DECORATION** offset: g9-battle-sprites **3.5.1**
answers a fifth `frontArt` value — `head`, the height in the frame's own rows of
a leading decoration (Kingambit's blade, Sirfetchd's leek, Aegislash's hilt) —
and the window starts that many rows down, so a decorated creature's card shows
the FACE instead of a blade. `head` is `0` for every other creature, and an
older copy of that mod answers no such value at all, so the crop is unchanged
there. This is why a genuinely TALL creature is unaffected: `head` is measured
from the ART — a leading run of rows that is *taller than it is wide* and at
least a fifth of the frame — never from a species list, and a tall creature's
head reaches a real share of its width within a few rows (Eternatus' 33 of 89px
by row 12, Lapras' 26 of 62 by row 2, Wailord's 52 of 86 by row 16), so it
answers 0. A pack **older than
3.1.2** answers no content box (its bake was the whole animation's union), so
the card keeps the previous best-effort window — the card's top 8% down — and
logs ONE line naming the version to update. Nothing better can be computed from
that union bake, because LÖVE 11.5 has no Image pixel readback
(`Image:newImageData` / `Image:getData` do not exist there) and a mod cannot
read another mod's files; the box has to come from the bake itself.
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
  cards in colour even with no downloaded sheets. A separate, later line covers
  the second case: a 3.0.8–3.1.1 sprites mod HAS the exports but answers **no
  content box** from `frontArt` (its bake is the whole animation's union), so
  the anchored window cannot be computed and the module logs ONE notice (`g9-battle-sprites
  <version> trims party portraits to the whole animation instead of to frame
  1 -- … (update it to 3.1.2+, keeping your downloaded assets/front sheets)`),
  after which the card keeps the 8%-down window — the only crop a union bake
  allows.

Everything is clipped to the card with `love.graphics.setScissor`, so a
mismatched atlas can never spill into the next column. On **Gen 2** the scissor
rectangle is computed from the page's own transform — the window-space pixels
the 540×360 page is scaled into — because LÖVE's scissor ignores graphics
transforms, so a raw page-space crop would land in the wrong place; the card
crop therefore sits in the same pixels on both generations.

**Both generations use both presentations.** The pack's front sheet and its icon
atlas answer for a Gold species exactly as they do for a Gen 1 one — and since
**2.6.2** the module no longer forces the `icons` presentation on a Gold boot —
so `sprites` mode draws the pack's front-art head crop on Gold too. Only the
**engine fallback** differs: Gold has no Gen 1 front-pic table for
`src.pokemon.Sprites.path` to read, so `sprites` mode's engine fallback on a Gold
boot is Gold's own party **icon** (the same picture `icons` mode would show)
rather than the game's front pic, and never a `?`. That path is reached only for
a species the pack has no sheet for, or with no sprites mod at all.

### National Dex compatibility (`ui/national_dex.lua`)

With the **national_dex** mod installed, its Pokédex is the game's: it patches
`PokedexMenu` and `DexEntryMenu` in memory (its files are loaded after the
engine's own but **before** this mod's, which sits at a higher load priority),
so its 1025-species roster, its START search screen, and — on a species — a
STATS page and an evolution/learnset strip behind the engine's description page
are all there. This mod draws that roster and those entry pages on its own
540×360 page while every line of the peer's logic keeps running; nothing in it
is reimplemented or patched. The one thing it does **not** follow is the peer's
SELECT view modes: the suite's listing is the number order, 001 to the last
entry, with SELECT masked (see *The POKéDEX's number order*).

The seams it relies on, in order of how load-bearing they are:

* **A peer mod's files cannot be read.** `love.filesystem` is closed to mods
  and `mod:read` only sees the caller's own folder, so another mod's Lua is
  simply not reachable. The one channel is `mod.find("national_dex")`, which
  answers a handle whose `exports` are functions the peer published — here
  `statsBySpecies(id)` (a copy of the species record plus its abilities, full
  move pool and every learnset) and `evolutionsOf(id)`. `M.installed` is true
  only when the handle exists **and** `statsBySpecies` is a function, so an
  older or broken copy degrades to the vanilla page instead of erroring.
* **Its view modes do not reach this listing.** The peer reorders the engine's
  item array on SELECT (`num` / `A-Z` / `SEEN`), reading the mode from a closure
  local it never exposes. The suite's listing is the number order instead — it
  rebuilds the array itself and masks SELECT from the peer's wrapper (see *The
  POKéDEX's number order*) — so nothing here has to read that mode.
* **Its STATS mode is a saved option.** `modern` shows separate SP. ATK /
  SP. DEF rows, `gen1` one combined SPC row. The value is read from
  `SaveData.loadOptions().modOptions.national_dex.stats`, memoised and
  `pcall`-guarded, defaulting to the peer's own `modern`.
* **Its page length is 12 rows.** The peer's update clamps its own `self.page`
  against the last page it computed, so a learnset this page paginated
  differently would desync both. `ROWS_PER_PAGE = 12` matches its constant and
  `paginate` cuts every section the same way.
* **The description and the strip share one counter.** The engine's
  `DexEntryMenu:update` pages the description through `self.page` (the original
  151 keep their `\f`-broken cart text, so several of them run to two pages),
  while the peer reuses that same field for its strip. In nd mode
  `ui/dex_entry.lua` therefore keeps its **own** two counters (`__g9strip`,
  `__g9desc`) and, on a frame A/B/UP/DOWN is actually pressed, wraps the game's
  input so those four keys read as unpressed for the length of the inner
  update (`maskedInput`). Both of the inner updates then see a quiet frame and
  neither pager moves; the wrapper drives the composite itself — UP/DOWN walk
  the entry's pages (1 = description, 2 = STATS, 3+ = strip), A/B page the
  description and then close. LEFT/RIGHT is never masked, so form cycling over
  the species' alternate forms stays entirely the peer's own.
* **The strip's pages.** The entry's page 1 is the description (footer
  `PAGE d/D` while it has more than one); page 2 is STATS (portrait over the
  type rows, an ABILITIES panel, and a bared base-stat block whose row height
  follows the space the abilities leave — the panel is a **hard budget**, so
  the rows are always sized to fit inside it: a three-ability species with the
  modern split special stats, seven rows in a column the abilities have already
  crowded, is exactly the case that used to push its TOTAL row through the foot
  rule and no longer can); pages 3+ are one strip section each
  (header `PAGE n/N` for the position in the whole entry), a full-width list
  indented per evolution depth with `HIDDEN` tags and per-method move groups.
  Each of those drawers runs under `pcall` and falls back to the description
  page, so a malformed record costs one page, not the screen.
* **Its search screen is left as the peer ships it.** That screen is built
  directly and pushed onto the stack rather than registered in the screens
  registry, and its file cannot be read, so there is no seam to dress it
  through; it keeps its own 160×144 GB drawing (fully functional). See *Scope*.

**On Gen 2 (Gold)** the peer works differently: Gold has no separate entry
menu, so the peer patches Gold's own `src/ui/gen2/PokedexMenu` **class** in
memory (`mod/src/gen2dexlist.lua`), widening its listing past 251 and adding
its alternate-form browsing and its STAT and LVL views. Because the class
itself is patched, this mod's `Gen2PokedexMenu` arm builds that patched class
and the peer's widened `self.rows` flow through the suite's listing by
construction — pinned to Gold's `OLD` (number) order, with SELECT masked, so
the row numbers run 001 upward to the last entry (see *The POKéDEX's number
order*). On the entry screen `ui/pokedex.lua` reads the peer's own state
— the browsed form (`self.formId`/`formBase`/`formList`/`formIndex`), the
selected bar slot (`self.entryAction`) and the LVL page (`self.movePage`) — and
names the form in the header caption beside the species' kind
(`KIND · MEGA X 2/3`, the index counted off the peer's own list), offers the
`↑↓ FORM` footer hint whenever the species has forms (off the peer's `formsOf`
export), and widens the action bar to the peer's six slots (PAGE / AREA / CRY /
PRNT / STAT / LVL — the order is load-bearing, because the peer dispatches A
off the slot index) as a pixel window that slides to keep the selection
visible, the same rule as the peer's tile-grid `barWindow`. Pressing A on the
peer's STAT or LVL slot opens a page drawn on the suite's own 540×360 page
from the data the peer publishes through its exports, turned into rows by
`g2Info` (memoised, as the peer caches its own per-id page), `g2StatRows` (the
six modern rows plus a gold TOTAL, the `baseStats.specialAttack` / `spAttack` /
`special` fallback chain), `g2TypeNames` (the peer's `PSYCHIC_TYPE` /
`CURSE_TYPE` map and its `hide_type_2` rule) and `g2MovePages` (evolution then
level-up, the peer's own 14 rows a page): the STAT page is the portrait and its
TYPE 1 / TYPE 2 block beside an ABILITIES panel, with the hidden ability marked
and the bared base-stat block below it; the LVL page is the peer's own
evolution and level-up sections, titled and paginated from the peer's state so
its UP/DOWN and LEFT/RIGHT keep working exactly as it wired them. A record
with no ability data (a form whose reply carries none) prints no ABILITIES
block rather than an empty one — the peer's own rule — and a page that cannot
be built falls `pcall`-back to the engine's own GB drawing.

The peer's name, version and install state are logged once at boot
(`national_dex 0.35.6 found -- the POKeDEX listing draws its full roster in
number order and its entry pages gain the STATS page and the species strip`).
With the peer absent, not one line of this path runs and both pages are exactly
the vanilla ones.

### Translation (`translation`)

The modern screens normally show whatever national_dex names its records:
English. A game run under a **translation mod** — the output of the Gen 1 recomp
translation-mod generator (ids `translation-fr` / `-de` / `-es` / `-it` /
`-ja-hrkt` / `-ko`, plus a `-gen2` / `-gen3` suffix per generation) **or one of
the Brazilian Portuguese community mods** (`gen1_pt-br_mod` for Red/Blue/Yellow,
`versaodourada` for Gold/Silver, `versaocristal` for Crystal) — is
Spanish/French/Portuguese everywhere the ROM reaches, but that mod patches the
ROM's own Gen 1/2 content — it has no idea the expanded dex exists, so every
modern species, move, item and ability stays English. `ui/translation.lua`
closes that seam.

At load — **before the content freeze**, and **before `ui/display_names.lua`**
names the forms — `main.lua` calls `Translation.install()`:

1. **Detect.** There is no public mod-list API, so the known ids are probed with
   `mod.find` (`translation-<lang>`, then `-gen2`, `-gen3`). The Brazilian mods
   are a **second, independent family** — not generator output — so their ids
   cannot be synthesised and are hand-listed in a `LANGUAGE_MODS` table
   (`gen1_pt-br_mod`, `versaodourada`, `versaocristal`, each reporting
   `pt-br`); they are probed after the generator ids. g9-gui lists all of them
   in its manifest's `optional_dependencies` purely for the **ordering edge**: it
   makes the translation mods initialise FIRST, so their own patches are in
   place when this reads the records (and so a form inherits an
   already-translated base name). An absent optional dependency is not an error;
   with none of them the probe simply finds nothing.
2. **Catalog.** The language comes off the id. `data/lang/` ships a catalog per
   language (`fr`, `de`, `it`, `ja-hrkt`, `ko`, BOTH Spanish files `es-419` and
   `es`, and `pt-br`); Spanish picks its region from the **SPANISH** row
   (`translation_spanish`, LATAM / ESPAÑA). A detected language with no catalog
   is still reported in the log, it just rewrites nothing. Each catalog carries
   `species` (all 1025, by dex), `moves`/`items`/`abilities` (by folded English
   name, only where they differ) and a `ui` lexicon (step 5). `data/lang/pt-br.lua`
   is the **one hand-authored catalog**: PokeAPI ships no pt-BR species/move/item
   names (only a dozen abilities), so its names come from Pokemon GO's official
   pt-BR text dump (`PokeMiners/pogo_assets`) wherever GO carries the entry, and
   from the suite's own Brazilian wording otherwise — `species` holds the sixteen
   names that differ from the international ones (Type: Null, Sirfetch'd and the
   Paradox mons; every other species keeps its international name, as the
   Brazilian mods themselves do), plus 912 `moves`, 1609 `items` and 308
   `abilities`. The Brazilian mods still translate every Gen 1/2 move and item
   themselves at the registries (a name they changed no longer folds to an
   English key, so it is never touched). It also carries the full `ui` lexicon,
   the `messages` / `messageTemplates` tables and the eight `engineLearner`
   literals.
3. **Patch.** `moves` and `items` are keyed by the **folded English name**
   (`fold`: lowercase, then drop the whitespace and `- ' . : ! ? ,` the display
   layer treats as noise — so the engine's `Double Edge` finds PokeAPI's
   `Double-Edge`). A record is rewritten only when its *current* name still
   folds to an English key, so a Gen 1 move the translation mod already renamed
   (`Absorcion`) no longer matches `absorb` and is left exactly as the ROM
   rendered it. Species are keyed by **national dex** and only rewritten for
   **152 and up** (`def.dex > 151`): the translation mod owns the original 151,
   and national_dex's expanded records start at 152. Form records are skipped —
   `ui/display_names.lua` names them from their base record, already translated
   by then. The engine's own field-move submenu builds its rows from
   `Strings(<move id>)` (the HMs — `SURF`, `CUT`, `FLY` …), which the
   translation mod does not carry, so those `strings` entries are rewritten from
   the moves catalog too — but only where nothing has translated them yet (an
   existing value that is neither empty nor the id itself is left alone). The
   field-move `strings` pass runs BEFORE the moves registry is renamed, because
   it keys off the records' English names.
4. **Abilities** have no content registry at all (their names live inside
   pokemon records and g9-battle-engine / national_dex exports), so they resolve
   at **draw time** through `ctx.Translation.ability(name)` — used by
   `ui/summary.lua`'s ABIL row, `ui/train.lua`'s ability panel and
   `ui/national_dex.lua`'s `abilityRows` (which feed the entry page and the
   listing).
5. **The UI's own lexicon.** The translation mod patches the ROM, not this
   suite, so this mod's chrome — the footer key hints (SELECT, OK, BACK, MENU,
   CLOSE …), the START-screen captions, the appended party-submenu rows
   (HAPPINESS, TRAIN, COIN CHARGE …) and the Mod Manager option labels — would
   stay English. Each catalog's `ui` table maps the English source string to
   the language, and `ui/theme.lua` grows `Theme.setLocalizer`, applied at all
   FOUR text entry points (draw and the three measurers, so a localized string
   is measured as it is drawn). The header readouts are COMPOSED around their
   numbers in `ui/shell.lua` (`S.ui`), because `MONEY: 2244` is one string the
   lexicon cannot match on its own. For a key the engine also knows, the
   engine's value wins (an official menu word beats a paraphrase); a string the
   lexicon does not carry — a species name, a dialogue line, a number — passes
   straight through.  The same catalogs' `messages` / `messageTemplates` tables
   do the same for the full sentences this suite's own mods send to the battle
   screen — see **Messages** below.
6. **Publish.** `mod.exports.translation` carries the whole handle (`enabled`,
   `language`, `code`, `region`, `fold`, `species`, `name`, `ability`, `ui`,
   `line`, `symbolBytes`, `symbolFont`, `attach`) so a peer g9 UI mod can use
   the same names, the same UI lexicon, the same message lexicon and the same
   font fallback without a catalog of its own.

**Messages.** The translation mod patches the ROM, so the sentences this
suite's own mods send stay English too: the battle scene's refusals (`Can't use
that here yet.`, `Can't throw a ball -- 2+ foes still standing!`), the
FORM/gimmick lines, the run and outcome lines (`You won the battle!`), the
target and switch prompts, the gimmick picker's DYNAMAX/TERA labels, and
g9-battle-sample's rematch question (`Do you want to battle again?`). Each
catalog's `messages` table maps the exact English source, and `messageTemplates`
maps the sentences a mon/trainer NAME is spliced into (`Go, %1!`,
`%1 is Mega Evolving!`, `%1 switched places with %2!`). `M.line(text)` tries
`messages`, then the `ui` lexicon, then matches the whole string against the
templates and re-splices the captured names into the value (so a language may
reorder them). g9-Battle-Scene reads the layer with
`mod.find("g9-gui").exports.translation` and passes every message, outcome,
picker and gimmick label through `M.line` as it draws; g9-battle-sample
localizes its rematch question the same way. Both fail open — no g9-gui, the
TRANSLATION row off, or no translation mod leaves the English standing. Both
text wrappers as well (this mod's `Theme.wrap` and the scene's own
`drawWrapped`) break an over-long, space-less run on UTF-8 boundaries, because a
Japanese/Korean message has no spaces to wrap on and would otherwise be cut to
one line or run past the box.

**The MOVE LEARNER.** The learner is the one message flow that straddles both
generations. Gen 1 opens it as a screen (`src.ui.MoveLearnMenu`, which
`ui/move_learn.lua` paints) and reads its four folded lines through
`romText(data, "_TryingToLearnText", "<Gen 1 literal>", …)`, so on Red/Blue/
Yellow the pokered label carries the translation mod's own text. Gold/Silver/
Crystal have no such labels in `data.text` — and every Gold out-of-battle learn
funnels through that same Gen 1 module (see *Gold's out-of-battle learn*) — so
the literal is used as a fallback and reaches `Strings(<literal>, …)`, which
the GSC catalog cannot key. Each catalog's `engineLearner` table carries those
eight literals byte-for-byte (`\n`/`\v`/`\f` included) and
`Translation.install()` registers them into the `strings` registry the same
guarded way as the field-move labels — only a source nothing has translated is
filled — so the learner's question, its HM refusal, its abandon confirm and its
"1, 2 and… Poof!" / "did not learn X!" narration are translated in battle (the
queue's own mid-fight pause) and out of it (a TM, a RARE CANDY, an evolution,
the tutor). The page's own chrome (`LEARN A MOVE`, the which-move prompt, the
OK/FORGET/GIVE UP hints) is in the `ui` lexicon, and the scene's
`"%1 learned %2!"` / `"%1 grew to level %2!"` lines in `messageTemplates`.

**The suite's own labels (the PC, boxes, storage and trade).** The suite's
screens draw a great many words of their own, and some of them are the ROM's
words too — `BILL's PC`, `CHANGE BOX`, `TURN OFF`, `MOVE`, `STATS`, `RELEASE`,
the storage prompts — which the translation mod already carries in the engine's
`strings` catalog, keyed by the English source. `ui/translation.lua`'s
`M.engineString(text)` (memoised) looks a source up there, and both `M.ui` and
`M.line` consult it: `M.ui` as its FIRST source, so an official menu word beats
the suite's paraphrase where both carry the key, and `M.line` as its last
fallback, so a label with no lexicon entry still translates. `Theme.setLocalizer`
is wired to `M.line` (not `M.ui`), which is what brings the suite's `messages`
sentences onto modern screens — a notice such as `You can't leave while holding
a POKéMON.` lives only in `messages` and used to draw English. The catalogs
gained the words the PC/box/storage and trade pages were missing (`SLOTS`,
`STACKS`, `TEN`, `POCKET`, `RECORD`, `RELEASE`, `COST`, `TRADE EVO` /
`WONDER TRADE` / `WONDER PITY`, `NO ITEM HERE`, `The PARTY is full.`, the storage
captions) and the templates the trade result page splices (`DV %1/%2`,
`BONUS +%1`, `WITH %1`, `PITY %1/%2`, `+%1 STAR`, `+%1 STARS`, `Released %1.`).
`ui/pc.lua` drives its Bill's-PC labels through a new `word(s)` (`Shell.ui`)
helper and `entryLabel(entry)` / `entryDescribe(entry)`, shared by both entry
row-builders, the storage rail and the banner/box captions, and renames the
withdraw row to MOVE off the entry's STABLE `id` (`"withdraw"`) rather than its
English text — under a translation mod the engine's label is already localized
(`SACAR POKéMON` for Spanish), so the old text-pattern match silently did
nothing. Composed readouts (`BOX n`, `PARTY 6/6`, `SLOTS n/m`) splice the
localized noun around the figure, so a translated word stays inside a layout
built for its English width.

**The POKéDEX.** The dex pages carry two kinds of text. The ROM's own words
(species kinds, move and item names) arrive already translated on the records
and through `NatDex.translate` (`src.core.Strings`), so they were never the
problem — the problem was the suite's OWN furniture, which no lexicon had:
the listing tally (`SEEN n  OWN n`, and on Gold `... SORT OLD`), `No.010` and
its `... FORM 1/3` form index, the entry's `HEIGHT` / `WEIGHT` rows, Gold's
`PAGE` / `AREA` / `CRY` / `PRNT` action bar (the peer swaps in `+ STAT` / `+ LVL`)
and the `PAGE 2/2` readout, the `BASE STATS` panel's `TOTAL` and the modern stat
abbreviations (`ATK`, `DEF`, `SP. ATK`, `SP. DEF`, `SPD`, `SPC`), the
`TYPE` / `TYPE 1` / `TYPE 2` / `ABILITIES` / `HIDDEN` / `NO DATA` rows, the
evolution strip's section titles (`EVOLUTION`, `LEVEL UP`, `MACHINE`, `EGG`,
`TUTOR`, `OTHER`) and every footer key hint (`PAGE`, `VIEW`, `ACTION`, `FORM`,
`NEXT`, `MORE`, `BACK`, `SEARCH`). Standalone words go into the catalogs' `ui`
lexicon; the COMPOSED readouts (`SEEN %1  OWN %2`, `SEEN %1  OWN %2   SORT %3`,
`PAGE %1/%2`, `No.%1`, `No.%1   FORM %2/%3`) go in as `messageTemplates`, so the
figures are re-spliced and each language words the sentence its own way. Both Gen
1 arms (`PokedexMenu`, `DexEntryMenu`) and the Gen 2 arm (`Gen2PokedexMenu`) draw
through `Theme`, so no code path had to be found twice. **Gotcha fixed here:** a
template slot is a lazy, unconstrained capture, so the compiled template list is
now sorted longest-key-first — without it `SEEN 37  OWN 12` matched
`SEEN 37  OWN 12   SORT OLD` (with `%2` = `12   SORT OLD`) and the sort clause
stayed English.

**Font.** The Latin-script catalogs use only characters Saira already carries;
what it lacks lives in `assets/fonts/g9-symbols.ttf`, built from Noto Sans
Symbols 2, Noto Sans JP and Noto Sans KR — U+2640 FEMALE SIGN, U+2642 MALE
SIGN and U+2605 BLACK STAR, the kana a Japanese catalog needs and the Hangul a
Korean one needs (1093 glyphs, 316116 B). `ui/theme.lua` attaches it to every
baked face as a LOVE 11.3 `Font:setFallbacks` fallback. The same file, with the
same wiring, ships in **g9-Battle-Scene** and **g9-evolutions**, which draw the
same translated records (the scene's HUD and move names, the evolution/trade
pages). The fallback is not gated by the row — it only ever adds glyphs. The
deck pages' `M.caps` also folds the accented Latin-1 lowercase letters, so an
uppercased translated row reads `ABSORCIÓN`, not `ABSORCIóN`.

**Rebuild recipe** (also in each catalog's header): PokeAPI's
`pokemon_species_names` / `move_names` / `item_names` / `ability_names` CSVs,
`local_language_id` 9 (English), 5 (fr), 6 (de), 7 (es), 8 (it), 14 (es-419),
1 (ja-hrkt), 3 (ko); fold the English name and emit the localized value; species
keyed by dex (all 1025), the rest by folded English name; keys must stay
byte-identical to `fold()`. Only entries whose localized name differs from
English are listed for moves/items/abilities. The `ui` lexicon is authored and
hand-checked. The `messages` and `messageTemplates` tables are authored and
hand-checked the same way. `data/lang/pt-br.lua` is the exception to the
generated-catalog rule: PokeAPI has no pt-BR row for species, moves or items
(`local_language_id` 13 exists but is all but empty — twelve ability names
only), and the main-series games were never localized to pt-BR at all. That file
is authored by hand: its names come from **Pokemon GO**, the one game localized
to pt-BR, whose text dump (`PokeMiners/pogo_assets`,
`Texts/Latest APK/Brazilian Portuguese.txt`) supplies the value for every entry
GO carries, keyed `pokemon_name_<dex>` / `move_name_<id>` / `item_*_name`; the
rest is the suite's own Brazilian wording. It holds 16 `species`, 912 `moves`,
1609 `items` and 308 `abilities` (mega stones, Z-Crystals, the PokeAPI "★..."
star-named items and exact cognates — Elixir, Carbos, Gracidea, Banana,
Jalapeño, Wasabi, Gigantamix, Ketchup, Bacon, Tofu, Kiwi, Poké Radar, Scanner —
are intentionally left English), plus the `ui` / `messages` /
`messageTemplates` / `engineLearner` tables written like every other language's. The font supplement is rebuilt from Noto Sans JP / KR
/ Symbols 2 with only the codepoints the catalogs and the lexicon use.

### Optional dependencies

* **`translation-*`** — a game-translation mod. Optional, and listed only for
  the ordering edge (see *Translation* above): with one installed the modern
  names it cannot reach are translated; with none installed, or with the
  `translation` row OFF, every modern name stays as national_dex spells it.
* **`gen1_pt-br_mod`**, **`versaodourada`**, **`versaocristal`** — the Brazilian
  Portuguese translation mods, a second family the generator does not emit.
  Optional and listed for the same ordering edge; each is detected as `pt-br`
  and uses `data/lang/pt-br.lua`. They already translate every Gen 1/2 move and
  item at the content registries and every engine `strings` entry they carry, so
  this suite adds the **Gen 3+ names** those mods never reach (from Pokemon GO's
  official pt-BR text) plus its own `ui` / `messages` lexicon (and the learner
  literals) on top. With none installed, or with the `translation` row OFF,
  nothing changes.
* **`national_dex`** — the full National Dex (all 1025 species, its search,
  STATS page and evolution/learnset strip) drawn on this suite's pages, through
  its public exports only (see *National Dex compatibility*). Its SELECT view
  modes are the one part the suite's listing does not follow.
  Optional at every level: with it absent the POKéDEX and entry pages are the
  vanilla ones, and with an older copy that lacks the exports the entry page
  simply stays the description page.
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

* **Gen 2 is complete.** The manifest declares `games: ["gen1","gen2"]` and
  `main.lua` no longer bails on `GameVersion.generation(GameVersion.get()) == 2`;
  it selects the Gen 1 id set or the Gen 2 one. As of **2.5.5** the START,
  POKéMON, summary, bag (PACK), PokéDEX, OPTION (with its group sub-pages), the
  trainer card, the MOD MANAGER and the boot MAIN MENU takeovers are Gen 2-ready
  — every screen the START menu opens plus the menu that opens it — and so are
  the three re-skinned screens (the TRAIN editor, the BLACKLIST window and the
  engine's own dialogue windows), so every screen the suite touches answers on
  Gold as well as Red/Blue/Yellow. Post-completion patches have since repaired
  a run of Gen 2 defects (2.5.8: the START portrait crash; 2.5.9: START ↔ POKéMON
  LEFT/RIGHT paging, true-colour dex pictures, the portrait scissor and the cart
  glyph-macro expansion; 2.6.0: the seamless START ↔ POKéMON swap, the cart's
  white menu fade taken out of both of `Game2`'s start-menu entry points; 2.6.1:
  the Adv.Stats panel's EVS/IVS pages and the animated corner sprite on Gold;
  2.6.2: the Gold START rail's POKéMON row removed and the pack's front art in
  the Gold party portraits; 2.6.3: the party card's head crop anchored to the
  pack's frame-1 content box, with the integer step-down that keeps big sheets
  like Dragonite's Mega and Eternatus from landing on blank rows; 2.6.4: a
  no-op `:draw` on every taken-over Gen 2 page so the cart's own screen can no
  longer blit under a message card, the POKéMON page's GIVE/TAKE flow taken
  over by new `ui/held_item.lua`, and the engine's YES/NO `ChoiceBox` dressed
  by new `ui/choice.lua`; 2.6.5: the BLACKLIST re-skin's `MEGA` / `GIGA` row
  with `RESET ALL` pushed below it, matching g9-battle-sample 1.1.0's window;
  2.6.6: the EXPORT LOG's write pinned to the save root, so the same file lands
  in the same place on Red and on Gold; 2.6.7: the dialogue card and the YES/NO
  skin drawn at native window resolution on Gold too (off its own `render.hud`
  viewport payload), the choice skin now generation-agnostic (both gens, with
  `setUIAnchor` kept and LEFT/RIGHT row toggling), the Gold SAVE flow made this
  suite's own modal, and the save / QUIT confirms answering LEFT → YES / RIGHT →
  NO as well as up/down — with the tiny-species portrait cards (TOTODILE and its
  kin) fixed by g9-battle-sprites 3.2.6; 2.8.4: the dialogue card and its YES/NO
  now apply over this suite's OWN wide pages — the engine's classic box is
  dressed and painted in the page's own space with the classic offset undone and
  its edge anchor suppressed, so the white 160×144 window and the hole the
  engine carved for it are both gone, and a YES/NO over a message over a page is
  one card; 2.8.5: the POKéMART is a page of the suite on both generations — the
  `BUY` / `SELL` / `QUIT` rail beside the clerk's own line, the buy list, and a
  Gen 1 SELL list drawn as this suite's own bag page, the same modern PACK Gold's
  sell flow already opened, so the cart's own menu can no longer bleed under the
  item list).
  The plan, the engine-difference table, the screen-id
  mapping and the per-phase order live in **`GEN2-PORT.md`**.
* The **START menu tree** is modernised: START, POKéMON, the summary, the bag
  (ITEM), the Pokédex and its species entry pages, OPTION and its group pages,
  the trainer card and the mod manager — plus the SAVE/QUIT modals, the boot
  title menu with its CONTINUE window, and the LOAD REPORT. **Re-skinned in
  place** (not owned, not modified): g9-battle-engine's TRAIN editor and
  g9-battle-sample's BLACKLIST window — plus the engine's own dialogue
  windows, which get this suite's card while a battle is NOT composing the
  surface. Still drawn by the engine: the battle HUD, a dialogue box over a
  battle's own wide surface (or another mod's wide page), and the lists that are
  not opened from the START menu (the Pokédex CONTENTS menu) — the PC
  is fully modernised now, including its mon submenu, its pushed quantity
  stepper, the HALL OF FAME viewer (2.8.3) and the dialogue/YES-NO boxes a PC
  page pushes (2.8.4); so is the POKéMART (2.8.5), since 2.9.0 the
  evolution movie (`EvolutionState` / `Gen2EvolutionAnim`) and, since 3.1.0,
  the move learner (`MoveLearnMenu` — the four-move forget screen, reached
  mid-battle and, since 3.2.0, from Gold's out-of-battle flows), which is an
  opaque page precisely so a learn opened during a battle never shows the
  battle behind it.
* A classic non-opaque overlay over ANOTHER mod's wide page (or a battle's wide
  surface) still draws where the engine centres it — see *Known limit*. This
  suite's own pages no longer have that gap: since 2.8.4 a box over one is
  dressed and painted in the page's own space with the classic offset undone.
* **national_dex's SEARCH screen keeps its own drawing.** It is constructed
  directly and pushed onto the state stack rather than registered in the
  screens registry, and a peer mod's files cannot be read, so there is no seam
  to take it over through; it stays the peer's own classic 160×144 screen
  (fully functional, just not in this suite's style). Dressing it would mean
  recognising the pushed state by its shape at the `StateStack.push` wrapper
  (it exposes `Search`, `matches`, `query`, `vocab`, `onPick`, …) and replacing
  its draw — a candidate for a later round.

## Repository

<https://github.com/tectorifter/g9-gui> — the home of this mod. The manifest
declares it as `"github"`, so the gen1recomp launcher can pull an update for an
installed copy straight from its own release.

## License

GNU General Public License v3.0 (GPL-3.0). Copyright (C) 2026
[tectorifter](https://github.com/tectorifter/). The full text ships as
`LICENSE` beside this file.

## Third-party notices

Pokemon and all related names, characters, creatures, moves, items, sprites and
other assets are the property of Nintendo, Creatures Inc., GAME FREAK inc. and
The Pokemon Company. This is an unofficial fan mod and is not affiliated with,
sponsored by or endorsed by them; it owns only its own Lua source (see
`LICENSE`). Third-party fonts, sprite packs, data and companion mods keep their
own licences. The full list ships in
[`THIRD-PARTY-NOTICES.md`](THIRD-PARTY-NOTICES.md).
