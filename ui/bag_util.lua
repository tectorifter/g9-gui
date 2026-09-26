-- ui/bag_util.lua -- the bag's capacity, its guards and its pockets.
--
-- Adapted from the "Useful Bag" mod (ShaneMcGovernIE, 2.6.4) so the suite can
-- own a modern bag without depending on it.  Three separate jobs live here:
--
--   1. CAPACITY + GUARDS (both generations).  The engine's bag is small on
--      purpose -- 20 distinct slots and a 99-per-stack ceiling (the save
--      format's own numbers).  This raises the runtime limits to 300 slots
--      and 999 per slot and refuses the one thing the engine cannot express:
--      a request that would carry a stack PAST the ceiling adds nothing at
--      all rather than silently trimming.
--
--      The three registry patches are the same trio Useful Bag uses -- the
--      distinct-slot count (`constants.bagSize`), the per-stack ceiling
--      (`constants.itemStackCap`) and the PC's item storage (`field.pcItemCap`)
--      -- plus a `Bag.add` shim, because an engine build that still hard-codes
--      99 inside `Bag.add` would otherwise refuse the growth the constants
--      already advertise.  The shim calls the engine's own `Bag.add` FIRST and
--      only repairs the one rejection it owns (an existing, positive stack the
--      engine refused for its old 99 ceiling); a genuinely full bag or a new
--      slot with no room still fails, exactly as shipped.
--
--   2. SIX POCKETS (Gen 1 only).  Gen 1's engine has ONE flat bag; Gen 2's
--      engine already has four pockets of its own.  On Gen 1 the bag is
--      therefore shown as six auto-sorted projections of the same hidden bag
--      -- ITEMS, MEDICINE, POKe BALLS, TMs/HMs, BATTLE ITEMS, KEY ITEMS --
--      cycled with LEFT/RIGHT, exactly as Useful Bag does.  Nothing is moved
--      out of `save.inventory`/`save.bagOrder`: every pocket is only a view,
--      so key items, scripted checks and the PC deposit all keep reading the
--      real inventory.  SELECT still reorders, but pocket-safely (the two
--      visible rows are translated back onto the hidden order before the
--      swap); TAB / R3 / the touch SELECT overlay opens SORT BY NAME / SORT
--      BY COUNT, which rewrites that same hidden order.
--
--   3. A TAG STRIP, for the page to draw (ui/bag.lua owns the pixels).
--
-- WHY A PEER CHECK.  Useful Bag is the specialist; when it is installed this
-- module stands down entirely and leaves it the bag, so installing both mods
-- can never leave the two capacity patches fighting over one constant or two
-- pocket projections stacked on one list.
--
-- WHAT THIS DOES NOT DO.  The raw save formats keep their own limits (a Gen 1
-- raw save still holds 20 bag entries and a 99 quantity byte; a Gen 2 SRAM
-- save's pocket counts are bytes).  The raised limits are runtime limits.
return function(mod, ctx)
  local U = {}
  U.SLOTS = 300
  U.STACK = 999
  U.PC_ITEMS = 300

  local gen = ctx and ctx.gen or 1
  local opt = (ctx and ctx.opt) or function() return nil end

  local function info(msg)
    if mod and mod.log and mod.log.info then
      pcall(mod.log.info, mod.log, tostring(msg):gsub("%%", "%%%%"))
    end
  end

  local function req(name)
    local ok, m = pcall(require, name)
    if ok then return m end
    return nil
  end

  -- ---------------------------------------------------------------- pockets
  -- The six Gen 1 pockets, in cycle order.  `label` is the page title, `tab`
  -- the short form the strip has room for (six full labels do not fit 540px).
  local POCKETS = {
    { id = "items",    label = "ITEMS",        tab = "ITEMS" },
    { id = "medicine", label = "MEDICINE",     tab = "MED" },
    { id = "balls",    label = "POKé BALLS",   tab = "BALLS" },
    { id = "tms",      label = "TMs / HMs",    tab = "TM/HM" },
    { id = "battle",   label = "BATTLE ITEMS", tab = "BATTLE" },
    { id = "key",      label = "KEY ITEMS",    tab = "KEY" },
  }
  U.POCKETS = POCKETS

  -- Fallback classification sets, mirroring Useful Bag's: the real ROM flags
  -- (`def.keyItem` from KeyItemFlags, `def.machine` for a TM/HM) are
  -- authoritative, and these cover fixture / hand-written / mod items that
  -- carry no flag.  ESCAPE_ROPE and EXP_ALL are NOT key items; the eight
  -- badges are key items by flag but never appear in the bag (Bag.isBadge).
  local KEY_ITEMS = {
    TOWN_MAP = true, BICYCLE = true, SURFBOARD = true, SAFARI_BALL = true,
    POKEDEX = true,
    BOULDERBADGE = true, CASCADEBADGE = true, THUNDERBADGE = true,
    RAINBOWBADGE = true, SOULBADGE = true, MARSHBADGE = true,
    VOLCANOBADGE = true, EARTHBADGE = true,
    OLD_AMBER = true, DOME_FOSSIL = true, HELIX_FOSSIL = true,
    SECRET_KEY = true, ITEM_2C = true, BIKE_VOUCHER = true,
    CARD_KEY = true,
    S_S_TICKET = true, GOLD_TEETH = true, COIN_CASE = true, OAKS_PARCEL = true,
    ITEMFINDER = true, SILPH_SCOPE = true, POKE_FLUTE = true, LIFT_KEY = true,
    OLD_ROD = true, GOOD_ROD = true, SUPER_ROD = true,
  }
  local MEDICINE = {
    POTION = true, SUPER_POTION = true, HYPER_POTION = true, MAX_POTION = true,
    FRESH_WATER = true, SODA_POP = true, LEMONADE = true,
    ANTIDOTE = true, BURN_HEAL = true, ICE_HEAL = true, AWAKENING = true,
    PARLYZ_HEAL = true, FULL_HEAL = true, FULL_RESTORE = true,
    REVIVE = true, MAX_REVIVE = true, RARE_CANDY = true,
    HP_UP = true, PROTEIN = true, IRON = true, CARBOS = true, CALCIUM = true,
    ETHER = true, MAX_ETHER = true, ELIXER = true, MAX_ELIXER = true,
    PP_UP = true,
  }
  local BATTLE_ITEMS = {
    X_ATTACK = true, X_DEFEND = true, X_SPEED = true, X_SPECIAL = true,
    X_ACCURACY = true, DIRE_HIT = true, GUARD_SPEC = true, POKE_DOLL = true,
  }
  local BALLS = {
    POKE_BALL = true, GREAT_BALL = true, ULTRA_BALL = true,
    MASTER_BALL = true, SAFARI_BALL = true,
  }

  local function isMachine(id, def)
    if def and def.machine then return true end
    local head = tostring(id):sub(1, 2)
    return head == "TM" or head == "HM"
  end

  -- Which pocket an item id lives in (Gen 1).  The POKe FLUTE is the one
  -- contextual exception: usable in battle, so it rides with the battle items
  -- there and stays a KEY ITEM in the overworld.
  function U.classify(data, id, inBattle)
    if id == "POKE_FLUTE" and inBattle then return "battle" end
    local def = data and data.items and data.items[id]
    if (def and def.keyItem) or KEY_ITEMS[id] then return "key" end
    if isMachine(id, def) then return "tms" end
    if (def and def.ball) or BALLS[id] then return "balls" end
    if MEDICINE[id] then return "medicine" end
    if BATTLE_ITEMS[id] then return "battle" end
    return "items"
  end

  -- ------------------------------------------------------------- sort / order
  -- The hidden bag, canonical and acquisition-ordered.  `Bag.order` maintains
  -- it incrementally, so PC deposits, uses and tosses all land here first.
  local function hiddenOrder(save, data)
    local Bag = req("src.inventory.Bag")
    if Bag and Bag.order then return Bag.order(save, data) end
    return (save and save.bagOrder) or {}
  end
  U.hiddenOrder = hiddenOrder

  -- Rewrite the hidden order in place: "name" (alphabetical, id tiebreak) or
  -- "count" (biggest stacks first).  `Bag.order` hands back `save.bagOrder`
  -- itself, so sorting it is the whole write.
  function U.applySort(save, data, mode)
    local order = hiddenOrder(save, data)
    local inv = (save and save.inventory) or {}
    local items = data and data.items or {}
    if mode == "count" then
      table.sort(order, function(a, b)
        local ca, cb = inv[a] or 0, inv[b] or 0
        if ca == cb then return a < b end
        return ca > cb
      end)
    else
      table.sort(order, function(a, b)
        local da, db = items[a], items[b]
        local na, nb = (da and da.name) or a, (db and db.name) or b
        if na == nb then return a < b end
        return na < nb
      end)
    end
    return order
  end

  -- Swap two ids inside the hidden order (the row swap the pocket rows
  -- translate back onto; a no-op when either id is missing).
  function U.swapIds(save, data, a, b)
    if not a or not b or a == b then return false end
    local order = hiddenOrder(save, data)
    local ia, ib
    for k, id in ipairs(order) do
      if id == a then ia = k elseif id == b then ib = k end
      if ia and ib then break end
    end
    if ia and ib then order[ia], order[ib] = order[ib], order[ia] return true end
    return false
  end

  -- ----------------------------------------------------------------- guards
  local MARK_ADD = "__g9guiBagAdd"
  local MARK_CAP = "__g9guiBagCapacity"

  function U.install()
    if U.installed then return U.enabled end
    U.installed = true
    local Bag = req("src.inventory.Bag")
    if not Bag then
      info("bag utilities: the inventory module is missing -- capacity and "
        .. "pockets are off")
      return false
    end

    -- A peer bag mod owns the bag outright; do not fight it over one
    -- constant or stack two pocket views on one list.
    if mod and mod.find then
      for _, id in ipairs({ "useful_bag", "useful-bag", "Useful Bag" }) do
        local ok, peer = pcall(mod.find, mod, id)
        if ok and peer then
          info("bag utilities: " .. id .. " is installed -- the bag, its "
            .. "capacity and its pockets are left to it")
          return false
        end
      end
    end

    U.enabled = true

    -- 1. the three registry patches.  Each is best-effort: an older engine
    -- payload may not accept the key at all, and the Bag shims below still
    -- work without it.
    pcall(function() mod.content.constants:patch("bagSize", U.SLOTS) end)
    pcall(function() mod.content.constants:patch("itemStackCap", U.STACK) end)
    -- field.pcItemCap is a Gen 1 registry: Schemas.lua's R.GEN2.field is
    -- false, so on Gold this patch is dropped and reported ("the field
    -- registry has no Gen 2 target") rather than rerouted.  Gold's own PC
    -- item storage is a different store, and this module's other two
    -- registry patches plus every shim below already cover both
    -- generations -- so the patch is simply not attempted there.
    if gen ~= 2 then
      pcall(function() mod.content.field:patch("pcItemCap", U.PC_ITEMS) end)
    end

    -- 2. per-pocket capacity.  Gen 2's Bag answers a per-pocket cap from a
    -- hard-coded table unless a mod replaces it, so raise every pocket (Gen 1
    -- asks for the single "ITEM" pool, which the same override lifts to 300).
    local vanillaCapacity = Bag.capacity
    if type(vanillaCapacity) == "function" and not Bag[MARK_CAP] then
      Bag[MARK_CAP] = true
      Bag.capacity = function(data, pocket)
        local base = U.SLOTS
        local ok, v = pcall(vanillaCapacity, data, pocket)
        if ok and type(v) == "number" and v > base then base = v end
        return base
      end
    end

    -- 3. the per-stack ceiling, readable by other mods and by the PC.
    local nativeStack = Bag.stackCapacity
    Bag.stackCapacity = function(data)
      if type(nativeStack) == "function" then
        local ok, v = pcall(nativeStack, data)
        if ok and type(v) == "number" and v >= U.STACK then
          return math.floor(v)
        end
      end
      local c = data and data.constants and data.constants.itemStackCap
      if type(c) == "number" and c >= U.STACK then return math.floor(c) end
      return U.STACK
    end

    -- 4. the add shim.  Engine first; repair only the one rejection this mod
    -- owns -- an EXISTING, positive stack the engine refused for its old 99
    -- ceiling.  Anything that would pass the ceiling now fails outright, so
    -- an item never lands past 999.
    if type(Bag.add) == "function" and not Bag[MARK_ADD] then
      Bag[MARK_ADD] = true
      local vanillaAdd = Bag.add
      Bag.__g9guiVanillaAdd = vanillaAdd
      Bag.add = function(save, id, qty, data)
        local inv = save and save.inventory
        local before = inv and inv[id]
        local amount = tonumber(qty) or 1
        -- a request that would pass the per-item ceiling adds NOTHING (the
        -- whole stack stays where it is), which is the guard the bag is for
        if amount > U.STACK then return false end
        if type(before) == "number" and before + amount > U.STACK then
          return false
        end
        if vanillaAdd(save, id, qty, data) then return true end
        if amount < 1 then return false end
        local badge = type(Bag.isBadge) == "function" and Bag.isBadge(id)
        if type(before) == "number" and before >= 1 and inv[id] == before then
          -- an existing stack the engine refused for its old 99 ceiling
          if before + amount > U.STACK then return false end
          inv[id] = before + amount
          return true
        end
        -- a NEW stack: the engine refused it for the old ceiling too, but it
        -- also refuses a genuinely full bag, so room has to be confirmed in
        -- the item's OWN pocket before the slot is opened.
        if before ~= nil and before ~= 0 then return false end
        if not (badge or (type(Bag.slots) == "function"
            and type(Bag.pocketOf) == "function")) then
          return false
        end
        if not badge then
          local pocket = Bag.pocketOf(id, data)
          local cap = (type(Bag.capacity) == "function"
            and Bag.capacity(data, pocket)) or U.SLOTS
          if Bag.slots(save, data, pocket) >= cap then return false end
        end
        local add = badge and amount or math.min(amount, U.STACK)
        if not badge then
          -- insert the order entry BEFORE the inventory write: Bag.order's
          -- defensive append reads save.inventory, and writing first would
          -- let both paths add the id (one pickup, two rows)
          local order = hiddenOrder(save, data)
          order[#order + 1] = id
        end
        inv[id] = add
        return true
      end
    end

    info(("bag utilities: %d slots, x%d per item, %d PC stacks")
      :format(U.SLOTS, U.STACK, U.PC_ITEMS))
    return true
  end

  -- ------------------------------------------------------- Gen 1 bag list
  -- The shared bag session: one bag is open at a time, and the Input wrap
  -- installed at game.ready writes the TAB/R3/touch-SELECT sort edge here.
  local session = { active = nil, wantSort = false, sortOpen = false }
  U.session = session

  local SORT_LABELS = { "SORT BY NAME", "SORT BY COUNT" }
  U.SORT_LABELS = SORT_LABELS

  local function cancelLabel()
    local Strings = req("src.core.Strings")
    if Strings then
      local ok, s = pcall(Strings, "CANCEL")
      if ok and type(s) == "string" and s ~= "" then return s end
    end
    return "CANCEL"
  end

  local function soundSwap(data)
    local S = req("src.core.Sound")
    if S and S.play then pcall(S.play, data, "Swap") end
  end

  local function soundPress(data)
    local S = req("src.core.Sound")
    if S and S.play then pcall(S.play, data, "Press_AB") end
  end

  -- Decorate the engine's own bag list (Gen 1) with the six pockets, L/R
  -- cycling, a pocket-safe SELECT swap, cursor wrap and the sort prompt.
  -- `opts` is the bag's open options (opts.battle marks a battle bag).  The
  -- engine's ListMenu stays the owner of the cursor, the item flows, the
  -- effects and the save offsets: only `items`/`title` and the input paths
  -- below change.
  function U.decorateBagList(list, game, opts)
    if not (U.enabled and gen == 1) then return list end
    if type(list) ~= "table" or list.__g9bag then return list end
    -- If a peer pocketed this list first (Useful Bag), leave it whole.
    if list.__usefulBagKind then return list end
    local data = game and game.data
    local save = game and game.save
    local Bag = req("src.inventory.Bag")
    if not (data and save and Bag) then return list end

    list.__g9bag = true
    list.__g9pocket = 1
    list.wrap = true -- Up on the first row / Down on the last wraps
    local battle = opts and opts.battle or nil

    local function buildIds()
      local id0 = list.items and list.items[list.index] and list.items[list.index].value
      return id0
    end

    -- Re-project the active pocket from the hidden bag, keeping the selected
    -- item when it is still in this pocket.
    local function project()
      local pocket = POCKETS[list.__g9pocket] or POCKETS[1]
      local want = buildIds()
      local order = hiddenOrder(save, data)
      local items, ids = {}, {}
      for _, id in ipairs(order) do
        if U.classify(data, id, battle and true or false) == pocket.id then
          ids[#ids + 1] = id
          local def = data.items and data.items[id]
          -- key items and HMs print no count, exactly as the engine's own
          -- buildItems decides (PrintListMenuEntries skips IsKeyItem_'s)
          local unsellable = (def and def.keyItem)
            or tostring(id):sub(1, 3) == "HM_"
          items[#items + 1] = {
            value = id,
            label = (def and def.name) or tostring(id),
            count = (not unsellable) and (save.inventory[id] or 0) or nil,
          }
        end
      end
      -- the terminator row: selectable, and A/B on it leaves like B
      items[#items + 1] = { cancel = true, label = cancelLabel() }
      list.items, list.__g9ids = items, ids
      list.title = pocket.label
      list.__g9pocketIndex = list.__g9pocket
      if want then
        for i, id in ipairs(ids) do
          if id == want then list.index = i break end
        end
      end
      list.index = math.max(1, math.min(list.index, #items))
      list.scroll = math.max(0, math.min(list.scroll or 0,
        math.max(0, list.index - (list.cursorRows or list.rows or 3))))
      return ids
    end
    list.__g9project = project

    -- does the live row set still match the pocket?  The engine's own item
    -- flows (TOSS's itemMenuLoop) rebuild the FULL bag into list.items, so
    -- this is how the pocket re-asserts itself instead of silently widening.
    local function matchesPocket()
      local ids = list.__g9ids or {}
      local items = list.items or {}
      if #items ~= #ids + 1 then return false end
      for i = 1, #ids do
        if not items[i] or items[i].value ~= ids[i] then return false end
      end
      return true
    end

    local function switchPocket(dir)
      local n = #POCKETS
      list.__g9pocket = ((list.__g9pocket - 1 + dir) % n) + 1
      list.swapIndex = nil
      list.index, list.scroll = 1, 0
      project()
    end

    -- SELECT still reorders, but the two visible rows are translated back
    -- onto the hidden order first (the engine's own swap uses list indices,
    -- which are only the bag's own order when the list IS the whole bag).
    list.onSelectKey = function(item, l)
      if not item or item.cancel then return end
      if not l.swapIndex then
        l.swapIndex = l.index
        return
      end
      local a = l.items[l.swapIndex] and l.items[l.swapIndex].value
      local b = l.items[l.index] and l.items[l.index].value
      if U.swapIds(save, data, a, b) then soundSwap(data) end
      l.swapIndex = nil
      project()
    end

    local vanillaChoose = list.onChoose
    list.onChoose = function(item, l)
      -- A also completes a pending swap (the engine does the same)
      if l.swapIndex then
        local a = l.items[l.swapIndex] and l.items[l.swapIndex].value
        local b = l.items[l.index] and l.items[l.index].value
        if U.swapIds(save, data, a, b) then soundSwap(data) end
        l.swapIndex = nil
        project()
        return
      end
      if vanillaChoose then return vanillaChoose(item, l) end
    end

    -- the sort card: SORT BY NAME / SORT BY COUNT over the hidden bag
    local function openSort()
      list.swapIndex = nil
      list.__g9sort = { index = 1 }
    end

    local function handleSort()
      local s = list.__g9sort
      local input = game.input
      if input:wasPressed("up") or input:wasPressed("down") then
        s.index = (s.index == 1) and 2 or 1
        soundPress(data)
      elseif input:wasPressed("b") or input:wasPressed("select")
          or input:wasPressed("tab") then
        list.__g9sort = nil
        soundPress(data)
      elseif input:wasPressed("a") then
        U.applySort(save, data, (s.index == 1) and "name" or "count")
        list.__g9sort = nil
        soundSwap(data)
        project()
      end
    end

    local baseUpdate = list.update
    list.update = function(self, dt)
      local input = self.game and self.game.input
      if self.__g9sort then
        if input then handleSort() end
        return
      end
      if input and input.wasPressed then
        local left = input:wasPressed("left")
        local right = input:wasPressed("right")
        if left or right then
          switchPocket(left and -1 or 1)
          soundPress(data)
        end
      end
      if session.wantSort and session.active == self and not self.__g9sort
          and self.game.stack:top() == self then
        session.wantSort = false
        openSort()
      end
      if not matchesPocket() then project() end
      if baseUpdate then baseUpdate(self, dt) end
    end

    local vanillaClose = list.close
    list.close = function(self, ...)
      session.active = nil
      session.wantSort = false
      session.sortOpen = false
      return vanillaClose(self, ...)
    end

    session.active = list
    session.wantSort = false
    project()
    return list
  end

  -- Put the sort on keys the engine's own bag leaves free: TAB (which the
  -- input map aliases to SELECT), R3 / right-stick click, and the touch
  -- overlay's SELECT.  The press is swallowed so it cannot ALSO swap an item.
  function U.installInput()
    local Input = req("src.core.Input")
    if not Input then return false end
    -- The session is published on the Input module, not just closed over, so a
    -- hot reload's fresh module can hand its own session to the already-
    -- installed wrapper instead of the wrapper holding a stale one.
    if Input.__g9guiBagSort then
      Input.__g9guiBagSession = session
      return true
    end
    Input.__g9guiBagSort = true
    Input.__g9guiBagSession = session

    local function live()
      return Input.__g9guiBagSession or session
    end
    -- Only while OUR bag is the TOP state: an item flow (USE/TOSS, the
    -- quantity stepper, a message) is pushed over it and owns SELECT, so the
    -- press must pass through untouched instead of being swallowed here.
    local function bagOpenActive()
      local a = live().active
      if not (a and a.__g9bag) then return false end
      local stack = a.game and a.game.stack
      if stack and stack.top then
        local ok, top = pcall(stack.top, stack)
        if ok and top ~= a then return false end
      end
      return true
    end
    local function toggle()
      local s = live()
      if s.active.__g9sort then
        s.active.__g9sort = nil
      else
        s.wantSort = true
      end
    end

    local vanillaKey = Input.keypressed
    Input.keypressed = function(self, key)
      if key == "tab" and bagOpenActive() then
        toggle()
        return
      end
      return vanillaKey(self, key)
    end

    local vanillaPad = Input.gamepadpressed
    Input.gamepadpressed = function(self, joystick, button)
      if button == "rightstick" and bagOpenActive() then
        toggle()
        return
      end
      return vanillaPad(self, joystick, button)
    end

    local vanillaOverlay = Input.overlayPressed
    Input.overlayPressed = function(self, button)
      if button == "select" and bagOpenActive() then
        toggle()
        return
      end
      return vanillaOverlay(self, button)
    end
    return true
  end

  -- The page title / strip the caller draws, plus the two sort rows.
  function U.tabCaptions()
    local out = {}
    for i, p in ipairs(POCKETS) do out[i] = p.tab end
    return out
  end

  return U
end
