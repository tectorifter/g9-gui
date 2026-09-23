-- ui/choice.lua -- the modern YES / NO choice box.
--
-- The one input box the suite had left classic.  src.ui.ChoiceBox is the
-- engine's shared two-option menu: the overworld's `askYesNo` prompts (every
-- NPC and event question), the SURF / field-move confirmations, a shop's or
-- PC's questions, the pokecenter's HEAL/CANCEL -- every one of them a small
-- white box with the cart's tile labels and a tile cursor, drawn just above
-- the dialogue window.  ui/textbox.lua already KNOWS about it (it tells the
-- box apart from a state that replaced it so the dialogue card under it keeps
-- drawing) but only ever drew the engine's own version.
--
-- This module DRESSES the instance at the same push choke point main.lua uses
-- for the dialogue window: the engine's own object stays on the stack, so its
-- input (up/down or left/right, A, B), its Timing.YES_NO_ANSWER hold and the
-- cursor snap to NO on B all keep running; only :draw is replaced.
--
-- BOTH GENERATIONS.  This used to install on Gold only, because Gen 1's
-- dialogue card is painted in WINDOW space through the render.hud hook while
-- the engine still drew the choice box in the classic letterbox -- modernising
-- it there needed a second window-space painter.  That painter now exists, and
-- it rides the dialogue card's own space: the box is drawn through the same
-- `Theme.fontsAt(scale)` faces at the renderer's own scale, so YES/NO and the
-- labels are as sharp as the question above them on either generation.  The
-- space itself is ui/textbox.lua's `M.hudSpace` -- one derivation, used by
-- both painters, so the pair can never disagree about where UI pixels land
-- (the engine docks the whole canvas when the box is anchored, so both must
-- apply the same origin).
--
-- Fail-open, exactly like the dialogue card: the window-space half is only
-- engaged once the engine has actually raised render.hud, and without a usable
-- space (no hook, no frameRects, or a wide surface under the box) the box
-- falls back to the same card composed at 1:1 in the classic 160x144 canvas --
-- chunkier, never missing.
return function(mod, ctx)
  local Theme = ctx.Theme
  local C = Theme.col
  -- The dialogue card's window space, so the box above it lands on the same
  -- pixels with the same density.  Optional: without it (the module failed to
  -- load) every box keeps the surface card.
  local Textbox = ctx.Textbox
  -- The page helpers (S.card / S.pageOffset): a box over one of this suite's
  -- own pages is drawn as that page's card.  Optional, like everything else.
  local Shell = ctx.Shell

  local Strings
  do
    local ok, v = pcall(require, "src.core.Strings")
    Strings = ok and v or function(s) return s end
  end
  local UIVisibility
  do
    local ok, v = pcall(require, "src.battle.UIVisibility")
    UIVisibility = ok and v or nil
  end
  local ChoiceBox
  do
    local ok, v = pcall(require, "src.ui.ChoiceBox")
    ChoiceBox = ok and v or nil
  end

  local M = { isChoiceSkin = true, gen2 = ctx.gen == 2 }

  -- The engine builds this box with setmetatable({}, ChoiceBox), so the class
  -- table IS the identity: nothing else on the stack answers this.
  function M.isChoiceBox(state)
    if type(state) ~= "table" or not ChoiceBox then return false end
    return getmetatable(state) == ChoiceBox
  end

  -- Only modernise a box that belongs to a conversation the suite has already
  -- dressed -- one sitting over the modern dialogue card (or over one of the
  -- suite's own pages).  A battle's switch offer and a bare shop/PC prompt keep
  -- the engine's box, exactly as the battle's own message window keeps the
  -- classic look.
  --
  -- A Gen 1 page of this suite counts as dressed in its own right: the PC's
  -- toss confirm is pushed straight over the item list (there is no TextBox to
  -- dress, the question is the list's own footer), and over a wide page the
  -- engine centres the classic box inside the page, so the answer is drawn as
  -- the suite's card in the PAGE's space instead (see M.draw).
  function M.canDress(stack, state)
    local states = stack and stack.states
    local lower = states and states[#states - 1]
    if type(lower) ~= "table" then return false end
    if lower.__g9guiBox then return true end
    return lower.__g9gui == true and not lower.isBattle
  end

  -- The box's own geometry, in the GB canvas the engine placed it in: tx/ty/
  -- tw/th are tile counts, and the labels sit two rows apart starting on
  -- `firstItem` (Theme.choiceBox's default is 14,7,6,5).
  local function geom(state)
    local tx = (state.tx or 14) * 8
    local ty = (state.ty or 7) * 8
    local tw = (state.tw or 6) * 8
    local th = (state.th or 5) * 8
    return tx, ty, tw, th
  end

  -- A hairline stroke is drawn with love's line mode, whose width is a LOVE
  -- unit and does NOT scale with the coordinates it is given -- so window space
  -- has to set it to one physical pixel on purpose (see ui/textbox.lua).
  local function withLineWidth(lw, fn)
    local g = love.graphics
    local set = g and g.setLineWidth
    local changed = false
    if set then changed = pcall(set, lw) end
    fn()
    if changed then pcall(set, 1) end
  end

  -- The card, painted through a space.  `nil` is the surface space: the
  -- identity mapping, so every expression below is exactly what this module
  -- has always drawn at 1:1 in the classic canvas.  A space (see
  -- ui/textbox.lua's `M.hudSpace`) supplies the origin (`ox`,`oy`), the window
  -- extent of one UI pixel (`kx`,`ky`) and the face set built at that scale.
  local function paint(state, sp)
    local game = state.game
    local kx = sp and sp.kx or 1
    local ky = sp and sp.ky or 1
    local ox = sp and sp.ox or 0
    local oy = sp and sp.oy or 0
    local round = math.min(kx, ky)
    local hair = (sp and sp.hair) or 1
    local F = sp and sp.fonts or Theme.fonts(game)
    local f = F.boxSmall or F.box or F.body
    local ux, uy, uw, uh = geom(state)
    local x, y = ox + ux * kx, oy + uy * ky
    local w, h = uw * kx, uh * ky
    local pulse = 0.5 + 0.5 * math.sin((state.__t or 0) * 0.22)

    -- card: shadow, panel, top shine, hairline border, accent cap
    Theme.set(C.shadow)
    Theme.rect("fill", x + 2 * kx, y + 2 * ky, w - 2 * kx, h, 4 * round)
    Theme.set(C.panelDeep)
    Theme.rect("fill", x, y, w, h, 4 * round)
    Theme.set(C.shine)
    Theme.rect("fill", x + hair, y + hair, w - 2 * hair, hair, 0)
    Theme.set(C.border)
    withLineWidth(hair, function()
      Theme.rect("line", x + 0.5 * hair, y + 0.5 * hair, w - hair, h - hair,
        4 * round)
    end)
    Theme.set(C.accent, 0.42)
    Theme.rect("fill", x + 4 * kx, y + hair, w - 8 * kx, hair, 0)

    local labels = state.labels or { "YES", "NO" }
    local index = state.index or 1
    local first = state.firstItem or 1
    local vy = type(state.ty) == "number" and state.ty or 7
    for i = 1, 2 do
      local ly = oy + (vy + first + (i - 1) * 2) * 8 * ky
      local on = i == index
      if on then
        Theme.set(C.rowLit, 0.55)
        Theme.rect("fill", x + 3 * kx, ly - 3 * ky, w - 6 * kx, 15 * ky,
          3 * round)
        Theme.chevrons(x + 5 * kx, ly + 1.5 * ky, 9 * round, C.accent, pulse)
      end
      Theme.text(Theme.fit(tostring(Strings(labels[i])), f, w - 26 * kx),
        x + 20 * kx, ly + 1 * ky, f, "left", on and C.accent or C.ink)
    end
    Theme.set(C.white)
  end

  -- The dressed box on top of the stack, if any: a choice box is always the
  -- last thing pushed (`TextBox`'s own choice hook pushes it and nothing goes
  -- over it), so the top IS the box being answered.
  local function topChoice(game)
    local stack = game and game.stack
    if not (stack and type(stack.top) == "function") then return nil end
    local ok, top = pcall(stack.top, stack)
    if not (ok and M.isChoiceBox(top)) then return nil end
    return top
  end

  -- Set by M.hudDraw when the top box was actually painted in window space.
  -- The surface draw stands down only on that -- a failed hook, a nil space or
  -- a wide surface leaves the box on the surface card, so it can never vanish.
  local hudLive = false

  -- The box as the suite's card, in a page's own coordinates.  The question is
  -- carried over from the page's own caption where there is one: the PC's toss
  -- confirm prints "Toss X?" on the list's footer rather than in a TextBox, and
  -- the card's wash would otherwise bury it.  When the box below is a dressed
  -- TextBox -- a YES/NO the engine pushes over a message ("Want to get your
  -- #DEX rated?") -- the QUESTION LINES come from that box instead: over a page
  -- the dialogue card stands down for this one (ui/textbox.lua's
  -- `choiceOverTop`), so the message and the two rows are ONE card, exactly as
  -- the Gold PC draws its own confirms.
  local function paintCard(state)
    local stack = state.game and state.game.stack
    local states = stack and stack.states
    local lower = states and states[#states - 1]
    local lines
    if Textbox and Textbox.pageLines and type(lower) == "table"
        and lower.__g9guiBox then
      lines = Textbox.pageLines(lower)
    end
    local prompt = lower and lower.footer
    if not lines and type(prompt) == "string" and prompt ~= "" then
      lines = { (prompt:gsub("[\r\n\v\f]+", " "):gsub("%s+$", "")) }
    end
    local labels = state.labels or { "YES", "NO" }
    local rows = {}
    for i = 1, 2 do rows[i] = { text = tostring(Strings(labels[i])) } end
    Shell.card(Theme, state.game, {
      lines = lines, rows = rows, index = state.index, w = 320,
      hints = {
        { key = "\xe2\x86\x91\xe2\x86\x93", text = "SELECT" },
        { key = "A", text = "OK" },
        { key = "B", text = "NO" },
      },
      t = state.__t or 0,
    })
  end

  function M.draw(state)
    if UIVisibility and not UIVisibility.bottomVisible(state, false) then
      return
    end
    local game = state.game
    -- A page of this suite under the box: the engine shifts a pushed classic
    -- overlay right by classicOffset (Game:draw), so the box is drawn in the
    -- PAGE's own coordinates -- the same centred card every other popup takes
    -- -- after undoing that shift.  Only this suite's own 540-wide page does
    -- this: a battle's 304px surface shifts a classic overlay too, and there
    -- the box keeps the classic drawing (and canDress refuses a battle anyway).
    local off = (Shell and Shell.pageOffset) and Shell.pageOffset(game) or 0
    if not (off > 0 and Shell.W and off == math.floor((Shell.W - 160) / 2)) then
      off = 0
    end
    local r = game and game.renderer
    if off <= 0 and r and r.setUIAnchor then
      -- Keep the engine's own edge anchor, which ChoiceBox:draw used to set
      -- before this module replaced it: in UI LAYOUT = DYNAMIC the renderer
      -- docks this region against the window edge, and the window-space card
      -- reads the very same canvas shift out of its space (ui/textbox.lua's
      -- spaceOrigin), so the box and the dialogue card under it travel
      -- together.  A no-op under the default CENTERED layout, and on Gold
      -- (which has no layout row).  NOT declared over one of this suite's own
      -- pages: there the card is drawn in PAGE space, and a classic anchor
      -- would make the renderer lift that rectangle out of the page blit and
      -- blit it against the window edge -- a white hole in the page (see
      -- ui/textbox.lua's M.draw).
      local ax, ay, aw, ah = geom(state)
      r:setUIAnchor(ax, ay, aw, ah, state.anchor)
    end
    -- The window-space card for this frame is drawn by the render.hud hook,
    -- after the frame's composite; drawing it here as well would double the
    -- translucent panel under it.
    if state == topChoice(game) and hudLive then return end
    if off > 0 then
      local g = love.graphics
      if g.push then g.push() end
      if g.translate then g.translate(-off, 0) end
      local ok, err = pcall(paintCard, state)
      if g.pop then g.pop() end
      if not ok then
        error("g9-gui: the page-space choice card failed: " .. tostring(err), 0)
      end
      return
    end
    -- GOLD's half of the same answer (see ui/textbox.lua's M.pageUnder and
    -- M.inPageSpace).  Gold has no renderer and no classicOffset: the page
    -- paints the whole window itself through ui/shell.lua's gen2Fit, and the
    -- engine then draws this box over it at Chrome's integer letterbox -- so the
    -- card is mapped into that pass and lands on the page's own pixels.  The
    -- message card under it stands down in the same frame (ui/textbox.lua's
    -- M.draw / choiceOverTop), so the QUESTION and the two rows are still one
    -- card, exactly as on Gen 1.
    local page = Textbox and Textbox.pageUnder and Textbox.pageUnder(state)
    if page and Textbox.inPageSpace and not (game and game.renderer) then
      if Textbox.inPageSpace(game, page, function() paintCard(state) end) then
        return
      end
    end
    paint(state, nil)
  end

  -- The render.hud half: paint the top choice box through the dialogue card's
  -- own window space, so the pair is drawn at one scale and one origin.  Called
  -- from the hook installed by M.installHook; public so the render harness can
  -- drive it directly.
  function M.hudDraw(game, viewport)
    hudLive = false
    local box = topChoice(game)
    if not box then return end
    if UIVisibility and not UIVisibility.bottomVisible(box, false) then return end
    local sp = Textbox and Textbox.hudSpace
      and Textbox.hudSpace(box, game, viewport) or nil
    if not sp then return end
    hudLive = true
    local g = love.graphics
    local pushed = false
    if g and g.push then
      pushed = pcall(g.push, "all")
      if not pushed then pushed = pcall(g.push) end
    end
    if g and g.setColor then pcall(g.setColor, 1, 1, 1, 1) end
    local ok, err = pcall(paint, box, sp)
    if g and g.setColor then pcall(g.setColor, 1, 1, 1, 1) end
    if pushed and g and g.pop then pcall(g.pop) end
    if not ok then
      error("g9-gui: the window-space choice box failed: " .. tostring(err), 0)
    end
  end

  -- Subscribe the window-space painter.  A missing/refusing hook API is not an
  -- error: hudLive simply stays false and every box keeps the surface card.
  function M.installHook(m)
    if M.__hooked then return true end
    if not (m and m.hooks and type(m.hooks.wrap) == "function") then
      return false
    end
    local remover = m.hooks:wrap("render.hud", function(next, game, viewport)
      if type(next) == "function" then pcall(next, game, viewport) end
      M.hudDraw(game, viewport)
    end)
    M.__hooked = true
    M.unhook = remover
    return true
  end

  -- Take over a pushed ChoiceBox instance.  Called from the StateStack.push
  -- wrapper in main.lua.
  function M.dress(state)
    if type(state) ~= "table" or state.__g9guiChoice then return state end
    state.__g9guiChoice = true
    state.__t = 0
    local baseUpdate = state.update
    if type(baseUpdate) == "function" then
      state.update = function(self, dt)
        self.__t = (self.__t or 0) + 1
        -- LEFT/RIGHT work the two rows too.  They are stacked VERTICALLY, so
        -- the arrows TOGGLE rather than pointing at a button (the engine's own
        -- ChoiceBox update watches up/down only).  The engine still owns A/B,
        -- the YES_NO_ANSWER hold and the cursor snap to NO; a direction press
        -- is simply left for it to ignore.
        local input = self.game and self.game.input
        if input and self.pending == nil
            and (input:wasPressed("left") or input:wasPressed("right")) then
          self.index = self.index == 1 and 2 or 1
        end
        return baseUpdate(self, dt)
      end
    end
    state.draw = function(self) M.draw(self) end
    return state
  end

  return M
end
