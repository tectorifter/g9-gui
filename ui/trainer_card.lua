-- ui/trainer_card.lua -- the trainer card (the player-name START row).
--
-- A VIEW takeover of src.ui.TrainerCard.  The engine's object stays on the
-- stack, so any button still dismisses it back to the START menu through its
-- own update; the player picture it already loaded (Sprites.playerPath, with
-- the true-colour flag a mod's player.sprite hook can set) is reused rather
-- than loaded again.  Only the drawing and the surface change: the classic
-- card is two 8-tile banded boxes on the 160x144 screen, this is the same
-- 540x360 page as the rest of the suite -- a portrait panel, the trainer's
-- figures, and one slot per badge drawn with the game's OWN badge tiles.
return function(mod, ctx)
  local Theme, Backdrop, Shell, Portraits = ctx.Theme, ctx.Backdrop, ctx.Shell,
    ctx.Portraits
  local opt = ctx.opt

  local M = {}
  local Builtin = require("src.ui.TrainerCard")
  local Strings = require("src.core.Strings")
  local Assets = require("src.render.Assets")

  -- Gold arm: the Gen 2 module is required LAZILY (see ui/options.lua) so the
  -- Gen 1 boot never pulls a Gold screen in and vice versa.
  local Gen2 = ctx.gen == 2
  local G2Builtin
  local function builtin2()
    G2Builtin = G2Builtin or require("src.ui.gen2.TrainerCard")
    return G2Builtin
  end

  -- The badge slot art: the engine's own trainer-card tile sheet
  -- (assets/generated/trainer_card/badges.png -- DrawBadges FaceBadgeTiles).
  -- It is 8 stacked [gym-leader face, badge] pairs, so the BADGE tile is the
  -- second 16x16 row of each 32px pair.  Loaded lazily and cached; if the
  -- sheet is not extracted (a runtime with no ROM import) the slots fall back
  -- to an empty well + ring.  Assets.image goes through Assets.resolve, so an
  -- enabled mod's overrides/ shadows these tiles like every other asset.
  local sheet = { done = false }
  local function badgeSheet()
    if not sheet.done then
      sheet.done = true
      local ok, img = pcall(Assets.image,
        "assets/generated/trainer_card/badges.png")
      if ok and img and img.getDimensions then
        local quads = {}
        local iw, ih = img:getDimensions()
        for i = 1, 8 do
          local y = (i - 1) * 32 + 16
          if y + 16 <= ih then
            quads[i] = love.graphics.newQuad(0, y, 16, 16, iw, ih)
          end
        end
        sheet.img, sheet.quads = img, quads
      end
    end
    return sheet.img, sheet.quads
  end
  -- forget the loaded tiles when the engine flushes its asset caches (dev hot
  -- reload, or a mod's sprite swap landing) -- the hook portraits.lua uses
  if Assets.register then
    Assets.register(function() sheet = { done = false } end)
  end

  local W, H = Shell.W, Shell.H
  local MARGIN = Shell.MARGIN

  function M.uiSize() return W, H end
  M.isWideBattleLayout = Shell.wide
  function M.wantsFillScale(self) return Shell.wide(self) end
  function M.sgbPalettes() return {} end

  function M.decorate(self)
    if type(self) ~= "table" then return self end
    self.__g9gui = true
    self.isOpaque = true
    self.letterboxWhite = true
    self.__t = 0
    self.uiSize = M.uiSize
    self.isWideBattleLayout = M.isWideBattleLayout
    self.wantsFillScale = M.wantsFillScale
    self.sgbPalettes = M.sgbPalettes
    local baseUpdate = self.update
    self.update = function(s, dt)
      s.__t = (s.__t or 0) + 1
      baseUpdate(s, dt)
    end
    self.draw = function(s) M.draw(s) end
    return self
  end

  function M.new(game, opts)
    if Gen2 then
      return M.decorateGen2(builtin2().new(game, opts))
    end
    return M.decorate(Builtin.new(game, opts))
  end

  -- ---------------------------------------------------------------- helpers
  local function badgeList(game)
    local ok, Badges = pcall(require, "src.inventory.Badges")
    if not (ok and type(Badges) == "table" and Badges.list) then return nil end
    local ok2, list = pcall(Badges.list, game.data)
    if not (ok2 and type(list) == "table") then return nil end
    return list, Badges
  end

  local function badgeOwned(game, Badges, name)
    if not (Badges and Badges.itemFor) then return false end
    local ok, item = pcall(Badges.itemFor, name)
    if not ok or not item then return false end
    local inv = game.save and game.save.inventory
    return (inv and inv[item]) and true or false
  end

  -- a figure row inside the card
  local function figure(Theme, game, F, x, y, w, label, value, valueColor)
    Theme.text(label, x, y, F.small, "left", Theme.col.inkFaint)
    Theme.text(Theme.fit(value, F.bold, w), x + w, y - 3, F.bold, "right",
      valueColor or Theme.col.ink)
  end

  -- ------------------------------------------------------------------- draw
  function M.draw(self)
    local game = self.game
    local C = Theme.col
    local F = Theme.fonts(game)
    local save = game.save or {}
    local background = opt("ui_background") ~= "false"
    local embellish = opt("ui_embellishment") ~= "false"

    Backdrop.draw(Theme, { w = W, h = H, t = self.__t or 0,
      background = background, embellishment = embellish })

    local t = math.floor(save.playTime or 0)
    local time = ("%d:%02d"):format(math.floor(t / 3600), math.floor(t / 60) % 60)
    local badges, Badges = badgeList(game)
    local total = badges and #badges or 8

    Shell.top(Theme, game, {
      title = Strings("TRAINER CARD"),
      right = ("ID %05d"):format(save.player and save.player.id or 0),
      caption = "Your trainer profile.",
      embellish = embellish,
    })

    -- portrait panel (the engine already loaded the picture in new())
    local px, py, pw, ph = MARGIN, Shell.CONTENT_Y, 150, 168
    Theme.panel(px, py, pw, ph, { radius = 6, shadow = 2 })
    Theme.set(C.panelDeep)
    Theme.rect("fill", px + 6, py + 6, pw - 12, ph - 12, 5)
    if self.pic then
      local iw = self.picW or (self.pic.getWidth and self.pic:getWidth()) or 40
      local ih = self.picH or (self.pic.getHeight and self.pic:getHeight()) or 56
      local scale = math.min((pw - 24) / iw, (ph - 24) / ih)
      Theme.set(C.white)
      love.graphics.draw(self.pic, px + (pw - iw * scale) * 0.5,
        py + (ph - ih * scale) * 0.5, 0, scale, scale)
    else
      -- no picture available: a quiet silhouette so the panel never reads as
      -- an empty box
      Theme.set(C.cardDark)
      love.graphics.circle("fill", px + pw * 0.5, py + 62, 28)
      Theme.rect("fill", px + pw * 0.5 - 44, py + 96, 88, 62, 22)
    end

    -- figures
    local fx = px + pw + 24
    local fw = (W - MARGIN) - fx
    local owned = 0
    for i = 1, total do
      if badgeOwned(game, Badges, badges and badges[i]) then owned = owned + 1 end
    end
    local y = Shell.CONTENT_Y + 6
    local step = 34
    Theme.text(Strings("NAME"), fx, y, F.small, "left", C.inkFaint)
    Theme.text(Theme.fit(save.player and save.player.name or "RED", F.body,
      fw), fx, y + 14, F.body, "left", C.ink)
    y = y + step + 10
    figure(Theme, game, F, fx, y, fw, Strings("MONEY"),
      ("\xc2\xa5%d"):format(save.money or 0), C.gold)
    y = y + step
    figure(Theme, game, F, fx, y, fw, Strings("TIME"), time, C.ink)
    y = y + step
    figure(Theme, game, F, fx, y, fw, Strings("BADGES"),
      ("%d / %d"):format(owned, total), C.gold)
    -- the badge row: one slot per badge, each drawn with the game's OWN tile
    -- (scaled up so the emblem fills its circle) instead of a synthetic fill
    -- and number.  Earned badges show in their own colours behind a lit ring;
    -- unearned ones are the same tile knocked back to a ghost, so the row
    -- reads as a set of slots you are still filling.
    local img, quads = badgeSheet()
    local R = 15                       -- slot radius
    local scale = (R * 2) / 16         -- size the 16px tile to fill the slot
    -- the row spans the figures column exactly, flush with the labels on the
    -- left and the values on the right
    local pitch = total > 1 and ((fw - R * 2) / (total - 1)) or 0
    local cx0 = fx + R
    local cy = y + 38
    for i = 1, total do
      local cx = cx0 + (i - 1) * pitch
      local owned = badgeOwned(game, Badges, badges and badges[i])
      if owned then
        -- a warm halo so an earned badge sits in its own light
        Theme.set(C.gold, 0.16)
        love.graphics.circle("fill", cx, cy, R + 2)
      end
      -- the well: the pale surface the vanilla card prints the badge on, so
      -- the tile reads in its own colours (and a ghosted one still shows)
      Theme.set(C.card)
      love.graphics.circle("fill", cx, cy, R)
      local q = quads and quads[i]
      if img and q then
        if owned then Theme.set(C.white) else Theme.set(C.inkFaint, 0.62) end
        love.graphics.draw(img, q, cx - R, cy - R, 0, scale, scale)
      end
      -- ring: lit for an earned badge, quiet while it is still unearned
      Theme.set(owned and C.gold or C.border)
      love.graphics.circle("line", cx, cy, R + 0.5)
    end

    Shell.footer(Theme, game, {
      hints = {
        { key = "A", text = "CLOSE" },
        { key = "B", text = "BACK" },
      },
    })

    Theme.set(C.white)
  end

  -- ============================================================== Gen 2 (Gold)
  -- Gold's trainer card is THREE pages driven by the engine's own update
  -- (page 1 the card, 2 the Johto badge board, 3 the Kanto one) and it loads
  -- its art as TILE SHEETS rather than a picture.  The Gen 2 arm keeps that
  -- navigation and draws each page on the suite's surface: the card page is
  -- the same portrait + figures design as Gen 1 -- the portrait and the badges
  -- come straight from the engine's own sheets -- and the badge pages are the
  -- suite's own boards.
  local PORTRAIT_W, PORTRAIT_TILES = 5, 35
  local JOHTO_FALLBACK = { "ZEPHYR", "HIVE", "PLAIN", "FOG", "STORM",
    "MINERAL", "GLACIER", "RISING" }
  local KANTO_FALLBACK = { "BOULDER", "CASCADE", "THUNDER", "RAINBOW", "SOUL",
    "MARSH", "VOLCANO", "EARTH" }
  local BADGE_CELLS = { { 0, 0, 0 }, { 1, 0, 1 }, { 0, 1, 2 }, { 1, 1, 3 } }

  local function badgeNames()
    local B = builtin2()
    return (B and B.JOHTO_BADGES) or JOHTO_FALLBACK,
           (B and B.KANTO_BADGES) or KANTO_FALLBACK
  end

  -- A save keys a badge set by name or by position (the engine looks up both),
  -- so both spellings count as owned here.
  local function ownedAt(set, names, index)
    if type(set) ~= "table" then return false end
    return (set[index] or (names[index] and set[names[index]])) and true
      or false
  end

  function M.decorateGen2(self)
    if type(self) ~= "table" then return self end
    self.__g9gui = true
    self.isOpaque = true
    self.__t = 0
    Shell.gen2Surface(Theme, self, function(s) M.drawGen2(s) end)
    local baseUpdate = self.update
    self.update = function(s, dt)
      s.__t = (s.__t or 0) + 1
      if baseUpdate then baseUpdate(s, dt) end
    end
    return self
  end

  -- The 5x7 portrait out of the engine's card sheet, scaled to the panel.  The
  -- cart draws it at tile (14,1), and the sheet picks each tile's colours by
  -- its CELL, so the real coordinates are kept under a translate rather than
  -- drawing the block at the origin.
  local function drawPortrait2(Theme, self, px, py, pw, ph)
    if self.card and self.card.available and self.card:available() then
      local wide, high = PORTRAIT_W, math.floor(PORTRAIT_TILES / PORTRAIT_W)
      local s = math.min((pw - 24) / (wide * 8), (ph - 24) / (high * 8))
      local G = love.graphics
      G.push()
      G.translate(px + (pw - wide * 8 * s) * 0.5,
        py + (ph - high * 8 * s) * 0.5)
      G.scale(s, s)
      G.translate(-14 * 8, -1 * 8)
      for row = 0, high - 1 do
        for col = 0, wide - 1 do
          self.card:draw(row * wide + col, 14 + col, 1 + row)
        end
      end
      G.pop()
      return
    end
    local C = Theme.col
    Theme.set(C.cardDark)
    love.graphics.circle("fill", px + pw * 0.5, py + 62, 28)
    Theme.rect("fill", px + pw * 0.5 - 44, py + 96, 88, 62, 22)
  end

  -- One badge's 2x2 tiles at the current animation frame.  The OAM frame is
  -- the tile id (bit 7 is the x-flip Risingbadge turns on); nothing is drawn
  -- when the sheet is not extracted, so the caller falls back to its well.
  local function drawBadgeSprite(self, obj, cx, cy, scale)
    local sheet = self.badges
    if not (sheet and sheet.draw and obj and obj.frames) then return false end
    local frame = math.floor((self.frames or 0) / 8) % 8
    local tile = obj.frames[frame + 1]
    if tile == nil then return false end
    local flip = tile >= 0x80
    local base = flip and (tile - 0x80) or tile
    local G = love.graphics
    G.push()
    G.translate(cx - 8 * scale, cy - 8 * scale)
    G.scale(scale, scale)
    for _, c in ipairs(BADGE_CELLS) do
      sheet:draw(base + c[3], flip and (1 - c[1]) or c[1], c[2])
    end
    G.pop()
    return true
  end

  -- One badge slot: the earned halo, the well, the sprite and the ring.
  local function badgeSlot(Theme, self, names, set, index, cx, cy, r, oam)
    local C = Theme.col
    local on = ownedAt(set, names, index)
    if on then
      Theme.set(C.gold, 0.16)
      love.graphics.circle("fill", cx, cy, r + 2)
    end
    Theme.set(C.card)
    love.graphics.circle("fill", cx, cy, r)
    if on and drawBadgeSprite(self, oam and oam[index], cx, cy,
        (r * 2) / 16) then
      -- the engine's own badge art
    elseif on then
      Theme.set(C.accentDim)
      love.graphics.circle("fill", cx, cy, r - 5)
    end
    Theme.set(on and C.gold or C.border)
    love.graphics.circle("line", cx, cy, r + 0.5)
  end

  function M.drawCard2(self)
    local game = self.game
    local C = Theme.col
    local F = Theme.fonts(game)
    local save = self.save or {}
    local player = save.player or {}
    local johto = badgeNames()
    local total = 8
    local pages = (self.pages and self:pages()) or 2

    Shell.top(Theme, game, {
      title = Strings("TRAINER CARD"),
      right = ("ID %05d"):format(player.id or 0),
      caption = "Your trainer profile.",
      embellish = opt("ui_embellishment") ~= "false",
    })

    local px, py, pw, ph = MARGIN, Shell.CONTENT_Y, 150, 168
    Theme.panel(px, py, pw, ph, { radius = 6, shadow = 2 })
    Theme.set(C.panelDeep)
    Theme.rect("fill", px + 6, py + 6, pw - 12, ph - 12, 5)
    drawPortrait2(Theme, self, px, py, pw, ph)

    local fx = px + pw + 24
    local fw = (W - MARGIN) - fx
    local time = save.playTime or {}
    -- the card page's own badge strip is the JOHTO eight, so its count is the
    -- Johto set too (the Kanto board is page 3, reachable with A / the arrows);
    -- this keeps the figure and the eight circles under it telling one story
    local owned = 0
    for _, has in pairs(player.badges or {}) do if has then owned = owned + 1 end end
    local y = Shell.CONTENT_Y + 6
    local step = 34
    Theme.text(Strings("NAME"), fx, y, F.small, "left", C.inkFaint)
    Theme.text(Theme.fit(player.name or "GOLD", F.body, fw), fx, y + 14,
      F.body, "left", C.ink)
    y = y + step + 10
    figure(Theme, game, F, fx, y, fw, Strings("MONEY"),
      ("\xc2\xa5%d"):format(player.money or 0), C.gold)
    y = y + step
    figure(Theme, game, F, fx, y, fw, Strings("TIME"),
      ("%d:%02d"):format(time.hours or 0, time.minutes or 0), C.ink)
    y = y + step
    figure(Theme, game, F, fx, y, fw, Strings("POK\xc3\xa9DEX"),
      ("%d"):format((self.caughtCount and self:caughtCount()) or 0), C.gold)
    y = y + step
    figure(Theme, game, F, fx, y, fw, Strings("BADGES"),
      ("%d / %d"):format(owned, total), C.gold)

    -- the badge row: the Johto eight, in the same well/ring slots as Gen 1
    local oam = self.gfx and self.gfx.badgeOam
    local R = 15
    local pitch = (fw - R * 2) / 7
    local cy = y + 38
    for i = 1, 8 do
      badgeSlot(Theme, self, johto, player.badges, i, fx + R + (i - 1) * pitch,
        cy, R, oam)
    end

    Shell.footer(Theme, game, {
      hints = {
        { key = "A", text = pages >= 3 and "PAGE" or "CLOSE" },
        { key = "B", text = "BACK" },
      },
    })
    Theme.set(C.white)
  end

  function M.drawBadges2(self, names, label, set)
    local game = self.game
    local C = Theme.col
    local F = Theme.fonts(game)
    local oam = self.gfx and self.gfx.badgeOam

    Shell.top(Theme, game, {
      title = Strings("TRAINER CARD"),
      right = Strings("BADGES"),
      caption = label,
      embellish = opt("ui_embellishment") ~= "false",
    })

    local x, y = MARGIN, Shell.CONTENT_Y
    local w, h = W - MARGIN * 2, (Shell.FOOT_RULE_Y - 8) - Shell.CONTENT_Y
    Theme.panel(x, y, w, h, { radius = 6, shadow = 2 })

    local cw = (w - 24) / 2
    local rh = (h - 24) / 4
    local R = 15
    for i = 1, 8 do
      local col = (i - 1) % 2
      local row = math.floor((i - 1) / 2)
      local cx = x + 12 + col * cw + 22
      local cy = y + 12 + row * rh + rh * 0.5
      badgeSlot(Theme, self, names, set, i, cx, cy, R, oam)
      Theme.text(Theme.fit(Strings(names[i]), F.body, cw - 70),
        x + 12 + col * cw + 46, cy - 8, F.body, "left",
        ownedAt(set, names, i) and C.ink or C.inkFaint)
    end

    Shell.footer(Theme, game, {
      hints = {
        { key = "\xe2\x86\x90\xe2\x86\x92", text = "PAGE" },
        { key = "A", text = "CLOSE" },
        { key = "B", text = "BACK" },
      },
    })
    Theme.set(C.white)
  end

  function M.drawGen2(self)
    local player = (self.save or {}).player or {}
    local johto, kanto = badgeNames()
    local page = self.page or 1
    if page == 1 then
      M.drawCard2(self)
    elseif page == 2 then
      M.drawBadges2(self, johto, Strings("JOHTO BADGES"), player.badges)
    else
      -- the Kanto board reads the real kantoBadges set; the cart's own page 3
      -- re-labels the JOHTO flags instead (its OAM table is the Johto one), so
      -- this is the one place the port reads the badges the page means
      M.drawBadges2(self, kanto, Strings("KANTO BADGES"),
        player.kantoBadges or player.badges)
    end
  end

  return M
end
