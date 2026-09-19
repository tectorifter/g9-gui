-- ui/portraits.lua -- portrait art for a party row.
--
-- Two presentations, picked by the PARTY PORTRAITS option:
--   "sprites" -- the head space of the pack's FRONT battle sheet for the
--                species (assets/front/<STEM>.png): the card's own window of
--                the frame, anchored to the creature's head, drawn at the
--                pack's own pixels (1:1) so every species keeps the size the
--                pack gives it.  See drawHeadSpace.
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

  -- The "head space" window is the card's own 56x34 of the frame, drawn at the
  -- pack's OWN pixels -- 1:1, never a zoom (see drawHeadSpace).  HEAD_TOP is
  -- only the fallback for a frame whose creature box cannot be read: 8% down,
  -- which keeps a horn or a hat inside the window.
  local HEAD_TOP = 0.08

  local images = {}
  local quads = {}
  local boxes = {}

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

  -- LÖVE hands back a Quad as USERDATA, but the test harness's stand-in is a
  -- plain table -- so a quad arriving from another mod is recognised by SHAPE
  -- (something that answers getViewport), never by its Lua type.  The sprites
  -- mod hands its cells over wrapped in a per-cell table
  -- ({ full = quad, tl = ..., tr = ..., br = ... }); quadOf pulls the `full`
  -- Quad out.  The wrapper MUST come off: a guard that only checked
  -- `type(q.full) == "table"` left the wrapper TABLE in place on a real boot
  -- (the Quad inside it is userdata), and love.graphics.draw then read that
  -- table as the x coordinate -- "bad argument #2 to 'draw' (number expected,
  -- got table)".  The Gen 2 portrait path always resolves through the icon
  -- export, so that was the Gen 2 START crash.
  local function isQuad(q)
    if type(q) ~= "table" and type(q) ~= "userdata" then return false end
    return type(q.getViewport) == "function"
  end

  local function quadOf(q)
    if type(q) == "table" and isQuad(q.full) then return q.full end
    return q
  end

  -- forget cached art when the engine flushes its asset caches (dev hot
  -- reload, or a mod's sprite swap landing)
  Assets.register(function() images = {} quads = {} boxes = {} end)

  -- The opaque-pixel box of a frame Image, in the image's own pixels, or nil.
  -- The sprites mod hands over the FIRST frame trimmed to the WHOLE
  -- animation's union box, so that frame can sit inside it with spare rows
  -- above its head (and spare columns beside it) -- anchoring the crop to the
  -- image's own top would leave that gap under the card's top edge, and a
  -- fixed left/right centre would frame the animation's travel instead of the
  -- creature.  Reading the pixels back is what lets the crop anchor to the
  -- CREATURE: `Image:newImageData` + `getPixel` (the same read the sprites mod
  -- itself uses to measure its cells), scanned once per image -- a frame is at
  -- most ~75px a side -- and cached beside the art.  nil when the pixels
  -- cannot be read, and the caller falls back to the frame's own top.
  local function contentBox(img)
    local hit = boxes[img]
    if hit == nil then
      local ok, box = pcall(function()
        local id = img:newImageData()
        if not (id and id.getPixel) then return nil end
        local iw, ih = img:getDimensions()
        local x0, y0, x1, y1 = iw, ih, -1, -1
        for y = 0, ih - 1 do
          for x = 0, iw - 1 do
            local a = select(4, id:getPixel(x, y))
            if a and a > 0 then
              if x < x0 then x0 = x end
              if x > x1 then x1 = x end
              if y < y0 then y0 = y end
              if y > y1 then y1 = y end
            end
          end
        end
        if x1 < x0 or y1 < y0 then return nil end
        return { x = x0, y = y0, w = x1 - x0 + 1, h = y1 - y0 + 1 }
      end)
      hit = (ok and box) or false
      boxes[img] = hit
    end
    return hit or nil
  end

  -- the icon entry is the same resolution PartyMenu.drawIcon performs:
  -- per-species override, then the species record's own `icon`, then the
  -- dex-indexed default table.
  local function iconSpec(game, mon)
    local data = game.data or {}
    local def = data.pokemon and data.pokemon[mon.species]
    -- Gold keeps its icons at data.gen2Icons with the SAME shape
    -- PartyMenu.iconFor reads: species[species] -> iconId, icons[iconId].image
    -- (and the same src.pokemon.Sprites.iconPath seam on the way out).
    local g2 = data.gen2Icons
    if g2 then
      local name = g2.species and g2.species[mon.species]
      if not name and def then name = def.icon end
      local entry = name and g2.icons and g2.icons[name]
      local path = type(entry) == "table" and entry.image
        or (type(entry) == "string" and entry) or nil
      path = Sprites.iconPath(data, mon, path, { name = name })
      return name, path
    end
    local icons = data.icons
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
    q = quadOf(q)
    if not (img and type(img.getDimensions) == "function"
      and isQuad(q)) then return nil end
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
  -- standalone frame Image.  The trim is the WHOLE animation's union box, so
  -- the image can carry spare rows above frame 1's head -- which is why the
  -- caller reads the frame's own pixels back (see contentBox) instead of
  -- trusting the image's top.  Answers (image, w, h) once it is ready -- the
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
    q = quadOf(q)
    if not (img and type(img.getDimensions) == "function"
      and isQuad(q)) then return nil end
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

  -- Draw the HEAD SPACE of a frame into the card: the card's own window of the
  -- image, anchored to the CREATURE (its opaque-pixel box, `box`) -- the head
  -- at the card's top edge, centred across the creature -- and drawn at the
  -- pack's OWN pixels, 1:1.
  --
  -- 1:1 is the whole point.  The pack's sheets are trimmed per species, so a
  -- species' sheet size IS its size in the pack: drawing every sheet at the
  -- same 1:1 is what keeps their relative sizes reading true -- a Weedle stays
  -- a Weedle beside an Amoonguss -- and it is the same "natural size" the
  -- battle screen draws.  It is also the one scale that resamples nothing at
  -- all.  The old rule picked a WHOLE MULTIPLE per frame (ceil(w / frameW), so
  -- that a narrow frame still reached the card's edges) which made exactly the
  -- SMALLEST sheets the most zoomed -- a 37px sheet came out at 2x while a 62px
  -- one stayed 1:1 -- so the portrait looked most wrong for the smallest
  -- Pokemon.  A frame narrower or shorter than the card is simply centred in
  -- it, at its own size.
  --
  -- `box` is the CREATURE's box; without one (unreadable pixels) the window
  -- falls back to the frame's own top, HEAD_TOP down, centred on the frame.
  local function drawHeadSpace(img, q, aw, ah, x, y, w, h, box)
    -- the card's window of the frame, in the frame's own pixels (1:1), and
    -- never more of it than the frame has
    local winW = math.min(aw, w)
    local winH = math.min(ah, h)
    local winX, winY
    if box then
      winX = math.floor(box.x + box.w * 0.5 - winW * 0.5)
      winY = math.floor(box.y)
      if winY < 0 then winY = 0 end
      -- the window's first row is the creature's head, so it must not run past
      -- the frame's last row: SHRINK it (the head stays on the first row)
      -- rather than pushing the head down, which would leave a blank strip
      -- above it -- the very thing this crop exists to avoid.  A shorter
      -- window is top-anchored at the draw below, so the head is flush.
      if winY + winH > ah then winH = ah - winY end
      local maxX = aw - winW
      if winX > maxX then winX = maxX end
      if winX < 0 then winX = 0 end
    else
      winX = math.floor((aw - winW) * 0.5)
      winY = math.floor(ah * HEAD_TOP)
      -- keep the fallback window inside the frame
      local maxX, maxY = aw - winW, ah - winH
      if winX > maxX then winX = maxX end
      if winY > maxY then winY = maxY end
      if winX < 0 then winX = 0 end
      if winY < 0 then winY = 0 end
    end
    if winW <= 0 or winH <= 0 then return end
    -- a sub-quad of the frame, so the crop costs no extra atlas work
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
    -- 1:1 into the card's own surface.  A box-anchored window keeps its first
    -- row (the creature's head) on the card's first row, so the head is flush
    -- even when the frame is shorter than the card; without a box the window is
    -- centred on whichever axis the frame does not fill.
    local dy = box and y or math.floor(y + (h - winH) * 0.5)
    love.graphics.draw(img, q, math.floor(x + (w - winW) * 0.5), dy)
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

  -- Clip the card's own art to the card rect.  love.graphics.setScissor works
  -- in WINDOW pixels and is NOT affected by the current transform ("The
  -- dimensions of the scissor are unaffected by graphical transformations" --
  -- love.graphics.setScissor).  Gen 1 draws this 540x360 page into a real
  -- surface at 1:1, so a page-space rect IS the window rect there.  Gen 2
  -- paints the page into the window under Shell.gen2Page's translate/scale, so
  -- a raw page-space setScissor clips a rectangle that no longer lines up with
  -- the art -- at 2x it lands a whole card away and the portrait is clipped to
  -- nothing (the "blank head space" bug).  Theme.page carries the active page
  -- transform while the page draws (Shell.gen2Page), so map page -> window when
  -- one is in play and use the plain rect otherwise.  nil = Gen 1.
  local function clip(Theme, x, y, w, h)
    local G = love.graphics
    local p = Theme and Theme.page
    if p then
      local x0 = math.floor(p.ox + x * p.scale)
      local y0 = math.floor(p.oy + y * p.scale)
      local x1 = math.ceil(p.ox + (x + w) * p.scale)
      local y1 = math.ceil(p.oy + (y + h) * p.scale)
      G.setScissor(x0, y0, x1 - x0, y1 - y0)
    else
      G.setScissor(x, y, w, h)
    end
  end

  local function unclip() love.graphics.setScissor() end

  -- Draw into the card body (x,y,w,h).  `Theme` is the shared theme, used for
  -- the no-art placeholder.  Returns true when art was drawn.
  function P.draw(Theme, game, mon, x, y, w, h, mode)
    local icons = (mode == "icons")
    -- Gold has no Gen 1 front-pic table for src.pokemon.Sprites.path to read
    -- (it keys off def.spriteFront) and the g9-battle-sprites pack is a Gen 1
    -- mod, so on a Gold boot BOTH presentation modes resolve through the
    -- engine's own party ICON -- an honest picture in the card rather than a
    -- '?' under the chosen mode.
    if not icons and game and game.data and game.data.gen2Icons then
      icons = true
    end
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
        clip(Theme, x, y, w, h)
        drawWhole(img, q, cw, ch, x, y, w, h)
        unclip()
        return true
      end
    else
      local img, aw, ah, wait = packFront(mon)
      pending = wait or false
      if img then
        Theme.set(Theme.col.white)
        clip(Theme, x, y, w, h)
        -- the export trims to the WHOLE animation's union box, so frame 1 can
        -- sit inside it with spare rows above its head (and spare columns
        -- beside it): read frame 1's OWN box back and anchor the crop to the
        -- creature.  A frame whose pixels cannot be read is taken as its own
        -- content, so the window anchors to its top exactly as a truly trimmed
        -- frame would.
        local box = contentBox(img) or { x = 0, y = 0, w = aw, h = ah }
        local q = quad(0, 0, aw, ah, aw, ah)
        drawHeadSpace(img, q, aw, ah, x, y, w, h, box)
        unclip()
        return true
      end
    end

    -- 2. the pack's HD icon cell (an older sprites mod without frontArt /
    --    iconArt16): the 64x64 true-colour party cell, cropped or fitted.
    local img, q, aw, ah, box = packArt(mon)
    if img then
      Theme.set(Theme.col.white)
      clip(Theme, x, y, w, h)
      if icons then
        -- the whole frame, fitted (a fractional scale only when the frame is
        -- taller than the card)
        drawWhole(img, q, aw, ah, x, y, w, h)
      else
        drawHeadSpace(img, q, aw, ah, x, y, w, h, box)
      end
      unclip()
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
      clip(Theme, x, y, w, h)
      -- 16x16 icon sheet: taller sheets stack frames, so the resting frame is
      -- the first 16 rows, drawn at the largest whole multiple that fits.
      local fh = ih >= 32 and 16 or math.min(16, ih)
      local q2 = quad(0, 0, math.min(16, iw), fh, iw, ih)
      local s = math.max(1, math.floor(math.min(w / 16, h / fh)))
      local dw, dh = 16 * s, fh * s
      love.graphics.draw(img, q2, math.floor(x + (w - dw) * 0.5),
        math.floor(y + (h - dh) * 0.5), 0, s, s)
      unclip()
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
    clip(Theme, x, y, w, h)
    love.graphics.draw(img, quad(0, 0, iw, ih, iw, ih),
      math.floor(x + (w - dw) * 0.5), y, 0, s, s)
    unclip()
    return true
  end

  return P
end
