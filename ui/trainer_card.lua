-- ui/trainer_card.lua -- the trainer card (the player-name START row).
--
-- A VIEW takeover of src.ui.TrainerCard.  The engine's object stays on the
-- stack, so any button still dismisses it back to the START menu through its
-- own update; the player picture it already loaded (Sprites.playerPath, with
-- the true-colour flag a mod's player.sprite hook can set) is reused rather
-- than loaded again.  Only the drawing and the surface change: the classic
-- card is two 8-tile banded boxes on the 160x144 screen, this is the same
-- 540x360 page as the rest of the suite -- a portrait panel, the trainer's
-- figures, and one pip per badge.
return function(mod, ctx)
  local Theme, Backdrop, Shell, Portraits = ctx.Theme, ctx.Backdrop, ctx.Shell,
    ctx.Portraits
  local opt = ctx.opt

  local M = {}
  local Builtin = require("src.ui.TrainerCard")
  local Strings = require("src.core.Strings")

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
    -- the badge pips sit under the figures, one per Kanto badge
    local py2 = y + 26
    for i = 1, total do
      local cx = fx + 14 + (i - 1) * 34
      if badgeOwned(game, Badges, badges and badges[i]) then
        Theme.set(C.gold)
        love.graphics.circle("fill", cx, py2 + 12, 11)
        Theme.text(tostring(i), cx, py2 + 4, F.small, "center", C.void)
      else
        Theme.set(C.border)
        love.graphics.circle("line", cx, py2 + 12, 11)
        Theme.text(tostring(i), cx, py2 + 4, F.small, "center", C.inkFaint)
      end
    end

    Shell.footer(Theme, game, {
      hints = {
        { key = "A", text = "CLOSE" },
        { key = "B", text = "BACK" },
      },
    })

    Theme.set(C.white)
  end

  return M
end
