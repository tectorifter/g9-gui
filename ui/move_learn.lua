-- ui/move_learn.lua -- the MOVE LEARNER, modernised.
--
-- When a Pokemon with four moves levels into a new one the engine opens
-- src.ui.MoveLearnMenu: the "X is trying to learn Y! ... Delete an older move to
-- make room for Y?" question, then the list of the four moves to replace (with
-- the HM guard), the Abandon-learning confirm and the "1, 2 and... Poof!"
-- narration.  This module is a VIEW TAKEOVER of that screen, exactly like every
-- other g9-gui page: the engine still builds its own object and keeps its whole
-- state machine (selecting / index / the HM refusal / every write), and only the
-- surface and the drawing move onto the instance.
--
-- UNLIKE most of the suite, this screen is routinely opened MID-BATTLE: the
-- engine's own battle queue (BattleState:learnMove), the bag's TM use, the
-- evolution's post-evolution learn run, and g9-Battle-Scene's in-battle learn
-- pause all push it.  A classic 160px menu there would leave the battle, its
-- HUD and the Pokemon sitting behind the question -- which is exactly what the
-- battle scene used to show.  As a wide page it does not: it answers :uiSize
-- with the suite's 540x360, Game.wideBattleInStack resolves the surface to THIS
-- page, and it is opaque, so Game:draw starts from it and nothing under it is
-- drawn.
--
-- The messages stay the engine's own TextBoxes -- the question, the abandon
-- confirm, the HM notice and the "Poof!" narration -- and the suite's dialogue
-- /YES-NO skins already paint those as its cards in THIS page's coordinates
-- (ui/textbox.lua asks whether the wide state under the box is one of ours, and
-- `__g9gui` marks this one as ours).  Only the move list, the prompt and the
-- page furniture are drawn here, because the engine's own :draw can no longer
-- run.
--
-- Registered under the engine's own `MoveLearnMenu` id, so EVERY caller reaches
-- it -- and main.lua publishes `mod.exports.moveLearnScreenId` so a peer mod
-- that pushes the learner (g9-Battle-Scene) can tell the modern screen is live.
return function(mod, ctx)
  local Theme, Backdrop, Shell = ctx.Theme, ctx.Backdrop, ctx.Shell
  local gen, opt = ctx.gen, ctx.opt
  local C = Theme.col
  local W, H = Shell.W, Shell.H
  local Strings = require("src.core.Strings")

  local M = {}

  -- ---------------------------------------------------------------- the mon
  -- The name the engine itself would print: a nickname wins, else the species
  -- record's name (which g9-gui's display_names normalisation has already
  -- returned to the base species' real name for an alternate form).
  local function monName(self)
    local mon = self.mon
    if type(mon) ~= "table" then return "" end
    local nick = mon.nickname
    if type(nick) == "string" and nick ~= "" then return nick end
    local data = self.game and self.game.data
    local def = data and data.pokemon and data.pokemon[mon.species]
    if def and def.name then return def.name end
    return tostring(mon.species or "")
  end

  local function moveName(self, id)
    local data = self.game and self.game.data
    local def = data and data.moves and data.moves[id]
    if def and def.name then return def.name end
    return tostring(id or "")
  end

  local function moveRows(self)
    local rows = {}
    local mon = self.mon
    local moves = type(mon) == "table" and mon.moves or nil
    if type(moves) ~= "table" then return rows end
    for _, mv in ipairs(moves) do
      rows[#rows + 1] = { text = moveName(self, mv and mv.id) }
    end
    return rows
  end

  -- --------------------------------------------------------------- the page
  local function drawPage(self)
    local game = self.game
    local embellish = opt("ui_embellishment") ~= "false"
    local background = opt("ui_background") ~= "false"
    local selecting = self.selecting == true
    local F = Theme.fonts(game)

    Backdrop.draw(Theme, { w = W, h = H, t = self.__t or 0,
      background = background, embellishment = embellish })

    -- The header: the new move is the page's right-hand readout, the learner
    -- its caption -- so the question the engine's card asks has its two nouns
    -- already on the page behind it.
    Shell.top(Theme, game, {
      title = Strings("LEARN A MOVE"),
      caption = monName(self),
      right = moveName(self, self.newMoveId),
      embellish = embellish,
    })

    -- One panel for the content band: the prompt line at its head, the four
    -- moves under it.  The engine's own card (the question, the abandon
    -- confirm, the HM notice) floats over this, the way a page of this suite
    -- always carries its modals.
    local px, py, pw = 16, Shell.CONTENT_Y, W - 32
    local ph = Shell.FOOT_RULE_Y - Shell.CONTENT_Y - 8
    Theme.panel(px, py, pw, ph,
      { radius = 10, shadow = 4, color = C.panelDeep, border = C.border })
    if embellish then
      Theme.brackets(px + 6, py + 6, pw - 12, ph - 12, 24, C.accentDim)
    end

    -- The engine's own forget-list prompt, drawn here because our page
    -- replaced the draw that used to print it in the bottom dialogue box.
    Theme.text(Strings(selecting and "Which move should be forgotten?"
      or "Choose the move to forget."),
      px + 24, py + 16, F.body, "left", selecting and C.ink or C.inkDim)

    local rows = moveRows(self)
    if #rows > 0 then
      Shell.list(Theme, game, {
        rows = rows,
        index = selecting and self.index or nil,
        x = px + 16, y = py + 52, w = pw - 32, row = 36, labelPad = 46,
        t = self.__t or 0,
      })
    end

    -- The engine's own input contract: A takes the highlighted slot (or opens
    -- the list from the question), B backs out / gives the new move up.
    local hints = {}
    if selecting then
      hints[#hints + 1] = { key = "A", text = Strings("FORGET") }
      hints[#hints + 1] = { key = "B", text = Strings("GIVE UP") }
    else
      hints[#hints + 1] = { key = "A", text = Strings("OK") }
      hints[#hints + 1] = { key = "B", text = Strings("GIVE UP") }
    end
    Shell.footer(Theme, game, { hints = hints })
    Theme.set(C.white)
  end

  -- ----------------------------------------------------- the end of the flow
  -- The engine's own :finish is the ONE beat of the learner that does not keep
  -- this page up: it pops the screen and only THEN pushes the narration
  -- ("1, 2 and... Poof!" / "did not learn X!"), so the last screen of the
  -- sequence came down on whatever lay under the page -- the battle gone from
  -- the page's cover and the cart's own white 20x6 window composited over the
  -- fight (the user's screenshot: the raw cart box floating over the fantasy
  -- combat band).  Every OTHER message in the flow -- the question, the abandon
  -- confirm, the HM notice -- is pushed while this page is still on the stack,
  -- so ui/textbox.lua already draws it as the page's own card; the narration
  -- must be the same picture.
  --
  -- So :finish is WRAPPED rather than reimplemented: the engine's own body
  -- still builds the message (romText, the TextBox.PAUSE markers, the SFX
  -- options), pops the screen it thinks is on top and pushes its narration.
  -- The one pop it makes IS its own self-removal, and that is the pop swallowed
  -- here; the page then stays under the narration -- precisely the arrangement
  -- every other message in the flow is in -- so the narration is the page's
  -- card too.  When the narration is dismissed the page comes down with it, so
  -- the caller's own completion (the battle queue's resume through onDone)
  -- still sees the stack it always saw.
  local function installFinish(self)
    local nativeFinish = self.finish
    local game = self.game
    local stack = game and game.stack
    if type(nativeFinish) ~= "function" or type(stack) ~= "table"
        or type(stack.pop) ~= "function" or type(stack.push) ~= "function" then
      -- nothing to preserve (a test double, or an engine that renamed the
      -- method): leave :finish alone and let the flow run as it always did
      return false
    end
    self.finish = function(s, learned)
      -- Snapshot the methods with rawget so the restore can put the table back
      -- EXACTLY as it was: `stack.pop = realPop` would leave an instance field
      -- shadowing the class for good, and a later mod re-wrapping
      -- StateStack.push would then never be seen by this stack.
      local savedPop = rawget(stack, "pop")
      local savedPush = rawget(stack, "push")
      local realPop, realPush = stack.pop, stack.push
      local narration
      -- swallow the self-removal only; any other pop the body might make
      -- passes straight through
      stack.pop = function(st, ...)
        local states = st.states
        if states and states[#states] == s then return s end
        return realPop(st, ...)
      end
      -- catch the narration the body pushes, so its dismissal can bring the
      -- page down with it
      stack.push = function(st, state, ...)
        local a, b = realPush(st, state, ...)
        if narration == nil and type(state) == "table" and state.isTextBox then
          narration = state
        end
        return a, b
      end
      local ok, err = pcall(nativeFinish, s, learned)
      if savedPop == nil then stack.pop = nil else stack.pop = savedPop end
      if savedPush == nil then stack.push = nil else stack.push = savedPush end
      if not ok then error(err, 0) end
      if narration then
        local done = narration.onDone
        narration.onDone = function(...)
          -- the engine pops the box before it calls this, so the page is top
          -- again by the time it runs
          local states = stack.states
          if states and states[#states] == s then
            realPop(stack)
          elseif states then
            for i = #states, 1, -1 do
              if states[i] == s then table.remove(states, i) end
            end
          end
          if done then return done(...) end
        end
      else
        -- no narration rode the page (an engine that finished some other way):
        -- put the flow back exactly as the engine left it rather than let the
        -- page stand over the next beat
        local states = stack.states
        if states and states[#states] == s then realPop(stack) end
      end
    end
    return true
  end

  -- ------------------------------------------------------------------ surface
  -- Gen 1: the same 540x360 page every other screen in the suite answers with.
  -- `Shell.wide` is the shared "do I own the surface right now" question -- it
  -- stays true under the non-opaque TextBoxes this screen pushes.
  function M.uiSize() return W, H end
  function M.isWideBattleLayout(self) return Shell.wide(self) end
  function M.wantsFillScale(self) return Shell.wide(self) end
  function M.sgbPalettes() return {} end

  -- --------------------------------------------------------------------- new
  -- The engine's own constructor signature, so Screens.build/push reach this
  -- screen exactly as they reached the builtin: (game, mon, newMoveId, onDone,
  -- learnedSound).  The builtin object is built FIRST and kept whole; only the
  -- drawing and the surface are installed on the instance.
  local function build(game, mon, newMoveId, onDone, learnedSound)
    local Builtin = require("src.ui.MoveLearnMenu")
    local self = Builtin.new(game, mon, newMoveId, onDone, learnedSound)
    self.__g9gui = true
    self.__t = 0
    local baseUpdate = self.update
    self.update = function(s, dt)
      s.__t = (s.__t or 0) + 1
      if baseUpdate then return baseUpdate(s, dt) end
    end
    if gen == 2 then
      -- Gold has no :uiSize(); install the widescreen contract instead (a
      -- no-op classic :draw, drawsWidescreen and the 540x360 page painter).
      Shell.gen2Surface(Theme, self, function(s) drawPage(s) end)
      -- OPAQUE and WIDE, the two markers the Gen 1 arm gets above, because
      -- this screen is opened MID-BATTLE: the custom battle scene below is
      -- itself a wide, OPAQUE state, and Game2:drawScene resolves the wide
      -- layer as the stack's TOP or its visible BASE.  Without `isOpaque` the
      -- visible base is the SCENE, so Game2 paints the battle (and this
      -- screen's no-op classic :draw paints nothing) -- the user's report:
      -- the engine's plain TextBox floating over a live battlefield with no
      -- modern page under it.  Opaque makes THIS page the visible base, so
      -- Game2 calls its :drawWidescreen and the battle is left underneath,
      -- exactly as the Gen 1 arm's isOpaque does there.  `isWideBattleLayout`
      -- is the same marker the Gen 1 arm installs, and on Gold it is what
      -- ui/textbox.lua's surfaceIsWide reads to decide the engine's own
      -- messages belong on this page: with it, a card in the page's
      -- coordinates; without it, `Game.wideBattleInStack` would find the
      -- battle under this page and keep the classic white box.
      self.isOpaque = true
      self.isWideBattleLayout = M.isWideBattleLayout
    else
      self.isOpaque = true
      self.uiSize = M.uiSize
      self.isWideBattleLayout = M.isWideBattleLayout
      self.wantsFillScale = M.wantsFillScale
      self.sgbPalettes = M.sgbPalettes
      self.draw = function(s) drawPage(s) end
    end
    -- ...and keep the page under the engine's own narration (see
    -- installFinish): the last message of the flow must read as this page's
    -- card too, not as the cart's window over the battle.
    installFinish(self)
    return self
  end

  function M.new(game, ...) return build(game, ...) end

  -- the render harness drives the page directly (a state cannot be pushed in a
  -- headless boot); public so a shot can draw without building one
  M.drawPage = drawPage
  M.monName = monName

  return M
end
