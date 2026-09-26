-- ui/color_protection.lua -- the COLOR PROTECTION row: keep the native
-- OPTIONS > GRAPHICS > COLORS display mode off this suite's own pages.
--
-- gen1recomp's COLORS row (Gen 1) and COLOR row (Gold) repaint the finished
-- frame through a 4-shade palette (src/render/PaletteFX.lua and
-- src/render/GbcPalette.lua).  This suite's pages are TRUE COLOUR -- Saira type
-- and a hand-picked palette -- so a mono / OG / CLASSIC ramp destroys them.
--
-- Every screen here already answers :sgbPalettes() with an EMPTY list, which
-- keeps the per-zone SGB shade-remap shader off a page, but two engine paths
-- still reach it:
--
--   * Gen 1's PaletteFX.ensureZones forces ONE whole-screen GRAYS zone for the
--     mono / OG / CLASSIC modes whenever the palette-owning state exposes no
--     zones (src/render/PaletteFX.lua:935), and the blit then shades the whole
--     UI canvas with it;
--   * Gold's CLASSIC present pass tints the WHOLE frame whatever the state
--     says, because Gold's colour is inside the picture and its present pass
--     has no per-state opt-out (src/core/Game2.lua:1595).
--
-- Both are decided through the one `render.zones` seam -- raised by Game:draw
-- on Gen 1 just before the blit (src/core/Game.lua:748) and by
-- Game2:drawViewportFrame on Gold (src/core/Game2.lua:1616).  So this module
-- wraps that seam: whenever the state that OWNS the palette this frame is one
-- of this suite's own pages, the zone list is replaced with ONE whole-screen
-- `colors = false` zone -- the engine's own true-colour opt-out, which blits
-- that region with the shader switched OFF.  The engine's real SGB zones are
-- consulted first (`next` runs the vanilla list), so the world and every
-- engine screen keep their native colourization untouched.  Gold computes a
-- zone list for the CLASSIC mode alone, so there the wrapper stands down when
-- the frame carries no tint at all -- GEN 2 / DMG frames are already the right
-- colour and must not be pushed down Game2's present-canvas path for nothing.
--
-- WHO OWNS THE PALETTE.  The rule is the engine's own.  Gen 1 takes the
-- topmost VISIBLE state that exposes :sgbPalettes (Game.lua:732's zoneOwner
-- walk); Gold takes its widescreen layer -- the stack's top when it paints one,
-- else the visible base (Game2:drawScene).  A screen is "ours" when it carries
-- the suite's own marker (`__g9gui`, plus the overlay markers the dressed
-- states use), or `__g9modern` -- the plain flag a sibling g9 mod sets on its
-- own modern screens (g9-evolutions' trade / inspector / trade-anim pages,
-- g9-Battle-Scene's scene) so ONE g9-gui toggle protects every modern UI, not
-- only the suite's.  The marker is read only here.  The non-opaque overlays -- the dialogue card, YES/NO and the
-- "How many?" box -- are drawn in WINDOW space by the render.hud hook, AFTER
-- the palette pass, so they already reach the screen unshaded and need no
-- entry here; the map a dialogue sits over therefore keeps its colour.
--
-- The row is read live, so flipping it in the Mod Manager takes effect on the
-- next frame.  With it OFF (or the hook API missing) the wrapper returns the
-- engine's own list, exactly as if this file were not installed.
return function(mod, ctx)
  local M = {}

  -- Gen 1's UI canvas can be WIDE (each page is 540x360), so its opt-out has
  -- to name a rect that covers the canvas; the blit clamps the rect to the
  -- viewport, so one generous rect covers any page size.  Gold maps its zone
  -- rects out of the 160x144 screen space onto the window, where 160x144 is
  -- the picture.
  local ZONE = (ctx.gen == 2)
    and { x = 0, y = 0, w = 160, h = 144, colors = false }
    or { x = 0, y = 0, w = 1e7, h = 1e7, colors = false }

  local function ours(state)
    return type(state) == "table"
      and (state.__g9gui == true or state.__g9guiBox == true
        or state.__g9guiChoice == true or state.__g9guiQty == true
        or state.__g9modern == true)
  end

  local function visible(stack, state)
    if type(stack.renderVisible) == "function" then
      local ok, v = pcall(stack.renderVisible, stack, state)
      if ok then return v ~= false end
    end
    return true
  end

  local function wideLayer(stack, state)
    return type(state) == "table" and type(state.drawsWidescreen) == "function"
      and type(state.drawWidescreen) == "function" and state:drawsWidescreen()
  end

  -- The state that owns the palette this frame, by the engine's own rule (see
  -- the header).  Returns nil when nothing owns it (e.g. the plain overworld).
  local function owner(game)
    local stack = game and game.stack
    local states = stack and stack.states
    if type(states) ~= "table" then return nil end
    if ctx.gen == 2 then
      local top = (type(stack.top) == "function") and stack:top() or nil
      if top and visible(stack, top) and wideLayer(stack, top) then return top end
      local baseIdx = (type(stack.visibleBase) == "function")
        and stack:visibleBase() or nil
      local base = baseIdx and states[baseIdx] or nil
      if base and visible(stack, base) and wideLayer(stack, base) then
        return base
      end
      return nil
    end
    for i = #states, 1, -1 do
      local s = states[i]
      if type(s) == "table" and s.sgbPalettes and visible(stack, s) then
        return s
      end
    end
    return nil
  end

  function M.enabled()
    return ctx.on("color_protection")
  end

  -- Would this frame be protected?  Public so a harness (and any future
  -- sibling) can ask without going through the hook bus.
  function M.protecting(game)
    return M.enabled() and ours(owner(game))
  end

  function M.zone() return ZONE end

  function M.install()
    if M.__installed then return true end
    if type(mod.hooks) ~= "table" or type(mod.hooks.wrap) ~= "function" then
      return false
    end
    M.__installed = true
    mod.hooks:wrap("render.zones", function(next, game, zones)
      local out = zones
      if type(next) == "function" then out = next(game, zones) end
      if not M.enabled() then return out end
      if not ours(owner(game)) then return out end
      if ctx.gen == 2 and not (type(out) == "table" and out[1] ~= nil) then
        -- Gold computes a zone list for one case only -- the CLASSIC present
        -- palette (GbcPalette.presentColors).  With none, the frame is already
        -- the right colour, and handing Game2 a list would make it take the
        -- whole-frame present-canvas path for nothing.
        return out
      end
      -- One whole-screen opt-out is all the blit needs; the engine's extra
      -- trueColor rects are `colors == false` too and are covered by it.
      return { ZONE }
    end)
    return true
  end

  return M
end
