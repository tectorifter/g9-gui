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
--
-- GEN 2: the same page on Gold.  The module builds Gold's own
-- src.ui.gen2.PartyMenu (so its STATS/SWITCH/MOVE/ITEM/MAIL/field-move actions
-- and its swap and medicine animations all keep running) and paints the page
-- through :drawWidescreen instead of :uiSize -- see the Gen 2 arm at the end.
return function(mod, ctx)
  local Theme, Backdrop, Roster, Portraits = ctx.Theme, ctx.Backdrop,
    ctx.Roster, ctx.Portraits
  local Shell = ctx.Shell
  local opt = ctx.opt
  -- The party-HP sentinel (ui/hp_guard.lua).  Optional; nil means the page
  -- simply browses without it.
  local HPGuard = ctx.HPGuard

  local M = {}
  local Strings = require("src.core.Strings")
  local Gen2 = ctx.gen == 2

  -- The engine's OWN PartyMenu class, one per generation.  Required lazily so a
  -- Gen 1 boot never pulls the Gold module in (src/ui/gen2/PartyMenu.lua).
  local function builtin()
    if Gen2 then return require("src.ui.gen2.PartyMenu") end
    return require("src.ui.PartyMenu")
  end

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
    if Gen2 then return M.newGen2(game, opts) end
    local self = builtin().new(game, opts)
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
      -- the HP sentinel: compare the party against the pre-turn baseline
      if HPGuard then HPGuard.tick(s.game, s) end
      -- LEFT/RIGHT returns to the START menu, the mirror of the START menu's
      -- LEFT/RIGHT paging in here.  Popping first (then onCancel, which is the
      -- engine's own `reopen`) is exactly what the shipped Menu does for a
      -- row, so the stack ends up [world, START] and never stacks pages.
      if s.__fromStart and not s.submenu and not s.battle and not s.heal then
        local input = s.game and s.game.input
        if input and (input:wasPressed("left") or input:wasPressed("right"))
            and s.game.stack:top() == s then
          if HPGuard then
            HPGuard.keep(s.game, "POKeMON->START", s.party)
          end
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
    -- The HP sentinel (ui/hp_guard.lua) guards only the FIELD page -- the one
    -- the START screen pages into.  A battle switch, an item target, a TM/HM
    -- or evolution-stone "ABLE?" list and the medicine picker are all the
    -- same engine object but may legitimately move HP, so they carry the
    -- ineligible flag and the sentinel never second-guesses them.  `keep` is
    -- a no-op here when the START page already took the pre-turn baseline.
    self.__g9guard = not (self.battle or self.pickOnly or self.itemUse
      or self.tmhm or self.evoStone or self.forceSwitch)
    if HPGuard and self.__g9guard then
      HPGuard.keep(game, nil, self.party or (game.save and game.save.party))
    end
    self.draw = function(s) M.draw(s) end
    return self
  end

  -- ---------------------------------------------------------------- rendering

  local function drawSubmenu(self, game, sub_items, sub_index, rowY)
    local C = Theme.col
    local F = Theme.fonts(game).body
    local n = #sub_items
    if n == 0 then return end
    -- rows are 34px: a 15px-ink label needs 15, and ONE column of seven ends
    -- exactly on the content band (7 * 34 + 16 = 254 = ROSTER_Y..H-40) -- so
    -- seven is the most that may be stacked before the list reaches the
    -- footer's hint row.  A longer list WRAPS instead of running under it: the
    -- columns on screen are the ones the cursor has reached, so pressing DOWN
    -- off the seventh row grows the popup by a column and lands on the rest of
    -- the list at the TOP of it (the engine's own subIndex wraps from the last
    -- option back to the first, STATS).  The rail wraps the same way (see
    -- ui/shell.lua S.rows), so both lists in this page behave alike.
    local row = 34
    local cap = 7
    local gap = 8
    local totalCols = math.max(1, math.ceil(n / cap))
    local shown = math.ceil((sub_index or 1) / cap)
    if shown < 1 then shown = 1 end
    if shown > totalCols then shown = totalCols end
    local widest = 0
    for _, it in ipairs(sub_items) do
      local tw = Theme.w(it.label or "", F)
      if tw > widest then widest = tw end
    end
    -- A single column keeps the popup's usual chunky width.  Several hug their
    -- own labels so the whole grid still fits inside the roster band: they take
    -- the band's full width and tighten the label gutter while a very wide
    -- option needs the pixels, so no option is ever cut to an ellipsis.
    local w = 240
    local pad = 44
    if shown > 1 then
      local room = math.floor((Shell.ROSTER_W - (shown - 1) * gap) / shown)
      if room < 130 then room = 130 end
      pad = math.max(24, math.min(44, room - widest - 16))
      w = math.max(150, widest + pad + 16)
      if w > room then w = room end
    elseif widest + 56 > w then
      w = widest + 56
    end
    local h = math.min(cap, n) * row + 16
    local pw = shown * w + (shown - 1) * gap
    local x = Shell.ROSTER_X + Shell.ROSTER_W - pw
    -- The popup must clear the footer's hint row: the frame used to be clamped
    -- to H-40 (320), which is where the hints' key chips and text print, so a
    -- tall popup's bottom border and its drop shadow ran through them.  Clamp
    -- instead so the SHADOW (3px below the fill) stops at the footer RULE
    -- (314) -- the frame then ends exactly on the rule -- and when even that
    -- does not fit, tighten the panel's own padding rather than slide it up
    -- past the content band.
    local bottom = Shell.FOOT_RULE_Y - 3
    local y = rowY
    if y + h > bottom then y = bottom - h end
    if y < Shell.ROSTER_Y then y = Shell.ROSTER_Y end
    if y + h > bottom then h = bottom - y end
    -- dim the roster behind the popup so the list reads as modal
    Theme.set(C.black, 0.45)
    Theme.rect("fill", Shell.ROSTER_X - 6, Shell.ROSTER_Y - 8,
      Shell.ROSTER_W + 12, Shell.HEADER_H + 6 * Shell.ROW_H + 12, 6)
    Theme.panel(x, y, pw, h, { radius = 6, shadow = 3 })
    for k = 1, shown do
      local cx = x + (k - 1) * (w + gap)
      -- a rule between the columns, so the grid reads as columns and not as
      -- one very wide list
      if k > 1 then
        Theme.set(C.border)
        Theme.rect("fill", cx - gap * 0.5 - 0.5, y + 10, 1, h - 20, 0)
      end
      local first = (k - 1) * cap + 1
      local count = math.min(cap, n - first + 1)
      local ty = y + 8
      for i = 1, count do
        local at = first + i - 1
        local it = sub_items[at]
        local selected = at == sub_index
        if selected then
          Theme.set(C.rowLit)
          Theme.rect("fill", cx + 5, ty - 5, w - 10, row - 6, 5)
          Theme.chevrons(cx + 12, ty + 3, 18, C.accent,
            0.5 + 0.5 * math.sin(self.__t * 0.2))
        end
        Theme.text(Theme.fit(it.label or "", F, w - pad - 12), cx + pad, ty + 3, F,
          "left", selected and C.accent or C.inkDim)
        ty = ty + row
      end
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
      right = ("%s %d/%d"):format(Shell.ui("PARTY"), #party, 6),
      caption = caption,
      money = Shell.money(game),
      embellish = embellish,
    })

    Roster.draw(Theme, game, {
      x = Shell.ROSTER_X, y = Shell.ROSTER_Y, w = Shell.ROSTER_W,
      rowH = Shell.ROW_H, headerH = Shell.HEADER_H,
      party = party, index = index, focus = true,
      t = self.__t or 0, mode = opt("ui_portraits"),
      embellish = embellish, logic = self, portraits = Portraits,
    })

    -- the START menu's rows, in the same rail the START screen draws; the
    -- POKeMON row is the section being shown (band, no cursor).  A START menu
    -- long enough to run under the footer wraps into COLUMNS on the START
    -- screen (ui/shell.lua S.rows), but this page's rail is a STATIC mirror --
    -- it has no cursor of its own -- and the roster it sits beside starts 8px
    -- away: a second rail column would land on the first member's portrait and
    -- read as a rendering bug, not as a menu.  So the mirror shows the
    -- section's own column only (`cols = 1`); the rows past the eighth stay
    -- one DOWN away on the START screen, whose rail is the one with a cursor.
    Shell.rows(Theme, game, {
      items = self.__rows,
      active = self.__partyRow,
      columns = true, cap = 8, cols = 1,
      t = self.__t or 0,
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

  -- ============================================================= Gen 2 (Gold)
  -- Gold's PartyMenu is the same idea on a different engine object
  -- (src/ui/gen2/PartyMenu.lua): it owns the same party/index/cursor, but the
  -- field submenu lives at self.submenu {items,index,...} and its registry
  -- writes lowercase status ids.  The arm below builds the REAL Gen 2 object
  -- -- so every action (STATS, SWITCH, MOVE, ITEM/MAIL, the field moves, the
  -- medicine HP-fill and swap animations, TM/HM ABLE views) keeps running --
  -- and swaps only :drawWidescreen for the suite's page, laid out exactly as
  -- the Gen 1 page above.  Gold has no LEFT/RIGHT turn back to the START menu
  -- (its START screen has no paging), so the footer does not advertise one.

  function M.newGen2(game, opts)
    local self = builtin().new(game, opts)
    self.__g9gui = true
    self.__t = 0
    -- the START menu's own rows, for the shared left rail (Gold arm).
    -- Shell.startRows skips the POKeMON row, so the rail is the START screen's
    -- rows minus this page's own -- exactly the Gen 1 arrangement.
    self.__rows = Shell.startRows(game, Strings("POK\xc3\xa9MON"), 2)
    self.__partyRow = Shell.partyRow(self.__rows, Strings("POK\xc3\xa9MON"))
    -- The HP sentinel (ui/hp_guard.lua) guards only the field page the START
    -- menu pages into -- Gold marks that push with opts.submenu = true.  A
    -- battle switch (battle / battleSubmenu) or a TM/HM list is the same
    -- engine object but may legitimately move HP, so it is left alone.
    self.__g9guard = self.wantsSubmenu == true and not self.battle
      and not self.wantsBattleSubmenu and not self.tmhm
    if HPGuard and self.__g9guard then
      HPGuard.keep(game, nil, self.party or (game.save and game.save.party))
    end
    -- tick an animation counter; the engine's own update (cursor, submenu,
    -- switch/softboiled, item targeting) is otherwise untouched.
    local baseUpdate = self.update
    self.update = function(s, dt)
      s.__t = (s.__t or 0) + 1
      if HPGuard then HPGuard.tick(s.game, s) end
      if M.pageToMenu2(s) then return end
      if baseUpdate then baseUpdate(s, dt) end
    end
    Shell.gen2Surface(Theme, self, function(s) M.drawGen2(s) end)
    -- the summary screen floats over this page and re-draws it beneath itself
    -- (see ui/summary.lua's Gen 2 arm); this is the page painter it calls.
    self.__g9guiPage = function(s) M.drawGen2(s) end
    return self
  end

  -- LEFT/RIGHT returns to the START menu, the mirror of that menu's paging into
  -- here.  Only the START menu's own POKeMON page answers it: the engine marks
  -- that push with opts.submenu = true (Game2:pushStartMenuItem), and it is the
  -- only push carrying onCancel = back.  So a battle switch, an item target, a
  -- PC box or the Day-Care list keeps its shipped LEFT/RIGHT behaviour (which
  -- is nothing outside a battle grid).  The engine's own B path is reused --
  -- storeCursor, then onCancel, which pops this page back onto the rail.  The
  -- cart's white menu fade is gone (ui/start_menu.lua's installNoFade), so both
  -- the LEFT/RIGHT turn and B land on the rail in the same frame -- the swap is
  -- seamless.
  function M.pageToMenu2(self)
    if not self.wantsSubmenu then return false end
    -- a popup / swap / medicine result owns the pad while it is up
    if self.submenu or self.switchFrom or self.softboiledFrom
        or self.itemResult then
      return false
    end
    if type(self.onCancel) ~= "function" then return false end
    local game = self.game
    local input = game and game.input
    if not (input and (input:wasPressed("left") or input:wasPressed("right")))
    then return false end
    if game.stack:top() ~= self then return false end
    if self.storeCursor then self:storeCursor() end
    if HPGuard then HPGuard.keep(game, "POKeMON->START", self.party) end
    self.onCancel()
    return true
  end

  -- the Gen 2 screen's own prompt string, resolved through Strings when the
  -- engine stored a builtin key rather than literal text, then through
  -- Shell.display so the cart's print-time glyph macros ("Choose a #MON." uses
  -- "<PK><MN>") reach the screen as the text the tile font would have drawn.
  local function g2Prompt(self)
    local p = self.prompt
    if self.promptIsBuiltin and self.prompt then
      local ok, s = pcall(Strings, self.prompt)
      if ok then p = s end
    end
    return Shell.display(p)
  end

  function M.drawGen2(self)
    local game = self.game
    local C = Theme.col
    local background = opt("ui_background") ~= "false"
    local embellish = opt("ui_embellishment") ~= "false"

    Backdrop.draw(Theme, { w = W, h = H, t = self.__t or 0,
      background = background, embellishment = embellish })

    local party = self.party or (game.save and game.save.party) or {}
    local index = math.min(math.max(1, self.index or 1), math.max(1, #party))

    Shell.top(Theme, game, {
      title = "POK\xc3\xa9MON",
      right = ("%s %d/%d"):format(Shell.ui("PARTY"), #party, 6),
      caption = g2Prompt(self),
      money = Shell.money(game),
      embellish = embellish,
    })

    Roster.draw(Theme, game, {
      x = Shell.ROSTER_X, y = Shell.ROSTER_Y, w = Shell.ROSTER_W,
      rowH = Shell.ROW_H, headerH = Shell.HEADER_H,
      party = party, index = index, focus = true,
      t = self.__t or 0, gen = 2, mode = opt("ui_portraits"),
      embellish = embellish, logic = self, portraits = Portraits,
    })

    -- the START menu's rows, in the same rail the START screen draws.  Gold's
    -- START menu carries one more row than Gen 1's (POKeGEAR) and its own list
    -- already scrolls at eight, so a rail longer than the band is the norm here
    -- -- it wraps into columns on the START screen (ui/shell.lua S.rows), but
    -- this page's rail is the same STATIC mirror as the Gen 1 arm above and
    -- draws only the section's own column (`cols = 1`) for the same reason:
    -- the roster is 8px away, so a second column would sit on the first
    -- member's portrait.
    Shell.rows(Theme, game, {
      items = self.__rows, active = self.__partyRow, t = self.__t or 0,
      w = 158, labelPad = 32, columns = true, cap = 8, cols = 1,
    })

    -- the switch / softboiled source row keeps a hollow marker
    local from = self.switchFrom or self.softboiledFrom
    if from and from ~= index and party[from] then
      local _, ry = Roster.rowRect({ x = Shell.ROSTER_X, y = Shell.ROSTER_Y,
        w = Shell.ROSTER_W, rowH = Shell.ROW_H, headerH = Shell.HEADER_H }, from)
      Theme.set(C.accentDim)
      Theme.rect("line", Shell.ROSTER_X + 2.5, ry + 11.5, 22, 22, 4)
    end

    -- Gold's field submenu lives at self.submenu {items,index}; the shared
    -- popup draws the same {label} rows either generation.
    local sm = self.submenu
    if sm and sm.items then
      local _, ry = Roster.rowRect({ x = Shell.ROSTER_X, y = Shell.ROSTER_Y,
        w = Shell.ROSTER_W, rowH = Shell.ROW_H, headerH = Shell.HEADER_H },
        index)
      drawSubmenu(self, game, sm.items, sm.index or 1, ry)
    end

    local hints = {
      { key = "\xe2\x86\x91\xe2\x86\x93", text = "SELECT" },
      { key = "A", text = "OK" },
    }
    -- advertise the LEFT/RIGHT turn back to the START menu only on the page
    -- that menu opened (a battle or item party menu has no menu behind it)
    if self.wantsSubmenu then
      hints[#hints + 1] = { key = "\xe2\x86\x90\xe2\x86\x92", text = "MENU" }
    end
    hints[#hints + 1] = { key = "B", text = "BACK" }
    Shell.footer(Theme, game, { hints = hints })

    Theme.set(C.white)
  end

  return M
end
