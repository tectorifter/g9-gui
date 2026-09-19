-- ui/theme.lua -- g9-gui shared look and drawing primitives.
--
-- One palette, one set of primitives: every g9-gui screen draws through this
-- module so the START screen, the POKeMON screen and the summary panel read as
-- one design.  Nothing here touches the Renderer (setUISize/setCanvas from
-- inside a state's draw is the silent-crash hazard) -- a screen answers
-- :uiSize() and Game:draw sizes the surface.
--
-- Colours are plain love.graphics colours; g9-gui screens answer
-- :sgbPalettes() with an EMPTY zone list, so the engine's shade-remap shader
-- never runs over them and these values reach the screen unchanged.
--
-- Text: this module makes its own love Font objects instead of using the
-- engine's tile/TTF Font.  Reasons: (1) g9-gui draws in raw surface pixels
-- while the engine Font is laid out for an 8x8 tile grid; (2) a
-- love.graphics.print call takes the current colour, which is what lets the
-- palette above put gold on levels and accent blue on values.
--
-- The face is SAIRA (SIL OFL 1.1 -- see assets/fonts/OFL.txt), a geometric
-- humanist sans picked to match the FINAL FANTASY XII: THE ZODIAC AGE menu
-- type: mixed case, wide, low stroke contrast, flat terminals, no serifs and
-- heavy tabular figures.  Saira is not that font (the real one is not
-- redistributable) but it is the closest free match measured against a
-- screenshot of the game's party screen.  Because Saira is proportional, no
-- layout in this mod may count cells any more: measure with Theme.w /
-- Theme.fit, which is what every screen now does.  The body is 22 (cap ink
-- 15px), the secondary size is 13 and the caption size is 10 (`tiny`, the
-- roster's "Lv" prefix); the shipped TTFs are static instances of
-- upstream's variable font, so each carries one weight and no variation axes.
-- Saira-SemiBold is the `bold` cut, used for the figures (levels, HP, money,
-- stats) the way the reference weights its numbers.  A fourth rung, `box`
-- (10), is the dialogue window's body -- see ui/textbox.lua -- with `boxSmall`
-- (9) its emergency cut.  Since 2.3.4 that rung always draws, on every engine:
-- the box paints its own Saira at the window's own size rather than handing the
-- body back to the host engine's TTF.  The box body is the one rung re-flowed:
-- the box wraps its text at the `box` font's own width, not the engine's 18
-- tile cells, so it fits more of a message per line than the engine's
-- pagination would -- and a smaller `box` fits more still.
-- `box` is the one rung that is also built at a MULTIPLE of its size
-- (Theme.fontsAt), because the dialogue card is rasterised in window space
-- rather than in the 160x144 surface -- same type proportions, drawn at the
-- window's own resolution instead of an upscaled bitmap.
--
-- Plain Pixel (the engine's own bundled pixel TTF) stays the fallback: if the
-- two Saira files cannot be read, the exact same layout is built from it and
-- only the look changes.
return function(mod)
  local Theme = {}

  local COL = {
    void      = { 0.043, 0.055, 0.086, 1.00 },
    voidDeep  = { 0.016, 0.022, 0.038, 1.00 },
    panel     = { 0.070, 0.092, 0.133, 0.88 },
    panelDeep = { 0.036, 0.050, 0.078, 0.92 },
    panelLit  = { 0.125, 0.165, 0.240, 0.94 },
    row       = { 0.115, 0.150, 0.220, 0.50 },
    rowLit    = { 0.220, 0.330, 0.460, 0.55 },
    border    = { 0.290, 0.380, 0.520, 0.60 },
    borderLit = { 0.520, 0.690, 0.900, 0.90 },
    shine     = { 1.000, 1.000, 1.000, 0.09 },
    ink       = { 0.930, 0.950, 0.990, 1.00 },
    inkDim    = { 0.620, 0.680, 0.790, 1.00 },
    inkFaint  = { 0.360, 0.420, 0.530, 1.00 },
    accent    = { 0.470, 0.800, 1.000, 1.00 },
    accentDim = { 0.210, 0.400, 0.560, 1.00 },
    gold      = { 0.960, 0.800, 0.360, 1.00 },
    goldDim   = { 0.480, 0.400, 0.200, 1.00 },
    good      = { 0.380, 0.880, 0.480, 1.00 },
    warn      = { 0.960, 0.790, 0.270, 1.00 },
    bad       = { 0.950, 0.380, 0.360, 1.00 },
    card      = { 0.870, 0.898, 0.950, 1.00 },
    cardEdge  = { 1.000, 1.000, 1.000, 0.80 },
    cardDark  = { 0.150, 0.180, 0.235, 1.00 },
    shadow    = { 0.000, 0.000, 0.000, 0.55 },
    dim       = { 0.000, 0.000, 0.000, 0.66 },
    white     = { 1.000, 1.000, 1.000, 1.00 },
    black     = { 0.000, 0.000, 0.000, 1.00 },
  }
  Theme.col = COL

  -- ------------------------------------------------------------------ fonts
  local FONT_REGULAR = "assets/fonts/Saira-Regular.ttf"
  local FONT_BOLD    = "assets/fonts/Saira-SemiBold.ttf"
  local FONT_PIXEL   = "assets/fonts/plainpixel/PlainPixel-Regular.ttf"
  -- `DIALOG` is the dialogue-box rung.  The window is drawn out of the classic
  -- 160x144 surface, where anything near `body` would not hold two lines; the
  -- box keeps its own size rather than borrowing `body`.  It shipped at 11
  -- through 2.2.0, was raised to 13 in 2.3.0 and settled at 12 in 2.3.1; 2.3.2
  -- drops it to 10 -- a 7px cap, a touch under the flat cap of the vanilla 8px
  -- tile glyph -- so more of a message fits the card.  That works because the
  -- box body is the ONE rung re-flowed: ui/textbox.lua wraps its text at the
  -- `box` font's own width rather than the engine's 18 tile cells, so a
  -- smaller `box` genuinely packs more glyphs per line.  `BOX_SMALL` (9) is
  -- the rung a page falls back to when a wide line still will not fit at 10.
  -- 2.3.3 briefly handed the body back to the engine's own TTF; 2.3.4 undoes
  -- that, so this rung -- and the re-flow -- always draw now, at the window's
  -- own size on every engine.
  local BODY, SMALL, TINY, DIALOG, BOX_SMALL = 22, 13, 10, 10, 9
  local ELLIPSIS = "\xe2\x80\xa6"

  -- Vertical metrics per file, in em: ascent (line top -> baseline), cap height
  -- (baseline -> flat-cap top) and descent.  Measured from the shipped TTFs --
  -- Saira: upm 1000, hhea ascender 1135 / descender 439, OS/2 sCapHeight 688;
  -- Plain Pixel: 19/11/9 at its 15px em.  A love Font is userdata, so these
  -- live in side tables keyed by the font object, like the size below.
  local METRIC = {
    ["Saira-Regular.ttf"] = { asc = 1135 / 1000, cap = 688 / 1000, desc = 439 / 1000 },
    ["Saira-SemiBold.ttf"] = { asc = 1135 / 1000, cap = 688 / 1000, desc = 439 / 1000 },
    ["PlainPixel-Regular.ttf"] = { asc = 19 / 15, cap = 11 / 15, desc = 9 / 15 },
  }
  local PIXEL_METRIC = METRIC["PlainPixel-Regular.ttf"]

  local fonts
  -- Which size each font object was built at.  A love Font is userdata, so the
  -- size cannot be stashed on it; this side table is what lets Theme.text
  -- convert a print position into an ink position without being told the size.
  local fontSize = {}
  local fontCap, fontAsc = {}, {}

  local function baseName(path)
    return tostring(path or ""):match("[^/\\]+$") or ""
  end

  local function remember(obj, size, metric)
    -- linear: a proportional TTF is antialiased, and the page is blitted at a
    -- whole 2x, so smooth sampling of the glyph atlas is correct here (the old
    -- pixel face wanted nearest)
    if obj.setFilter then pcall(obj.setFilter, obj, "linear", "linear") end
    fontSize[obj] = size
    fontCap[obj] = (metric and metric.cap) or PIXEL_METRIC.cap
    fontAsc[obj] = (metric and metric.asc) or PIXEL_METRIC.asc
    return obj
  end

  -- LOVE 11 takes a hinting-mode string and a dpi scale; older builds do not.
  -- Try the full call, then the two-argument one, and give up quietly -- the
  -- caller falls back to Plain Pixel, then to the engine's own font.
  local function tryFont(a, size, metric)
    local ok, obj = pcall(love.graphics.newFont, a, size, "normal", 1)
    if not (ok and obj and obj.getWidth) then
      ok, obj = pcall(love.graphics.newFont, a, size)
    end
    if not (ok and obj and obj.getWidth) then return nil end
    return remember(obj, size, metric)
  end

  -- A FileData is the engine-independent route: it works even when the mod
  -- directory is not mounted into love.filesystem, because the sandboxed
  -- mod:read is the only reader this mod is actually promised.
  local function newFileData(bytes, name)
    local fn = (love.data and love.data.newFileData)
      or (love.filesystem and love.filesystem.newFileData)
    if not fn then return nil end
    local ok, fd = pcall(fn, bytes, name)
    if not (ok and fd) then ok, fd = pcall(fn, bytes) end
    return (ok and fd) or nil
  end

  -- Load one of this mod's own TTFs: bytes through mod:read first, then the
  -- same path route ui/portraits.lua uses for mod.assets:image.
  local function fromMod(rel, size)
    if not rel then return nil end
    local metric = METRIC[baseName(rel)]
    local ok, bytes = pcall(mod.read, mod, rel)
    if ok and type(bytes) == "string" and #bytes > 0 then
      local fd = newFileData(bytes, baseName(rel))
      if fd then
        local f = tryFont(fd, size, metric)
        if f then return f end
      end
    end
    if mod.assets and mod.assets.path then
      local ok2, path = pcall(mod.assets.path, mod.assets, rel)
      if ok2 and type(path) == "string" then
        local f = tryFont(path, size, metric)
        if f then return f end
      end
    end
    return nil
  end

  -- A font the engine already knows how to open (its own bundled TTF).
  local function fromFile(path, size)
    if not path then return nil end
    return tryFont(path, size, METRIC[baseName(path)])
  end

  -- Fonts are built once, from the first game table that shows up: only that
  -- boot knows where the engine's own TTF lives.  A call with no game (the
  -- module-level helpers below default to `body`) builds an uncached set from
  -- the engine font so it can never poison the real one.
  --
  -- `k` multiplies every size.  k == 1 is the set every screen draws with;
  -- k == the renderer's window scale is what the dialogue card asks for when
  -- it paints in window space (Theme.fontsAt).  A love Font rasterises its
  -- glyphs at the size it was built with, so scaling a draw transform would
  -- just resample the atlas -- the size has to be baked in.
  local function buildSet(game, k, fallback)
    local def = game and game.data and game.data.font
    local engineFile = (def and def.ttf and def.ttf.file) or nil
    local function sized(rel, size)
      return fromMod(rel, size) or fromFile(engineFile, size)
    end
    local body = sized(FONT_REGULAR, BODY * k) or fallback
    local small = sized(FONT_REGULAR, SMALL * k) or body
    -- the caption cut (the roster's tiny "Lv"): same face, one size down from
    -- `small` if the TTF cannot be opened there
    local tiny = sized(FONT_REGULAR, TINY * k) or small
    local bold = sized(FONT_BOLD, BODY * k) or body
    local box = sized(FONT_REGULAR, DIALOG * k) or body
    local boxSmall = sized(FONT_REGULAR, BOX_SMALL * k) or box
    local smallBold = sized(FONT_BOLD, SMALL * k) or small
    return { body = body, big = body, bold = bold, small = small,
      tiny = tiny, box = box, boxSmall = boxSmall, smallBold = smallBold }
  end

  function Theme.fonts(game)
    if fonts then return fonts end
    local okF, cur = pcall(love.graphics.getFont)
    local built = buildSet(game, 1, (okF and cur) or nil)
    if game then fonts = built end
    return built
  end

  -- The same faces at `k` times every size, for drawing in window space.  A
  -- love Font object cannot be resized and building one per frame would leak,
  -- so the last few scales are kept in a tiny ring: a window resize walks the
  -- scale through a handful of values, not a continuum.
  local scaled, scaledRing = {}, {}
  function Theme.fontsAt(game, k)
    if type(k) ~= "number" or k <= 0 or math.abs(k - 1) < 1e-6 then
      return Theme.fonts(game)
    end
    local hit = scaled[k]
    if hit then return hit end
    local okF, cur = pcall(love.graphics.getFont)
    local built = buildSet(game, k, (okF and cur) or nil)
    scaled[k] = built
    scaledRing[#scaledRing + 1] = k
    while #scaledRing > 3 do
      scaled[table.remove(scaledRing, 1)] = nil
    end
    return built
  end

  function Theme.w(str, font)
    return (font or Theme.fonts(nil).body):getWidth(str)
  end

  -- Cap-height ink of a font, in pixels (the size of a flat-top capital).
  function Theme.capOf(font)
    local size = fontSize[font] or BODY
    return math.max(1, math.floor(size * (fontCap[font] or PIXEL_METRIC.cap) + 0.5))
  end

  -- Truncate `str` to a pixel budget, measured through the real font.  The
  -- budget covers the ellipsis too, and a prefix is never cut through the
  -- middle of a UTF-8 sequence (LÖVE's print rejects malformed UTF-8).  With
  -- no room even for the ellipsis the longest bare prefix is used.
  function Theme.fit(str, font, maxPx)
    if str == nil then return str end
    str = tostring(str)
    font = font or Theme.fonts(nil).body
    if str == "" or maxPx <= 0 then return str end
    if font:getWidth(str) <= maxPx then return str end
    local function longest(budget)
      if budget <= 0 then return 0 end
      local lo, hi = 0, #str
      while lo < hi do
        local mid = math.floor((lo + hi + 1) / 2)
        if font:getWidth(str:sub(1, mid)) <= budget then lo = mid else hi = mid - 1 end
      end
      -- do not end on a UTF-8 continuation byte
      while lo > 0 do
        local b = str:byte(lo + 1)
        if b and b >= 0x80 and b < 0xC0 then lo = lo - 1 else break end
      end
      return lo
    end
    local ell = font:getWidth(ELLIPSIS)
    local n = longest(maxPx - ell)
    if n >= 1 then return str:sub(1, n) .. ELLIPSIS end
    return str:sub(1, longest(maxPx))
  end

  -- Ink offset: plain love.graphics.print places the font's LINE TOP at y, so
  -- the glyph ink actually starts at y + ascent - capHeight.  Both faces here
  -- carry a large em box -- at body 22 Saira's ink starts 10px below the y you
  -- pass, Plain Pixel's 12px -- which is enough to run a caption into the
  -- heading under it.  Every g9-gui layout is therefore written in INK
  -- coordinates: Theme.text's y is the ink's top edge, and this offset is
  -- subtracted.  It is the same trick the engine's own Font.draw performs when
  -- it anchors the TTF baseline to the tile font's (yOffset = 7 -
  -- font:getBaseline()).
  local inkCache = {}
  local function inkOf(font)
    local hit = inkCache[font]
    if hit then return hit end
    local size = fontSize[font] or BODY
    local asc
    if fontAsc[font] then
      asc = fontAsc[font] * size
    elseif font.getBaseline then
      local ok, v = pcall(font.getBaseline, font)
      if ok and type(v) == "number" then asc = v end
    end
    if not asc and font.getAscent then
      local ok, v = pcall(font.getAscent, font)
      if ok and type(v) == "number" then asc = v end
    end
    if not asc and font.getHeight then
      local ok, v = pcall(font.getHeight, font)
      if ok and type(v) == "number" then asc = v * 0.68 end
    end
    -- a wrong guess here only shifts text vertically as a block, it cannot
    -- reorder anything
    hit = math.floor((asc or (size * 1.27)) + 0.5) - Theme.capOf(font)
    inkCache[font] = hit
    return hit
  end
  Theme.inkOffset = inkOf

  -- ----------------------------------------------------------------- drawing

  -- Rounded rectangles are LÖVE 11 only.  pcall once per call site and fall
  -- back to a square rect, so a 0.10 build degrades instead of erroring.
  local function rect(mode, x, y, w, h, r)
    w = w < 0 and 0 or w
    h = h < 0 and 0 or h
    if r and r > 0 then
      local ok = pcall(love.graphics.rectangle, mode, x, y, w, h, r, r)
      if ok then return end
    end
    love.graphics.rectangle(mode, x, y, w, h)
  end
  Theme.rect = rect

  function Theme.set(c, a)
    if not c then love.graphics.setColor(1, 1, 1, 1) return end
    love.graphics.setColor(c[1], c[2], c[3], a or c[4] or 1)
  end

  -- Top-left anchored text (love.graphics.print places the line's top at y).
  -- align: nil/"left" | "right" | "center" -- x is then the right edge or the
  -- centre.  Returns the drawn width.
  function Theme.text(str, x, y, font, align, color)
    str = tostring(str)
    font = font or Theme.fonts(nil).body
    if color then Theme.set(color) end
    love.graphics.setFont(font)
    local w = font:getWidth(str)
    local dx = x
    if align == "right" then dx = x - w
    elseif align == "center" then dx = x - w * 0.5 end
    -- y is the top of the INK, not the top of the line
    love.graphics.print(str, math.floor(dx + 0.5),
      math.floor(y - inkOf(font) + 0.5))
    return w
  end

  -- Panel: shadow + translucent fill + 1px border + a 1px top highlight.
  -- opts = { color, border, radius, shadow (offset), highlight (bool) }
  function Theme.panel(x, y, w, h, opts)
    opts = opts or {}
    local r = opts.radius or 5
    local sh = opts.shadow
    if sh and sh > 0 then
      Theme.set(COL.shadow)
      rect("fill", x + sh, y + sh, w, h, r)
    end
    Theme.set(opts.color or COL.panel)
    rect("fill", x, y, w, h, r)
    Theme.set(opts.border or COL.border)
    rect("line", x + 0.5, y + 0.5, w - 1, h - 1, math.max(0, r - 1))
    if opts.highlight ~= false then
      Theme.set(opts.highlightColor or COL.shine)
      rect("fill", x + 4, y + 1, math.max(0, w - 8), 1, 0)
    end
  end

  -- A bar with rounded ends.  frac 0..1; fill colour optional.
  function Theme.bar(x, y, w, h, frac, color, opts)
    opts = opts or {}
    frac = frac or 0
    if frac < 0 then frac = 0 elseif frac > 1 then frac = 1 end
    local r = opts.radius or math.floor(h * 0.5)
    Theme.set(opts.bg or opts.background or COL.panelDeep)
    rect("fill", x, y, w, h, r)
    if frac > 0 then
      Theme.set(color or COL.good)
      rect("fill", x, y, math.max(1, w * frac), h, r)
    end
    if opts.border then
      Theme.set(opts.border)
      rect("line", x + 0.5, y + 0.5, w - 1, h - 1, r)
    end
  end

  -- Selection cursor: a modernised double chevron.  `pulse` 0..1 nudges the
  -- second chevron so the marker breathes without moving the anchor.
  function Theme.chevrons(x, y, size, color, pulse)
    local s = size or 9
    local off = pulse and pulse * 1.6 or 0
    Theme.set(color or COL.accent)
    local function tri(ox)
      love.graphics.polygon("fill", ox, y, ox + s * 0.60, y + s * 0.5, ox, y + s)
    end
    tri(x)
    tri(x + s * 0.62 + off)
  end

  -- Small lozenge, the "in the party" marker and the page-tab marker.
  function Theme.diamond(cx, cy, r, color)
    Theme.set(color or COL.accent)
    love.graphics.polygon("fill", cx, cy - r, cx + r, cy, cx, cy + r, cx - r, cy)
  end

  -- Corner brackets, the embellishment that frames the whole surface.
  -- sx/sy are the stroke thickness; 1 in the surface's own pixels, the
  -- window scale when the same bracket is drawn natively (textbox.lua).
  function Theme.brackets(x, y, w, h, len, color, sx, sy)
    Theme.set(color or COL.accentDim)
    sx, sy = sx or 1, sy or 1
    local function L(px, py, bw, bh)
      rect("fill", px, py, bw, bh, 0)
    end
    L(x, y, len, sy) L(x, y, sx, len)
    L(x + w - len, y, len, sy) L(x + w - sx, y, sx, len)
    L(x, y + h - sy, len, sy) L(x, y + h - len, sx, len)
    L(x + w - len, y + h - sy, len, sy) L(x + w - sx, y + h - len, sx, len)
  end

  -- A compact heading: accent rule + label, used above roster columns and
  -- inside panels.
  function Theme.rule(x, y, w, color)
    Theme.set(color or COL.border)
    rect("fill", x, y, w, 1, 0)
  end

  -- Footer hint strip: a list of {key=, text=} chips, left to right.
  -- Returns the width used.
  --
  -- A key made of arrow characters is drawn as VECTOR arrows, not text: the
  -- bundled face (Saira, and Plain Pixel before it) has no U+2190..U+2193, so
  -- `key = "\xe2\x86\x90\xe2\x86\x92"` printed the engine's missing-glyph box
  -- twice at the foot of every screen.  Reading the key as directions keeps
  -- every existing hint list unchanged and puts a real chevron in the chip.
  local ARROW_DIR = {
    ["\xe2\x86\x90"] = "left", ["\xe2\x86\x91"] = "up",
    ["\xe2\x86\x92"] = "right", ["\xe2\x86\x93"] = "down",
  }
  -- [] -> list of directions, or nil when the key is ordinary text
  local function arrowKey(key)
    local dirs, i, n = {}, 1, #key
    while i <= n do
      local dir = ARROW_DIR[key:sub(i, i + 2)]
      if not dir then return nil end
      dirs[#dirs + 1] = dir
      i = i + 3
    end
    return #dirs > 0 and dirs or nil
  end

  -- One filled triangle, apex pointing `dir`.  `r` is the half-height.  Built
  -- as six numbers rather than a vertex table: love.graphics.polygon takes
  -- both, but the render harness's stand-in records the varargs form only.
  local function arrowTri(dir, cx, cy, r, color)
    Theme.set(color or COL.accent)
    if dir == "left" then
      love.graphics.polygon("fill", cx - r, cy, cx + r * 0.52, cy - r,
        cx + r * 0.52, cy + r)
    elseif dir == "right" then
      love.graphics.polygon("fill", cx + r, cy, cx - r * 0.52, cy - r,
        cx - r * 0.52, cy + r)
    elseif dir == "up" then
      love.graphics.polygon("fill", cx, cy - r, cx - r, cy + r * 0.52,
        cx + r, cy + r * 0.52)
    else
      love.graphics.polygon("fill", cx, cy + r, cx - r, cy - r * 0.52,
        cx + r, cy - r * 0.52)
    end
  end

  function Theme.hints(list, x, y, font, opts)
    opts = opts or {}
    font = font or Theme.fonts(nil).body
    -- The key chip is measured from the font, not fixed: at body 22 it is a
    -- 19px lozenge rather than the 13px one a 15px font got.
    local size = fontSize[font] or BODY
    local cap = Theme.capOf(font)
    local chipH = math.floor(size * 13 / 15 + 0.5)
    local inset = math.floor(size * 3 / 15 + 0.5)
    local gap = math.floor(size * 6 / 15 + 0.5)
    local radius = math.floor(size * 3 / 15 + 0.5)
    local pen = x
    local keyCol = opts.keyColor or COL.accent
    local txtCol = opts.textColor or COL.inkFaint
    for i = 1, #list do
      local h = list[i]
      local dirs = arrowKey(tostring(h.key or ""))
      local kw, arrowR, step
      if dirs then
        arrowR = math.max(3, cap * 0.50)
        step = arrowR * 1.44
        kw = #dirs * step
      else
        kw = font:getWidth(h.key)
      end
      local cy = y - math.floor((chipH - cap) * 0.5)
      Theme.set(opts.keyBg or COL.accentDim)
      rect("fill", pen, cy, kw + inset * 2, chipH, radius)
      if dirs then
        local ax = pen + inset
        for k = 1, #dirs do
          arrowTri(dirs[k], ax + step * (k - 0.5), y + cap * 0.5, arrowR, keyCol)
        end
      else
        Theme.text(h.key, pen + inset, y, font, "left", keyCol)
      end
      pen = pen + kw + inset * 2 + gap
      if h.text then
        pen = pen + Theme.text(h.text, pen, y, font, "left", txtCol)
      end
      pen = pen + (list[i + 1] and opts.gap or 0)
    end
    return pen - x
  end

  -- HP fraction + colour band.
  function Theme.hpFrac(mon)
    local max = (mon and mon.stats and mon.stats.hp) or 0
    if max <= 0 then return 0 end
    local f = (mon.hp or 0) / max
    if f < 0 then f = 0 elseif f > 1 then f = 1 end
    return f
  end

  function Theme.hpColor(frac)
    if frac > 0.5 then return COL.good end
    if frac > 0.2 then return COL.warn end
    return COL.bad
  end

  return Theme
end
