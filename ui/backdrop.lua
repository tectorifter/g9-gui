-- ui/backdrop.lua -- the layered background behind every g9-gui screen.
--
-- Everything here is plain rectangles and circles: no canvases, no shaders,
-- no assets.  The engine draws the state's own surface and blits it, so a
-- backdrop made of a few hundred translucent primitives costs nothing worth
-- measuring, and it can be switched off wholesale (ui_background) or trimmed
-- to just the flat field.
--
-- Two layers:
--   * the FOUNDATION -- always drawn: a vertical gradient plus a soft glow
--     low-left and a vignette, which is what makes a translucent panel read
--     as glass instead of as a grey rectangle.
--   * the EMBELLISHMENT -- only with ui_embellishment: the diagonal weave,
--     the horizon rule and the drifting highlight.
return function(mod)
  local B = {}

  local function vgrad(Theme, x, y, w, h, top, bottom, steps)
    steps = steps or 24
    for i = 0, steps - 1 do
      local t = i / (steps - 1)
      local c = {
        top[1] + (bottom[1] - top[1]) * t,
        top[2] + (bottom[2] - top[2]) * t,
        top[3] + (bottom[3] - top[3]) * t,
        1,
      }
      Theme.set(c)
      local band = math.min(h / steps + 1, h - h * i / steps)
      Theme.rect("fill", x, y + h * i / steps, w, band, 0)
    end
  end

  -- soft radial glow, built from concentric translucent discs
  local function glow(Theme, cx, cy, r, color, alpha, steps)
    steps = steps or 12
    for i = steps, 1, -1 do
      local t = i / steps
      Theme.set(color, alpha * (1 - t) * 0.55)
      love.graphics.circle("fill", cx, cy, r * t)
    end
  end

  local function vignette(Theme, w, h, color, strength)
    local depth = math.max(8, math.floor(h * 0.20))
    for i = 0, depth - 1 do
      local a = strength * (1 - i / depth) * (1 - i / depth)
      Theme.set(color, a)
      Theme.rect("fill", 0, i, w, 1, 0)
      Theme.rect("fill", 0, h - 1 - i, w, 1, 0)
    end
    local side = math.max(8, math.floor(w * 0.12))
    for i = 0, side - 1 do
      local a = strength * (1 - i / side) * (1 - i / side) * 0.9
      Theme.set(color, a)
      Theme.rect("fill", i, 0, 1, h, 0)
      Theme.rect("fill", w - 1 - i, 0, 1, h, 0)
    end
  end

  -- t = seconds-ish counter for the slow-moving embellishments
  function B.draw(Theme, opts)
    local w, h = opts.w or 540, opts.h or 360
    local C = Theme.col
    local embellish = opts.embellishment ~= false

    if opts.background == false then
      Theme.set(C.voidDeep)
      Theme.rect("fill", 0, 0, w, h, 0)
    else
      vgrad(Theme, 0, 0, w, h, { 0.075, 0.100, 0.150 }, { 0.014, 0.020, 0.036 }, 24)
      -- warm rim down the right, cold glow behind the left list: gives the
      -- flat gradient a light direction so panels sit on something
      glow(Theme, w * 0.10, h * 0.30, h * 0.85, C.accent, 0.30)
      glow(Theme, w * 0.92, h * 0.86, h * 0.70, C.gold, 0.10)
      if embellish then
        local t = (opts.t or 0)
        local sweep = (math.sin(t * 0.35) * 0.5 + 0.5)
        glow(Theme, w * (0.35 + sweep * 0.4), h * 0.10, h * 0.55,
          C.accent, 0.07 + 0.04 * sweep, 8)
      end
      vignette(Theme, w, h, C.black, 0.34)
    end

    if embellish then
      -- diagonal weave: one pass of faint 1px lines, 1px of alpha each
      Theme.set(C.white, 0.022)
      local step = 7
      local i = -h
      while i < w do
        love.graphics.line(i, h, i + h, 0)
        i = i + step
      end
      -- horizon rule where the roster's table would meet a "floor"
      Theme.set(C.accentDim, 0.20)
      Theme.rect("fill", 0, h - 34, w, 1, 0)
      Theme.set(C.white, 0.03)
      Theme.rect("fill", 0, h - 33, w, 1, 0)
      -- corner brackets around the whole surface
      Theme.brackets(2, 2, w - 4, h - 4, 12, C.accentDim)
    end
  end

  return B
end
