-- ui/textbox.lua -- the modern NPC dialogue window.
--
-- Every "chat box" in the game is one engine state, src.render.TextBox: the
-- 20x6-tile white window the overworld, the scripts, the signs and the
-- in-battle messages all print through.  This module DRESSES that state at
-- the one choke point every push goes through (the StateStack.push wrapper in
-- main.lua) -- it is not registered as a screen and the engine's class is
-- untouched.  The engine still paginates, runs the typewriter, waits for A,
-- honours \n \v \f and the {PROMPT}/{DONE} markers, pushes the YES/NO
-- ChoiceBox and pops itself; only :draw is replaced, plus a per-frame counter
-- for the cursor pulse.  Nothing here can change how a conversation advances.
--
-- WHAT IS DRAWN.  The classic white box and its pokeball-rivet frame become
-- the same dark card every other g9-gui screen uses: a translucent panel with
-- a soft shadow, a hairline border, an accent cap and (when embellishments
-- are on) corner brackets, a modern pulsing down-chevron in place of the tile
-- arrow, and -- since 2.3.4 -- the message itself in the suite's OWN face,
-- drawn by this module at the window's native resolution.  A visible MONEY box
-- gets the same treatment as a small card.
--
-- WHY NATIVE TYPE.  2.3.3 briefly handed the body back to the engine's own
-- face (src.render.Font.draw) whenever the engine had a TTF.  This version
-- undoes that, deliberately.  gen1recomp ships Plain Pixel -- an 8px pixel
-- font -- and Font.draw prints it as an 8px bitmap scaled through an integer
-- window multiple: at 3x that is 24px blocks with the stair-stepped silhouette
-- of the tile glyph it was cut from.  It is "correct" only in the sense of
-- being pixel-exact; it is LOW density, and a blocky pixel face reads worse
-- inside a smooth vector card than the card's own type.  The suite's Saira is
-- instead built by love AT the window's size (Theme.fontsAt: Saira-30 in
-- window space, not a 10px atlas resampled 3x), so every stem lands on a real
-- device pixel -- higher density, no resampling, no distortion, and no
-- dependence on which font the host engine happens to bundle.  The re-flow
-- (below) stays: the card re-pages the message at the Saira width, so the
-- higher-density body still fits MORE of it per line than the engine's 18
-- tile cells.  The engine still owns the conversation: this module only
-- changes pixels.
--
-- TWO SPACES, ONE CARD.  The card's own geometry is written in the box's UI
-- pixels -- the bottom 20x6 tiles the engine put the window in.  `paint`
-- renders that geometry through a SPACE: a window-space mapping plus the font
-- set built for it.  There are two callers:
--
--   * THE DRAW-TIME PATH (M.draw).  The classic 160x144 surface, at 1:1.  It
--     is the fallback and the only path a wide surface ever takes.
--   * THE WINDOW-SPACE PATH (M.hudDraw, subscribed to the engine's render.hud
--     hook).  The card is rasterised straight into the window at the
--     renderer's own scale, from fonts built at that scale (Theme.fontsAt).
--     The panel, its hairline border and the type are then drawn at native
--     resolution instead of being composed as a 160x144 bitmap and upscaled
--     several times -- which is the whole point of this path: the glyphs get
--     MORE PIXEL DENSITY without the box growing a single screen pixel.
--
-- WHY THE SURFACE DOES NOT GROW.  The obvious way to get density would be to
-- answer :uiSize() with a bigger canvas.  That is a trap and this mod does not
-- take it: Renderer:fitScale() is max(1, floor(min(pw/uiw, ph/uih))), so a
-- taller/wider UI surface lowers the integer scale and the WORLD pass, which
-- sizes itself from the same fitScale, shows several times more map at the
-- same window size -- the background visibly zooms out.  (That is also why the
-- engine's own wide battle is 304x144: same height, so the classic layout
-- still fits.)  Answering 160x144 and drawing natively keeps the background,
-- the world zoom, the SGB zones, the anchors and the YES/NO placement bit for
-- bit where they were -- only the pixels of the card change.
--
-- WHY IT STILL KNOWS ABOUT ANCHORS.  The native card has to land on exactly
-- the screen pixels the engine sends the box's own region to, and the engine
-- moves that region in two different ways.  In UI LAYOUT = CENTERED (the
-- default) setUIAnchor() is a no-op: the UI is the classic letterbox blit and
-- the origin is the renderer's uox/uoy.  Under UI LAYOUT = DYNAMIC -- or
-- whenever a state on the stack holds anchors off, which is what a battle
-- does (Renderer.uiAnchorHold) -- the region is DOCKED to the window edge
-- instead: an anchor keeps an element's distance from the CANVAS edge
-- measured from the SCREEN edge, so a box sitting on the canvas's bottom edge
-- lands on the window's bottom edge, the whole canvas effectively shifting
-- down to `vuy + vuh - uih*Uy` (x keeps its letterbox position: only the
-- vertical is edge-relative).  `spaceOrigin` derives whichever applies from
-- the same rects the engine places the region with, so the native card and
-- the (now empty) region beneath it can never disagree.  The one case that
-- still keeps the surface path is a wide surface (a battle composing its own
-- screen, or one of this mod's 540x360 pages) -- the battle scene dresses its
-- own message window.
--
-- Text is rebuilt rather than decoded: the engine pages hold the real strings
-- and `state.shown` holds one glyph-code list per visible line, so the line's
-- string is cut to that many glyphs with the engine's own Font.split -- no
-- code->character table to drift out of sync with the game's charmap, and a
-- multi-byte glyph like é is never torn in half.
--
-- OVER A PAGE OF THIS SUITE (2.8.4).  The engine's Game:draw only knows two
-- kinds of state: the one that owns the surface (a :uiSize() page or a wide
-- battle) and the classic 160x144 overlays, which it centres inside a wide
-- surface by translating them `classicOffset` = (uiSize - 160) / 2 to the
-- right.  A TextBox pushed over one of this suite's 540x360 pages is such an
-- overlay -- so the cart's white 20x6 window used to land mid-page, floating
-- over the modern list (the PC's "Accessed someone's PC." was the last one).
-- Since 2.8.4 the push wrapper DRESSES that box too, and this module paints
-- its message as the suite's own CARD in the PAGE's coordinates: it undoes the
-- engine's shift and calls ui/shell.lua's S.card -- the very centred card the
-- YES/NO over a page (ui/choice.lua) and the Gold PC's own messages
-- (ui/pc.lua g2modal) already use, so a message anywhere in the suite reads as
-- one design.  A YES/NO the engine pushes over such a box carries the message
-- itself (ui/choice.lua reads M.pageLines), so the pair draws ONE card.  The
-- wallet card is not drawn there: this suite's pages carry the wallet in their
-- own header.  `surfaceIsWide` still refuses a battle's own 304px surface and
-- any other mod's wide screen -- those are not in this suite's page
-- coordinates and keep the classic window.
--
-- ...AND ON GOLD.  The Gen 1 half of that page card works because the engine
-- blits the page into a real 540x360 surface and then shifts this box's classic
-- rectangle into it by `classicOffset` -- an offset this module can undo.  Gold
-- has neither: the page is painted straight into the window by :drawWidescreen
-- (ui/shell.lua's gen2Fit, which now publishes the fit it used on the game) and
-- the engine THEN re-runs the stack over it at Chrome's own integer letterbox,
-- which is the pass a pushed TextBox draws in.  That is two scales in one
-- frame, so the box used to be painted as the cart's card at the classic
-- scale -- several times the page's, and in the cart's face -- over the modern
-- page (the plain message over the Gen 2 move learner).  `M.inPageSpace` maps
-- the PAGE's coordinates into that classic pass, so the same S.card lands on
-- exactly the pixels gen2Fit put the page on and a Gold message reads as the
-- page's own card, at the page's own size.
--
-- GEN 2 (since 2.5.5; native since 2.6.7).  src.render.TextBox is ONE shared
-- class -- Gold's Game2.lua requires the same module -- and it draws its window
-- at boxTx*8, boxTy*8 in the classic 160x144 screen space on both generations,
-- so this module dresses it identically.  What differs is the space.  Gold has
-- no `renderer` table at all, so the Gen 1 rects are unavailable -- but
-- Game2:drawScene blits the classic 160x144 UI canvas at the plain integer
-- letterbox fit (Chrome.fitScale/fitOrigin) and Game2:viewport hands that very
-- mapping to the render.hud payload as gameX/gameY/scale.  That is all the
-- window-space path needs, so since 2.6.7 Gold takes it too (`gen2Space`): the
-- same dark card, her body and pulsing chevron, but rasterised straight into
-- the window at that scale from fonts built for it -- the same density Gen 1
-- gets, instead of a Saira-10 body composed at 1:1 in the 160x144 canvas and
-- then upscaled with it.  Two cases keep the surface card: a hook payload with
-- no usable mapping, and a box over a WIDE page (Game2 panelBlits that stack at
-- the PAGE's scale, not the letterbox -- see `wideUnder`).  The re-flow wrap is
-- class-level and works on both.
return function(mod, ctx)
  local Theme = ctx.Theme
  local C = Theme.col
  local embellish = ctx.on and ctx.on("ui_embellishment")
  -- The page helpers (S.card / S.pageOffset / S.W): a box over one of this
  -- suite's own pages is drawn as that page's card.  Optional, like everything
  -- else -- without it every box keeps the surface card.
  local Shell = ctx.Shell

  local Font
  do
    local ok, v = pcall(require, "src.render.Font")
    Font = ok and v or nil
  end
  local UIVisibility
  do
    local ok, v = pcall(require, "src.battle.UIVisibility")
    UIVisibility = ok and v or nil
  end
  local Game
  do
    local ok, v = pcall(require, "src.core.Game")
    Game = ok and v or nil
  end
  -- Gold's own integer letterbox (src/ui/gen2/Chrome.lua), only so a card that
  -- belongs on a Gen 2 page can be mapped into the classic overlay pass the
  -- engine runs that page's pushed states through (see M.inPageSpace).  Gen 1
  -- has no such module, so the pcall leaves it nil there.
  local Chrome
  do
    local ok, v = pcall(require, "src.ui.gen2.Chrome")
    Chrome = ok and v or nil
  end
  -- The engine's YES/NO box, only so a box sitting on top of the dialogue box
  -- can be told apart from a state that replaced it.  It is NOT re-skinned:
  -- the choice box keeps the engine's own drawing, exactly where the engine
  -- puts it (just above the card's top edge).
  local ChoiceBox
  do
    local ok, v = pcall(require, "src.ui.ChoiceBox")
    ChoiceBox = ok and v or nil
  end
  -- The engine's own dialogue state, only so this module can RE-FLOW a box's
  -- text at the dialogue font's width instead of the engine's 18 tile cells.
  -- The class is never registered as a screen and none of its behaviour is
  -- replaced -- see `reflow` below for what is borrowed and why.
  local TextBox
  do
    local ok, v = pcall(require, "src.render.TextBox")
    TextBox = ok and v or nil
  end

  local M = { isTextboxSkin = true }

  -- Panel geometry in the box's own UI pixels.  The engine's window is tiles
  -- (boxTx,boxTy)+(boxTw,boxTh) -- by default (0,12) 20x6, i.e. 160x48 against
  -- the bottom of the screen.  The card insets that by 2px so it reads as a
  -- modern panel rather than a full-bleed band.  PITCH is the leading between
  -- the two body lines, in the same UI pixels -- 15 to match the 10 body, so
  -- two lines still centre inside the 44px card with a clear gap between them.
  local INSET, PAD, PITCH, RADIUS = 2, 6, 15, 3

  -- Has the engine ever called the render.hud hook?  Only then is the
  -- window-space path safe -- an older engine without the hook (or a hook this
  -- mod failed to subscribe) leaves the card on the surface, chunky but
  -- present.  The box can therefore never disappear.
  local hudSeen = false

  local function geom(state)
    local tx = (state.boxTx or 0) * 8
    local ty = (state.boxTy or 12) * 8
    local tw = (state.boxTw or 20) * 8
    local th = (state.boxTh or 6) * 8
    return tx + INSET, ty + INSET, tw - INSET * 2, th - INSET * 2
  end

  -- ------------------------------------------------------------------ spaces
  -- A space maps the card's UI pixels to wherever it is being painted:
  --   ox/oy = the screen position of UI (0,0)
  --   kx/ky = screen extent of one UI pixel
  --   fonts = the face set built at that scale
  -- The surface space is the identity (0,0 / 1,1).  Window space comes from
  -- the renderer's frame rects.
  local function surfaceSpace(game)
    return { fonts = Theme.fonts(game), ox = 0, oy = 0, kx = 1, ky = 1,
      hair = 1 }
  end

  -- A hairline stroke is drawn with love's line mode, whose width is a LOVE
  -- unit and does NOT scale with the coordinates it is given -- so the window
  -- space has to set it to one UI pixel on purpose.
  local function withLineWidth(lw, fn)
    local g = love.graphics
    local set = g and g.setLineWidth
    local changed = false
    if set then changed = pcall(set, lw) end
    fn()
    if changed then pcall(set, 1) end
  end

  -- The strings the box is currently holding, cut to what has typed out.
  -- `shown` is one code list per visible line (at most two); the engine's
  -- `visibleText` shows the page rows those map to are lineIndex-count+1 ..
  -- lineIndex, and Font.split gives the same glyph boundaries Font.encode
  -- counted, so the cut is exact.
  local function visibleLines(state)
    local page = state.pages and state.pages[state.pageIndex]
    local shown = state.shown
    if not page or not shown then return {} end
    local count = #shown
    local out = {}
    for i = 1, count do
      local row = page[(state.lineIndex or 1) - count + i]
      local codes = shown[i]
      local n = codes and #codes or 0
      if row == nil then
        out[#out + 1] = ""
      elseif n <= 0 or not Font then
        out[#out + 1] = ""
      else
        local spans = Font.split(row)
        local last = spans[n]
        out[#out + 1] = last and row:sub(1, last.to) or row
      end
    end
    return out
  end

  -- The body face: Saira 10 (the `box` rung) -- small enough that a message
  -- packs into the card, still clear of the 8px tile glyph it sits near --
  -- stepping down to `boxSmall` (9) when a line will not fit the panel's text
  -- width.  The engine paginated to 18 vanilla 8px cells; Saira is
  -- proportional, so a line of wide capitals or a box this module could not
  -- re-flow (`reflow` below) can still overrun that budget, and the smaller
  -- size beats a truncation or an overhang.
  local function bodyFont(F, lines, maxW)
    local ladder = { F.box, F.boxSmall }
    for _, f in ipairs(ladder) do
      local widest = 0
      for _, s in ipairs(lines) do
        local w = Theme.w(s, f)
        if w > widest then widest = w end
      end
      if widest <= maxW then return f, widest end
    end
    return ladder[#ladder], maxW
  end

  -- ---------------------------------------------------------------- re-flow
  -- WHY.  The engine paginated every box with TextBox.paginate, whose budget
  -- is `maxCols` (18) tiles of the VANILLA 8px glyph -- 144px -- regardless of
  -- the face this module actually draws.  Saira at 10 is far narrower than
  -- 8px a glyph, so an engine line of 18 glyphs leaves a third of the card's
  -- text width empty, and merely shrinking the font would only draw the SAME
  -- 18 glyphs smaller.  To make a smaller font fit MORE per line -- the whole
  -- point of this change -- the text has to be re-paginated at the dialogue
  -- font's own width.
  --
  -- WHAT.  `reflow` is the engine's own algorithm, copied deliberately: trim
  -- the same trailing empty line, split on \n \v and \f, soft-wrap on glyph
  -- boundaries and prefer the last space on the line.  One thing changes: the
  -- per-line budget is the card's pixel text width, and each span is measured
  -- with Theme.w through the face that will draw it.  The page shape is
  -- identical (pages[p][i] a line, pages.contBefore[p][i] a \v scroll), so the
  -- engine's typewriter, page waits and \v slides all keep working untouched.
  local function reflow(text, font, budget)
    local function pushLine(lines, conts, line, wait)
      while true do
        local spans = Font.split(line)
        local used, fit = 0, 0
        for _, span in ipairs(spans) do
          used = used + Theme.w(line:sub(span.from, span.to), font)
          if used > budget then break end
          fit = fit + 1
        end
        if fit >= #spans then break end
        fit = math.max(fit, 1)
        local cut = spans[fit].to
        for i = fit, 1, -1 do
          if line:sub(spans[i].from, spans[i].to) == " " then
            cut = spans[i].to
            break
          end
        end
        table.insert(lines, line:sub(1, cut))
        table.insert(conts, wait)
        wait = false
        line = line:sub(cut + 1)
      end
      table.insert(lines, line)
      table.insert(conts, wait)
    end
    local pages, contBefore = {}, {}
    for pageText in (text .. "\f"):gmatch("(.-)\f") do
      if pageText ~= "" then
        local lines, conts = {}, {}
        local pos, waitNext = 1, false
        while true do
          local npos = pageText:find("[\n\v]", pos)
          if not npos then
            pushLine(lines, conts, pageText:sub(pos), waitNext)
            break
          end
          pushLine(lines, conts, pageText:sub(pos, npos - 1), waitNext)
          waitNext = pageText:sub(npos, npos) == "\v"
          pos = npos + 1
        end
        if lines[#lines] == "" then
          table.remove(lines)
          table.remove(conts)
        end
        if #lines > 0 then
          table.insert(pages, lines)
          table.insert(contBefore, conts)
        end
      end
    end
    if #pages == 0 then
      pages = { { "" } }
      contBefore = { { false } }
    end
    pages.contBefore = contBefore
    return pages
  end

  -- Wrap the engine class at load so `dress` can learn the exact text a box was
  -- built from.  TextBox.new runs substitute + stripPauses BEFORE it paginates,
  -- so the string TextBox.paginate receives is the clean display text (tokens
  -- resolved, no {PROMPT}/{DONE} markers) -- which is precisely what re-flow
  -- needs.  `pending` is captured during the paginate call and picked up by the
  -- new() call around it, so a box only ever gets its OWN text; a new that
  -- throws (or a caller that paged something else) leaves the flag clear.
  --
  -- The `__g9reflowWrapped` marker lives on the engine class, not this module,
  -- because the CLASS is the persistent thing: if the mod is reloaded, a fresh
  -- module must not stack a second wrapper on an already-wrapped class.
  function M.installWrap()
    if M.__wrapped then return true end
    if type(TextBox) ~= "table" or type(TextBox.paginate) ~= "function"
        or type(TextBox.new) ~= "function" then
      return false
    end
    if TextBox.__g9reflowWrapped then
      M.__wrapped = true
      return true
    end
    local basePaginate = TextBox.paginate
    local pending
    TextBox.paginate = function(text, maxCols)
      pending = text
      return basePaginate(text, maxCols)
    end
    local baseNew = TextBox.new
    TextBox.new = function(...)
      pending = nil
      local self = baseNew(...)
      if type(self) == "table" and pending then self.__g9raw = pending end
      return self
    end
    TextBox.__g9reflowWrapped = true
    M.__wrapped = true
    return true
  end

  -- Re-page one dressed box at the dialogue font's width.  Skipped, and the
  -- engine's own pages kept, when: the class or Font is missing; the box did
  -- not come through TextBox.new (a hand-built state in a test, or an older
  -- engine without the exported constructor); the box holds an opts.instant
  -- page (its text is already read and it must not re-type); or it carries
  -- pause markers -- those are timed against the code stream the engine built
  -- at pagination time (pauseAt[page][line][charIndex]), so re-flowing under
  -- them would misplace every {PAUSE}.
  local function reflowBox(state)
    if not (TextBox and Font and state.__g9raw and not state.instant
        and not state.pauseAt) then
      return false
    end
    local F = Theme.fonts(state.game)
    local font = F.box or F.body
    if not font then return false end
    local _, _, tw = geom(state)
    -- the panel's own PAD on each side, less a 2px margin: paint re-fits a line
    -- only by stepping the WHOLE box down a rung, so the budget here must sit a
    -- hair inside the budget bodyFont will be handed, or a line that measured
    -- "just over" at 10 would be re-drawn at 9.
    local budget = tw - PAD * 2 - 2
    local ok, pages = pcall(reflow, state.__g9raw, font, budget)
    if not (ok and type(pages) == "table" and type(pages[1]) == "table") then
      return false
    end
    -- Reset the typewriter to the top of the re-flowed text by hand rather than
    -- calling state:beginLine() -- a state dressed here has no metatable in the
    -- harness, and the two fields beginLine would touch are set below anyway.
    state.pages = pages
    state.pageIndex = 1
    state.lineIndex = 1
    state.shown = { {} }
    state.charIndex = 0
    state.codes = (Font.encode and Font.encode(pages[1][1] or "")) or {}
    state.done = false
    state.waiting = false
    state.contAdvance = false
    state.scrollPx = nil
    return true
  end

  -- A modern page-advance cursor: a filled down triangle that breathes with
  -- the box's own blink counter, drawn where the tile arrow used to sit.
  local function cursor(cx, cy, r, pulse)
    Theme.set(C.accent, 0.55 + pulse * 0.45)
    love.graphics.polygon("fill", cx - r, cy - r, cx + r, cy - r, cx, cy + r)
  end

  -- The MONEY box (engine/menus/text_box.asm DisplayMoneyBox at 11,0): a
  -- small card at the top-right with the label on its first row and the
  -- figure, gold and right-aligned, on the second -- two rows so a long
  -- amount can never run into the label.
  local function drawMoney(state, sp, round)
    local kx, ky, F = sp.kx, sp.ky, sp.fonts
    local amount = 0
    local ok, v = pcall(function() return state:money() end)
    if ok and type(v) == "number" then amount = v end
    local w, h = 84, 26
    local ux, uy = 160 - w - 2, 2
    local x, y = sp.ox + ux * kx, sp.oy + uy * ky
    local W, H, R = w * kx, h * ky, RADIUS * round
    Theme.set(C.panelDeep)
    Theme.rect("fill", x, y, W, H, R)
    local hair = sp.hair or 1
    Theme.set(C.border)
    withLineWidth(hair, function()
      Theme.rect("line", x + 0.5 * hair, y + 0.5 * hair, W - hair, H - hair, R)
    end)
    Theme.set(C.goldDim)
    Theme.rect("fill", x + R, y + H - 2 * ky, W - R * 2, ky, 0)
    Theme.text("MONEY", x + PAD * kx, y + 4 * ky, F.tiny, "left", C.inkFaint)
    Theme.text(("\xc2\xa5%d"):format(amount), x + W - PAD * kx, y + 14 * ky,
      F.small, "right", C.gold)
  end

  -- The card, painted through a space.  Everything below is the card's own UI
  -- geometry run through the space's mapping: with the surface space this is
  -- pixel-for-pixel what this module has always drawn.
  local function paint(state, sp)
    local kx, ky = sp.kx, sp.ky
    local round = math.min(kx, ky)
    -- One device pixel, in the space's own units.  Surface space: the surface's
    -- own pixel (1).  Window space: 1/dpi LOVE units, so a hairline lands on
    -- ONE physical pixel instead of being blown up to a whole UI pixel -- the
    -- card's frame is a sharp 1px edge at any window scale, never a resampled
    -- 3px band.  The fills inside it still scale with the window.
    local hair = sp.hair or 1
    local F = sp.fonts

    local x, y, w, h = geom(state)
    local X, Y = sp.ox + x * kx, sp.oy + y * ky
    local W, H, R = w * kx, h * ky, RADIUS * round

    -- soft drop shadow, panel, top shine, hairline border
    Theme.set(C.shadow)
    Theme.rect("fill", X + 2 * kx, Y + 2 * ky, W - 2 * kx, H, R)
    Theme.set(C.panelDeep)
    Theme.rect("fill", X, Y, W, H, R)
    Theme.set(C.shine)
    Theme.rect("fill", X + hair, Y + hair, W - 2 * hair, hair, 0)
    Theme.set(C.border)
    withLineWidth(hair, function()
      Theme.rect("line", X + 0.5 * hair, Y + 0.5 * hair, W - hair, H - hair, R)
    end)
    -- accent cap along the inside of the top edge
    Theme.set(C.accent, 0.42)
    Theme.rect("fill", X + R, Y + hair, W - R * 2, hair, 0)
    if embellish then
      local len = math.min(7, math.floor(w * 0.055))
      Theme.brackets(X + 3 * kx, Y + 3 * ky, W - 6 * kx, H - 6 * ky,
        len * round, C.accentDim, hair, hair)
    end

    -- body text.  The scroll-up slide the engine keeps in scrollPx applies to
    -- the retained (first) line exactly as TextBox:draw does.
    local lines = visibleLines(state)
    local off = state.scrollPx or 0
    if off > 0 then
      state.scrollPx = off - 2
      if state.scrollPx <= 0 then state.scrollPx = nil end
    end
    -- The body: the suite's own face built at THIS space's scale -- Saira-30 in
    -- window space, Saira-10 on the surface -- so the glyphs are rasterised at
    -- the resolution they are drawn at (no atlas is ever resampled).  The
    -- fit budget is the panel's text width scaled into the space: the font
    -- measures in its own (window) units, the geometry does not.
    local font = bodyFont(F, lines, (w - PAD * 2) * kx)
    local cap = Theme.capOf(font)
    local line1 = y + math.floor((h - (cap / ky + PITCH)) * 0.5)
    -- `ys` is in absolute UI pixels (y-derived), so map it through the space's
    -- origin directly -- adding the card origin again would double it.
    local ys = { line1 - off, line1 + PITCH }
    for i, str in ipairs(lines) do
      if str ~= "" then
        Theme.text(str, X + PAD * kx, sp.oy + (ys[i] or ys[2]) * ky, font,
          "left", C.ink)
      end
    end
    local cursorX = X + W - 11 * kx
    local cursorY = sp.oy + ys[2] * ky + cap * 0.5

    if state.moneyVisible and state:moneyVisible() then
      -- The MONEY card is an un-anchored canvas element: the engine leaves it
      -- where it was drawn on the 160x144 canvas and blits that part of the
      -- canvas in the letterbox, so under DYNAMIC it must NOT travel down with
      -- the docked box.  `sp.money` is that second space; when nothing is
      -- docked the two are the same space and the card simply rides along.
      drawMoney(state, sp.money or sp, round)
    end

    if state.arrowVisible and state:arrowVisible() then
      local on = (state.blink or 0) % 60 < 30
      if on then
        local pulse = 1 - math.abs((((state.blink or 0) % 60) / 30) - 1)
        cursor(cursorX, cursorY, math.max(1, 4 * round), pulse)
      end
    end
  end

  -- ------------------------------------------------- which box owns the screen
  local function isChoiceBox(v)
    if type(v) ~= "table" or not ChoiceBox then return false end
    return getmetatable(v) == ChoiceBox
  end

  -- The dressed box whose card is the one currently on screen: the top of the
  -- stack, or the box just under a YES/NO the engine pushed over it.
  local function activeBox(game)
    local stack = game and game.stack
    if not stack or type(stack.top) ~= "function" then return nil end
    local ok, top = pcall(stack.top, stack)
    if not ok or type(top) ~= "table" then return nil end
    if isChoiceBox(top) then
      local states = stack.states
      local lower = states and states[#states - 1]
      if type(lower) == "table" and lower.__g9guiBox then return lower end
      return nil
    end
    if top.__g9guiBox then return top end
    return nil
  end

  -- The wide state under the box, if any.  Game.wideBattleInStack matches ANY
  -- state answering :isWideBattleLayout(), and that is not only a battle:
  -- this suite's own 540x360 pages answer it too (ui/shell.lua S.wide), and so
  -- does any other mod's wide screen.
  local function wideStateUnder(state)
    local game = state and state.game
    local stack = game and game.stack
    if not (Game and stack) then return nil end
    local ok, wide = pcall(Game.wideBattleInStack, stack)
    if not ok then return nil end
    return wide
  end

  -- True when a wide surface that is NOT one of this suite's own pages is under
  -- the box: a battle composing its own screen, or another mod's wide screen.
  -- There the engine centres the classic 160px UI inside the wide canvas and
  -- the box must keep the classic look -- the battle scene dresses its own
  -- message window, and a card pulled out of the surface's coordinate space
  -- would land in the wrong place.  A page of THIS suite (every takeover here
  -- marks its instance `__g9gui`) is different: it is drawn by the suite, so
  -- the box is dressed and its message painted as the suite's card in the
  -- PAGE's coordinates (see `paintPageCard`).
  function M.surfaceIsWide(state)
    local wide = wideStateUnder(state)
    if wide == nil then return false end
    if type(wide) == "table" and wide.__g9gui == true then return false end
    return true
  end

  -- The page of THIS suite a box is riding, or nil.  The same wide state
  -- surfaceIsWide asks about, kept only when it is one of ours (`__g9gui`): a
  -- battle's surface or another mod's page answers nil here and keeps the
  -- classic window.  On Gen 1 such a box is drawn in the PAGE's own surface
  -- (M.draw's `pageOffset` half); Gold has neither a renderer nor a shift -- the
  -- page paints the whole window through ui/shell.lua's gen2Fit and the engine
  -- re-runs the stack over it at Chrome's integer letterbox -- so the box is
  -- mapped into that pass instead (M.inPageSpace).
  function M.pageUnder(state)
    local wide = wideStateUnder(state)
    if type(wide) == "table" and wide.__g9gui == true then return wide end
    return nil
  end

  -- How far the engine has shifted a pushed CLASSIC overlay to the right inside
  -- a wide page (Game:draw's classicOffset), in page pixels.  This suite's page
  -- is exactly 540 wide, so the shift is (540 - 160) / 2 = 190 -- the same test
  -- ui/choice.lua uses to tell this suite's page from a battle's 304px surface
  -- (offset 72), whose classic overlays keep the classic drawing.  0 when there
  -- is nothing to undo: a classic surface, or no renderer to ask (Gold).
  local function pageOffset(game)
    if not (Shell and Shell.pageOffset and Shell.W) then return 0 end
    local ok, off = pcall(Shell.pageOffset, game)
    if not (ok and type(off) == "number" and off > 0) then return 0 end
    if off ~= math.floor((Shell.W - 160) / 2) then return 0 end
    return off
  end

  -- Does the renderer leave the box's region in the classic letterbox this
  -- frame?  Anchoring is a no-op -- and the letterbox blit IS the answer --
  -- both in UI LAYOUT = CENTERED and while a state on the stack holds anchors
  -- off (a battle composing its own screen); only a real DYNAMIC layout with
  -- no hold docks the region.  `M.draw` asks the engine for the anchor either
  -- way, so this is purely about which origin the native card has to use.
  local function letterboxed(r)
    return r.uiCentered == true or r.uiAnchorHold == true
  end

  -- Where UI pixel (0,0) lands on screen this frame, in LOVE units.  Under
  -- DYNAMIC the box region is docked against the window's bottom edge, which
  -- is the whole canvas moved down until its bottom edge meets the window's:
  --   y = vuy + vuh - uih*Uy
  -- (derivation: the engine places an anchor "bottom" at
  -- dy = vuy + vuh - (uih - (a.y + a.h))*Uy - a.h*Uy, and the card's UI y maps
  -- through dy + (uiy - a.y)*Uy, which reduces to vuy + vuh + (uiy - uih)*Uy
  -- for ANY box position).  x keeps its letterbox origin -- an anchored region
  -- is not re-centred horizontally, the engine uses uox for it too.
  local function spaceOrigin(r, R)
    if letterboxed(r) then return R.uox, R.uoy end
    return R.uox, R.vuy + R.vuh - R.uih * R.Uy
  end

  -- The engine's own renderer, when this boot has one.  Gold does not: it
  -- composes and presents its own frame in src/core/Game2.lua, so the Gen 1
  -- rects do not exist there and Gold reads the render.hud viewport instead
  -- (see `gen2Space`).
  local function gen1Renderer(game)
    local r = game and game.renderer
    if type(r) == "table" and type(r.frameRects) == "function" then return r end
    return nil
  end

  -- GEN 2's window space.  Game2:drawScene blits the classic 160x144 UI canvas
  -- at the plain integer letterbox fit -- Chrome.fitScale/fitOrigin, the same
  -- whole-number scale Gen 1's CENTERED layout uses -- and Game2:viewport hands
  -- that very mapping to the render.hud payload as gameX/gameY/scale.  So the
  -- card can be rasterised natively on Gold too, from fonts built at that scale
  -- exactly as on Gen 1, instead of being composed in the 160x144 canvas and
  -- upscaled with it.  `scale` here is LOVE units per GB pixel, the same unit
  -- Gen 1's Ux/Uy carry, so the two generations build the same font sizes.
  --
  -- Two cases keep the surface card:
  --   * no usable viewport (an engine whose render.hud payload lacks the
  --     mapping, or a direct test call with none) -- the surface card always
  --     exists, so the box can never disappear;
  --   * a WIDE page under the box.  Game2 presents a stack with a widescreen
  --     base through panelBlit, i.e. at the PAGE's scale rather than the
  --     letterbox, so the card's UI-pixel geometry no longer maps through
  --     gameX/gameY/scale.  (`M.surfaceIsWide` covers the Gen 1 wide battle;
  --     `wideUnder` covers Gold's own widescreen pages.)
  local gen2Live = false

  -- Is another state on the stack painting a widescreen page?  If so the box
  -- travels through Game2's panelBlit and must stay on the surface.
  local function wideUnder(state, game)
    local stack = game and game.stack
    local states = stack and stack.states
    if not states then return false end
    for i = #states, 1, -1 do
      local s = states[i]
      if s ~= state and type(s) == "table"
          and type(s.drawsWidescreen) == "function" then
        local ok, wide = pcall(s.drawsWidescreen, s)
        if ok and wide then return true end
      end
    end
    return false
  end

  local function gen2Space(state, game, viewport)
    if wideUnder(state, game) then return nil end
    local vp = viewport
    if type(vp) ~= "table" then return nil end
    local k = tonumber(vp.scale)
    local ox, oy = tonumber(vp.gameX), tonumber(vp.gameY)
    if not (k and k > 0 and ox and oy) then return nil end
    local dpi = math.max(tonumber(vp.dpiX) or 1, tonumber(vp.dpiY) or 1)
    if dpi <= 1e-6 then dpi = 1 end
    return { fonts = Theme.fontsAt(game, k), ox = ox, oy = oy,
      kx = k, ky = k, hair = 1 / dpi }
  end

  -- The message lines the box is showing right now, for the page card -- and
  -- for ui/choice.lua's card, which carries the question the box is asking: a
  -- YES/NO over a page is ONE card with the message and the two rows, the way
  -- the Gold PC draws its own confirms.
  function M.pageLines(state)
    local out = {}
    for _, line in ipairs(visibleLines(state)) do
      if line ~= "" then out[#out + 1] = line end
    end
    if #out == 0 then out[1] = "" end
    return out
  end

  -- The card for a box over one of this suite's own pages, in the PAGE's own
  -- coordinates.  The engine shifted the classic overlay right by `off`
  -- (Game:draw's classicOffset), so undoing that puts us back in page space,
  -- where ui/shell.lua's S.card places the suite's centred card -- the same
  -- card the YES/NO over a page and the Gold PC's own messages already use.
  -- S.card also lays the wash, which is what makes the message legible over
  -- the list behind it.
  local function paintPageCard(state, off)
    local game = state.game
    local more = false
    if type(state.arrowVisible) == "function" then
      local ok, v = pcall(state.arrowVisible, state)
      more = ok and v == true
    end
    local g = love.graphics
    if g.push then g.push() end
    if g.translate then g.translate(-off, 0) end
    local ok, err = pcall(Shell.card, Theme, game, {
      lines = M.pageLines(state), w = 420, more = more,
      hints = { { key = "A", text = "OK" } },
      t = state.__t or 0,
    })
    if g.pop then g.pop() end
    if not ok then
      error("g9-gui: the page-space dialogue card failed: "
        .. tostring(err), 0)
    end
  end

  -- GOLD's half of the page card (see M.pageUnder).  Game2 paints a
  -- widescreen base with :drawWidescreen(w, h) -- this suite's page through
  -- ui/shell.lua's gen2Fit, which publishes that fit on the game -- and then
  -- re-runs the stack through Chrome's integer letterbox
  -- (Game2:drawScene -> panelBlit -> Chrome.fitScale/fitOrigin), which is the
  -- pass a pushed TextBox draws in.  The two are one frame at two scales, so
  -- page pixels map into the classic pass through
  --   classic = (pageOrigin - classicOrigin + page * pageScale) / classicScale
  -- and `fn` -- a painter written in the PAGE's coordinates -- lands on exactly
  -- the pixels gen2Fit put the page on.  Returns false, leaving the caller its
  -- surface card, whenever the frame cannot be described: no page fit
  -- published, a fit left over from another page, or an engine without Chrome.
  function M.inPageSpace(game, page, fn)
    local fit = game and game.__g9guiPageFit
    if type(fit) ~= "table" or (page and fit.self ~= page) then return false end
    if not (Chrome and type(Chrome.fitScale) == "function"
        and type(Chrome.fitOrigin) == "function") then return false end
    local w, h = tonumber(fit.w), tonumber(fit.h)
    local ps, pox, poy = tonumber(fit.scale), tonumber(fit.ox), tonumber(fit.oy)
    if not (w and h and ps and ps > 0 and pox and poy) then return false end
    local okS, cs = pcall(Chrome.fitScale, w, h)
    if not (okS and type(cs) == "number" and cs > 0) then return false end
    local okO, cox, coy = pcall(Chrome.fitOrigin, w, h, cs)
    if not (okO and type(cox) == "number" and type(coy) == "number") then
      return false
    end
    local g = love.graphics
    local pushed = false
    if g and g.push then pushed = pcall(g.push) end
    if g and g.translate then
      pcall(g.translate, (pox - cox) / cs, (poy - coy) / cs)
    end
    if g and g.scale then pcall(g.scale, ps / cs, ps / cs) end
    local ok, err = pcall(fn)
    if pushed and g and g.pop then pcall(g.pop) end
    if not ok then
      error("g9-gui: the Gold page-space dialogue card failed: "
        .. tostring(err), 0)
    end
    return true
  end

  -- True when the state on top of the stack is the engine's YES/NO box: the
  -- box under it must then stand down, because that box's card already carries
  -- this message (ui/choice.lua reads M.pageLines) and two cards over one page
  -- would stack.
  local function choiceOverTop(game)
    local stack = game and game.stack
    local states = stack and stack.states
    local top = states and states[#states]
    return isChoiceBox(top)
  end

  -- The window space the dialogue card is painted in this frame, or nil when
  -- the surface card is the right one.  One entry point for the two callers
  -- that must agree: M.hudDraw (which paints the card) and ui/choice.lua
  -- (which paints the choice box riding the same canvas -- it asks for this
  -- very space, so the pair can never disagree about where UI pixels land).
  --
  -- Gen 1 reads the renderer's own rects; Gold has no renderer, so it reads
  -- the render.hud viewport payload.  Both refuse a WIDE surface under the
  -- box (there the classic UI is centred inside the wide canvas -- Gen 1's
  -- battle -- or panelBlit at the page's scale -- Gold's own widescreen
  -- pages), because the card's UI-pixel geometry no longer maps through a
  -- single origin.
  function M.hudSpace(state, game, viewport)
    if state and M.surfaceIsWide(state) then return nil end
    -- ...and a box over one of this suite's own pages takes the page card in
    -- M.draw instead: its geometry is in PAGE pixels, not the classic 20x6
    -- tiles, so the window space below would put it in the wrong place.
    if pageOffset(game) > 0 then return nil end
    local r = gen1Renderer(game)
    if r then
      local okR, R = pcall(r.frameRects, r)
      if not (okR and type(R) == "table") then return nil end
      local kx, ky = R.Ux, R.Uy
      if type(kx) ~= "number" or type(ky) ~= "number" or kx <= 0 or ky <= 0
          or type(R.uox) ~= "number" or type(R.uoy) ~= "number" then
        return nil
      end
      local docked = not letterboxed(r)
      if docked and not (type(R.vuy) == "number" and type(R.vuh) == "number"
          and type(R.uih) == "number") then
        -- a renderer that cannot answer where the window is cannot be trusted
        -- to say where the docked region lands; the surface card draws instead
        return nil
      end
      local dpi = math.max(R.dpiX or 1, R.dpiY or 1)
      local fonts = Theme.fontsAt(game, ky)
      local ox, oy = spaceOrigin(r, R)
      local sp = { fonts = fonts, ox = ox, oy = oy, kx = kx, ky = ky,
        hair = 1 / dpi }
      if docked then
        -- The box region is docked this frame, so the un-anchored MONEY card
        -- stays up in the letterbox while the card itself travels down to the
        -- window's bottom edge (see `spaceOrigin`).
        sp.money = { fonts = fonts, ox = R.uox, oy = R.uoy, kx = kx, ky = ky,
          hair = 1 / dpi }
      end
      return sp
    end
    return gen2Space(state, game, viewport)
  end

  -- Will the render.hud half paint this box this frame?  Gen 1 answers from the
  -- renderer; Gold has none, so it stands on the hook having run once and left
  -- a usable letterbox (`gen2Live`, set by M.hudDraw).  Anything else is "no",
  -- which leaves the box on the surface card -- it can never vanish.
  local function hudWillPaint(state, game)
    if not hudSeen then return false end
    if M.surfaceIsWide(state) then return false end
    -- ...and over one of this suite's own pages the page card is the painter
    -- (see paintPageCard): the window-space half would draw a second card.
    if pageOffset(game) > 0 then return false end
    if gen1Renderer(game) then return true end
    return gen2Live and not wideUnder(state, game)
  end

  function M.draw(state)
    if UIVisibility and not UIVisibility.bottomVisible(state, true) then
      return
    end
    local game = state.game
    -- Over one of this suite's own pages the card is drawn in the PAGE's
    -- coordinates (below), so the engine must NOT be handed the classic edge
    -- anchor: under UI LAYOUT = DYNAMIC the renderer would lift that classic
    -- rectangle out of the page blit and blit it against the window edge --
    -- a white hole where the 20x6 tiles were, plus a detached slice of the
    -- modern page down at the window's bottom.  The page owns the surface;
    -- there is nothing to dock.
    local off = pageOffset(game)
    local r = game and game.renderer
    if off <= 0 and r and r.setUIAnchor then
      -- Keep the engine's edge anchor: in UI LAYOUT = DYNAMIC the renderer
      -- docks this region to the window's bottom edge; in CENTERED (the
      -- default) it is a no-op.  The region is the classic box, which contains
      -- the card.
      r:setUIAnchor((state.boxTx or 0) * 8, (state.boxTy or 12) * 8,
        (state.boxTw or 20) * 8, (state.boxTh or 6) * 8, "bottom")
    end
    -- The window-space card for this frame is drawn by the render.hud hook,
    -- after the frame's composite; drawing it here as well would double the
    -- translucent panel under it.
    if state == activeBox(game) and hudWillPaint(state, game) then return end

    -- Over one of this suite's own pages the cart's window is not on offer at
    -- all: the engine has shifted this classic overlay right by classicOffset,
    -- so the message is painted as the suite's card in the PAGE's coordinates
    -- instead.  A YES/NO the engine pushed over this box already carries the
    -- message (ui/choice.lua), so the box stands down and the pair draws one
    -- card rather than two.
    if off > 0 then
      if not choiceOverTop(game) then paintPageCard(state, off) end
      Theme.set(C.white)
      return
    end

    -- GOLD's half of the same answer.  There is no renderer to undo a shift
    -- for -- the page paints the whole window through ui/shell.lua's gen2Fit --
    -- and the engine's classic overlay pass draws this box at Chrome's integer
    -- letterbox, several times the page's own scale, so the cart's window used
    -- to land on a modern page as a huge chunky box in the cart's face (the
    -- user's report: the plain TextBox over the Gen 2 move learner).  The card
    -- is mapped into that pass instead (M.inPageSpace), so the message reads as
    -- the page's own card.  A YES/NO the engine pushed over this box already
    -- carries the message (ui/choice.lua), so the box stands down and the pair
    -- draws one card rather than two -- the Gen 1 half's contract exactly.
    local page = M.pageUnder(state)
    if page and gen1Renderer(game) == nil then
      local over = choiceOverTop(game)
      local drew = false
      if not over then
        drew = M.inPageSpace(game, page,
          function() paintPageCard(state, 0) end)
      end
      if drew or over then
        Theme.set(C.white)
        return
      end
    end

    paint(state, surfaceSpace(game))
    Theme.set(C.white)
  end

  -- The render.hud half: paint the active box's card in window space, at the
  -- renderer's own scale, from fonts built at that scale.  Called from the
  -- hook installed by M.installHook; public so the render harness can drive it
  -- directly.
  function M.hudDraw(game, viewport)
    hudSeen = true
    gen2Live = false
    local box = activeBox(game)
    if not box then return end
    local sp = M.hudSpace(box, game, viewport)
    if not sp then return end
    -- Latching `gen2Live` on Gold is what lets M.draw stand down next frame --
    -- exactly the role `frameRects` plays on Gen 1 (see `hudWillPaint`).
    gen2Live = gen1Renderer(game) == nil
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
      error("g9-gui: the window-space dialogue card failed: "
        .. tostring(err), 0)
    end
  end

  -- Subscribe the window-space painter.  A missing/refusing hook API is not an
  -- error: hudSeen simply stays false and every box keeps the surface card.
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

  -- Take over a pushed TextBox instance.  Called from the StateStack.push
  -- wrapper in main.lua.
  function M.dress(state)
    if type(state) ~= "table" or state.__g9guiBox then return end
    state.__g9guiBox = true
    state.__t = 0
    -- g9-gui paints its own colours: an empty zone list keeps the engine's
    -- SGB shade-remap shader off the card (the same rule every screen here
    -- follows).  The map keeps its own world zones.
    state.sgbPalettes = function() return {} end
    local baseUpdate = state.update
    state.update = function(self, dt)
      self.__t = (self.__t or 0) + 1
      if baseUpdate then return baseUpdate(self, dt) end
    end
    state.draw = function(self) M.draw(self) end
    -- Re-page at the dialogue font's own width so the smaller face really does
    -- fit more of the message per line (see `reflow` above).  Purely a change
    -- to which strings sit on which line -- the page/line counters, \v order
    -- and pause markers all keep the engine's shape.
    reflowBox(state)
    return state
  end

  return M
end
