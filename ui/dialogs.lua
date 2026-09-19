-- ui/dialogs.lua -- the modern modal dialogs the suite still needed.
--
-- The engine draws the SAVE flow, the QUIT confirmation and the title's
-- CONTINUE window as classic 160x144 white boxes (a `Font.drawBox` panel, a
-- `TextBox` with a `ChoiceBox` beside it).  They are the last screens in the
-- START / title trees that were NOT the 540x360 page, so this module gives
-- them the same look as every other g9-gui screen:
--
--   card    a titled panel of label/value rows (the SAVE player panel, the
--           CONTINUE save data), optionally after a 30-frame beat
--   confirm a message plus YES / NO rows with the pulsing chevron cursor
--   notice  a message stage -- "Now saving...", "RED saved the game!" -- with
--           an icon and (optionally) a progress bar, auto-advancing
--
-- SURFACE.  Every dialog answers :uiSize() with 540x360 like the rest of the
-- suite, and :isWideBattleLayout()/:wantsFillScale() with Shell.wide(self), so
-- a dialog takes the window-fill page exactly like the screen it opens from.
--
-- FLOAT vs PAGE.  A dialog pushed over a page of OURS (the START screen, the
-- title menu) is NON-opaque: it dims that page and floats a centred panel over
-- it, so the menu stays visible around the panel the way ui/summary.lua's
-- Adv.Stats panel does.  Pushed over anything else -- the overworld behind the
-- QUIT confirm, a battle -- it is OPAQUE and draws the mod's own backdrop.
-- That is not cosmetic: the engine centres a CLASSIC state in the wide page
-- horizontally only (see ui/shell.lua's KNOWN LIMIT), so a non-opaque dialog
-- over a 160x144 overworld would leave the map band at the TOP of the page
-- instead of the middle.  The opaque page sidesteps that entirely.
--
-- Input: A advances/chooses, B cancels/answers NO, up/down move the confirm's
-- cursor -- the same keys the classic TextBox + ChoiceBox pair read.  A confirm
-- answers after a short HOLD with the box still up and the cursor settled,
-- exactly like ChoiceBox's Timing.YES_NO_ANSWER beat, so a held A cannot bleed
-- into whatever the answer pushes.
return function(mod, ctx)
  local Theme, Backdrop, Shell = ctx.Theme, ctx.Backdrop, ctx.Shell
  local opt = ctx.opt
  local Strings = require("src.core.Strings")

  local D = {}
  local C = Theme.col
  local W, H = Shell.W, Shell.H

  local HOLD = 12                      -- frames the answer cursor settles for
  local CARD_W, CONFIRM_W, NOTICE_W = 380, 400, 340

  -- ---------------------------------------------------------------- surfaces
  function D.uiSize() return W, H end
  function D.isWideBattleLayout(self) return Shell.wide(self) end
  function D.wantsFillScale(self) return Shell.wide(self) end
  function D.sgbPalettes() return {} end

  -- Does a page of ours sit under this dialog (so it should float and dim
  -- rather than paint its own backdrop)?  Asked at PUSH time, when the state
  -- below is the top of the stack.
  local function floatsOver(game)
    local stack = game and game.stack
    local top = stack and stack.top and stack:top()
    if not (top and top.__g9gui and top.isOpaque) then return false end
    return (top.isWideBattleLayout and top:isWideBattleLayout()) and true or false
  end

  local function newState(game, kind)
    local s = {
      game = game, __g9gui = true, __kind = kind, __t = 0,
      letterboxWhite = true,
      isOpaque = not floatsOver(game),
    }
    setmetatable(s, { __index = D })
    return s
  end

  local function sfx(game, name)
    if not name then return end
    pcall(function() require("src.core.Sound").play(game.data, name) end)
  end

  local function lines(text)
    local out = {}
    for piece in tostring(text):gmatch("[^\n]+") do out[#out + 1] = piece end
    if #out == 0 then out[1] = tostring(text) end
    return out
  end

  local function embellished()
    return opt("ui_embellishment") ~= "false"
  end

  -- pop self (if still on top) and hand control to one of the two callbacks
  local function leave(self, advance)
    local stack = self.game and self.game.stack
    if stack and stack:top() == self then stack:pop() end
    local fn = advance and self.onAdvance or self.onCancel
    if fn then fn() end
  end

  -- A dialog that throws while drawing takes the whole LÖVE loop down, and the
  -- engine does not pcall a state's draw -- so a real-engine-only error would
  -- leave a blank frame (an opaque dialog hides the menu under it).  Wrap both
  -- halves: a draw/update failure is logged ONCE with its message and the
  -- dialog steps aside, so the screen beneath comes back instead of blanking.
  local function harden(s)
    local baseDraw, baseUpdate = s.draw, s.update
    local reported = false
    local function report(err)
      if reported then return end
      reported = true
      local msg = ("g9-gui: the %s dialog failed: %s")
        :format(tostring(s.__kind), tostring(err)):gsub("%%", "%%%%")
      if mod and mod.log then mod.log:warn(msg) end
    end
    if baseDraw then
      s.draw = function(self, ...)
        local ok, err = pcall(baseDraw, self, ...)
        if not ok then report(err) end
      end
    end
    if baseUpdate then
      s.update = function(self, ...)
        local ok, err = pcall(baseUpdate, self, ...)
        if not ok then
          report(err)
          local stack = self.game and self.game.stack
          if stack and stack:top() == self then stack:pop() end
        end
      end
    end
    return s
  end

  -- ------------------------------------------------------------------ shared
  -- The save readout the SAVE card and the title's CONTINUE card both show:
  -- the engine's own PrintSaveScreenText / DisplayContinueGameInfo figures.
  function D.saveRows(game)
    local save = (game and game.save) or {}
    local badges = 0
    pcall(function()
      badges = require("src.inventory.Badges").count(game.data, save)
    end)
    local owned = 0
    for _ in pairs((save.pokedex and save.pokedex.owned) or {}) do
      owned = owned + 1
    end
    local t = math.floor(save.playTime or 0)
    return {
      { Strings("PLAYER"), (save.player and save.player.name) or "RED", "ink" },
      { Strings("BADGES"), ("%2d"):format(badges), "gold" },
      { Strings("POK\xc3\xa9DEX"), ("%3d"):format(owned), "gold" },
      { Strings("TIME"),
        ("%d:%02d"):format(math.floor(t / 3600), math.floor(t / 60) % 60),
        "gold" },
    }
  end

  local function paintBack(state, game)
    if state.isOpaque then
      Backdrop.draw(Theme, { w = W, h = H, t = state.__t or 0,
        background = opt("ui_background") ~= "false",
        embellishment = embellished() })
    else
      Theme.set(C.black, 0.62)
      Theme.rect("fill", 0, 0, W, H, 0)
    end
  end

  local function frame(x, y, w, h)
    Theme.panel(x, y, w, h, { radius = 8, shadow = 5,
      color = C.panelLit, border = C.borderLit })
    if embellished() then
      Theme.brackets(x + 5, y + 5, w - 10, h - 10, 18, C.accentDim)
    end
  end

  local function pulse(state)
    return 0.5 + 0.5 * math.sin((state.__t or 0) * 0.18)
  end

  -- ------------------------------------------------------------------- card
  -- spec = { title, rows = {{label, value, tone}}, pause, hints,
  --          onAdvance, onCancel }
  -- `pause` is a beat of frames the card holds before advancing on its own
  -- (the cart's `ld c, 30 / jp DelayFrames` before the SAVE prompt); with no
  -- pause the card waits for A.
  function D.paintCard(state, game, spec)
    local F = Theme.fonts(game)
    local rows = spec.rows or {}
    local hints = spec.hints
    local w = CARD_W
    local h = 46 + math.max(1, #rows) * 34 + (hints and 44 or 16)
    local x = math.floor((W - w) * 0.5)
    local y = math.floor((H - h) * 0.5) - 6

    paintBack(state, game)
    frame(x, y, w, h)

    Theme.set(C.panelDeep, 0.95)
    Theme.rect("fill", x + 1, y + 1, w - 2, 38, 7)
    Theme.set(C.accent, 0.35)
    Theme.rect("fill", x + 1, y + 39, w - 2, 1, 0)
    Theme.text(Theme.fit(spec.title or "", F.body, w - 44), x + 22, y + 10,
      F.body, "left", C.accent)

    local ry = y + 56
    for i = 1, #rows do
      local r = rows[i]
      local label = tostring(r[1] or "")
      Theme.text(label, x + 22, ry, F.body, "left", C.inkDim)
      local value = tostring(r[2] or "")
      local budget = (x + w - 22) - (x + 22 + Theme.w(label, F.body) + 24)
      Theme.text(Theme.fit(value, F.bold, budget), x + w - 22, ry,
        F.bold, "right", C[r[3] or "gold"] or C.gold)
      ry = ry + 34
    end

    if hints then
      Theme.hints(hints, x + 22, y + h - 30, F.body, { gap = 20 })
    end
  end

  function D.card(game, spec)
    local s = newState(game, "card")
    s.title = spec.title
    s.rows = spec.rows
    s.hints = spec.hints or {
      { key = "A", text = Strings("OK") },
      { key = "B", text = Strings("BACK") },
    }
    s.onAdvance, s.onCancel = spec.onAdvance, spec.onCancel
    s.__pause = spec.pause
    s.draw = function(self)
      D.paintCard(self, game, { title = self.title, rows = self.rows,
        hints = self.hints })
    end
    s.update = function(self, dt)
      self.__t = (self.__t or 0) + 1
      local input = self.game.input
      if (self.__pause or 0) > 0 then
        -- the cart's beat holds the panel before its prompt and watches no
        -- key, but B is a universal "out" here rather than a dead press
        self.__pause = self.__pause - 1
        if input and input:wasPressed("b") then
          sfx(self.game, "Press_AB")
          return leave(self, false)
        end
        if self.__pause <= 0 then
          self.__pause = nil
          leave(self, true)
        end
        return
      end
      if input:wasPressed("a") then
        sfx(self.game, "Press_AB")
        leave(self, true)
      elseif input:wasPressed("b") then
        sfx(self.game, "Press_AB")
        leave(self, false)
      end
    end
    return harden(s)
  end

  -- ------------------------------------------------------------------ confirm
  -- spec = { message, defaultNo, onChoose }
  function D.paintConfirm(state, game, spec)
    local F = Theme.fonts(game)
    local ls = spec.lines or {}
    local w = CONFIRM_W
    local h = 34 + #ls * 30 + 100
    local x = math.floor((W - w) * 0.5)
    local y = math.floor((H - h) * 0.5) - 6

    paintBack(state, game)
    frame(x, y, w, h)

    local ty = y + 24
    for i = 1, #ls do
      Theme.text(Theme.fit(ls[i], F.body, w - 44), x + 22, ty, F.body, "left",
        C.ink)
      ty = ty + 30
    end

    ty = ty + 12
    local labels = { Strings("YES"), Strings("NO") }
    for i = 1, 2 do
      local ry = ty + (i - 1) * 38
      local on = (state.index or 1) == i
      if on then
        Theme.set(C.rowLit, 0.55)
        Theme.rect("fill", x + 14, ry - 5, w - 28, 32, 5)
        Theme.chevrons(x + 24, ry + 2, 18, C.accent, pulse(state))
      end
      Theme.text(labels[i], x + 54, ry, F.body, "left",
        on and C.accent or C.ink)
    end

    Theme.hints({
      { key = "\xe2\x86\x91\xe2\x86\x93", text = Strings("CHOOSE") },
      { key = "A", text = Strings("OK") },
      { key = "B", text = Strings("NO") },
    }, x + 22, y + h - 30, F.body, { gap = 20 })
  end

  function D.confirm(game, spec)
    local s = newState(game, "confirm")
    s.lines = lines(spec.message)
    s.index = spec.defaultNo and 2 or 1
    s.onChoose = spec.onChoose
    s.draw = function(self)
      D.paintConfirm(self, game, { lines = self.lines, index = self.index })
    end
    s.update = function(self, dt)
      self.__t = (self.__t or 0) + 1
      local input = self.game.input
      if self.pending ~= nil then
        self.hold = self.hold - 1
        if self.hold <= 0 then
          local yes = self.pending
          self.pending = nil
          local stack = self.game.stack
          if stack:top() == self then stack:pop() end
          if self.onChoose then self.onChoose(yes) end
        end
        return
      end
      if input:wasPressed("up") or input:wasPressed("down") then
        self.index = self.index == 1 and 2 or 1
      elseif input:wasPressed("a") then
        sfx(self.game, "Press_AB")
        self.pending = (self.index == 1)
        self.hold = HOLD
      elseif input:wasPressed("b") then
        sfx(self.game, "Press_AB")
        self.index = 2
        self.pending = false
        self.hold = HOLD
      end
    end
    return harden(s)
  end

  -- ------------------------------------------------------------------- notice
  -- spec = { message, tone, icon, sound, auto, progress, onDone }
  -- `auto` frames is the whole life of the notice (the cart's "Now saving..."
  -- holds 120 by DelayFrames and takes no input), then onDone runs.
  function D.paintNotice(state, game, spec)
    local F = Theme.fonts(game)
    local ls = spec.lines or {}
    local w = NOTICE_W
    local h = 30 + #ls * 32 + (spec.total and 40 or 22)
    local x = math.floor((W - w) * 0.5)
    local y = math.floor((H - h) * 0.5) - 6

    paintBack(state, game)
    frame(x, y, w, h)

    local ink = C.ink
    if spec.tone == "good" then ink = C.good
    elseif spec.tone == "bad" then ink = C.bad end
    local blockTop = y + 24
    local blockH = #ls * 32

    -- icon: a lozenge in the message's own tone, with a tick inside a "check"
    local ix, iy = x + 24, blockTop + math.floor(blockH * 0.5) - 13
    Theme.set(C[spec.tone] or C.accent, 0.22)
    Theme.rect("fill", ix, iy, 26, 26, 6)
    Theme.set(C[spec.tone] or C.accent)
    Theme.rect("line", ix + 0.5, iy + 0.5, 25, 25, 6)
    if spec.icon == "check" then
      -- a tick, drawn with love.graphics.line's polyline (no line-width call:
      -- the engine's own minimal builds and the layout harness both lack it)
      Theme.set(ink)
      love.graphics.line(ix + 6, iy + 14, ix + 11, iy + 19, ix + 20, iy + 7)
    elseif spec.icon == "warn" then
      Theme.text("!", ix + 13, iy + 5, F.bold, "center", ink)
    else
      Theme.diamond(ix + 13, iy + 13, 5, C[spec.tone] or C.accent)
    end

    local ty = y + 26
    for i = 1, #ls do
      Theme.text(Theme.fit(ls[i], F.body, w - 86), x + 62, ty, F.body, "left",
        ink)
      ty = ty + 32
    end

    if spec.total and spec.total > 0 then
      local frac = 1 - (state.auto or 0) / spec.total
      Theme.bar(x + 24, y + h - 30, w - 48, 8, frac, C.accent,
        { bg = C.panelDeep, border = C.border })
    end
  end

  function D.notice(game, spec)
    local s = newState(game, "notice")
    s.lines = lines(spec.message)
    s.tone = spec.tone or "accent"
    s.icon = spec.icon
    s.auto = spec.auto
    s.onDone = spec.onDone
    s.draw = function(self)
      D.paintNotice(self, game, { lines = self.lines, tone = self.tone,
        icon = self.icon, auto = self.auto, total = spec.auto })
    end
    s.update = function(self, dt)
      self.__t = (self.__t or 0) + 1
      if self.auto and self.auto > 0 then
        self.auto = self.auto - 1
        if self.auto <= 0 then
          local stack = self.game.stack
          if stack:top() == self then stack:pop() end
          if self.onDone then self.onDone() end
        end
      end
    end
    sfx(game, spec.sound)
    return harden(s)
  end

  return D
end
