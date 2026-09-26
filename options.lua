-- Mod Manager option schema for g9-gui ("modern UI & stats").
--
-- Declared in manifest.json's "options_schema" AND defined from main.lua with
-- mod.options:define(), so the manager can render the rows before the entry
-- chunk has run and both paths share one source of truth.
--
-- READ CONVENTION: mod.options:get(key) returns the choice's value STRING
-- ("true"/"false"/"icons"/"sprites"), so every read in this mod compares
-- against a string, never a boolean.
return {
  {
    key = "modern_ui",
    label = "MODERN UI",
    type = "choice",
    default = "true",
    choices = { { "ON", "true" }, { "OFF", "false" } },
    description = "ON (default): the START screen, the POKeMON screen and the POKeMON summary are replaced by this mod's full-screen modern design (a 540x360 UI surface -- 1.7x the classic page in width and 2.5x in height -- drawn at a 30px design type size, so it fills the page rather than floating in it). OFF: every screen is left exactly as the engine drew it -- the mod loads but does nothing, which is the switch to flip if a mod conflict shows up.",
  },
  {
    key = "ui_background",
    label = "UI BACKGROUND",
    type = "choice",
    default = "true",
    choices = { { "ON", "true" }, { "OFF", "false" } },
    description = "ON (default): draws the layered backdrop behind every modern screen -- a deep vertical gradient, two soft corner glows, a vignette and a faint diagonal weave. OFF: a flat dark field instead (lighter to draw, and easier to read on very bright displays).",
  },
  {
    key = "ui_embellishment",
    label = "EMBELLISHMENTS",
    type = "choice",
    default = "true",
    choices = { { "ON", "true" }, { "OFF", "false" } },
    description = "ON (default): the decorative furniture -- corner brackets, panel top highlights, column rules, the header emblem and the pulsing selection chevrons. OFF: the same layout with none of the decoration, for a cleaner or lower-distraction menu.",
  },
  {
    key = "ui_portraits",
    label = "PARTY PORTRAITS",
    type = "choice",
    default = "sprites",
    choices = { { "BATTLE SPRITES", "sprites" }, { "ICONS", "icons" } },
    description = "BATTLE SPRITES (default): each party row's portrait card is filled with the head area of the Pokemon's FRONT battle art -- with g9-battle-sprites installed that is the pack's own assets/front/<STEM>.png sheet, baked to a trimmed frame and cropped to the head at the pack's own 1:1 pixels so it fills the 56x34 card (an older copy of that mod falls back to its 64x64 party cell); without it the game's own front picture is shown. ICONS: the pack's party-icon art is shown at its REAL size instead -- the 64x64 HD icon cells (assets/icons/party_icons_hd.png, the pack's own frames; the 16x16 atlas is a 4:1 copy of them) cropped to the same 56x34 card at 1:1, so an icon reads as large as a battle-sprite portrait rather than a shrunken figure; an older copy of that mod with no HD cell gets the 16x16 atlas, fitted.",
  },
  {
    key = "ui_pc_row",
    label = "PC ROW",
    type = "choice",
    default = "false",
    choices = { { "ON", "true" }, { "OFF", "false" } },
    description = "OFF (default): the START screen's rail carries the game's own rows (minus POKeMON, which is the right-hand party page). ON: one extra row, PC, joins the rail -- press A on it to turn the POKeMON storage system (BILL's PC) on straight from the menu, exactly as the PC standing in a POKeMON CENTER does, with this mod's own PC pages. It sits right after ITEM/PACK, and the POKeMON page's rail carries it too, so the two halves of the spread stay identical.",
  },
  {
    key = "color_protection",
    label = "COLOR PROTECTION",
    type = "choice",
    default = "true",
    choices = { { "ON", "true" }, { "OFF", "false" } },
    description = "ON (default): keeps gen1recomp's OPTIONS > GRAPHICS > COLORS display mode off every MODERN screen, on BOTH generations -- this suite's own pages and the modern screens sibling g9 mods draw (g9-evolutions' trade / inspector / trade-anim pages, g9-Battle-Scene's battle scene), which mark themselves with the shared __g9modern flag. The modern pages are true colour (Saira type and a hand-picked palette), so the mono / OG / CLASSIC ramps would otherwise repaint every panel, portrait and label. It hooks the engine's render.zones seam and blits each modern page with the palette shader switched off, while the world and every engine screen keep their native colour. OFF: the native palette applies to the modern screens exactly as it does to the rest of the game.",
  },
  {
    key = "translation",
    label = "TRANSLATION",
    type = "choice",
    default = "true",
    choices = { { "ON", "true" }, { "OFF", "false" } },
    description = "ON (default): if a game-translation mod (a mod built by the Gen 1 recomp translation-mod generator, id translation-<lang>) is installed, this mod also translates the content that mod cannot reach -- the expanded-dex Pokemon (national dex 152+) and their moves, items and abilities -- so a translated game has no English names left in the modern screens. The language is detected from the translation mod's own id; French, German, Spanish (Latin American or Spain -- see the SPANISH row), Italian, Japanese and Korean all ship. It also localizes this mod's OWN screens -- the footer key hints, the header readouts (MONEY / BADGES / DEX / PARTY), the START-menu captions and the extra party-submenu rows (HAPPINESS, TRAIN ...) -- with the same language, since the translation mod never sees those, and localizes the sentences our own mods send to the battle screen (the battle scene's refusals and outcome lines, the gimmick picker's labels and the NPC rematch question) and wraps translated text properly (a Japanese/Korean message has no word breaks). Gen 1/2 names (species 1-151, and the classic moves/items/abilities) are left to the translation mod itself, so its spellings are never overwritten. OFF: every modern name stays exactly as national_dex spells it (English), and no detection or UI localization runs. Either way the font gains the extra glyphs (accented kana/Hangul, and the female/male sign and star) a translated name can use.",
  },
  {
    key = "translation_spanish",
    label = "SPANISH",
    type = "choice",
    default = "la",
    choices = { { "LATAM", "la" }, { "ESPAÑA", "esp" } },
    description = "Which Spanish this mod's own content uses, when a Spanish translation mod (translation-es) is installed. LATAM (default): Latin American Spanish -- PokeAPI's es-419 names. ESPAÑA: European Spanish -- PokeAPI's es names, matching the Spanish ROM the translation mod itself is built from. Only the names THIS mod fills in are affected (the expanded-dex Pokemon and their moves, items and abilities, plus the UI lexicon); the translation mod's own Gen 1/2 spellings are never touched either way. Ignored when the detected translation mod is not Spanish.",
  },
  {
    key = "short_heal_chat",
    label = "SHORT HEAL CHAT",
    type = "choice",
    default = "true",
    choices = { { "ON", "true" }, { "OFF", "false" } },
    description = "ON (default): talking to a POKeMON CENTER nurse keeps only the one line that matters -- \"We restore your tired Pokemon to full health.\" -- after the heal. The welcome, the HEAL/CANCEL question, \"we'll need your POKeMON\", \"fighting fit\" and the goodbye are dropped. If the nurse spots POKeRUS she still reports it first (with its own flag and Elm phone call), then that same line follows, so the virus is never missed. OFF: the full original conversation is kept on both generations. Only the CHAT is affected either way -- g9-battle-engine still full-heals the party to its modern max, still skips the pokeball-into-the-machine animation, and still turns the player away (south) when the nurse is done.",
  },
  {
    key = "ui_hp_guard",
    label = "HP GUARD",
    type = "choice",
    default = "catch",
    choices = { { "CATCH", "catch" }, { "LOG ONLY", "log" }, { "OFF", "off" } },
    description = "CATCH (default): a small sentinel watches the party's HP while you browse the START screen and the POKeMON page. If any member's HP drops during a pure page turn (no battle, no item, no medicine animation), it puts the old value back and writes a diagnostic line to the mod log -- the safeguard for the reported \"a mon in some state loses 1 HP every time the cursor pages onto the party\" bug. LOG ONLY: it reports the drop in the mod log but leaves the HP alone, so you can measure how much is lost and over how long. OFF: no sentinel. A drop is only ever objected to while you are merely looking at the party; HP changed on any other screen is re-baselined and never undone.",
  },
}
