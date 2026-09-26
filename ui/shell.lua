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

  -- The modern UI's own lexicon (ui/translation.lua's M.ui).  Individual labels
  -- are localized by the Theme as they are drawn, but a COMPOSED readout -- the
  -- "MONEY: 2244" wallet, the "BADGES n HH:MM DEX n" line, "PARTY 3/6" -- is
  -- one string the lexicon cannot match, so its WORDS are looked up here and
  -- the number is spliced in.  No-op when the translation layer is absent or
  -- inactive.  Resolved lazily and once, since the layer is published in the
  -- entry chunk before any screen draws.
  local uiFn
  local function T(text)
    if not uiFn then
      local t = mod.exports and mod.exports.translation
      if t and type(t.ui) == "function" then uiFn = t.ui end
    end
    if not uiFn then return text end
    local ok, v = pcall(uiFn, text)
    if ok and type(v) == "string" and v ~= "" then return v end
    return text
  end
  S.ui = T

  -- A boolean option row, read the same way main.lua reads it: the choice's
  -- stored value ("true"/"false"), a boolean, a number or the choice's own
  -- LABEL ("ON"/"OFF") all mean the same thing.  The Android report that
  -- flipped g9-Battle-Scene's learner row showed the platform can hand a row
  -- back in any of those shapes, and this module reads mod.options directly
  -- (it is built from the mod alone), so it needs the same reader rather than
  -- an exact `tostring(v) == "false"`.  Answers nil for a row that is absent or
  -- of no shape we know, so each caller keeps its own fail-open default.
  local function optionOn(key)
    local o = mod and mod.options
    if not (o and type(o.get) == "function") then return nil end
    local ok, v = pcall(o.get, o, key)
    if not ok then return nil end
    if v == true then return true end
    if v == false then return false end
    if type(v) == "number" then return v ~= 0 end
    if type(v) == "string" then
      local s = v:lower()
      if s == "on" or s == "true" or s == "yes" or s == "1" then return true end
      if s == "off" or s == "false" or s == "no" or s == "0" or s == "" then
        return false
      end
    end
    return nil
  end

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

  -- ------------------------------------------------------------- gen 2 surface
  -- Gold has no :uiSize(); a screen that wants the big page answers
  -- :drawsWidescreen() and paints the whole window itself.  These are the Gen 2
  -- half of the surface contract above.  S.gen2Page fills the window with the
  -- suite's own void, computes the FILL scale for the 540x360 page (the same
  -- min(winW/540, winH/360) the Gen 1 Renderer's uiFill path uses, so both
  -- generations blit the page at one size) and draws the page under a
  -- translate/scale.  S.gen2Surface installs the three methods on an instance,
  -- so a screen module only supplies its page painter.
  function S.gen2Fit(winW, winH)
    winW = tonumber(winW) or S.W
    winH = tonumber(winH) or S.H
    local scale = math.min(winW / S.W, winH / S.H)
    if not (scale and scale > 0) then scale = 1 end
    local ox = math.floor((winW - S.W * scale) / 2 + 0.5)
    local oy = math.floor((winH - S.H * scale) / 2 + 0.5)
    return scale, ox, oy
  end

  function S.gen2Page(Theme, self, winW, winH, drawFn)
    local G = love.graphics
    local C = Theme.col
    local scale, ox, oy = S.gen2Fit(winW, winH)
    -- the surround: the suite's own void edge to edge, so a window that is not
    -- 3:2 letterboxes in the design's dark blue rather than the cart's paper
    Theme.set(C.voidDeep)
    Theme.rect("fill", 0, 0, tonumber(winW) or S.W, tonumber(winH) or S.H, 0)
    if G.push then G.push() end
    G.translate(ox, oy)
    G.scale(scale, scale)
    -- Publish the page->window mapping while the page draws.  The page is drawn
    -- in its own 540x360 coordinates under this translate/scale, but
    -- love.graphics.setScissor works in WINDOW pixels and is NOT affected by
    -- graphical transformations ("The dimensions of the scissor are unaffected
    -- by graphical transformations" -- love.graphics.setScissor), so any rect
    -- that must be clipped has to map itself out of page space through this.
    -- `nil` means there is no transform (Gen 1 draws its page into a real
    -- 540x360 surface at 1:1).  See ui/portraits.lua's clip.
    local prev = Theme.page
    Theme.page = { scale = scale, ox = ox, oy = oy }
    -- Publish the page's own fit for the rest of the frame.  Gold runs a
    -- pushed TextBox through a SECOND pass at Chrome's integer letterbox (see
    -- ui/textbox.lua's M.inPageSpace), and the only way that pass can put the
    -- dialogue card on this page's pixels is to know the fit the page was just
    -- drawn with -- the same numbers, straight from gen2Fit.  `self` identifies
    -- the page so a box riding some other page is never given this one's fit.
    if self and type(self.game) == "table" then
      self.game.__g9guiPageFit = { self = self, scale = scale, ox = ox, oy = oy,
        w = tonumber(winW) or S.W, h = tonumber(winH) or S.H }
    end
    drawFn(self)
    Theme.page = prev
    if G.pop then G.pop() end
    Theme.set(C.white)
  end

  function S.gen2Surface(Theme, self, drawFn)
    -- The page is painted by :drawWidescreen, so the instance's NATIVE :draw
    -- must never paint again.  Game2:drawScene resolves the wide layer as the
    -- stack's TOP, or as its visible BASE when a non-wide state (a TextBox,
    -- the GIVE/TAKE menu) sits above one -- and then runs stack:draw() from
    -- that base up, which calls the taken-over screen's own classic :draw()
    -- UNDER the modern page: the native party list showing through the
    -- dialogue card, over the modern rails and portrait cards.  A no-op draw
    -- is correct for every state on this contract: whenever it is the wide
    -- layer it is painted by :drawWidescreen, and whenever it is drawn from
    -- stack:draw() instead, the page above it is what should show.
    self.draw = function() end
    self.drawsWidescreen = function() return true end
    self.wantsFillScale = function() return true end
    self.drawWidescreen = function(s, winW, winH)
      S.gen2Page(Theme, s, winW, winH, drawFn)
    end
  end

  -- ------------------------------------------------------------ display text
  -- Engine-authored labels carry the cart's print-time glyph macros: Gold's
  -- START menu spells its POKeGEAR row "<PO><KE>GEAR" (the $70/$71 ligature
  -- tiles) and prompts write POKeMON as "#MON".  On the cart the tile font
  -- expands them at print time (src/render/Font.lua's charmap + MACRO_TEXT);
  -- this suite draws Saira, which has no such tiles, so the macros would reach
  -- the screen raw -- the "<PO><KE>GEAR" row in the Gen 2 rail.  Expand them to
  -- the text the cart would draw, long before Theme.fit measures anything.
  -- Gen 1 labels already hold real characters, so this is a no-op there; a
  -- token with no entry is left exactly as it was.
  local TOKENS = {
    -- charmap.asm $70/$71: "<PO>" + "<KE>" together spell POKe ("<POKE>", $24)
    PO = "PO", KE = "K\xc3\xa9",
    POKE = "POK\xc3\xa9",
    PK = "PK", MN = "MN", PKMN = "POK\xc3\xa9MON",
    PC = "PC", TM = "TM",
    TRAINER = "TRAINER", ROCKET = "ROCKET",
    ["\xe2\x80\xa6\xe2\x80\xa6"] = "\xe2\x80\xa6\xe2\x80\xa6",
  }

  function S.display(text)
    if type(text) ~= "string" or text == "" then return text end
    -- charmap.asm $e1/$e2: "<PK>" + "<MN>" are TWO font glyphs whose shapes
    -- spell "POKé" and "MON" -- the cart's Font.split matches the SEQUENCE, so
    -- the pair is expanded first.  The single-token pass below cannot do it:
    -- it would turn the two macros into a literal "PKMN" (which is what the
    -- storage rails and BILL's PC prompts write, "WITHDRAW <PK><MN>").
    local out = text:gsub("<PK><MN>", "POK\xc3\xa9MON")
    out = out:gsub("<([^%s<>]+)>", TOKENS)
    -- charmap.asm $54: "#" prints POKe (the cart's "#MON"/"#DEX" macro).  Only
    -- a "#" introducing a capital is the macro; any other "#" is the literal.
    out = out:gsub("#(%u)", "POK\xc3\xa9%1")
    return out
  end

  -- ------------------------------------------------------------------- money
  -- The player's wallet is ONE readout on the header's second line, directly
  -- under the BADGES / DEX readout -- not a column in the roster.  Gold keeps
  -- it on save.player.money.
  function S.money(game)
    local save = game and game.save
    local m = (save and save.player and save.player.money)
      or (save and save.money) or 0
    return ("%s: %d"):format(T("MONEY"), m)
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
    local title = S.display(opts.title or "")
    local tw = Theme.text(title, leftX, S.HDR_Y, F.body, "left", C.ink)

    -- The right readout is the one header string that genuinely grows: the
    -- Safari Zone appends its step and BALL counters to the badge/time/dex
    -- line.  It gets the space the title does not use, drops to the secondary
    -- size when that is not enough, and is finally cut by pixel budget so it
    -- can never run into the title.
    if opts.right then
      local avail = (S.W - m) - (leftX + tw) - 16
      local rf = F.body
      local right = S.display(opts.right)
      if Theme.w(right, rf) > avail then rf = F.small end
      local ry = S.HDR_Y + capB - Theme.capOf(rf)
      Theme.text(Theme.fit(right, rf, avail), S.W - m, ry, rf, "right",
        C.gold)
    end

    -- Second line: the selected row's caption on the left, the wallet on the
    -- right.  The caption is cut by RENDERED width, leaving the wallet its own
    -- room so the two can never meet.
    --
    -- `opts.captionFont` lets a caller whose caption is a two-button control
    -- hint (the `national_dex` POKeDEX listing) draw it on the secondary rung:
    -- the suite's row descriptions are short sentences, but that hint is long
    -- enough to be cut at body size, and a hint under a gold wallet reads fine
    -- one rung down.
    -- A caller with no second-line caption (the MODS page's list screen -- the
    -- tab strip takes that line) passes nil, so it is coerced to the empty
    -- string here: `Theme.w` measures through the real font, and a nil string
    -- is an argument error in the cart, not a zero-width measurement.
    local cap = S.display(opts.caption or "")
    local cf = opts.captionFont or F.body
    local cbudget
    if opts.money then
      local mw = Theme.w(opts.money, F.bold)
      Theme.text(opts.money, S.W - m, S.CAP_Y, F.bold, "right", C.gold)
      cbudget = (S.W - m) - mw - 16 - leftX
    else
      cbudget = (S.W - m) - leftX
    end
    -- a caption too long for its budget steps a rung down (or two) before it is
    -- cut, so a full sentence is never left on screen as a half-sentence
    if Theme.w(cap, cf) > cbudget then cf = F.small end
    if Theme.w(cap, cf) > cbudget then cf = F.tiny end
    cap = Theme.fit(cap, cf, cbudget)
    if cap and cap ~= "" then
      Theme.text(cap, leftX, S.CAP_Y, cf, "left", C.inkDim)
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
    }, S.MARGIN, S.FOOT_Y, F.body, { gap = opts.gap or 24 })
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
  --
  -- A caller may override the geometry (x, y, w, row, labelPad) when its page
  -- has no roster beside the rail -- the title menu's rail is wider than the
  -- START screen's 152px so a longer label like NEW GAME is never cut.  The
  -- defaults are the spread's own numbers, so the START and POKeMON pages are
  -- unchanged.
  --
  -- COLUMNS (`opts.columns`).  A menu can grow past what the content band
  -- holds -- the START menu gains rows as the save unlocks them and as mods
  -- hook `ui.start_menu.items` in, and every one of those rows is a real
  -- destination.  Lowered into the band they ran over the footer's hint row
  -- (the START and POKeMON pages share this rail, so both showed it).  Instead
  -- of scrolling the window (which the engine's Menu does, and which the
  -- POKeMON page's rail cannot do at all: it is a static mirror with no
  -- cursor), the list WRAPS into columns: at most `cap` rows per column (8,
  -- the number that ends exactly on the footer rule), each new column a panel
  -- of its own, its rows starting at the TOP of the band.  The columns on
  -- screen are the ones the cursor has reached -- press DOWN off the eighth
  -- row and the rest of the list appears in the column beside it -- so the
  -- list "grows" a column at a time and never draws under the footer.
  --
  -- With no `index` every column is drawn (nothing has a cursor to narrow the
  -- window).  A caller may instead pass `cols` to fix the count -- the POKeMON
  -- page's static mirror uses `cols = 1`: it sits 8px from the roster, so a
  -- second column there would cover the first member's portrait and read as a
  -- rendering bug rather than a menu (the wrapped rows live on the START
  -- screen, whose rail is the one the cursor drives).
  --
  -- opts may also carry `labelPad` (the label inset, default 34), `w` (the
  -- column width, default 152) and `row` (the row pitch, default 30).
  function S.rows(Theme, game, opts)
    local C = Theme.col
    local F = Theme.fonts(game).body
    local items = opts.items or {}
    if #items == 0 then return end
    local x = opts.x or S.LIST_X
    local ry0 = opts.y or S.LIST_Y
    local w = opts.w or S.LIST_W
    local row = opts.row or S.LIST_ROW

    if opts.columns then
      local cap = math.max(1, opts.cap or opts.maxVisible or 8)
      local total = #items
      local totalCols = math.max(1, math.ceil(total / cap))
      -- the columns to draw: an explicit count (`cols`, for a page whose rail
      -- has no cursor of its own and wants one column), else the columns the
      -- cursor has reached, else -- with neither -- every column there is
      local cols
      if opts.cols then cols = opts.cols
      elseif opts.index then cols = math.ceil(opts.index / cap)
      else cols = totalCols end
      if cols < 1 then cols = 1 end
      if cols > totalCols then cols = totalCols end
      local gap = opts.colGap or 8
      local pad = opts.labelPad or 34
      -- Several columns lie over the roster (this rail is shared by the START
      -- and POKeMON pages and the START screen keeps its party preview behind
      -- it).  The panel is translucent by design, so dim what is behind the
      -- cluster first -- otherwise a party row's sprite and name read through
      -- the option labels.  The action popup does the same for its own columns
      -- (ui/party_menu.lua).
      if cols > 1 then
        local tallest = math.min(cap, total) * row + 4
        Theme.set(C.black, 0.55)
        Theme.rect("fill", x - 3, ry0 - 3,
          cols * w + (cols - 1) * gap + 6, tallest + 6, 8)
      end
      for k = 1, cols do
        local cx = x + (k - 1) * (w + gap)
        local first = (k - 1) * cap + 1
        local count = math.min(cap, total - first + 1)
        local lx = cx + pad
        local ch = count * row + 4
        Theme.panel(cx, ry0, w, ch, { radius = 6, shadow = 2 })
        local y = ry0 + 2
        for i = 1, count do
          local item = items[first + i - 1]
          local at = first + i - 1
          local label = type(item) == "string" and item or (item.label or "")
          label = S.display(label)
          local selected = at == opts.index
          local band = selected or at == opts.active
          if band then
            Theme.set(C.rowLit, selected and 0.55 or 0.34)
            Theme.rect("fill", cx + 4, y - 2, w - 8, row - 2, 5)
          end
          local label2 = Theme.fit(label, F, (cx + w) - lx - 6)
          if selected then
            Theme.chevrons(cx + 8, y + 5, 18, C.accent,
              0.5 + 0.5 * math.sin((opts.t or 0) * 0.18))
            -- double-print the selected row for weight
            Theme.text(label2, lx, y + 6, F, "left", C.accent)
            Theme.text(label2, lx + 1, y + 6, F, "left", C.accent)
          else
            Theme.text(label2, lx, y + 6, F, "left", band and C.ink or C.inkDim)
          end
          y = y + row
        end
      end
      return
    end

    local visible = opts.maxVisible and math.min(opts.maxVisible, #items) or #items
    local scroll = opts.scroll or 0
    local lx = x + (opts.labelPad or 34)
    local h = visible * row + 4
    Theme.panel(x, ry0, w, h, { radius = 6, shadow = 2 })

    local y = ry0 + 2
    for i = 1, visible do
      local item = items[scroll + i]
      if not item then break end
      local label = type(item) == "string" and item or (item.label or "")
      label = S.display(label)
      local at = scroll + i
      local selected = at == opts.index
      local band = selected or at == opts.active
      -- The band's own rect is row - 2 tall: an 18px chevron centred in it
      -- starts at y+5 and a 15px-ink label at y+6.
      if band then
        Theme.set(C.rowLit, selected and 0.55 or 0.34)
        Theme.rect("fill", x + 4, y - 2, w - 8, row - 2, 5)
      end
      local label2 = Theme.fit(label, F, (x + w) - lx - 6)
      if selected then
        Theme.chevrons(x + 8, y + 5, 18, C.accent,
          0.5 + 0.5 * math.sin((opts.t or 0) * 0.18))
        -- double-print the selected row for weight
        Theme.text(label2, lx, y + 6, F, "left", C.accent)
        Theme.text(label2, lx + 1, y + 6, F, "left", C.accent)
      else
        Theme.text(label2, lx, y + 6, F, "left", band and C.ink or C.inkDim)
      end
      y = y + row
    end

    if opts.maxVisible and scroll + opts.maxVisible < #items then
      Theme.set(C.accent)
      love.graphics.polygon("fill", x + w - 20, y - 12,
        x + w - 8, y - 12, x + w - 14, y - 4)
    end
  end

  -- ------------------------------------------------------- generic list page
  -- A full-height list panel for the classic lists this mod takes over (the
  -- bag, the POKeDEX, OPTIONS, the MODS manager).  Each screen converts its
  -- own state into plain view rows and this draws them, so every list in the
  -- game reads as the same page.
  --
  -- rows[i] = { text, right, marker, dim, header, indent }
  --   text   the row's own label
  --   right  right-aligned trailing text (a count, a value, a price)
  --   marker true draws the small lozenge (the POKeDEX's owned ball)
  --   dim    true draws the label faint (a disabled row)
  --   header true draws a section heading -- no band, no cursor
  --   indent extra left indent in pixels (the dex strip's family tree)
  --
  -- opts = { rows, index, scroll, maxVisible, x, y, w, row, t, rightPad, font }
  -- `index`/`scroll` are counted in ROWS, so a header row is addressable and
  -- the caller's own scroll arithmetic (cursorRows / syncScroll) applies.
  -- `font` overrides the row face for a denser strip (a 20px row needs the
  -- secondary size; the default body is the menu's own).
  function S.list(Theme, game, opts)
    local C = Theme.col
    local fonts = Theme.fonts(game)
    local F = opts.font or fonts.body
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
      -- A row may ask for extra left indent on top of the label gutter: the
      -- evolution strip indents each stage one step, and the value is in
      -- pixels (Saira is proportional, so there is no cell to count).
      local lx = x + labelPad + (tonumber(item.indent) or 0)
      if item.header then
        Theme.rule(x + 8, ry + row - 8, w - 16, C.border)
        Theme.text(Theme.fit(S.display(item.text or ""), fonts.small, w - 20),
          x + 12, ry + 5, fonts.small, "left", C.inkFaint)
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
        local rw = item.right and (Theme.w(S.display(item.right), F) + 14) or 0
        local budget = (x + w - rightPad - rw) - lx
        local ink = C.ink
        if item.dim then ink = C.inkFaint
        elseif selected then ink = C.accent
        elseif band then ink = C.ink end
        local raw = S.display(item.text or "")
        -- a label longer than the row steps down a rung (or two) before it is
        -- cut, so a long species/form name is never left as a stub like
        -- "MEGA CHARI…"
        local lf = F
        if Theme.w(raw, lf) > budget then lf = fonts.small end
        if Theme.w(raw, lf) > budget then lf = fonts.tiny end
        local label = Theme.fit(raw, lf, budget)
        Theme.text(label, lx, ry + 6, lf, "left", ink)
        if selected then -- double-print for weight, like the START rail
          Theme.text(label, lx + 1, ry + 6, lf, "left", ink)
        end
        if item.right then
          Theme.text(S.display(item.right), x + w - rightPad, ry + 6, F, "right",
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

  -- ---------------------------------------------------------------- popups
  -- One card, one design: the PC's mon submenu, a PC's "How many?" stepper and
  -- the YES/NO the engine pushes over a page are all this.  Every other modal
  -- in the suite (the Gen 2 PC pages, the bag's own popups) draws the same
  -- shape, so a popup anywhere in the game reads as one design instead of the
  -- cart's little white square.
  --
  -- Callers draw it in PAGE space.  A pushed CLASSIC overlay is not in page
  -- space: the engine centres the classic 160px UI inside a wide page by
  -- translating it `S.pageOffset(game)` to the right (Game:draw's
  -- classicOffset), so such a caller must undo that first -- see S.pageOffset.
  local function embellishOn()
    local v = optionOn("ui_embellishment")
    if v == nil then return true end
    return v
  end

  -- How far the engine has shifted a pushed classic overlay to the right
  -- inside a wide page, in page pixels.  0 when there is nothing to undo -- a
  -- classic 160px surface, or no renderer to ask.
  function S.pageOffset(game)
    local r = game and game.renderer
    if not (r and type(r.uiSize) == "function") then return 0 end
    local ok, uw = pcall(r.uiSize, r)
    if not (ok and type(uw) == "number") then return 0 end
    local off = math.floor((uw - 160) / 2)
    return (off > 0) and off or 0
  end

  -- o = { w, title, right, lines, rows ({text, dim}), index, yesno (the
  --       selected YES/NO row), yesnoLabels, more, hints, t }
  -- `lines` are wrapped-free single body lines; `rows` is the cursor list.
  -- `more` draws the page-advance cursor under the lines -- the modern
  -- placeholder for the classic dialogue window's blinking tile arrow (the
  -- page-space dialogue card ui/textbox.lua draws over a page of this suite).
  function S.card(Theme, game, o)
    o = o or {}
    local C = Theme.col
    local F = Theme.fonts(game)
    local w = o.w or 380
    local lines = o.lines or {}
    local rows = o.rows or {}
    local lh, rh = 26, 32
    local yn = o.yesno and 2 or 0
    local hintH = o.hints and 30 or 0
    local h = 22 + (o.title and 34 or 0) + #lines * lh
      + (o.more and 26 or 0)
      + (o.stepper and 42 or 0)
      + (#rows + yn) * rh + hintH + 12
    local x = math.floor((S.W - w) * 0.5)
    local y = math.floor((S.H - h) * 0.5)
    -- the wash the Gen 2 popups lay down, so the page behind reads as
    -- background rather than as text poking out either side of the card
    Theme.set(C.black, 0.55)
    Theme.rect("fill", 0, 0, S.W, S.H, 0)
    Theme.panel(x, y, w, h, { radius = 8, shadow = 8,
      color = C.panelLit, border = C.borderLit })
    if embellishOn() then
      Theme.brackets(x + 5, y + 5, w - 10, h - 10, 18, C.accentDim)
    end
    local ty = y + 17
    if o.title then
      Theme.text(Theme.fit(o.title, F.small, w - 62), x + 18, ty, F.small,
        "left", C.accent)
      if o.right then
        Theme.text(Theme.fit(o.right, F.small, w * 0.45), x + w - 18, ty,
          F.small, "right", C.gold)
      end
      Theme.rule(x + 14, ty + 20, w - 28, C.border)
      ty = ty + 34
    end
    for _, line in ipairs(lines) do
      Theme.text(Theme.fit(line, F.body, w - 40), x + 20, ty, F.body, "left",
        C.ink)
      ty = ty + lh
    end
    if o.more then
      -- The page-advance cursor, where the classic window's tile arrow sat: a
      -- breathing down-chevron at the card's bottom right.  It is the same
      -- cursor ui/textbox.lua draws on a classic surface (the card's own
      -- `cursor`), so a continuing message reads the same on both.
      local cx, cy = x + w - 26, ty + 5
      Theme.set(C.accent,
        0.55 + 0.45 * (0.5 + 0.5 * math.sin((o.t or 0) * 0.22)))
      love.graphics.polygon("fill", cx - 9, cy - 5, cx + 9, cy - 5, cx, cy + 6)
      ty = ty + 26
    end
    if o.stepper then
      -- The engine's "How many?" selector (DisplayChooseQuantityMenu): a value
      -- the UP/DOWN keys step, the arrows stacked beside it -- drawn pointing
      -- UP and DOWN because UP/DOWN is what steps it -- and, in a mart, the
      -- running price.
      local st = o.stepper
      local ax, ay = x + 30, ty + 6
      Theme.set(C.accent)
      love.graphics.polygon("fill", ax, ay + 7, ax + 12, ay + 7, ax + 6, ay)
      love.graphics.polygon("fill", ax, ay + 21, ax + 12, ay + 21, ax + 6,
        ay + 28)
      Theme.text(st.value or "", x + 62, ty + 8, F.bold, "left", C.accent)
      if st.right then
        Theme.text(Theme.fit(st.right, F.body, w * 0.4), x + w - 18, ty + 8,
          F.body, "right", C.gold)
      end
      ty = ty + 42
    end
    local function drawRow(label, on, dim)
      local label2 = Theme.fit(label or "", F.body, w - 74)
      if on then
        Theme.set(C.rowLit, 0.55)
        Theme.rect("fill", x + 12, ty - 3, w - 24, 28, 5)
        Theme.chevrons(x + 22, ty + 4, 18, C.accent,
          0.5 + 0.5 * math.sin((o.t or 0) * 0.18))
      end
      Theme.text(label2, x + 52, ty + 1, F.body, "left",
        on and C.accent or (dim and C.inkFaint or C.ink))
      if on then -- double-print for weight, like the rails
        Theme.text(label2, x + 53, ty + 1, F.body, "left", C.accent)
      end
      ty = ty + rh
    end
    for i, r in ipairs(rows) do
      drawRow(r.text, i == (o.index or 1), r.dim)
    end
    if o.yesno then
      local labels = o.yesnoLabels or { "YES", "NO" }
      for i = 1, 2 do drawRow(labels[i], i == o.yesno) end
    end
    if o.hints then
      Theme.hints(o.hints, x + 18, y + h - 18, F.small, { gap = 16 })
    end
    return x, y, w, h
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
  -- `gen` selects which engine START menu supplies the rows: Gen 1's
  -- src.ui.StartMenu or Gold's src.ui.gen2.StartMenu (which carries one row
  -- Gen 1's does not -- POKeGEAR).  A single game table boots one generation,
  -- so one cache slot per game is enough.
  -- The synthetic PC row's label.  Shared by the START rail (ui/start_menu.lua)
  -- and the rail mirror below, so the two halves of the spread agree.
  S.PC_ROW_LABEL = "PC"

  -- Where the synthetic PC row belongs: the label it follows, or nil when the
  -- ui_pc_row option is off.  ui/start_menu.lua records this on `game` as it
  -- builds the START rail; the fallback recomputes it for a POKeMON page that
  -- is somehow reached without the START menu having been built first (a mod's
  -- own entry), so the two rails stay identical either way.
  function S.pcRowAfter(game, gen)
    if type(game) == "table" and game.__g9guiPcRowAfter ~= nil then
      return game.__g9guiPcRowAfter
    end
    local onOpt = optionOn("ui_pc_row") == true
    if not onOpt then return nil end
    local ok, Strings = pcall(require, "src.core.Strings")
    if not (ok and type(Strings) == "function") then return nil end
    return Strings((gen == 2) and "PACK" or "ITEM")
  end

  function S.startRows(game, partyLabel, gen)
    if type(game) ~= "table" then return nil end
    if game.__g9guiStartRows then return game.__g9guiStartRows end
    local path = (gen == 2) and "src.ui.gen2.StartMenu" or "src.ui.StartMenu"
    local ok, StartMenu = pcall(require, path)
    if not (ok and type(StartMenu) == "table"
      and type(StartMenu.new) == "function") then return nil end
    local ok2, menu = pcall(StartMenu.new, game, {})
    if not (ok2 and type(menu) == "table") then return nil end
    local rows = {}
    for i, item in ipairs(menu.items or {}) do
      if item.label ~= partyLabel then rows[#rows + 1] = item.label end
    end
    -- Mirror the START rail's synthetic PC row (ui_pc_row): the row is not one
    -- the engine built, so this is the only way this rail learns about it.
    local after = S.pcRowAfter(game, gen)
    if after then
      local at
      for i = 1, #rows do if rows[i] == after then at = i break end end
      table.insert(rows, (at or #rows) + 1, S.PC_ROW_LABEL)
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
