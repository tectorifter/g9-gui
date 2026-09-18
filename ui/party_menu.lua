-- ui/party_menu.lua -- the POKeMON screen.
--
-- Another VIEW takeover.  The engine's own PartyMenu (src.ui.PartyMenu) is
-- still the object on the stack: it owns the party array (the save's, a
-- link/battle scoped view, or `opts.party`), the cursor index and its
-- remembered position, the field-move submenu and every action behind it --
-- FLY/SURF/CUT/FLASH/STRENGTH/SOFTBOILED/TELEPORT/DIG, STATS, SWITCH, CANCEL,
-- the medicine HP-fill animation, the swap animation, the TM/HM and evolution
-- stone ABLE/NOT ABLE views, battle switching and item targeting.  g9-gui only
-- replaces draw (and the surface), so all of that keeps working unchanged in
-- every context the engine pushes a party menu from.
--
-- Composition: the SAME page the START screen draws (ui/shell.lua owns the
-- geometry) -- its header, its footer, and the very same left rail -- with the
-- party roster filling the right column.  The rail deliberately omits the
-- START menu's POKeMON row (the right column IS the party; see
-- ui/start_menu.lua), and LEFT/RIGHT returns to the START menu when this page
-- was opened from there (the __fromStart flag below).  The old left-hand
-- detail card is gone: everything it duplicated (level, HP figures, the HP
-- gauge, status) is already on the member's own row, so the column now shows
-- the START menu's rows instead, exactly where the START menu draws them.
return function(mod, ctx)
  local Theme, Backdrop, Roster, Portraits = ctx.Theme, ctx.Backdrop,
    ctx.Roster, ctx.Portraits
  local Shell = ctx.Shell
  local opt = ctx.opt

  local M = {}
  local Builtin = require("src.ui.PartyMenu")
  local Strings = require("src.core.Strings")

  local W, H = Shell.W, Shell.H

  function M.uiSize() return W, H end

  -- the shared whole-stack walk (ui/shell.lua S.wide)
  M.isWideBattleLayout = Shell.wide

  -- This screen fills the window for the same reason the START screen does
  -- (see ui/start_menu.lua): its sibling already blits at the window-fill
  -- scale -- the engine's PartyMenu class carries a wantsFillScale installed
  -- by g9-battle-sprites, which this instance inherits -- and declaring it
  -- here makes the intent this mod's own rather than a side effect of another
  -- mod being installed.  Same whole-stack gate as isWideBattleLayout.
  function M.wantsFillScale(self)
    return Shell.wide(self)
  end

  function M.sgbPalettes() return {} end

  function M.new(game, opts)
    local self = Builtin.new(game, opts)
    self.__g9gui = true
    self.isOpaque = true
    self.letterboxWhite = true
    self.__t = 0
    self.uiSize = M.uiSize
    self.isWideBattleLayout = M.isWideBattleLayout
    self.wantsFillScale = M.wantsFillScale
    self.sgbPalettes = M.sgbPalettes
    -- Was this page opened from the START menu (the LEFT/RIGHT paging, or the
    -- arrow key's row)?  Set by ui/start_menu.lua and consumed here, so only
    -- the START menu's own party page answers LEFT/RIGHT -- a battle switch,
    -- an item target or a PC party menu keeps its shipped controls.
    self.__fromStart = game.__g9guiPartyFromStart and true or false
    game.__g9guiPartyFromStart = nil
    local baseUpdate = self.update
    self.update = function(s, dt)
      s.__t = (s.__t or 0) + 1
      -- LEFT/RIGHT returns to the START menu, the mirror of the START menu's
      -- LEFT/RIGHT paging in here.  Popping first (then onCancel, which is the
      -- engine's own `reopen`) is exactly what the shipped Menu does for a
      -- row, so the stack ends up [world, START] and never stacks pages.
      if s.__fromStart and not s.submenu and not s.battle and not s.heal then
        local input = s.game and s.game.input
        if input and (input:wasPressed("left") or input:wasPressed("right"))
            and s.game.stack:top() == s then
          s.game.stack:pop()
          if s.onCancel then s.onCancel() end
          return
        end
      end
      baseUpdate(s, dt)
    end
    -- the START menu's own rows, for the shared left rail (labels only; the
    -- POKeMON row is hidden there, so it is hidden here too)
    self.__rows = Shell.startRows(game, Strings("POK\xc3\xa9MON"))
    self.__partyRow = Shell.partyRow(self.__rows, Strings("POK\xc3\xa9MON"))
    self.draw = function(s) M.draw(s) end
    return self
  end

  -- ---------------------------------------------------------------- rendering

  local function drawSubmenu(self, game, sub_items, sub_index, rowY)
    local C = Theme.col
    local F = Theme.fonts(game).body
    local n = #sub_items
    if n == 0 then return end
    -- rows are 34px: a 15px-ink label needs 15, and the popup stays inside the
    -- roster band for a six-item field-move list
    local row = 34
    local h = n * row + 16
    local w = 240
    for _, it in ipairs(sub_items) do
      local tw = Theme.w(it.label or "", F) + 44
      if tw > w then w = tw end
    end
    local x = Shell.ROSTER_X + Shell.ROSTER_W - w
    local y = rowY
    if y + h > H - 40 then y = H - 40 - h end
    if y < Shell.ROSTER_Y then y = Shell.ROSTER_Y end
    -- dim the roster behind the popup so the list reads as modal
    Theme.set(C.black, 0.45)
    Theme.rect("fill", Shell.ROSTER_X - 6, Shell.ROSTER_Y - 8,
      Shell.ROSTER_W + 12, Shell.HEADER_H + 6 * Shell.ROW_H + 12, 6)
    Theme.panel(x, y, w, h, { radius = 6, shadow = 3 })
    local ty = y + 8
    for i, it in ipairs(sub_items) do
      local selected = i == sub_index
      if selected then
        Theme.set(C.rowLit)
        Theme.rect("fill", x + 5, ty - 5, w - 10, row - 6, 5)
        Theme.chevrons(x + 12, ty + 3, 18, C.accent,
          0.5 + 0.5 * math.sin(self.__t * 0.2))
      end
      Theme.text(Theme.fit(it.label or "", F, w - 44 - 12), x + 44, ty + 3, F,
        "left", selected and C.accent or C.inkDim)
      ty = ty + row
    end
  end

  function M.draw(self)
    local game = self.game
    local C = Theme.col
    local F = Theme.fonts(game)
    local background = opt("ui_background") ~= "false"
    local embellish = opt("ui_embellishment") ~= "false"

    Backdrop.draw(Theme, { w = W, h = H, t = self.__t or 0,
      background = background, embellishment = embellish })

    local party = self.party or (game.save and game.save.party) or {}
    local index = math.min(math.max(1, self.index or 1), math.max(1, #party))

    -- header: the engine's own context prompt is the caption
    local caption
    local okMsg, msg = pcall(function() return self:bottomMessage() end)
    if okMsg and type(msg) == "string" then caption = msg:gsub("\n", " ") end
    Shell.top(Theme, game, {
      title = "POK\xc3\xa9MON",
      right = ("PARTY %d/%d"):format(#party, 6),
      caption = caption,
      money = Shell.money(game),
      embellish = embellish,
    })

    -- the START menu's rows, in the same rail the START screen draws; the
    -- POKeMON row is the section being shown (band, no cursor)
    Shell.rows(Theme, game, {
      items = self.__rows,
      active = self.__partyRow,
      t = self.__t or 0,
    })

    Roster.draw(Theme, game, {
      x = Shell.ROSTER_X, y = Shell.ROSTER_Y, w = Shell.ROSTER_W,
      rowH = Shell.ROW_H, headerH = Shell.HEADER_H,
      party = party, index = index, focus = true,
      t = self.__t or 0, mode = opt("ui_portraits"),
      embellish = embellish, logic = self, portraits = Portraits,
    })

    -- the swap / softboiled source row keeps a hollow marker
    local from = self.swapFrom or self.softboiledFrom
    if from and from ~= index and party[from] then
      local _, ry = Roster.rowRect({ x = Shell.ROSTER_X, y = Shell.ROSTER_Y,
        w = Shell.ROSTER_W, rowH = Shell.ROW_H, headerH = Shell.HEADER_H }, from)
      Theme.set(C.accentDim)
      Theme.rect("line", Shell.ROSTER_X + 2.5, ry + 11.5, 22, 22, 4)
    end

    if self.submenu and self.subItems then
      local _, ry = Roster.rowRect({ x = Shell.ROSTER_X, y = Shell.ROSTER_Y,
        w = Shell.ROSTER_W, rowH = Shell.ROW_H, headerH = Shell.HEADER_H },
        index)
      drawSubmenu(self, game, self.subItems, self.subIndex or 1, ry)
    end

    -- the footer advertises the LEFT/RIGHT page turn only on a menu the START
    -- screen opened (a battle or item party menu has no menu to page back to)
    local hints = {
      { key = "\xe2\x86\x91\xe2\x86\x93", text = "SELECT" },
      { key = "A", text = "OK" },
    }
    if self.__fromStart then
      hints[#hints + 1] = { key = "\xe2\x86\x90\xe2\x86\x92", text = "MENU" }
    end
    hints[#hints + 1] = { key = "B", text = "BACK" }
    Shell.footer(Theme, game, { hints = hints })

    Theme.set(C.white)
  end

  return M
end
