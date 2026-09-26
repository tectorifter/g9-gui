-- ui/held_item.lua -- the GIVE / TAKE held-item menu (Gold).
--
-- Another VIEW takeover, and the last classic box the POKeMON page could still
-- drop into.  Gold's party submenu ITEM row pushes src.ui.gen2.HeldItemMenu --
-- a NON-opaque state drawn over the party list (menu_coords 12,12,19,17) -- so
-- pressing ITEM used to leave the modern page for the cart's white GIVE/TAKE
-- window, its own classic message boxes and a classic YES/NO.
--
-- This screen keeps the engine's object whole: the GIVE/TAKE cursor, the
-- DepositSellPack round-trip through the PACK, the KEY_ITEM / untossable
-- refusal, the MAIL-first guard, the swap question, the bag-full fallback and
-- the compose keyboard all keep running untouched.  Only :draw (and the
-- surface) move onto the suite's 540x360 page: the POKeMON page redraws under
-- a dim, so the flow reads as one modal on the party screen, and the three
-- boxes the engine draws itself -- the GIVE/TAKE menu, its message card and
-- its YES/NO -- become the suite's popups.
--
-- Gen 2 only: Gen 1 has no HeldItemMenu (MAIL is the only held-item path there,
-- src/ui/PartyMenu.lua's own MAIL row), so main.lua installs this arm on Gold
-- alone.
return function(mod, ctx)
  local Theme, Backdrop, Roster, Portraits = ctx.Theme, ctx.Backdrop,
    ctx.Roster, ctx.Portraits
  local Shell = ctx.Shell
  local opt = ctx.opt

  local M = {}
  local Strings = require("src.core.Strings")
  local W, H = Shell.W, Shell.H

  local Typer
  do
    local ok, v = pcall(require, "src.ui.gen2.Typer")
    Typer = ok and v or nil
  end

  -- The engine's OWN HeldItemMenu class: the object on the stack stays the
  -- engine's, so every behaviour above keeps working.  Required lazily.
  local function builtin()
    return require("src.ui.gen2.HeldItemMenu")
  end

  function M.new(game, opts)
    local self = builtin().new(game, opts)
    self.__g9gui = true
    self.__t = 0
    -- tick an animation counter; the engine's own update (cursor, messages,
    -- the swap question, the PACK round-trip) is otherwise untouched
    local baseUpdate = self.update
    self.update = function(s, dt)
      s.__t = (s.__t or 0) + 1
      if baseUpdate then return baseUpdate(s, dt) end
    end
    -- the START menu's own rows, for the shared left rail
    self.__rows = Shell.startRows(game, Strings("POK\xc3\xa9MON"), 2)
    Shell.gen2Surface(Theme, self, function(s) M.drawGen2(s) end)
    return self
  end

  -- ---------------------------------------------------------------- helpers
  local function pulse(self)
    return 0.5 + 0.5 * math.sin((self.__t or 0) * 0.2)
  end

  local function arrowOn(self)
    if Typer and Typer.arrowOn then return Typer.arrowOn(self) end
    return ((self.__t or 0) % 60) < 30
  end

  -- one centred panel + its page-advance chevron.  `lines` is the engine's own
  -- page (a list of display lines), already built by the engine's text tables.
  local function card(lines, self, withArrow)
    local C = Theme.col
    local F = Theme.fonts(self.game).body
    local w = 420
    local lh = 30
    local h = 22 + math.max(1, #lines) * lh + 22
    local x = math.floor((W - w) * 0.5)
    local y = math.floor((H - h) * 0.5)
    Theme.panel(x, y, w, h, { radius = 8, shadow = 5,
      color = C.panelLit, border = C.borderLit })
    if opt("ui_embellishment") ~= "false" then
      Theme.brackets(x + 5, y + 5, w - 10, h - 10, 18, C.accentDim)
    end
    local ty = y + 18
    for i = 1, #lines do
      Theme.text(Theme.fit(Shell.display(lines[i] or ""), F, w - 44), x + 22, ty,
        F, "left", C.ink)
      ty = ty + lh
    end
    if withArrow and arrowOn(self) then
      local cx = x + w - 24
      local cy = y + h - 14
      Theme.set(C.accent, 0.6 + 0.4 * pulse(self))
      love.graphics.polygon("fill", cx - 7, cy - 5, cx + 7, cy - 5, cx, cy + 5)
    end
    return x, y, w, h
  end

  -- the GIVE / TAKE menu: the engine's own ENTRIES, one modern row each
  local function drawChoices(self)
    local C = Theme.col
    local F = Theme.fonts(self.game).body
    local entries = builtin().ENTRIES or {}
    local n = #entries
    if n == 0 then return end
    local rowH = 44
    local w = 240
    for _, e in ipairs(entries) do
      local tw = Theme.w(Strings(e.label), F) + 96
      if tw > w then w = tw end
    end
    local h = n * rowH + 24
    local x = math.floor((W - w) * 0.5)
    local y = math.floor((H - h) * 0.5)
    Theme.panel(x, y, w, h, { radius = 8, shadow = 5,
      color = C.panelLit, border = C.borderLit })
    if opt("ui_embellishment") ~= "false" then
      Theme.brackets(x + 5, y + 5, w - 10, h - 10, 18, C.accentDim)
    end
    local ty = y + 12
    for i, e in ipairs(entries) do
      local on = i == (self.index or 1)
      if on then
        Theme.set(C.rowLit, 0.55)
        Theme.rect("fill", x + 8, ty - 4, w - 16, rowH - 8, 6)
        Theme.chevrons(x + 22, ty + 11, 18, C.accent, pulse(self))
      end
      Theme.text(Theme.fit(Strings(e.label), F, w - 92), x + 58, ty + 10, F,
        "left", on and C.accent or C.ink)
      ty = ty + rowH
    end
  end

  -- the engine's YES/NO, as the suite's two rows under the message
  local function drawYesNo(x, y, w, confirm, self)
    local C = Theme.col
    local F = Theme.fonts(self.game).body
    local labels = { Strings("YES"), Strings("NO") }
    for i = 1, 2 do
      local ry = y + (i - 1) * 38
      local on = (confirm.choice or 1) == i
      if on then
        Theme.set(C.rowLit, 0.55)
        Theme.rect("fill", x + 14, ry - 4, w - 28, 32, 5)
        Theme.chevrons(x + 24, ry + 3, 18, C.accent, pulse(self))
      end
      Theme.text(labels[i], x + 54, ry + 1, F, "left",
        on and C.accent or C.ink)
    end
  end

  -- the confirm: message pages first, then YES/NO on the last page (the
  -- engine's own held-item prompts ask the swap question across two pages)
  local function drawConfirm(self)
    local C = Theme.col
    local F = Theme.fonts(self.game).body
    local confirm = self.confirm
    local pages = confirm.pages or {}
    local lines = pages[confirm.page] or pages[1] or {}
    local last = confirm.page >= #pages
    local w = 420
    local lh = 30
    local h = 22 + math.max(1, #lines) * lh + (last and 2 * 38 + 22 or 0) + 22
    local x = math.floor((W - w) * 0.5)
    local y = math.floor((H - h) * 0.5)
    Theme.panel(x, y, w, h, { radius = 8, shadow = 5,
      color = C.panelLit, border = C.borderLit })
    if opt("ui_embellishment") ~= "false" then
      Theme.brackets(x + 5, y + 5, w - 10, h - 10, 18, C.accentDim)
    end
    local ty = y + 18
    for i = 1, #lines do
      Theme.text(Theme.fit(Shell.display(lines[i] or ""), F, w - 44), x + 22, ty,
        F, "left", C.ink)
      ty = ty + lh
    end
    if last then
      drawYesNo(x, ty + 12, w, confirm, self)
    elseif arrowOn(self) then
      local cx = x + w - 24
      local cy = y + h - 14
      Theme.set(C.accent, 0.6 + 0.4 * pulse(self))
      love.graphics.polygon("fill", cx - 7, cy - 5, cx + 7, cy - 5, cx, cy + 5)
    end
  end

  -- ---------------------------------------------------------------- the page
  function M.drawGen2(self)
    local game = self.game
    local C = Theme.col
    local background = opt("ui_background") ~= "false"
    local embellish = opt("ui_embellishment") ~= "false"

    Backdrop.draw(Theme, { w = W, h = H, t = self.__t or 0,
      background = background, embellishment = embellish })

    local party = (self.save and self.save.party)
      or (game and game.save and game.save.party) or {}
    local slot = math.min(math.max(1, self.slot or 1), math.max(1, #party))

    Shell.top(Theme, game, {
      title = "POK\xc3\xa9MON",
      right = ("PARTY %d/%d"):format(#party, 6),
      caption = Shell.display(self:monName()),
      money = Shell.money(game),
      embellish = embellish,
    })

    Roster.draw(Theme, game, {
      x = Shell.ROSTER_X, y = Shell.ROSTER_Y, w = Shell.ROSTER_W,
      rowH = Shell.ROW_H, headerH = Shell.HEADER_H,
      party = party, index = slot, focus = true,
      t = self.__t or 0, gen = 2, mode = opt("ui_portraits"),
      embellish = embellish, portraits = Portraits,
    })

    -- the same START rail as the START / POKeMON pages (when this page has
    -- one), drawn as the section's own column only -- see ui/shell.lua S.rows
    -- and the note in ui/party_menu.lua: this page is a modal, so the rail is
    -- context behind the wash and a second column would only be a distraction
    if self.__rows then
      Shell.rows(Theme, game, { items = self.__rows, w = 158, labelPad = 32,
        t = self.__t or 0, columns = true, cap = 8, cols = 1 })
    end

    -- the modal wash: the page stays visible under the popup, like the field
    -- submenu, so the flow reads as one screen
    Theme.set(C.black, 0.55)
    Theme.rect("fill", 0, 0, W, H, 0)

    local hints
    if self.message then
      local pages = self.message.pages or {}
      card(pages[self.message.page] or pages[1] or {}, self,
        self.message.page < #pages)
      hints = { { key = "A", text = Strings("OK") },
        { key = "B", text = Strings("BACK") } }
    elseif self.confirm then
      drawConfirm(self)
      hints = { { key = "\xe2\x86\x91\xe2\x86\x93", text = Strings("CHOOSE") },
        { key = "A", text = Strings("OK") },
        { key = "B", text = Strings("NO") } }
    else
      drawChoices(self)
      hints = { { key = "\xe2\x86\x91\xe2\x86\x93", text = Strings("SELECT") },
        { key = "A", text = Strings("OK") },
        { key = "B", text = Strings("BACK") } }
    end
    Shell.footer(Theme, game, { hints = hints })

    Theme.set(C.white)
  end

  return M
end
