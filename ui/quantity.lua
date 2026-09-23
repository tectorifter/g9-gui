-- ui/quantity.lua -- the modern "How many?" stepper.
--
-- src.ui.QuantityBox is the engine's number picker: UP/DOWN step 1..max with a
-- roll-over, A confirms, B cancels, and a mart passes a unit price so it can
-- print the running total.  It is pushed as its own state by the bag, the mart,
-- the PLAYER's PC (withdraw / deposit / toss) and the MOD MANAGER -- and it is
-- non-opaque, so it rides over whatever pushed it.
--
-- On a classic 160x144 screen it is already fine where it is, and this module
-- leaves it exactly as the engine draws it.  Over one of this suite's 540x360
-- pages it is not: the engine centres that classic box inside the wide page
-- (Game:draw's classicOffset), which lands a small white square in the middle
-- of a modern screen.  There the box becomes the suite's centred card -- the
-- same S.card the PC's mon submenu and the YES/NO use -- drawn in the PAGE's
-- own coordinates after undoing that shift.  The engine keeps the value, its
-- bounds and its keys; only :draw changes.
--
-- Fail-open in both directions: a state this module refuses to dress keeps the
-- engine's drawing, and a frame with no wide page falls back to the engine's
-- own :draw (the class method is still there -- only the INSTANCE's :draw is
-- replaced), so the picker can never disappear.
return function(mod, ctx)
  local Theme, Shell = ctx.Theme, ctx.Shell

  local QuantityBox
  do
    local ok, v = pcall(require, "src.ui.QuantityBox")
    QuantityBox = ok and v or nil
  end

  local M = {}

  -- The engine builds this box with setmetatable({}, QuantityBox), so the
  -- class table IS the identity: nothing else on the stack answers this.
  function M.isQuantity(state)
    if type(state) ~= "table" or not QuantityBox then return false end
    return getmetatable(state) == QuantityBox
  end

  -- Only over one of the suite's own pages: there the box has to be redrawn in
  -- the page's space.  A classic screen (the overworld, a mart, a battle's wide
  -- surface) keeps the engine's own drawing, exactly as it always has.
  function M.canDress(stack, state)
    local states = stack and stack.states
    local lower = states and states[#states - 1]
    if type(lower) ~= "table" or not lower.__g9gui then return false end
    if lower.isBattle then return false end
    if type(lower.drawsWidescreen) == "function"
        and lower:drawsWidescreen() then
      -- Gold's own pages present through their own blit, so the classic box is
      -- not shifted and there is nothing to undo; keep the engine's drawing.
      return false
    end
    return true
  end

  local function money(n)
    local digits = ("%06d"):format(math.max(0, math.floor(n or 0)))
    local first = digits:find("[1-9]") or #digits
    return "\xc2\xa5" .. digits:sub(first)
  end

  -- The card, in the PAGE's own 540x360 coordinates.
  function M.paint(state)
    local qty = state.qty or 1
    local right = state.max and ("MAX %d"):format(state.max) or nil
    Shell.card(Theme, state.game, {
      title = "HOW MANY?",
      right = right,
      w = 320,
      stepper = {
        value = ("\xc3\x97%02d"):format(qty),
        right = state.unitPrice and money(qty * state.unitPrice) or nil,
      },
      hints = {
        { key = "\xe2\x86\x91\xe2\x86\x93", text = "CHANGE" },
        { key = "A", text = "OK" },
        { key = "B", text = "BACK" },
      },
      t = state.__t or 0,
    })
  end

  function M.draw(state)
    local off = Shell.pageOffset(state.game)
    if off <= 0 then
      -- no wide page under it: the engine's own box, untouched
      if QuantityBox and type(QuantityBox.draw) == "function" then
        return QuantityBox.draw(state)
      end
      return
    end
    local g = love.graphics
    if g.push then g.push() end
    if g.translate then g.translate(-off, 0) end
    local ok, err = pcall(M.paint, state)
    if g.pop then g.pop() end
    if not ok then
      error("g9-gui: the quantity card failed: " .. tostring(err), 0)
    end
  end

  -- Take over a pushed QuantityBox instance.  Called from the StateStack.push
  -- wrapper in main.lua.
  function M.dress(state)
    if type(state) ~= "table" or state.__g9guiQty then return state end
    state.__g9guiQty = true
    state.__t = 0
    local baseUpdate = state.update
    if type(baseUpdate) == "function" then
      state.update = function(self, dt)
        self.__t = (self.__t or 0) + 1
        return baseUpdate(self, dt)
      end
    end
    state.draw = function(self) M.draw(self) end
    return state
  end

  return M
end
