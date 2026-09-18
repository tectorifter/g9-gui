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
    description = "ON (default): draws the layered backdrop behind every modern screen -- a deep vertical gradient, a soft glow behind the header, a vignette and a faint diagonal weave. OFF: a flat dark field instead (lighter to draw, and easier to read on very bright displays).",
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
    description = "BATTLE SPRITES (default): each party row's portrait card is filled with the head area of the Pokemon's FRONT battle art -- with g9-battle-sprites installed that is the pack's own assets/front/<STEM>.png sheet, baked to a trimmed frame and cropped to the head at a whole 2x so it fills the 72x36 card (an older copy of that mod falls back to its 64x64 party cell); without it the game's own front picture is shown. ICONS: the pack's 16x16 party-icon atlas (assets/icons/party_icons.png) is fitted into the same card instead, the smaller \"party icon\" reading.",
  },
}
