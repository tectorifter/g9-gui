-- ui/portraits.lua -- portrait art for a party row.
--
-- Two presentations, picked by the PARTY PORTRAITS option:
--   "sprites" -- the head space of the pack's FRONT battle sheet for the
--                species (assets/front/<STEM>.png), a window keeping the
--                card's own aspect taken from the top of the trimmed frame and
--                drawn at a whole multiple so the face fills the card.
--   "icons"   -- the pack's own 16x16 party-ICON atlas
--                (assets/icons/party_icons.png), the whole cell fitted into
--                the card.
--
-- The art itself comes from g9-battle-sprites when it is installed: it owns
-- the pack's true-colour frames, and two always-on exports hand them over --
-- `frontArt(mon)` -> the baked, trimmed front frame as a standalone Image, and
-- `iconArt16(mon)` -> the small icon atlas cell.  Both are independent of that
-- mod's battle options, so the modern UI shows the pack's art even with battle
-- sprites switched off.  Older copies of the sprites mod (no frontArt) still
-- work: `iconArtHD`'s 64x64 party cell is kept as a second choice, and the
-- engine's own front pic / 16x16 icon remain the final fallback -- so the
-- screen is still correct without that mod, it just shows the game's own art
-- (and says so once in the log, naming the version of that mod it found).
--
-- Everything is drawn through the engine's own seams (Sprites.path /
-- Sprites.iconPath -> Assets.resolve) or the pack's export, so a mod that
-- swaps battle art changes what the modern UI shows too -- and a true-colour
-- pack comes through in colour, since g9-gui screens run with no SGB
-- shade-remap zones.
return function(mod)
  local P = {}
  local Assets = require("src.render.Assets")
  local Sprites = require("src.pokemon.Sprites")

  -- Where in the pack's frame the "head space" window starts: 8% down, which
  -- keeps a horn or a hat inside it.  The window's HEIGHT follows the card's
  -- own aspect (see drawHeadSpace), so there is no second constant here.
  local HEAD_TOP = 0.08
  -- the largest whole multiple a card is ever filled with (6 keeps a very
  -- narrow trimmed frame -- a slim snake-like sprite -- filling a 96px card)
  local MAX_SCALE = 6

  local images = {}
  local quads = {}

  local function load(path)
    if not path then return nil end
    local hit = images[path]
    if hit == nil then
      local ok, img = pcall(Assets.image, path)
      hit = (ok and img) or false
      images[path] = hit
    end
    return hit or nil
  end

  local function quad(x, y, w, h, iw, ih)
    local key = table.concat({ x, y, w, h, iw, ih }, ":")
    local q = quads[key]
    if not q then
      q = love.graphics.newQuad(x, y, w, h, iw, ih)
      quads[key] = q
    end
    return q
  end

  -- forget cached art when the engine flushes its asset caches (dev hot
  -- reload, or a mod's sprite swap landing)
  Assets.register(function() images = {} quads = {} end)

  -- the icon entry is the same resolution PartyMenu.drawIcon performs:
  -- per-species override, then the species record's own `icon`, then the
  -- dex-indexed default table.
  local function iconSpec(game, mon)
    local icons = game.data.icons
    local def = game.data.pokemon and game.data.pokemon[mon.species]
    local entry = icons and icons.bySpecies and icons.bySpecies[mon.species]
    if not entry and def then entry = def.icon end
    local name, path
    if type(entry) == "string" then
      name = entry
      path = icons and icons.icons and icons.icons[entry]
    elseif type(entry) == "table" then
      path = entry.image
    end
    if not path then
      name = def and def.dex and icons and icons.byDex and icons.byDex[def.dex]
      path = name and icons and icons.icons and icons.icons[name]
    end
    path = Sprites.iconPath(game.data, mon, path, { name = name })
    return name, path
  end

  -- The g9-battle-sprites exports table, or nil.  ONE lookup feeds all three
  -- source helpers below, and a miss is counted so the fall-back to the game's
  -- own art is ANNOUNCED rather than silently looking like the mod is broken:
  -- the whole point of these cards is the pack's art, so the log has to say why
  -- they are not showing it.  A miss is only reported after a second's worth of
  -- roster rows (60 draws), so a peer that is momentarily unreachable is never
  -- blamed.  A mod cannot read another mod's files (love.filesystem is closed
  -- to mods and mod:read is scoped to its own folder), so these exports are the
  -- ONLY channel between the two mods -- a copy of the sprites mod from before
  -- 3.0.8 exports none of them and the cards fall back to the game's own art.
  local missFrames = 0
  local toldWhy = false
  local function peerEx()
    local handle = mod.find and mod.find("g9-battle-sprites") or nil
    local ex = handle and handle.exports
    if type(ex) == "table" and (type(ex.frontArt) == "function"
      or type(ex.iconArtHD) == "function"
      or type(ex.iconArt16) == "function") then
      missFrames = 0
      return ex
    end
    missFrames = missFrames + 1
    if missFrames == 60 and not toldWhy then
      toldWhy = true
      if not (mod.log and mod.log.warn) then return nil end
      if not handle then
        mod.log:info("g9-battle-sprites is not installed (or is disabled or "
          .. "failed to load) -- party portraits use the game's own art")
      else
        mod.log:warn("g9-battle-sprites " .. tostring(handle.version)
          .. " has no portrait art exports -- party portraits use the game's "
          .. "own art (update that mod to 3.0.8+, keeping your downloaded "
          .. "assets/front and assets/back sheets)")
      end
    end
    return nil
  end

  -- The pack's own true-colour art, as (image, quad, cellW, cellH, box).
  -- `iconArtHD`
  -- is g9-battle-sprites' always-on high-resolution accessor (that mod's own
  -- G9 PARTY SCREEN option does not have to be on for it); `iconArt` is its
  -- older, option-gated one, kept as a second choice so an older copy of the
  -- sprites mod still works.  It answers (quads, image, cellPixels, box) where
  -- `quads` is a TABLE of quads (full / tl / tr / br) and `box` is the bounding
  -- box of the cell's opaque pixels, in cell pixels (see drawHeadSpace -- an
  -- older copy answers a single quad and no box).  A nil result -- no sprites
  -- mod, no entry for this species, atlas still decoding, or an older copy with
  -- neither export -- falls through to the engine's own art.
  local function packArt(mon)
    local ex = peerEx()
    if type(ex) ~= "table" then return nil end
    local fn = ex.iconArtHD or ex.iconArt
    if type(fn) ~= "function" then return nil end
    local ok, q, img, cell, box = pcall(fn, mon)
    if not ok then return nil end
    -- the current export hands back the per-cell quad table; take its frame
    if type(q) == "table" and type(q.full) == "table" then q = q.full end
    if not (img and type(img.getDimensions) == "function"
      and type(q) == "table") then return nil end
    -- the cell size is the quad's own viewport (a 64x64 frame of a much wider
    -- atlas), so a sub-crop of it can be taken without guessing
    local cw, ch = 0, 0
    if type(q.getViewport) == "function" then
      local ok2, _, _, qw, qh = pcall(q.getViewport, q)
      if ok2 then cw, ch = qw or 0, qh or 0 end
    end
    if cw <= 0 or ch <= 0 then
      local n = tonumber(cell) or 0
      cw, ch = n, n
    end
    if cw <= 0 or ch <= 0 then return nil end
    -- only trust a box that actually describes this frame
    if type(box) ~= "table" or type(box.y) ~= "number"
      or type(box.h) ~= "number" then box = nil end
    return img, q, cw, ch, box
  end

  -- The pack's FRONT battle art for this mon, through g9-battle-sprites'
  -- always-on `frontArt` export: the pack's own assets/front/<STEM>.png sheet,
  -- baked (off the draw path, by that mod's core.update hook) into a trimmed,
  -- standalone frame Image.  Answers (image, w, h) once it is ready -- the
  -- first call starts the bake and answers `nil, pending` -- and nil, or a copy
  -- of the mod without the export, falls through to the HD icon cell below.
  -- `pending` says a real sheet is ON ITS WAY, so the caller must not fall back
  -- to the engine's own art for those frames: that would flash native art
  -- exactly where the pack's art is about to appear.
  local function packFront(mon)
    local ex = peerEx()
    if type(ex) ~= "table" then return nil end
    local fn = ex.frontArt
    if type(fn) ~= "function" then return nil end
    -- getFrames' SECOND value is `pending`, so keep the whole result: a
    -- `local ok, img = pcall(...)` would silently drop it.
    local res = { pcall(fn, mon) }
    if not res[1] then return nil end
    local img, w, h = res[2], res[3], res[4]
    if not img then return nil, nil, nil, res[3] and true or false end
    if type(img.getDimensions) ~= "function" then return nil end
    if type(w) ~= "number" or type(h) ~= "number" or w <= 0 or h <= 0 then
      w, h = img:getDimensions()
    end
    if not w or not h or w <= 0 or h <= 0 then return nil end
    return img, w, h
  end

  -- The pack's SMALL 16x16 party-ICON atlas, through the always-on `iconArt16`
  -- export: (image, quad, cellW, cellH) for the mon's icon cell, or nil.
  local function packIcon(mon)
    local ex = peerEx()
    if type(ex) ~= "table" then return nil end
    local fn = ex.iconArt16
    if type(fn) ~= "function" then return nil end
    local ok, q, img, cell = pcall(fn, mon)
    if not ok then return nil end
    if type(q) == "table" and type(q.full) == "table" then q = q.full end
    if not (img and type(img.getDimensions) == "function"
      and type(q) == "table") then return nil end
    local cw, ch = 0, 0
    if type(q.getViewport) == "function" then
      local ok2, _, _, qw, qh = pcall(q.getViewport, q)
      if ok2 then cw, ch = qw or 0, qh or 0 end
    end
    if cw <= 0 or ch <= 0 then
      local n = tonumber(cell) or 0
      cw, ch = n, n
    end
    if cw <= 0 or ch <= 0 then cw, ch = 16, 16 end
    return img, q, cw, ch
  end

  -- Fill the card with the HEAD SPACE of the frame: a window of it, anchored
  -- to the CREATURE (see the pack's opaque-pixel box, `box` -- the frames are
  -- bottom-anchored and the spare rows sit above the art, so a fixed
  -- top-anchored window would land on blank rows for many species) and centred
  -- across it, drawn at the largest WHOLE multiple of the art's own pixels that
  -- fits the card's WIDTH -- the card is a wide band, so the width is the axis
  -- that decides it, and a whole multiple means the pack's 64x64 frames land on
  -- exact 2x2 blocks instead of being resampled.  The window keeps the card's
  -- aspect, so the art reaches all four edges.  Without a box (an older sprites
  -- mod, or unreadable pixels) it falls back to the old 8%-down anchor.
  local function drawHeadSpace(img, q, aw, ah, x, y, w, h, box)
    -- CEIL, not the nearest multiple: the window is clamped to the frame's own
    -- width, so the scale must be the smallest whole multiple that makes the
    -- art at least as wide as the card -- otherwise a frame narrower than the
    -- card (a trimmed front sheet, unlike the 64px icon cell) would be drawn
    -- too small to reach the card's edges.
    local s = math.ceil(w / aw)
    if s < 1 then s = 1 elseif s > MAX_SCALE then s = MAX_SCALE end
    local winW = math.min(aw, math.max(1, math.ceil(w / s)))
    local winH = math.min(ah, math.max(1, math.ceil(h / s)))
    local winX = math.floor((aw - winW) * 0.5)
    local winY
    if box then
      -- a couple of pixels above the topmost opaque row, so the window starts
      -- just over the head rather than clipping it
      winY = math.max(0, math.floor(box.y) - 2)
    else
      winY = math.floor(ah * HEAD_TOP)
    end
    if winY + winH > ah then winY = ah - winH end
    if winY < 0 then winY = 0 end
    -- a sub-quad of the cell, so the crop costs no extra atlas work
    if winX > 0 or winY > 0 or winW < aw or winH < ah then
      local iw, ih = img:getDimensions()
      if q and q.getViewport then
        local ok, qx, qy = pcall(q.getViewport, q)
        if ok then
          q = quad((qx or 0) + winX, (qy or 0) + winY, winW, winH, iw, ih)
        else
          q = quad(winX, winY, winW, winH, iw, ih)
        end
      else
        q = quad(winX, winY, winW, winH, iw, ih)
      end
    end
    local dw, dh = winW * s, winH * s
    love.graphics.draw(img, q, math.floor(x + (w - dw) * 0.5),
      math.floor(y + (h - dh) * 0.5), 0, s, s)
  end

  -- The whole frame, for the ICON presentation: fitted into the card, snapped
  -- to a whole multiple when the frame is small enough and to a clean 1:2
  -- decimation when it is larger than the card (a point-sampled halving keeps
  -- the pixel edges hard -- no interpolation).
  local function drawWhole(img, q, aw, ah, x, y, w, h)
    local s = math.min(w / aw, h / ah)
    if s >= 1 then s = math.floor(s) elseif s > 0.5 then s = 0.5 end
    if s <= 0 then return end
    local dw, dh = aw * s, ah * s
    love.graphics.draw(img, q, math.floor(x + (w - dw) * 0.5),
      math.floor(y + (h - dh) * 0.5), 0, s, s)
  end

  -- Draw into the card body (x,y,w,h).  `Theme` is the shared theme, used for
  -- the no-art placeholder.  Returns true when art was drawn.
  function P.draw(Theme, game, mon, x, y, w, h, mode)
    local icons = (mode == "icons")
    -- set when the pack's front sheet for this mon is still baking, so the
    -- game's own art is NOT flashed on the frame before the pack art lands
    local pending = false

    -- 1. the pack's own art (g9-battle-sprites), source picked by the mode:
    --    "sprites" = the FRONT battle sheet's head space, "icons" = the small
    --    16x16 icon atlas cell.
    if icons then
      local img, q, cw, ch = packIcon(mon)
      if img then
        Theme.set(Theme.col.white)
        love.graphics.setScissor(x, y, w, h)
        drawWhole(img, q, cw, ch, x, y, w, h)
        love.graphics.setScissor()
        return true
      end
    else
      local img, aw, ah, wait = packFront(mon)
      pending = wait or false
      if img then
        Theme.set(Theme.col.white)
        love.graphics.setScissor(x, y, w, h)
        -- a trimmed front frame IS its own content, so the head-space window
        -- anchors to the frame's top (a full-frame box means "no spare rows")
        local q = quad(0, 0, aw, ah, aw, ah)
        drawHeadSpace(img, q, aw, ah, x, y, w, h,
          { x = 0, y = 0, w = aw, h = ah })
        love.graphics.setScissor()
        return true
      end
    end

    -- 2. the pack's HD icon cell (an older sprites mod without frontArt /
    --    iconArt16): the 64x64 true-colour party cell, cropped or fitted.
    local img, q, aw, ah, box = packArt(mon)
    if img then
      Theme.set(Theme.col.white)
      love.graphics.setScissor(x, y, w, h)
      if icons then
        -- the whole frame, fitted (a fractional scale only when the frame is
        -- taller than the card)
        drawWhole(img, q, aw, ah, x, y, w, h)
      else
        drawHeadSpace(img, q, aw, ah, x, y, w, h, box)
      end
      love.graphics.setScissor()
      return true
    end

    -- a pack sheet that is still baking must not flash the game's own art on
    -- its way in: leave the card to the pack art for those few frames
    if pending then return false end

    -- 3. the engine's own art
    if icons then
      local _, path = iconSpec(game, mon)
      img = load(path)
      if not img then
        Theme.set(Theme.col.cardDark)
        Theme.rect("fill", x, y, w, h, 3)
        return false
      end
      local iw, ih = img:getDimensions()
      Theme.set(Theme.col.white)
      love.graphics.setScissor(x, y, w, h)
      -- 16x16 icon sheet: taller sheets stack frames, so the resting frame is
      -- the first 16 rows, drawn at the largest whole multiple that fits.
      local fh = ih >= 32 and 16 or math.min(16, ih)
      local q2 = quad(0, 0, math.min(16, iw), fh, iw, ih)
      local s = math.max(1, math.floor(math.min(w / 16, h / fh)))
      local dw, dh = 16 * s, fh * s
      love.graphics.draw(img, q2, math.floor(x + (w - dw) * 0.5),
        math.floor(y + (h - dh) * 0.5), 0, s, s)
      love.graphics.setScissor()
      return true
    end

    local path = Sprites.path(game.data, mon.species, "front",
      { mon = mon, kind = "summary" })
    img = load(path)
    if not img then
      Theme.set(Theme.col.cardDark)
      Theme.rect("fill", x, y, w, h, 3)
      Theme.text("?", x + w * 0.5, y + h * 0.5 - 5,
        Theme.fonts(game).body, "center", Theme.col.inkFaint)
      return false
    end
    -- the whole front pic at a whole multiple, anchored to its TOP so the card
    -- shows the head and shoulders -- the same "portrait" reading the pack's
    -- head space gives -- rather than a resampled middle band
    local iw, ih = img:getDimensions()
    local s = math.max(1, math.floor(h / ih))
    local dw, dh = iw * s, ih * s
    Theme.set(Theme.col.white)
    love.graphics.setScissor(x, y, w, h)
    love.graphics.draw(img, quad(0, 0, iw, ih, iw, ih),
      math.floor(x + (w - dw) * 0.5), y, 0, s, s)
    love.graphics.setScissor()
    return true
  end

  return P
end
