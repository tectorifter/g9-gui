-- ui/shell.lua -- the frame both g9-gui menu screens are laid out in.
--
-- The START screen and the POKeMON screen are the same page with a different
-- right-hand column: one surface size, one header, one left rail, one footer.
-- Everything they share lives here, so the two can never drift apart -- they
-- used to own private copies of every constant, which is exactly how they
-- ended up at different sizes.
--
-- SURFACE.  Both screens answer :uiSize() with 540x360.  That is 3:2, the one
-- shape that divides 1080x720 evenly: a 1080x720 window blits this page at a
-- whole 2x with no letterbox at all (Renderer:fitScale = min(1080/540,
-- 720/360) = 2).  It is also 1.7x the classic page in width and 2.5x in
-- height, which is what lets the portrait cards be large rectangles instead of
-- the old 54x19 slivers.
--
-- The page cannot simply be 1080x720 itself: Renderer:setUISize rejects a
-- surface over MAX_UI_WIDTH/MAX_UI_HEIGHT (640x576) and falls all the way back
-- to 160x144, so 540x360 is the largest 3:2 page the engine will accept.
--
-- The type is Saira and it is proportional (see ui/theme.lua), so there is no
-- longer a cell grid to lay out on: every metric below is chosen against
-- MEASURED string widths, and any string that can grow (a caption, the
-- badge/time readout) goes through Theme.fit's pixel budget rather than a
-- character count.  The design body is 22 (cap ink 15px) and the secondary
-- size is 13.  At 22 a 540x360 page blits 2x, so a cap reaches 30 screen
-- pixels on a 1080x720 window -- the FFXII on-screen reading size.  Nothing
-- here ever calls Renderer:setUISize or love.graphics.setCanvas: a screen
-- answers :uiSize() and Game:draw sizes the surface (setCanvas from inside a
-- state's draw is the documented crash hazard).
--
-- KNOWN LIMIT: the engine centres a CLASSIC 160x144 state pushed over a wide
-- surface horizontally only (Game:draw's classicOffset).  A non-opaque overlay
-- -- a TextBox, the SAVE panel -- therefore draws at the TOP of this page
-- rather than its bottom.  The SAVE panel already lives at the top of the
-- classic page, so it is unaffected; a bottom dialogue box reads high.
return function(mod)
  local S = {}

  -- ---------------------------------------------------------------- geometry
  S.W, S.H = 540, 360

  -- Header: two ink-top lines and a rule, then the content band.  Ink tops
  -- because Theme.text's y is the top of the glyph ink, not of the line box.
  -- A body-22 line's ink is 15px tall, so 23px of pitch keeps the two lines and
  -- the rule apart without spreading the header over the content band.
  S.HDR_Y, S.CAP_Y, S.RULE_Y = 8, 31, 59
  S.CONTENT_Y = 66
  S.MARGIN = 16

  -- Footer: a rule and one line of hint chips, off the bottom edge.
  S.FOOT_RULE_Y, S.FOOT_Y = 314, 320

  -- Left rail: the START menu's own rows, in the same place on both screens.
  -- The rail is sized by its widest label ("POKeMON", ~109px at body 22) plus
  -- the chevron gutter -- at 30px with Plain Pixel a 136px rail was enough, but
  -- a proportional face needs ~152 for the same words.
  S.LIST_X, S.LIST_Y, S.LIST_W, S.LIST_ROW = 16, 66, 152, 30
  S.LIST_LABEL_X = S.LIST_X + 34

  -- Right column: the party roster (ui/roster.lua draws it).  Six rows of 40px
  -- fill the same band as the rail's eight rows of 30px, so the rail and the
  -- roster stand level with no header row between them and the band (a header
  -- row would push the sixth slot past the footer rule).
  S.ROSTER_X = S.LIST_X + S.LIST_W + 8
  S.ROSTER_Y = 66
  S.ROSTER_W = S.W - S.ROSTER_X - S.MARGIN
  S.ROW_H, S.HEADER_H = 40, 0

  -- --------------------------------------------------------------- surface
  -- The one question every g9-gui screen asks the stack: do I own the wide
  -- surface right now?  True unless an OPAQUE state that is not ours sits
  -- above us -- the whole-stack walk Game.wideBattleInStack/fillScaleInStack
  -- use.  A non-opaque prompt (a TextBox, the SAVE panel, the bag's own
  -- popups) keeps this surface and is centred by the engine's classic-offset
  -- path; an opaque classic screen this mod has not modernised (the town map,
  -- a PC box) takes the surface back to 160x144 so its layout stays whole.
  -- Shared so every screen answers the question identically -- a screen that
  -- answered it differently is exactly how the START page once ended up
  -- smaller than the POKeMON page.
  function S.wide(self)
    local states = self.game and self.game.stack and self.game.stack.states
    if not states then return true end
    local seen = false
    for i = 1, #states do
      local s = states[i]
      if s == self then seen = true
      elseif seen and s.isOpaque and not s.__g9gui then return false end
    end
    return true
  end

  -- Is a battle anywhere on the stack?  A screen that the engine also opens
  -- mid-battle (the bag, a Pokédex entry) must NOT take over the surface
  -- there: the wide battle owns it, and swapping in this mod's 540x360 page
  -- would re-centre the battle's own HUD and prompts.  Screens reachable only
  -- from the START menu never see a battle and skip this.
  function S.inBattle(game)
    local states = game and game.stack and game.stack.states
    for i = 1, #(states or {}) do
      local s = states[i]
      if s and s.isBattle then return true end
    end
    return false
  end

  -- ------------------------------------------------------------------- money
  -- The player's wallet is ONE readout on the header's second line, directly
  -- under the BADGES / DEX readout -- not a column in the roster.
  function S.money(game)
    return ("MONEY: %d"):format((game and game.save and game.save.money) or 0)
  end

  -- ------------------------------------------------------------------- header
  -- opts = { title, right, caption, money, embellish }
  function S.top(Theme, game, opts)
    local C = Theme.col
    local F = Theme.fonts(game)
    local m = S.MARGIN
    local leftX = 44
    local capB = Theme.capOf(F.body)

    if opts.embellish ~= false then
      Theme.diamond(24, S.HDR_Y + 9, 7, C.accent)
      Theme.diamond(24, S.HDR_Y + 9, 3, C.void)
    end
    local tw = Theme.text(opts.title or "", leftX, S.HDR_Y, F.body, "left", C.ink)

    -- The right readout is the one header string that genuinely grows: the
    -- Safari Zone appends its step and BALL counters to the badge/time/dex
    -- line.  It gets the space the title does not use, drops to the secondary
    -- size when that is not enough, and is finally cut by pixel budget so it
    -- can never run into the title.
    if opts.right then
      local avail = (S.W - m) - (leftX + tw) - 16
      local rf = F.body
      if Theme.w(opts.right, rf) > avail then rf = F.small end
      local ry = S.HDR_Y + capB - Theme.capOf(rf)
      Theme.text(Theme.fit(opts.right, rf, avail), S.W - m, ry, rf, "right",
        C.gold)
    end

    -- Second line: the selected row's caption on the left, the wallet on the
    -- right.  The caption is cut by RENDERED width, leaving the wallet its own
    -- room so the two can never meet.
    local cap = opts.caption
    if opts.money then
      local mw = Theme.w(opts.money, F.bold)
      Theme.text(opts.money, S.W - m, S.CAP_Y, F.bold, "right", C.gold)
      cap = Theme.fit(cap, F.body, (S.W - m) - mw - 16 - leftX)
    else
      cap = Theme.fit(cap, F.body, (S.W - m) - leftX)
    end
    if cap and cap ~= "" then
      Theme.text(cap, leftX, S.CAP_Y, F.body, "left", C.inkDim)
    end

    Theme.rule(S.MARGIN - 2, S.RULE_Y, S.W - (S.MARGIN - 2) * 2, C.border)
  end

  -- ------------------------------------------------------------------- footer
  -- opts = { hints, right }
  function S.footer(Theme, game, opts)
    local C = Theme.col
    local F = Theme.fonts(game)
    Theme.rule(S.MARGIN - 2, S.FOOT_RULE_Y, S.W - (S.MARGIN - 2) * 2, C.border)
    local used = Theme.hints(opts.hints or {
      { key = "\xe2\x86\x91\xe2\x86\x93", text = "SELECT" },
      { key = "A", text = "OK" },
      { key = "B", text = "BACK" },
    }, S.MARGIN, S.FOOT_Y, F.body, { gap = 24 })
    if opts.right then
      -- The right readout (a transient notice, the party count) shares the
      -- footer line with the hint chips, so it is cut to what the chips left
      -- free -- otherwise a long notice runs straight through the hints.
      local avail = (S.W - S.MARGIN) - (S.MARGIN + used) - 16
      Theme.text(Theme.fit(opts.right, F.body, avail), S.W - S.MARGIN, S.FOOT_Y,
        F.body, "right", C.inkFaint)
    end
  end

  -- --------------------------------------------------------------- left rail
  -- The START menu's rows, drawn identically on both screens.
  --
  -- opts = { items (labels or {label=}), index (the cursor row), active (a row
  --          that is not the cursor but is the section being shown), scroll,
  --          maxVisible, t }
  function S.rows(Theme, game, opts)
    local C = Theme.col
    local F = Theme.fonts(game).body
    local items = opts.items or {}
    if #items == 0 then return end
    local visible = opts.maxVisible and math.min(opts.maxVisible, #items) or #items
    local scroll = opts.scroll or 0
    local h = visible * S.LIST_ROW + 4
    Theme.panel(S.LIST_X, S.LIST_Y, S.LIST_W, h, { radius = 6, shadow = 2 })

    local y = S.LIST_Y + 2
    for row = 1, visible do
      local item = items[scroll + row]
      if not item then break end
      local label = type(item) == "string" and item or (item.label or "")
      local at = scroll + row
      local selected = at == opts.index
      local band = selected or at == opts.active
      -- The band's own rect is LIST_ROW - 2 tall, i.e. y-2 .. y+28: an 18px
      -- chevron centred in it starts at y+5 and a 15px-ink label at y+6.
      if band then
        Theme.set(C.rowLit, selected and 0.55 or 0.34)
        Theme.rect("fill", S.LIST_X + 4, y - 2, S.LIST_W - 8, S.LIST_ROW - 2, 5)
      end
      local lx = S.LIST_LABEL_X
      local label2 = Theme.fit(label, F,
        (S.LIST_X + S.LIST_W) - lx - 6)
      if selected then
        Theme.chevrons(S.LIST_X + 8, y + 5, 18, C.accent,
          0.5 + 0.5 * math.sin((opts.t or 0) * 0.18))
        -- double-print the selected row for weight
        Theme.text(label2, lx, y + 6, F, "left", C.accent)
        Theme.text(label2, lx + 1, y + 6, F, "left", C.accent)
      else
        Theme.text(label2, lx, y + 6, F, "left",
          band and C.ink or C.inkDim)
      end
      y = y + S.LIST_ROW
    end

    if opts.maxVisible and scroll + opts.maxVisible < #items then
      Theme.set(C.accent)
      love.graphics.polygon("fill", S.LIST_X + S.LIST_W - 20, y - 12,
        S.LIST_X + S.LIST_W - 8, y - 12, S.LIST_X + S.LIST_W - 14, y - 4)
    end
  end

  -- ------------------------------------------------------- generic list page
  -- A full-height list panel for the classic lists this mod takes over (the
  -- bag, the POKeDEX, OPTIONS, the MODS manager).  Each screen converts its
  -- own state into plain view rows and this draws them, so every list in the
  -- game reads as the same page.
  --
  -- rows[i] = { text, right, marker, dim, header }
  --   text   the row's own label
  --   right  right-aligned trailing text (a count, a value, a price)
  --   marker true draws the small lozenge (the POKeDEX's owned ball)
  --   dim    true draws the label faint (a disabled row)
  --   header true draws a section heading -- no band, no cursor
  --
  -- opts = { rows, index, scroll, maxVisible, x, y, w, row, t, rightPad }
  -- `index`/`scroll` are counted in ROWS, so a header row is addressable and
  -- the caller's own scroll arithmetic (cursorRows / syncScroll) applies.
  function S.list(Theme, game, opts)
    local C = Theme.col
    local F = Theme.fonts(game)
    local rows = opts.rows or {}
    if #rows == 0 then return end
    local x = opts.x or S.LIST_X
    local y = opts.y or S.LIST_Y
    local w = opts.w or S.LIST_W
    local row = opts.row or S.LIST_ROW
    local labelPad = opts.labelPad or 34
    local rightPad = opts.rightPad or 12
    local visible = opts.maxVisible and math.min(opts.maxVisible, #rows) or #rows
    local scroll = opts.scroll or 0
    local h = visible * row + 4
    Theme.panel(x, y, w, h, { radius = 6, shadow = 2 })

    local ry = y + 2
    for i = 1, visible do
      local item = rows[scroll + i]
      if not item then break end
      local at = scroll + i
      local lx = x + labelPad
      if item.header then
        Theme.rule(x + 8, ry + row - 8, w - 16, C.border)
        Theme.text(Theme.fit(item.text or "", F.small, w - 20), x + 12,
          ry + 5, F.small, "left", C.inkFaint)
      else
        local selected = at == opts.index
        local band = selected or at == opts.active
        if band then
          Theme.set(C.rowLit, selected and 0.55 or 0.34)
          Theme.rect("fill", x + 4, ry - 2, w - 8, row - 2, 5)
        end
        if selected then
          Theme.chevrons(x + 8, ry + 5, 18, C.accent,
            0.5 + 0.5 * math.sin((opts.t or 0) * 0.18))
        elseif item.marker then
          Theme.diamond(x + 15, ry + row * 0.5 - 3, 4, C.accentDim)
        end
        local rw = item.right and (Theme.w(item.right, F.body) + 14) or 0
        local budget = (x + w - rightPad - rw) - lx
        local ink = C.ink
        if item.dim then ink = C.inkFaint
        elseif selected then ink = C.accent
        elseif band then ink = C.ink end
        local label = Theme.fit(item.text or "", F.body, budget)
        Theme.text(label, lx, ry + 6, F.body, "left", ink)
        if selected then -- double-print for weight, like the START rail
          Theme.text(label, lx + 1, ry + 6, F.body, "left", ink)
        end
        if item.right then
          Theme.text(item.right, x + w - rightPad, ry + 6, F.body, "right",
            selected and C.accent or C.gold)
        end
      end
      ry = ry + row
    end

    if opts.more or (opts.maxVisible and scroll + opts.maxVisible < #rows) then
      Theme.set(C.accent)
      love.graphics.polygon("fill", x + w - 20, ry - 12, x + w - 8, ry - 12,
        x + w - 14, ry - 4)
    end
    return x, y, w, row, scroll
  end

  -- ------------------------------------------------------------ start rows
  -- The START menu's own row labels, built through the engine's StartMenu so
  -- the POKeDEX row (gated on Oak's gift), MODS (gated on a discovered mod)
  -- and the ui.start_menu.items hook all behave exactly as they do on the
  -- real START screen.  Labels only: the POKeMON screen's rail is a section
  -- marker, not a menu.  Cached per game table.
  --
  -- The POKeMON row is SKIPPED: that row is gone from the START menu (the
  -- POKeMON page is reached with LEFT/RIGHT instead -- see ui/start_menu.lua),
  -- and the two screens must draw the identical rail.  `partyLabel` is passed
  -- in because only the caller has Strings.
  function S.startRows(game, partyLabel)
    if type(game) ~= "table" then return nil end
    if game.__g9guiStartRows then return game.__g9guiStartRows end
    local ok, StartMenu = pcall(require, "src.ui.StartMenu")
    if not (ok and type(StartMenu) == "table"
      and type(StartMenu.new) == "function") then return nil end
    local ok2, menu = pcall(StartMenu.new, game)
    if not (ok2 and type(menu) == "table") then return nil end
    local rows = {}
    for i, item in ipairs(menu.items or {}) do
      if item.label ~= partyLabel then rows[#rows + 1] = item.label end
    end
    if #rows == 0 then return nil end
    game.__g9guiStartRows = rows
    return rows
  end

  -- the index of the START menu's POKeMON row inside a label list
  function S.partyRow(rows, partyLabel)
    for i = 1, #(rows or {}) do
      if rows[i] == partyLabel then return i end
    end
    return nil
  end

  return S
end
