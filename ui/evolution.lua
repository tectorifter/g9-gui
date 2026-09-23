-- ui/evolution.lua -- the EVOLUTION screen, modernised.
--
-- The engine plays an evolution as MOVIE_EvolutionAnim on Gold and
-- src/ui/EvolutionState on Red/Blue/Yellow: the mon's own front pic flashes
-- back and forth with the evolved form, speeding up, then the new form settles
-- and the "evolved into" text prints in a classic 160x144 white box.  This
-- module is a VIEW TAKEOVER of both states, exactly like every other g9-gui
-- screen: main.lua still asks the engine for the real object, the engine still
-- builds it, and every frame of the animation, the cry, the B-press cancel and
-- the post-evolution move learning stay the engine's own.  Only the surface and
-- the draw move onto the instance, so the page becomes this suite's 540x360 one.
--
-- The sprite shown for a Pokemon is the g9-battle-sprites pack's FRONT battle
-- sheet -- that mod's always-on `frontArt` export, reached through
-- ui/portraits.lua's drawFront, whose whole point is that export -- so the
-- evolution plays with the same true-colour art the roster, the summary and the
-- battles use, at the pack's own 1:1 pixels (never zoomed, stepped down by an
-- integer divisor only when a frame outgrows the stage), which is the one rule
-- that keeps every species' size honest.  With that mod absent, or with a
-- species it has no sheet for, the engine's own front pic is drawn in exactly
-- the same slot, so the screen is never empty.
--
-- The engine's own messages are respected, not reinvented: the "What? X is
-- evolving!" line is read from the same ROM string the engine reads
-- (src.core.RomText's _IsEvolvingText) and the post-evolution result stays the
-- engine's own TextBox -- which, over a page of this suite, ui/textbox.lua
-- already paints as the centred modern card.  The page therefore draws the
-- animation and its own heading, and the result card floats over it, the same
-- pair every other screen in the suite shows.
--
-- Two arms, one page:
--   * Gen 1 (Red/Blue/Yellow) -- src.ui.EvolutionState:
--       state:uiSize()          540x360  (via M.uiSize)
--       state:isWideBattleLayout() / :wantsFillScale()  -> Shell.wide(self)
--       state:sgbPalettes()     {}        (no SGB shade remap over the page)
--     The page flashes between the two front sheets itself, following the same
--     accelerating schedule the engine's own draw uses (so a B-press cancel
--     settles on the form that was on screen), and draws its own evolving line
--     because the engine's intro TextBox sits BELOW this opaque page.
--   * Gen 2 (Gold/Silver/Crystal) -- src.ui.gen2.EvolutionAnim:
--       Shell.gen2Surface(Theme, self, draw) -- Gold answers :drawWidescreen()
--       and paints the whole window, so the same page painter is installed
--       through that seam.  Gold's state already carries its own per-phase
--       message in `self.lines`, the flash state in `self.showNew` and the
--       reveal in `self.picAnim`; this page draws from exactly those fields.
--
-- Fail-open in both directions, like the rest of the suite: a state this module
-- cannot build for keeps the engine's own screen, and any error inside the page
-- is caught by main.lua's per-piece wrapper -- the evolution never becomes a
-- soft-lock, because the engine's update/state machine are untouched.
return function(mod, ctx)
  local Theme, Backdrop, Shell, Portraits = ctx.Theme, ctx.Backdrop, ctx.Shell,
    ctx.Portraits
  local opt, gen = ctx.opt, ctx.gen
  local C = Theme.col
  local W, H = Shell.W, Shell.H

  -- The engine's own string reader, when the boot has one.  pcall-guarded so a
  -- partial engine still lays the page out in English rather than erroring.
  local romText = nil
  do
    local ok, v = pcall(require, "src.core.RomText")
    if ok and type(v) == "function" then romText = v end
  end
  local Strings = require("src.core.Strings")
  local Assets = require("src.render.Assets")
  local Sprites = require("src.pokemon.Sprites")

  local M = {}

  -- ---------------------------------------------------------------- geometry
  -- The content band runs Shell.CONTENT_Y (66) to Shell.FOOT_RULE_Y (314).
  -- The stage is the picture's own panel; the name and the progress rule sit
  -- under it, so the three read as one column.
  local STAGE_X, STAGE_Y = 130, 66
  local STAGE_W, STAGE_H = 280, 178
  local NAME_Y = STAGE_Y + STAGE_H + 12          -- 256
  local BAR_Y = NAME_Y + 34                      -- 290
  local BAR_H = 8

  -- The engine's own pre-flash delay and flash length (src/ui/EvolutionState.lua:
  -- CANCEL_GRACE_FRAMES + ANIM_LOOP_FRAMES).  Used for the progress rule only.
  local G1_GRACE, G1_FLASH = 80, 288
  local G2_ROUNDS = 8

  -- ------------------------------------------------------------- messages
  local function gen1EvolvingText(self)
    local name = self.oldName
    if romText then
      local data = self.game and self.game.data or {}
      local ok, text = pcall(romText, data, "_IsEvolvingText",
        "What?\n%s is\nevolving!", name)
      if ok and type(text) == "string" and text ~= "" then
        -- the cart's three-line box; this page prints one line
        return (text:gsub("\n", " "))
      end
    end
    return ("What? %s is evolving!"):format(tostring(name or ""))
  end

  local function gen2Message(self)
    local lines = self.lines
    if type(lines) ~= "table" or #lines == 0 then return "" end
    return (table.concat(lines, " "))
  end

  local function speciesName(game, species)
    local def = game and game.data and game.data.pokemon
      and game.data.pokemon[species]
    if def and def.name then return def.name end
    return tostring(species or "")
  end

  -- A throwaway mon record carrying the EVOLVED species but every other trait
  -- of the record that walked in, so the pack's species/gender/shiny/form
  -- mapping answers exactly as it would for a party member of that species.
  local function monLike(self, species)
    local m = (type(self.mon) == "table") and self.mon or {}
    return {
      species = species,
      shiny = m.shiny, dvs = m.dvs,
      gender = m.gender, sex = m.sex, isFemale = m.isFemale,
      nickname = nil, isEgg = false,
    }
  end

  -- The engine's accelerating flash schedule, copied from EvolutionState.lua so
  -- the page settles on the same form the engine's own draw would: the engine
  -- only owns the TIMING now, this decides which sheet that timing is showing.
  local function showsNew(t)
    if t < 0 then return false end
    for b = 1, 8 do
      local hold = 18 - 2 * b
      if t < hold then return false end
      t = t - hold
      local swap = b * 6
      if t < swap then return t % 6 < 3 end
      t = t - swap
    end
    return true
  end

  local function shownSpecies(self)
    if gen == 2 then
      -- a cancelled run settles back on the form that walked in, whatever the
      -- engine's later phases say
      if self.canceled then return self.oldSpecies end
      if self.evolved or self.phase == "done" then return self.newSpecies end
      return self.showNew and self.newSpecies or self.oldSpecies
    end
    if self.done then
      if self.canceled then return self.mon and self.mon.species or nil end
      return self.newSpecies
    end
    if self.loading then return self.mon and self.mon.species or nil end
    local old = self.mon and self.mon.species or nil
    if showsNew((self.t or 0) - G1_GRACE) then return self.newSpecies end
    return old
  end

  -- Gold's animation phases.  While the state is in one of these the two forms
  -- are still trading places; the moment it leaves them the swap is over and
  -- one form has settled (the new one, or the old one again after a cancel).
  local G2_ANIM_PHASES = { evolving = true, cry = true, flash = true }

  -- Has the animation stopped?  Cosmetics only -- the engine owns the real
  -- schedule and the real commit; this only decides which form the page draws
  -- and how the header reads.
  local function isFinished(self)
    if gen == 2 then
      if self.canceled then return true end
      if self.phase == nil then return false end
      return not G2_ANIM_PHASES[self.phase]
    end
    -- Red/Blue sets `done` when the flash ends (or a B press aborts it) and
    -- stays there while the cry and the result text run
    return self.done == true
  end

  local function isCanceled(self) return self.canceled == true end

  -- Gold's three prompt phases: the state machine reads A or B to leave these,
  -- where every other post-animation phase advances on its own timer.
  local function isPrompt(self)
    local ph = self.phase
    return ph == "stopped" or ph == "congrats" or ph == "learn"
  end

  local function nameOf(self, species)
    return speciesName(self.game, species)
  end

  local function oldName(self)
    if gen == 2 then return self.nick or nameOf(self, self.oldSpecies) end
    return self.oldName or nameOf(self, self.mon and self.mon.species)
  end

  local function newName(self)
    if gen == 2 then
      return self.newName or nameOf(self, self.newSpecies)
    end
    return nameOf(self, self.newSpecies)
  end

  -- 0..1 through the animation, for the progress rule.  Cosmetics only -- the
  -- engine owns every real frame count.
  local function progress(self)
    if isFinished(self) then return 1 end
    if gen == 2 then
      if self.phase == "flash" then
        local r = tonumber(self.round) or 1
        return math.min(1, math.max(0, (r - 1) / G2_ROUNDS))
      end
      return 0
    end
    local t = (self.t or 0) - G1_GRACE
    if t <= 0 then return 0 end
    return math.min(1, t / G1_FLASH)
  end

  -- ---------------------------------------------------------------- sprites
  -- The engine's own front pic, real size, whole integer divisor when it
  -- outgrows the stage -- the same sizing rule ui/portraits.lua's drawFront
  -- uses for the pack's art, so the two sources sit at one scale.
  local function drawSized(img, x, y, w, h)
    if not (img and type(img.getDimensions) == "function") then return false end
    local iw, ih = img:getDimensions()
    if not (iw and ih and iw > 0 and ih > 0) then return false end
    local d = 1
    if iw > w or ih > h then
      d = math.max(1, math.ceil(math.max(iw / w, ih / h)))
    end
    local s = 1 / d
    local dw, dh = iw * s, ih * s
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(img, math.floor(x + (w - dw) * 0.5),
      math.floor(y + (h - dh) * 0.5), 0, s, s)
    return true
  end

  -- --------------------------------------------------------------- the page
  local function drawStage(self)
    local species = shownSpecies(self)
    local pad = 16
    local x, y, w, h = STAGE_X + pad, STAGE_Y + pad,
      STAGE_W - pad * 2, STAGE_H - pad * 2

    -- a soft glow behind the creature, so the panel reads as a lit stage
    -- rather than a flat box (plain translucent discs -- no canvas/shaders)
    local cx, cy = STAGE_X + STAGE_W * 0.5, STAGE_Y + STAGE_H * 0.72
    for i = 10, 1, -1 do
      local t = i / 10
      Theme.set(C.accent, 0.028 * (1 - t) * 3.2)
      love.graphics.circle("fill", cx, cy, 96 * t)
    end

    -- 1. the pack's own front sheet (g9-battle-sprites, via ui/portraits.lua).
    --    drawFront answers false when that mod is absent, has no sheet for the
    --    species, or is still baking its first frame.
    local drawn = false
    if species then
      local ok, value = pcall(Portraits.drawFront, Theme, self.game,
        monLike(self, species), x, y, w, h)
      drawn = ok and value == true
    end

    -- 2. the engine's own front pic, in the same slot.
    if not drawn and species then
      local img
      if gen == 1 then
        -- the two Image objects the engine loaded for this very animation,
        -- picked by which species the flash is showing
        local showingNew = (species == self.newSpecies)
        img = showingNew and self.newSprite or self.oldSprite
      end
      if not img then
        local game = self.game
        local data = game and game.data or {}
        local path
        local okP, p = pcall(function()
          return Sprites.path(data, species, "front",
            { mon = (type(self.mon) == "table") and self.mon or nil,
              kind = "evolution" })
        end)
        if okP then path = p end
        if not path then
          local def = data.pokemon and data.pokemon[species]
          path = def and def.spriteFront or nil
        end
        if path then
          local okI, v = pcall(Assets.image, path)
          img = okI and v or nil
        end
      end
      drawSized(img, x, y, w, h)
    end
  end

  local function drawProgress(self)
    local segs, gap = 12, 4
    local segW = (STAGE_W - gap * (segs - 1)) / segs
    local p = progress(self)
    local lit = math.floor(p * segs + 0.0001)
    for i = 1, segs do
      local sx = STAGE_X + (i - 1) * (segW + gap)
      local on = i <= lit
      Theme.set(on and C.accent or C.panelDeep, on and 1 or 0.9)
      Theme.rect("fill", math.floor(sx + 0.5), BAR_Y, math.floor(segW), BAR_H, 3)
      if not on then
        Theme.set(C.border, 0.5)
        Theme.rect("line", math.floor(sx + 0.5) + 0.5, BAR_Y + 0.5,
          math.floor(segW) - 1, BAR_H - 1, 3)
      end
    end
  end

  local function drawPanel(self)
    local game = self.game
    local background = opt("ui_background") ~= "false"
    local embellish = opt("ui_embellishment") ~= "false"
    local finished = isFinished(self)
    local canceled = isCanceled(self)

    Backdrop.draw(Theme, { w = W, h = H, t = self.__t or 0,
      background = background, embellishment = embellish })

    -- The engine's own line, never reinvented.  On Gold the state machine keeps
    -- its message in `lines` for the whole animation and swaps it per phase
    -- ("stopped evolving!", "Congratulations!", "evolved into ..."), so that is
    -- what the header prints; on Red/Blue it is the ROM's _IsEvolvingText, and
    -- once the result TextBox is up the engine owns the message and the caption
    -- clears (that box paints over this page as the centred card).
    local caption = ""
    if gen == 2 then
      caption = gen2Message(self)
    elseif not finished then
      caption = gen1EvolvingText(self)
    end

    Shell.top(Theme, game, {
      title = Strings("EVOLUTION"),
      caption = caption,
      right = (canceled and Strings("STOPPED"))
        or (finished and Strings("COMPLETE")) or Strings("EVOLVING"),
      embellish = embellish,
    })

    -- the stage
    Theme.panel(STAGE_X, STAGE_Y, STAGE_W, STAGE_H,
      { radius = 10, shadow = 4, color = C.panelDeep, border = C.border })
    if embellish then
      Theme.brackets(STAGE_X + 6, STAGE_Y + 6, STAGE_W - 12, STAGE_H - 12, 24,
        C.accentDim)
    end
    drawStage(self)

    -- the name under the stage
    local species = shownSpecies(self)
    local name = nameOf(self, species)
    local nameColor = C.ink
    if canceled then nameColor = C.bad
    elseif finished then nameColor = C.gold end
    local F = Theme.fonts(game)
    if (self.mon and self.mon.level) then
      Theme.text(("Lv %d"):format(self.mon.level), STAGE_X, NAME_Y + 2,
        F.small, "left", C.inkDim)
    end
    Theme.text(Theme.fit(name, F.bold, STAGE_W - 96), STAGE_X + STAGE_W * 0.5,
      NAME_Y, F.bold, "center", nameColor)

    drawProgress(self)

    -- Footer.  B stops the flash on both generations when the engine allows it
    -- (a stone evolution and a trade are forced); once the animation has
    -- settled, A advances whatever the engine puts up next.
    local hints = {}
    if gen == 2 then
      if self.phase == "flash" and not self.force then
        hints[#hints + 1] = { key = "B", text = Strings("CANCEL") }
      elseif isPrompt(self) then
        hints[#hints + 1] = { key = "A", text = Strings("OK") }
      end
    else
      if not finished and self.cancelable then
        hints[#hints + 1] = { key = "B", text = Strings("CANCEL") }
      end
      if finished then
        hints[#hints + 1] = { key = "A", text = Strings("OK") }
      end
    end
    Shell.footer(Theme, game, { hints = hints })
    Theme.set(C.white)
  end

  -- ------------------------------------------------------------------ surface
  function M.uiSize() return W, H end
  function M.isWideBattleLayout(self) return Shell.wide(self) end
  function M.wantsFillScale(self) return Shell.wide(self) end
  function M.sgbPalettes() return {} end

  -- ------------------------------------------------------------------- new
  -- Gen 1 -- src.ui.EvolutionState.new(game, mon, newSpecies, onDone, via)
  local function newGen1(game, mon, newSpecies, onDone, via)
    local Builtin = require("src.ui.EvolutionState")
    local self = Builtin.new(game, mon, newSpecies, onDone, via)
    self.__g9gui = true
    self.isOpaque = true
    self.__t = 0
    self.uiSize = M.uiSize
    self.isWideBattleLayout = M.isWideBattleLayout
    self.wantsFillScale = M.wantsFillScale
    self.sgbPalettes = M.sgbPalettes
    local baseUpdate = self.update
    self.update = function(s, dt)
      s.__t = (s.__t or 0) + 1
      return baseUpdate(s, dt)
    end
    self.draw = function(s) drawPanel(s) end
    return self
  end

  -- Gen 2 -- src.ui.gen2.EvolutionAnim.new(game, opts), and Game2 paints it
  -- through :drawWidescreen.  Shell.gen2Surface installs the whole contract
  -- (no-op :draw, drawsWidescreen, wantsFillScale, the page painter), so the
  -- page is what the window shows and the cart's classic draw never leaks
  -- through underneath it.
  local function newGen2(game, opts)
    local Builtin = require("src.ui.gen2.EvolutionAnim")
    local self = Builtin.new(game, opts)
    self.__g9gui = true
    self.__t = 0
    local baseUpdate = self.update
    self.update = function(s, dt)
      s.__t = (s.__t or 0) + 1
      return baseUpdate(s, dt)
    end
    Shell.gen2Surface(Theme, self, function(s) drawPanel(s) end)
    return self
  end

  function M.new(game, ...)
    if gen == 2 then return newGen2(game, ...) end
    return newGen1(game, ...)
  end

  -- the render harness drives the page directly (a state cannot be pushed in a
  -- headless boot); public so a shot can draw without building one
  M.drawPanel = drawPanel
  M.shownSpecies = shownSpecies

  return M
end
