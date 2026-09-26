-- ui/portraits.lua -- portrait art for a party row.
--
-- Two presentations, picked by the PARTY PORTRAITS option:
--   "sprites" -- the head space of the pack's FRONT battle sheet for the
--                species (assets/front/<STEM>.png): the card's own 56x34
--                window of the frame, anchored to the creature's head and
--                drawn at the pack's OWN 1:1 pixels.  A creature bigger than
--                the card is CROPPED to it (its head fills the band), never
--                scaled down, so no species is resampled and every species
--                keeps the size the pack gives it.  A frame whose top is a big
--                head DECORATION (Kingambit's blade, Sirfetchd's leek) starts
--                the window below it -- measured from the art by the sprites
--                mod, never a species list -- so the face shows, while a
--                genuinely TALL creature (whose head is its top) is untouched.
--                See drawHeadSpace.
--   "icons"   -- the pack's own party-ICON art at its REAL size: the HD cells
--                (assets/icons/party_icons_hd.png, the pack's 64x64
--                true-colour frames) at their own 1:1 pixels, cropped to the
--                card and anchored to the creature exactly as the front sheets
--                are (see drawHeadSpace).  The 16x16 atlas is a 4:1
--                point-sampled copy of those same frames, so drawing IT --
--                even scaled up to fill the card -- showed every party icon at
--                half the pack's own pixel scale and read as shrunken; an
--                older copy of the sprites mod with no HD cell still gets that
--                atlas, fitted.
--
-- ICON portraits are STILLS: the portrait always shows the icon's RESTING frame
-- (frame 0), asked for explicitly through the sprites mod's export so the card
-- cannot inherit that mod's own icon animation either.  A PORTRAIT ANIMATION
-- row (3.3.0/3.3.1) was removed in 3.3.2 -- there is no animation option.
--
-- The art itself comes from g9-battle-sprites when it is installed: it owns
-- the pack's true-colour frames, and two always-on exports hand them over --
-- `frontArt(mon)` -> the baked, frame-1-trimmed front frame as a standalone
-- Image (plus its content box, which tells this apart from an older copy's
-- whole-animation trim), and
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
--
-- BOTH generations use these two presentations.  On a Gold boot the pack's
-- front sheet and its icon atlas answer for a Gold species exactly as they do
-- for a Gen 1 one, so a card shows the pack's battle art there too; only the
-- ENGINE's fallback (a species the pack has no sheet for, or no sprites mod at
-- all) differs, because Gold has no Gen 1 front-pic table to read -- it uses
-- Gold's own party icon, an honest picture rather than a "?".
return function(mod)
  local P = {}
  local Assets = require("src.render.Assets")
  local Sprites = require("src.pokemon.Sprites")

  -- The "head space" window is the card's own 56x34 of the frame, drawn at the
  -- pack's OWN pixels.  The pack's sheets are trimmed per species, so a sheet's
  -- size IS that species' size in the pack: a Weedle is a Weedle beside an
  -- Amoonguss, and every creature is drawn 1:1 -- the same natural size the
  -- battle screen draws and the one scale that resamples nothing at all.  A
  -- creature BIGGER than the card is CROPPED to it (its head fills the band),
  -- never scaled down: stepping a big frame down 1:2, 1:3, ... threw away the
  -- pack's detail and left half the card empty -- the shrunken look the user
  -- asked to remove (a very WIDE creature was the worst case, because a width
  -- heavier than twice the card forced a second step that shrank the HEIGHT
  -- too, leaving a small sprite in a big band).  HEAD_TOP is only the fallback
  -- for a frame whose creature box cannot be read (an older sprites mod, whose
  -- export trims to the whole animation's travel instead of the frame): 8% down,
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
  -- got table)".  The Gen 2 portraits then resolved through the icon export,
  -- so that was the Gen 2 START crash.
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
  -- BEST EFFORT, and in practice always nil on the engine this mod runs on: it
  -- asks the Image for its pixels through `Image:newImageData`, which LÖVE 11.5
  -- does not implement (the readback API was removed after 0.10 -- see
  -- wrap_Image.cpp in 11.5, which registers only isFormatLinear, isCompressed
  -- and replacePixels).  It is kept because it costs one pcall per image and it
  -- IS the exact answer on any engine that allows the readback: the sprites
  -- mod's CURRENT frontArt trims to frame 1 and hands back the box directly
  -- (which is why this is only a fallback now), but an OLDER copy trims to the
  -- whole animation's union box, and then that frame can sit inside it with
  -- spare rows above its head -- anchoring the crop to the image's own top
  -- would leave that gap under the card's top edge, and a fixed left/right
  -- centre would frame the animation's travel instead of the creature.
  -- Scanned once per image -- a frame is at most ~150px a side -- and cached
  -- beside the art.  nil when the pixels cannot be read, and the caller falls
  -- back to the frame's own top (see drawHeadSpace).
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
  -- set once when a peer's frontArt answers no content box, i.e. an older copy
  -- whose portrait trim covers the whole animation (see packFront)
  local frontTrimTold = false
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
  -- `frame` (0-based) is always passed as 0: the pack's resting frame, so the
  -- portrait is a STILL whatever the sprites mod's own icon clock is doing (an
  -- older copy ignores the argument and keeps answering its live frame).  The
  -- export answers that frame's quad AND its content box.
  local function packArt(mon, frame)
    local ex = peerEx()
    if type(ex) ~= "table" then return nil end
    local fn = ex.iconArtHD or ex.iconArt
    if type(fn) ~= "function" then return nil end
    local ok, q, img, cell, box = pcall(fn, mon, frame)
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
  -- baked (off the draw path, by that mod's core.update hook) into a standalone
  -- Image of its FIRST FRAME, trimmed to that frame's own content.  So the
  -- image's top edge IS the creature's top edge, and the card can anchor
  -- straight to it.  Answers (image, w, h, box, head) once it is ready -- the
  -- first call starts the bake and answers `nil, pending` -- and nil, or a copy
  -- of the mod without the export, falls through to the HD icon cell below.
  -- A copy older than 3.1.2 answers no `box` and trims to the whole animation's
  -- travel instead, so frame 1 can sit below the image's top; the caller then
  -- reads the frame's own pixels back (see contentBox) or takes the old
  -- best-effort anchor, and says so once in the log.
  -- `pending` says a real sheet is ON ITS WAY, so the caller must not fall back
  -- to the engine's own art for those frames: that would flash native art
  -- exactly where the pack's art is about to appear.
  -- `head` (a copy 3.5.1+) is the height, in the image's own rows, of a leading
  -- head DECORATION in the frame -- Kingambit's blade, Sirfetchd's leek,
  -- Aegislash's hilt -- measured from the art by that mod (never a species
  -- list), so the card can start its window BELOW it and show the face.  A
  -- genuinely tall creature's head reaches a real share of its width within a
  -- few rows, so it answers 0 and nothing moves.
  local function packFront(mon)
    local ex = peerEx()
    if type(ex) ~= "table" then return nil end
    local fn = ex.frontArt
    if type(fn) ~= "function" then return nil end
    -- getFrames' SECOND value is `pending`, so keep the whole result: a
    -- `local ok, img = pcall(...)` would silently drop it.
    local res = { pcall(fn, mon) }
    if not res[1] then return nil end
    local img, w, h, box = res[2], res[3], res[4], res[5]
    -- A ready answer is (image, w, h, box, head) -- the head is the FIFTH value.
    -- A "still baking" answer is a TWO-value (nil, pending), so on that path
    -- `res[3]` (not res[6]) carries `pending`; the two shapes never mix, which
    -- is why the box/head read below cannot pick up a stray flag.
    if not img then return nil, nil, nil, nil, res[3] and true or false end
    -- `head` (a copy 3.5.1+): the height, in the image's own rows, of a leading
    -- head DECORATION -- Kingambit's blade, Sirfetchd's leek, Aegislash's hilt
    -- (see drawHeadSpace).  0, or an older copy with no such value, leaves the
    -- window anchored to the creature's top.
    local head = tonumber(res[6]) or 0
    if head < 0 then head = 0 end
    if type(img.getDimensions) ~= "function" then return nil end
    if type(w) ~= "number" or type(h) ~= "number" or w <= 0 or h <= 0 then
      w, h = img:getDimensions()
    end
    if not w or not h or w <= 0 or h <= 0 then return nil end
    -- only trust a box that actually describes this frame
    if type(box) ~= "table" or type(box.x) ~= "number"
      or type(box.y) ~= "number" or type(box.w) ~= "number"
      or type(box.h) ~= "number" then box = nil end
    -- A copy of the sprites mod older than 3.1.2 trims its portrait to the WHOLE
    -- animation's travel rather than to frame 1, so frame 1 can sit dozens of
    -- rows below the image's top and the card crops blank space for a big sheet
    -- (the bug this fourth value exists to avoid).  Say so once, and keep the
    -- old best-effort anchor (see drawHeadSpace).
    if not box and not frontTrimTold then
      frontTrimTold = true
      local handle = mod.find and mod.find("g9-battle-sprites") or nil
      if mod.log and mod.log.info then
        mod.log:info("g9-battle-sprites %s trims party portraits to the whole "
          .. "animation instead of to frame 1 -- a big sprite's portrait can "
          .. "crop blank rows (update it to 3.1.2+, keeping your downloaded "
          .. "assets/front sheets)", tostring(handle and handle.version))
      end
    end
    return img, w, h, box, false, head
  end

  -- The pack's SMALL 16x16 party-ICON atlas, through the always-on `iconArt16`
  -- export: (image, quad, cellW, cellH) for the mon's icon cell, or nil.
  -- `frame` is always passed as 0 (the resting frame, the same contract as
  -- packArt's); an older copy ignores it and keeps answering the live frame.
  local function packIcon(mon, frame)
    local ex = peerEx()
    if type(ex) ~= "table" then return nil end
    local fn = ex.iconArt16
    if type(fn) ~= "function" then return nil end
    local ok, q, img, cell = pcall(fn, mon, frame)
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

  -- Draw the HEAD SPACE of a frame into the card: the card's own w x h window of
  -- the image, anchored to the CREATURE (its opaque-pixel box, `box`) -- the head
  -- at the card's top edge, centred across the creature -- and drawn at 1:1.
  --
  -- The pack's sheets are trimmed per species, so a sheet's size IS that
  -- species' size in the pack, and every creature keeps it.  A creature wider or
  -- taller than the card is NOT shrunk to fit: the window simply stops at the
  -- card and the creature is CROPPED -- a Wailord is 87px wide against a 56px
  -- card and reads perfectly as a centred 56px window of itself, and a 92x95
  -- Mega Dragonite shows the top 34 rows, its head, at the pack's own pixels.
  -- Fitting the frame to the card instead (drawFit, or the pre-3.8.0 whole
  -- divisor) resamples the art and draws every species at the same on-screen
  -- size -- a Weedle as large as an Onix -- which is exactly the "wrong size"
  -- look, and the needless quality loss, the user asked to remove.
  --
  -- `box` is the CREATURE's box.  Without one -- an older sprites mod, whose
  -- frontArt trims to the whole animation's travel rather than to frame 1 -- the
  -- window falls back to the frame's own top, HEAD_TOP down, centred on the
  -- frame, at its own pixels, which is what it always did.
  --
  -- `head` (see packFront) slides the window DOWN by that many rows of the
  -- creature, so a frame whose top is a big head DECORATION -- Kingambit's
  -- blade, Sirfetchd's leek, Aegislash's hilt -- shows the face instead of the
  -- decoration.  It is clamped to the creature's own box, so a bogus value can
  -- never push the window off the art, and 0 is exactly the old behaviour.
  local function drawHeadSpace(img, q, aw, ah, x, y, w, h, box, head)
    if box and box.w and box.h and box.w > 0 and box.h > 0 then
      local cx, cy, cw, ch = box.x or 0, box.y or 0, box.w, box.h
      -- the card's window of the creature, in ITS pixels: never wider or taller
      -- than the card, starting at the creature's own top row so the head is
      -- flush with the card's top edge, and centred across the creature (a
      -- creature smaller than the card is drawn whole, at its own size)
      local winW = math.min(cw, w)
      -- a head decoration pushes the window down the creature, never past its
      -- last row (the whole window then shows the crop below the decoration)
      local shift = tonumber(head) or 0
      if shift > ch - 1 then shift = ch - 1 end
      if shift < 0 then shift = 0 end
      local winH = math.min(ch - shift, h)
      local winX = math.floor(cx + (cw - winW) * 0.5)
      local winY = cy + shift
      if winX < 0 then winX = 0 end
      if winY < 0 then winY = 0 end
      if winX + winW > aw then winX = aw - winW end
      if winY + winH > ah then winH = ah - winY end
      if winW <= 0 or winH <= 0 then return end
      -- a sub-quad of the frame (or of the atlas cell), so the crop costs no
      -- extra atlas work; the incoming quad is kept when the window IS the
      -- whole frame, which matters when it carries an atlas cell's viewport
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
      -- at the pack's own pixels -- no scale at all -- centred across the card
      -- and flush with its top edge, so the creature's first row IS the card's
      -- first row
      love.graphics.draw(img, q, math.floor(x + (w - winW) * 0.5), y)
      return
    end
    -- no readable box: best effort, exactly as before
    local winW = math.min(aw, w)
    local winH = math.min(ah, h)
    local winX = math.floor((aw - winW) * 0.5)
    local winY = math.floor(ah * HEAD_TOP)
    -- keep the fallback window inside the frame
    local maxX, maxY = aw - winW, ah - winH
    if winX > maxX then winX = maxX end
    if winY > maxY then winY = maxY end
    if winX < 0 then winX = 0 end
    if winY < 0 then winY = 0 end
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
    love.graphics.draw(img, q,
      math.floor(x + (w - winW) * 0.5), math.floor(y + (h - winH) * 0.5))
  end

  -- The whole frame, fitted into the card: snapped to a whole multiple when the
  -- frame is small enough and to a clean 1:2 decimation when it is larger than
  -- the card (a point-sampled halving keeps the pixel edges hard -- no
  -- interpolation).  This is the FALLBACK for the ICON presentation now --
  -- reached only when the pack offers no HD party cell to draw at real size
  -- (see P.draw) -- and the whole cell only ever shows the creature at the small
  -- atlas's own scale (the 4:1 downsample), which is exactly what the real-size
  -- HD path exists to avoid.
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

  -- Draw the whole frame at the creature's REAL size: the pack's own pixels,
  -- 1:1, centred in the panel -- stepping DOWN by a whole integer divisor only
  -- when the frame is larger than the panel.  Never zoomed UP.  Fitting the
  -- frame to the panel (what this used to do) draws every creature at the same
  -- on-screen size whatever the pack gives it -- a Weedle as large as an Onix,
  -- a 40-pixel frame blown up into 120 -- which is exactly the "wrong size"
  -- look the pack's own 1:1 battle screen never has.  Same rule as the roster
  -- cards: one species, one size.
  local function drawReal(img, q, aw, ah, x, y, w, h)
    local d = 1
    if aw > w or ah > h then
      d = math.max(1, math.ceil(math.max(aw / w, ah / h)))
    end
    local s = 1 / d
    local dw, dh = aw * s, ah * s
    love.graphics.draw(img, q, math.floor(x + (w - dw) * 0.5),
      math.floor(y + (h - dh) * 0.5), 0, s, s)
  end

  -- Fit a frame into the box (x,y,w,h): scaled up or down as needed, aspect
  -- kept, centred.  The GRID's icon cells use this where the big portraits use
  -- drawReal's one-species-one-size rule -- a slot is a fixed little window and
  -- the creature in it has to be READ, so the art fills the window instead of
  -- being stepped down a whole divisor and left a quarter of the slot.  The
  -- caller crops the pack's transparent cell margins away first (see
  -- croppedArt), so what fills the window is the creature, not its padding.
  local function drawFit(img, q, aw, ah, x, y, w, h)
    if not (aw > 0 and ah > 0 and w > 0 and h > 0) then return end
    local s = math.min(w / aw, h / ah)
    local dw, dh = aw * s, ah * s
    love.graphics.draw(img, q, math.floor(x + (w - dw) * 0.5),
      math.floor(y + (h - dh) * 0.5), 0, s, s)
  end

  -- A pack frame cropped to its own opaque-pixel box, as (quad, w, h).  A pack
  -- cell is 64x64 with the creature floating inside it, so fitting the WHOLE
  -- cell only fits its transparent margins; the box is the creature itself.
  -- Falls back to the uncropped cell when the export answered no usable box
  -- (an older copy of the sprites mod) or the box does not describe the cell.
  local function croppedArt(img, q, cw, ch, box)
    if type(box) ~= "table" or type(box.x) ~= "number"
        or type(box.y) ~= "number" or type(box.w) ~= "number"
        or type(box.h) ~= "number" or box.w <= 0 or box.h <= 0 then
      return q, cw, ch
    end
    local ok, qx, qy, qw, qh = pcall(q.getViewport, q)
    if not ok or type(qx) ~= "number" then return q, cw, ch end
    if box.x < 0 or box.y < 0
        or box.x + box.w > (qw or cw) + 0.5
        or box.y + box.h > (qh or ch) + 0.5 then
      return q, cw, ch
    end
    local iw, ih = img:getDimensions()
    local ok2, q2 = pcall(love.graphics.newQuad,
      qx + box.x, qy + box.y, box.w, box.h, iw, ih)
    if not ok2 or not q2 then return q, cw, ch end
    return q2, box.w, box.h
  end

  -- Draw into the card body (x,y,w,h).  `Theme` is the shared theme, used for
  -- the no-art placeholder.  `mode` picks the portrait source ("sprites" or
  -- "icons").  Both presentations are STILLS: the "sprites" source is a single
  -- front frame, and the icon source is the pack's resting frame (asked for as
  -- frame 0, see below).  Returns true when art was drawn.
  function P.draw(Theme, game, mon, x, y, w, h, mode)
    local icons = (mode == "icons")
    -- The ONE frame this draw shows.  The pack and the game's own icon sheets
    -- carry two frames per icon, so 0 -- the resting frame -- is asked for
    -- explicitly: that keeps the card a still even when the sprites mod's own
    -- icon clock is animating.  Only the icons branch reads it; the front-sheet
    -- source has no frames.
    local frame = 0
    -- Which boot this is.  Gold has no Gen 1 front-pic table for
    -- src.pokemon.Sprites.path to read (it keys off def.spriteFront), so the
    -- ENGINE's own art under "sprites" is Gold's party ICON (step 3) -- but the
    -- PACK's own art is asked for first on either boot, and its front sheets
    -- answer for Gold species exactly as they do for Gen 1, so a card shows the
    -- battle sprite on both generations and only a species the pack has no
    -- sheet for reaches the engine's fallback.
    local gen2 = (game and game.data and game.data.gen2Icons) and true or false
    -- set when the pack's front sheet for this mon is still baking, so the
    -- game's own art is NOT flashed on the frame before the pack art lands
    local pending = false

    -- 1. the pack's own art (g9-battle-sprites), source picked by the mode:
    --    "sprites" = the FRONT battle sheet's head space, "icons" = the pack's
    --    own HD party cell at its own 1:1 pixels.
    if icons then
      -- The ICON presentation is the pack's own party-icon art at its REAL
      -- size, not the 16x16 atlas fitted into the card.  The 16x16 atlas
      -- (assets/icons/party_icons.png) is a 4:1 point-sampled copy of the pack's
      -- 64x64 frames, so drawing IT -- even scaled up to the card's largest
      -- whole multiple -- showed the creature at HALF the pack's pixel scale
      -- and read as shrunken in the 56x34 card (every other caller of the
      -- pack's art here draws it 1:1).  iconArtHD hands over the true-colour
      -- 64x64 cell AND its opaque-pixel box, so the icon is cropped to the card
      -- through exactly the front sheet's head rule below: anchored to the
      -- creature, whole-integer steps only, never resampled.  The cells' own
      -- content is ~40-60px against a 34px card, so in practice the window is
      -- the card's own 56x34 at 1:1 -- the whole icon, at its natural size.
      -- A fully-opaque cell answers no box (there is no box to speak of); the
      -- whole cell IS the creature then, so the cell itself is the box.
      local himg, hq, haw, hah, hbox = packArt(mon, frame)
      if himg then
        local box = hbox or { x = 0, y = 0, w = haw, h = hah }
        Theme.set(Theme.col.white)
        clip(Theme, x, y, w, h)
        drawHeadSpace(himg, hq, haw, hah, x, y, w, h, box)
        unclip()
        return true
      end
      -- no HD cell at all (an older copy of the sprites mod): the 16x16 atlas,
      -- fitted into the card, which is all that copy can offer
      local img, q, cw, ch = packIcon(mon, frame)
      if img then
        Theme.set(Theme.col.white)
        clip(Theme, x, y, w, h)
        drawWhole(img, q, cw, ch, x, y, w, h)
        unclip()
        return true
      end
    else
      -- packFront answers (image, w, h, BOX, HEAD): the box is the fourth
      -- value, not the fifth (see packFront)
      local img, aw, ah, fbox, wait, head = packFront(mon)
      pending = wait or false
      if img then
        Theme.set(Theme.col.white)
        clip(Theme, x, y, w, h)
        -- The export answers the frame ALREADY TRIMMED to its own content (the
        -- fourth value), so the image's top row is the creature's top row and
        -- the head rule can anchor straight to it -- and scale a big creature
        -- down until its head fits the card, instead of filling the card with
        -- the first 34 rows of it (see drawHeadSpace).  An older copy of the
        -- sprites mod answers no box, and trims to the whole animation's travel
        -- instead: read frame 1's own pixels back where the engine allows it
        -- (LÖVE 11.5 does not -- see contentBox), else take the old
        -- best-effort anchor, which is what the card always did.  `head` (see
        -- packFront) starts the window below a big head decoration.
        local box = fbox or contentBox(img)
        local q = quad(0, 0, aw, ah, aw, ah)
        drawHeadSpace(img, q, aw, ah, x, y, w, h, box, head)
        unclip()
        return true
      end
    end

    -- 2. the pack's HD icon cell (an older sprites mod without frontArt /
    --    iconArt16): the 64x64 true-colour party cell, cropped or fitted.
    local img, q, aw, ah, box = packArt(mon, frame)
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

    -- 3. the engine's own art (Gold, with no pack sheet for this species, has
    --    no front pic to read, so its icon is the honest picture either way)
    if icons or gen2 then
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
      -- 16x16 icon sheet: taller sheets STACK their frames, so a still card
      -- holds the first one (row 0).  Drawn at the largest whole multiple that
      -- fits.
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

  -- Draw the pack's FRONT art WHOLE -- not a head crop -- into (x, y, w, h).
  -- A PC mon panel is not a portrait card: it shows the creature entire, the way
  -- the engine's own picFor draws it, so it wants the pack's whole frame rather
  -- than drawHeadSpace's head window.  Same source as everything else here (the
  -- peer's always-on frontArt), so an egg lands on its own single picture too.
  -- Drawn at the creature's REAL size (1:1, stepped down by an integer divisor
  -- only when the frame outgrows the panel) -- see drawReal.  Answers false (no
  -- error) when the peer is missing, has nothing for this mon, or is still
  -- baking its first frame, so the caller can fall back to the game's own art.
  function P.drawFront(Theme, game, mon, x, y, w, h)
    local img, aw, ah = packFront(mon)
    if not img then return false end
    Theme.set(Theme.col.white)
    clip(Theme, x, y, w, h)
    drawReal(img, quad(0, 0, aw, ah, aw, ah), aw, ah, x, y, w, h)
    unclip()
    return true
  end

  -- Draw a mon's MINI-ICON into a cell -- the modern PC's grid art.
  --
  -- The source is the pack's own party-ICON cells (assets/icons/party_icons_hd.png,
  -- the 64x64 true-colour frames), NOT the battle front sheet: a grid cell wants
  -- the little creature the party list shows, not a head crop of a portrait.
  -- Drawn at the creature's REAL size -- the whole cell at 1:1 when the cell can
  -- hold the pack's 64px frame, else one WHOLE divisor down -- so two species
  -- keep their relative sizes and no icon is resampled by a fraction (the same
  -- rule drawReal enforces for the portraits).  `frame` is 0: the resting frame,
  -- asked for explicitly, so a cell is a STILL whatever the sprites mod's own
  -- icon clock is doing.
  --
  -- Falls back the same way every other caller here does: the pack's 16x16
  -- atlas at a whole multiple (an older copy of the sprites mod, whose HD atlas
  -- may be missing), then the engine's own icon sheet, and finally false, so the
  -- caller can draw the suite's lozenge rather than an empty slot.
  function P.drawIcon(Theme, game, mon, x, y, w, h)
    if type(mon) ~= "table" then return false end
    local frame = 0
    -- 1. the pack's HD icon cell (the pack's natural 64x64 frames)
    local img, q, cw, ch, box = packArt(mon, frame)
    if img then
      Theme.set(Theme.col.white)
      clip(Theme, x, y, w, h)
      local aq, aw, ah = croppedArt(img, q, cw, ch, box)
      drawFit(img, aq, aw, ah, x, y, w, h)
      unclip()
      return true
    end
    -- 2. the pack's 16x16 atlas cell, at the largest whole multiple that fits
    --    (a 4:1 point-sampled copy of the HD cell above)
    local i2, q2, c2w, c2h = packIcon(mon, frame)
    if i2 and c2w > 0 and c2h > 0 then
      local m = math.max(1, math.floor(math.min(w / c2w, h / c2h)))
      local dw, dh = c2w * m, c2h * m
      Theme.set(Theme.col.white)
      clip(Theme, x, y, w, h)
      love.graphics.draw(i2, q2, math.floor(x + (w - dw) * 0.5),
        math.floor(y + (h - dh) * 0.5), 0, m, m)
      unclip()
      return true
    end
    -- 3. the game's own icon sheet (the engine path the whole suite falls back
    --    to when g9-battle-sprites is absent, or has nothing for this mon)
    local _, path = iconSpec(game, mon)
    local i3 = load(path)
    if not i3 then return false end
    local iw, ih = i3:getDimensions()
    local fh = ih >= 32 and 16 or math.min(16, ih)
    local fw = math.min(16, iw)
    if fw <= 0 or fh <= 0 then return false end
    local m = math.max(1, math.floor(math.min(w / fw, h / fh)))
    local dw, dh = fw * m, fh * m
    Theme.set(Theme.col.white)
    clip(Theme, x, y, w, h)
    love.graphics.draw(i3, quad(0, 0, fw, fh, iw, ih),
      math.floor(x + (w - dw) * 0.5), math.floor(y + (h - dh) * 0.5), 0, m, m)
    unclip()
    return true
  end

  return P
end
