-- ui/pc.lua -- the PC pages: the Pokecenter PC's own top menu, the player's
-- ITEM storage menu and its WITHDRAW / DEPOSIT / TOSS lists, BILL's PC storage
-- menu and its WITHDRAW / DEPOSIT / RELEASE lists, and the CHANGE BOX picker.
--
-- Every one of these is a VIEW takeover.  The engine builds the real Menu
-- (src.ui.Menu) or ListMenu (src.ui.ListMenu) and keeps its own cursor, its
-- key-repeat, the keepOpen row flow, the YES/NO and every item / mon write and
-- sound; this module only swaps the surface and the drawing for the suite's
-- 540x360 page (ui/shell.lua), reading the engine's own self.items / self.index
-- / self.scroll exactly as ui/bag.lua reads the ListMenu BagMenu returns.
--
-- WHAT IS WHAT (Gen 1)
--   * the top menu        -- Menu built inline in OverworldState:openPC and
--                            pushed from the "turned on the PC" text box's own
--                            callback.  It has NO screen id and NO kind, so
--                            installOpenPc() wraps openPC and marks the one
--                            Menu it builds (__g9pcMain); the mark has to live
--                            on the object because the push happens later.
--   * PlayerPC            -- screenId "PlayerPC" (Screens.push)
--   * BoxMenu             -- screenId "BoxMenu"
--   * the sub-lists       -- ListMenu instances whose kind starts "pc_" --
--                            pc_item_withdraw/deposit/toss and
--                            pc_box_withdraw/deposit/release
--   * the CHANGE BOX      -- the Menu whose kind is "pc_box_change"
--   * LeaguePC            -- screenId "LeaguePC" (the HALL OF FAME viewer):
--                            a bespoke classic screen, not a Menu or list, so
--                            it is recognised by screenId and given its own
--                            painter (M.drawLeague).
--
-- WHAT IS WHAT (Gen 2 / Gold)
-- Gold's PC is a different set of screens and takes the other branch of every
-- function below: src/ui/gen2/CenterPcMenu.lua (the whose-PC menu),
-- PcMenu.lua (the storage system: the five/six rows, the CHANGE BOX picker and
-- the change-box save prompt), ItemPcMenu.lua (the item PC and its
-- WITHDRAW / DEPOSIT / TOSS lists), BoxMenu.lua (BILL's PC: the box list, its
-- left mon panel, the MOVE / WITHDRAW / DEPOSIT / RELEASE / STATS submenu, the
-- insert cursor and the timed "Saving... Leave ON!" hold) and
-- MailboxMenu.lua.  None of them is a Menu or a ListMenu: each is a bespoke
-- class that already paints a widescreen page on the cart (they answer
-- :drawsWidescreen), so a Gold takeover rides the same seam as every other
-- Gold screen in this suite -- S.gen2Surface swaps the page and the painter,
-- and the engine object (its cursor, its phases, its save writes, its sounds,
-- its typer) keeps running untouched.  The five ids are stamped by
-- Screens.build before the push, so this file recognises them by screenId
-- alone -- no require of an engine Gen 2 module is needed to know what a
-- pushed state is.
--
-- The PC's own dialogue ("{PLAYER} turned on the PC.", "Accessed BILL's PC.",
-- the whose-PC "Bazzzt!" refusal, the change-box save prompt) is a TextBox or a
-- Typer page, so it is already modernised by the shared dialogue skin
-- (ui/textbox.lua) the moment it is written -- on both generations.
return function(mod, ctx)
  local Theme, Backdrop, Shell = ctx.Theme, ctx.Backdrop, ctx.Shell
  local Portraits = ctx.Portraits
  local opt = ctx.opt
  local Strings = require("src.core.Strings")

  local M = {}
  local W, H = Shell.W, Shell.H
  local MARGIN = Shell.MARGIN
  local Gen2 = ctx.gen == 2

  -- Rows the list pages reveal at once.  The engine's own cursor window is
  -- narrower (ListMenu's item lists keep the cursor in the top three), so the
  -- cursor is always inside whatever is drawn here.  Eight rows at row 30 is
  -- what the content band (S.CONTENT_Y 66 -> S.FOOT_RULE_Y 314) holds: a ninth
  -- row's panel would reach 340 and paint over the footer.
  local VISIBLE = 8

  -- Gold: the five PC screen ids (stamped by Screens.build before the push) and
  -- the page painter each one gets.  Populated at the bottom of this file, once
  -- the painters exist; `dress` reads it at push time.
  local G2_SCREENS = {
    Gen2CenterPcMenu = "center",
    Gen2PcMenu = "storage",
    Gen2ItemPcMenu = "items",
    Gen2BoxMenu = "box",
    Gen2MailboxMenu = "mail",
  }
  local G2_DRAW = {}

  -- The engine classes, required lazily and cached.  A Gen 2 boot needs none
  -- of them, and a `require` failure must leave isPc() answering false rather
  -- than throwing inside the push wrapper.
  local Menu, ListMenu
  local function menuClass()
    if Menu == nil then
      local ok, m = pcall(require, "src.ui.Menu")
      Menu = (ok and type(m) == "table") and m or false
    end
    return Menu or nil
  end
  local function listClass()
    if ListMenu == nil then
      local ok, m = pcall(require, "src.ui.ListMenu")
      ListMenu = (ok and type(m) == "table") and m or false
    end
    return ListMenu or nil
  end

  local function isMenu(state)
    local cls = menuClass()
    return cls ~= nil and getmetatable(state) == cls
  end
  local function isList(state)
    local cls = listClass()
    return cls ~= nil and getmetatable(state) == cls
  end

  -- The engine's own kind strings (PlayerPC / BoxMenu), which the engine sets
  -- on the ListMenu it pushes and on the CHANGE BOX Menu.
  local PC_KINDS = {
    pc_item_withdraw = true, pc_item_deposit = true, pc_item_toss = true,
    pc_box_withdraw = true, pc_box_deposit = true, pc_box_release = true,
    pc_box_change = true,
  }

  -- BoxMenu's monSubmenu: the ACTION / STATS / CANCEL box the engine pushes
  -- OVER a box list when a stored mon is chosen (bills_pc.asm
  -- DisplayDepositWithdrawMenu).  It is a plain Menu -- no screen id and no
  -- kind -- so the pose is its identity: three rows whose SECOND is the STATS
  -- row, the one row carrying keepOpen.  Nothing else in the game answers that
  -- shape (the party menu's own STATS/SWITCH/CANCEL is a field on the party
  -- screen, not a pushed Menu; a shop's is BUY/SELL; the item PC's rows are
  -- four), so a menu that matches is this one -- and a mod that adds or removes
  -- a row simply stops matching, leaving the menu to the engine's own drawing
  -- rather than being mis-claimed.
  local function isMonSubmenu(state)
    if not isMenu(state) then return false end
    if state.screenId or state.kind or state.__g9pcMain then return false end
    local items = state.items
    if type(items) ~= "table" or #items ~= 3 then return false end
    local second, third = items[2], items[3]
    if type(second) ~= "table" or type(third) ~= "table" then return false end
    if not second.keepOpen then return false end
    if second.label ~= Strings("STATS") then return false end
    return third.label == Strings("CANCEL")
  end

  function M.isPc(state)
    if type(state) ~= "table" then return false end
    if Gen2 then return G2_SCREENS[state.screenId] ~= nil end
    if state.screenId == "BoxMenu" or state.screenId == "PlayerPC"
        or state.screenId == "LeaguePC" then
      return true
    end
    if state.__g9pcMain then return true end
    if type(state.kind) == "string" and PC_KINDS[state.kind] then return true end
    if isMonSubmenu(state) then return true end
    return false
  end

  -- ------------------------------------------------------------ decorate core
  -- Swap the surface trio and the drawing on the INSTANCE the engine built.
  -- The engine's own update keeps running (wrapped only to tick a frame
  -- counter for the pulsing chevrons), so the cursor, the keepOpen flow and
  -- every write are untouched.
  local function decorate(state, drawFn)
    if state.__g9pcDressed then return state end
    state.__g9pcDressed = true
    state.__g9gui = true
    state.isOpaque = true
    state.letterboxWhite = true
    state.__t = 0
    function state.uiSize() return W, H end
    state.isWideBattleLayout = Shell.wide
    function state.wantsFillScale(self) return Shell.wide(self) end
    function state.sgbPalettes() return {} end
    local baseUpdate = state.update
    state.update = function(self, dt)
      self.__t = (self.__t or 0) + 1
      if baseUpdate then baseUpdate(self, dt) end
    end
    state.draw = function(self) drawFn(self) end
    return state
  end

  function M.dress(state)
    if type(state) ~= "table" or state.__g9pcDressed then return end
    if Gen2 then
      local kind = G2_SCREENS[state.screenId]
      local drawFn = kind and G2_DRAW[kind]
      if not drawFn then return end
      state.__g9pcDressed = true
      state.__g9gui = true
      state.__t = 0
      local baseUpdate = state.update
      state.update = function(self, dt)
        self.__t = (self.__t or 0) + 1
        if baseUpdate then return baseUpdate(self, dt) end
      end
      -- S.gen2Surface installs :drawsWidescreen (so Game2 hands this state the
      -- WINDOW), :drawWidescreen (the suite page under its own transform) and a
      -- no-op :draw -- without that last one the stack pass Game2 runs under a
      -- text box would also call the engine's own classic :draw() and paint the
      -- cart's windows through the modern page (see ui/shell.lua).
      Shell.gen2Surface(Theme, state, function(s) drawFn(s) end)
      return
    end
    if isMenu(state) then
      if isMonSubmenu(state) then state.__g9pcMon = true end
      decorate(state, M.drawMenu)
    elseif isList(state) then
      decorate(state, M.drawList)
    elseif state.screenId == "LeaguePC" then
      -- the HALL OF FAME viewer: a bespoke classic screen, not a Menu/list
      decorate(state, M.drawLeague)
    end
    -- anything else carrying a pc kind (the CHANGE BOX confirmation TextBox)
    -- is left to the dialogue skin
  end

  -- ---------------------------------------------------------------- display
  local function display(s) return Shell.display(s) end

  -- A mon's own name as the player reads it: its nickname when it has one,
  -- else its SPECIES' display name (the record this suite renamed on load --
  -- see ui/display_names.lua), else the raw species id as a last resort.  The
  -- record read is what makes a form show its real name ("PONYTA") instead of
  -- its identifier ("PONYTA_GALAR").
  local function monName(mon, game)
    if type(mon) ~= "table" then return "?" end
    local def = game and game.data and game.data.pokemon
      and game.data.pokemon[mon.species]
    return mon.nickname or mon.name or (def and def.name) or mon.species or "?"
  end

  -- one-line caption for a menu row, matched on the engine's English source
  -- labels; an unrecognised (i.e. localized) label simply has no caption
  local function describe(label)
    local s = display(label or ""):upper()
    if s:find("LOG OFF") or s:find("SEE YA") then return "Turn the PC off." end
    if s:find("WITHDRAW") then
      if s:find("ITEM") then return "Take an item out of storage." end
      return "Take a POKéMON out of the Box."
    end
    if s:find("DEPOSIT") then
      if s:find("ITEM") then return "Put an item into storage." end
      return "Store a POKéMON in the Box."
    end
    if s:find("TOSS") then return "Throw an item away." end
    if s:find("RELEASE") then return "Set a POKéMON free." end
    if s:find("CHANGE BOX") then return "Pick the active POKéMON BOX." end
    if s:find("PRINT") then return "Print this Box list." end
    if s:find("LEAGUE") then return "View the HALL OF FAME." end
    if s:find("OAK") then return "Get your POKéDEX rated." end
    if s:find("'S PC") or s:find("S PC") then
      if s:find("SOMEONE") or s:find("BILL") then
        return "POKéMON storage system."
      end
      return "Item storage system."
    end
    return nil
  end

  local MENU_HINTS = {
    { key = "\xe2\x86\x91\xe2\x86\x93", text = "SELECT" },
    { key = "A", text = "OK" },
    { key = "B", text = "BACK" },
  }
  local LIST_HINTS = {
    { key = "\xe2\x86\x91\xe2\x86\x93", text = "SELECT" },
    { key = "A", text = "OK" },
    { key = "B", text = "BACK" },
  }

  -- the engine's two-row prompts ("What do you want\nto withdraw?") become a
  -- one-line caption
  local function oneLine(s)
    if type(s) ~= "string" then return s end
    return (s:gsub("[\r\n\v\f]+", " "):gsub("%s+$", ""))
  end

  -- ------------------------------------------------------- the mon submenu
  -- BoxMenu's monSubmenu: the ACTION / STATS / CANCEL box the engine pushes
  -- OVER a box list when a stored mon is chosen (bills_pc.asm
  -- DisplayDepositWithdrawMenu).  See isMonSubmenu above for the identity rule;
  -- this is the page it is drawn on.
  --
  -- The PC page the engine left underneath (a box list), or nil.  The mon
  -- submenu is pushed over it with keepOpen semantics, so the cart drew the
  -- submenu with the list still visible around it; the modern card keeps that
  -- context by repainting the list page under itself.
  local function listBeneath(self)
    local states = self.game and self.game.stack and self.game.stack.states
    if not states then return nil end
    for i = #states, 1, -1 do
      if states[i] == self then
        local under = states[i - 1]
        if type(under) == "table" and under.__g9gui then return under end
        return nil
      end
    end
    return nil
  end

  -- A centred card over the page beneath: one implementation for every popup
  -- in the PC (ui/shell.lua's S.card), so the mon submenu, the quantity stepper
  -- and the YES/NO the engine pushes over a page all read as the same design --
  -- and as one design with the list they belong to, instead of the cart's white
  -- square in the corner.
  local function pcCard(self, o)
    o.t = self.__t or 0
    Shell.card(Theme, self.game, o)
  end

  -- --------------------------------------------------------------- page draw
  local function pageBegin(self)
    local game = self.game
    local bg = opt("ui_background") ~= "false"
    local emb = opt("ui_embellishment") ~= "false"
    Backdrop.draw(Theme, {
      w = W, h = H, t = self.__t or 0,
      background = bg, embellishment = emb,
    })
    return game, emb
  end

  local function rowsFromItems(items)
    local rows = {}
    for i, it in ipairs(items or {}) do
      rows[#rows + 1] = {
        text = display(it.label or ""),
        dim = it.cancel and true or false,
      }
    end
    return rows
  end

  -- ":L12" (the engine's mon sub) -> "Lv 12"
  local function levelText(sub)
    if type(sub) ~= "string" then return nil end
    local n = sub:match(":L(%d+)")
    if n then return "Lv " .. n end
    return nil
  end

  function M.drawMenu(self)
    if self.__g9pcMon then
      -- The ACTION / STATS / CANCEL box the engine pushes OVER a box list
      -- (bills_pc.asm DisplayDepositWithdrawMenu).  The cart drew it as a small
      -- white square in the corner with the list still visible around it; here
      -- it is the suite's centred card, over that same list page -- so it reads
      -- as one design with the list instead of a leftover native window.
      local under = listBeneath(self)
      local list = (under and PC_KINDS[under.kind]
        and type(under.items) == "table") and under or nil
      if list then
        M.drawList(list)
      else
        pageBegin(self)
      end
      local rows = {}
      for i, it in ipairs(self.items or {}) do
        rows[#rows + 1] = { text = display(it.label or "") }
      end
      local title, right
      if list then
        local sel = list.items[list.index or 1]
        if sel and not sel.cancel then
          title = display(sel.label or "")
          right = levelText(sel.sub)
        end
      end
      if not title then
        local first = self.items and self.items[1]
        title = display((first and first.label) or "POKéMON")
      end
      pcCard(self, { title = title, right = right, rows = rows,
        index = self.index, w = 380 })
      Theme.set(Theme.col.white)
      return
    end

    local game, emb = pageBegin(self)
    local C = Theme.col
    local F = Theme.fonts(game)
    local sid = self.screenId

    local title, right, caption, rows, index, rowH

    if self.kind == "pc_box_change" then
      -- CHANGE BOX: a 12-row picker with the active Box marked and each Box's
      -- occupancy on the right (the classic menu drew the same information as
      -- ball tiles down its right edge).
      local box = game.save.currentBox or 1
      local boxes = nil
      local okB, B = pcall(require, "src.pokemon.Boxes")
      if okB and type(B) == "table" and type(B.ensure) == "function" then
        local okE, ensured = pcall(B.ensure, game.save)
        if okE then boxes = ensured end
      end
      rows = {}
      for i, it in ipairs(self.items or {}) do
        local count = boxes and boxes[i] and #boxes[i] or 0
        rows[#rows + 1] = {
          text = display(it.label or ("BOX%2d"):format(i)),
          right = (count > 0) and tostring(count) or nil,
          marker = (i == box),
        }
      end
      title = "CHANGE BOX"
      right = ("BOX %d ACTIVE"):format(box)
      caption = "Pick the active POKéMON BOX."
      index = self.index
      rowH = 20
      Shell.top(Theme, game, {
        title = title, right = right, caption = caption, embellish = emb,
      })
      Shell.list(Theme, game, {
        rows = rows, index = index, scroll = 0, t = self.__t or 0,
        x = MARGIN, y = Shell.CONTENT_Y, w = (W - MARGIN * 2),
        row = rowH, labelPad = 44, rightPad = 56, font = F.small,
      })
      Shell.footer(Theme, game, { hints = MENU_HINTS })
      Theme.set(C.white)
      return
    end

    -- The three menus share one shape: a titled row list with the selected
    -- row's description under it.
    rows = rowsFromItems(self.items)
    index = self.index - (self.scroll or 0)
    rowH = 32

    if sid == "PlayerPC" then
      title = "ITEM STORAGE"
      local store = game.save.pcItems or {}
      local stacks = 0
      for _ in pairs(store) do stacks = stacks + 1 end
      right = ("%d STACK%s"):format(stacks, stacks == 1 and "" or "S")
    elseif sid == "BoxMenu" then
      local metBill = false
      local flags = game.save.flags or {}
      metBill = flags.EVENT_MET_BILL or flags.EVENT_GOT_SS_TICKET
      title = metBill and "BILL'S PC" or "SOMEONE'S PC"
      local cap = game.data and game.data.field
        and (game.data.field.boxCapacity or game.data.field.pokemonBoxCap)
      local box = nil
      local okB, B = pcall(require, "src.pokemon.Boxes")
      if okB and type(B) == "table" and type(B.ensure) == "function" then
        local okE, ensured = pcall(B.ensure, game.save)
        if okE then box = ensured[(game.save.currentBox or 1)] end
      end
      local n = box and #box or 0
      right = ("BOX %d  %d/%d"):format(game.save.currentBox or 1, n,
        (cap or (okB and B.CAPACITY) or 20))
    else
      title = "PC"
      right = nil
    end

    local sel = self.items and self.items[self.index]
    caption = sel and describe(sel.label) or nil

    Shell.top(Theme, game, {
      title = title, right = right, caption = caption,
      money = (sid == "PlayerPC") and Shell.money(game) or nil,
      embellish = emb,
    })
    Shell.list(Theme, game, {
      rows = rows, index = index, scroll = 0, t = self.__t or 0,
      x = MARGIN, y = Shell.CONTENT_Y, w = W - MARGIN * 2,
      row = rowH, labelPad = 44, rightPad = 20,
    })
    Shell.footer(Theme, game, { hints = MENU_HINTS })
    Theme.set(C.white)
  end

  -- title / right per list kind
  local LIST_SPEC = {
    pc_item_withdraw = { title = "WITHDRAW ITEM" },
    pc_item_deposit = { title = "DEPOSIT ITEM" },
    pc_item_toss = { title = "TOSS ITEM" },
    pc_box_withdraw = { title = "WITHDRAW POKéMON", box = true },
    pc_box_deposit = { title = "DEPOSIT POKéMON", box = true },
    pc_box_release = { title = "RELEASE POKéMON", box = true },
  }

  function M.drawList(self)
    local game, emb = pageBegin(self)
    local C = Theme.col
    local spec = LIST_SPEC[self.kind] or { title = "PC" }
    local items = self.items or {}
    local n = #items
    -- The drawn window follows the CURSOR, not the engine's own self.scroll.
    -- A PC list is an itemBox ListMenu: its cursor window is only the top three
    -- rows (ListMenu's `cursorRows = 3`, wMaxMenuItem), so the ENGINE's scroll
    -- starts moving while the cursor is still on row 3 of its own slice.
    -- Reading self.scroll here (the first fix for the off-page panel) therefore
    -- pinned the arrow to row 3 for the rest of the list -- the rows slid
    -- beneath a cursor that never appeared to move.  The whole 8-row band is
    -- the cursor's window instead: the arrow walks all eight rows and the list
    -- only turns over at the bottom, the way every other list in the game does
    -- (the engine keeps its own index/scroll and every write; only the slice
    -- drawn here is ours).
    local win = math.max(0, (self.index or 1) - VISIBLE)
    local maxWin = math.max(0, n - VISIBLE)
    if win > maxWin then win = maxWin end
    local rows = {}
    for slot = 1, VISIBLE do
      local i = win + slot
      local it = items[i]
      if not it then break end
      local right = nil
      if not it.cancel then
        if it.count then
          right = ("\xc3\x97%d"):format(it.count)
        elseif levelText(it.sub) then
          right = levelText(it.sub)
        end
      end
      rows[#rows + 1] = {
        text = display(it.cancel and Strings("CANCEL") or (it.label or "")),
        right = right,
        dim = it.cancel and true or false,
      }
    end

    local caption = oneLine(self.footer)
    if not caption or caption == "" then
      caption = self.onChoose and nil or nil
    end
    local right = nil
    if spec.box then
      right = ("BOX %d"):format(game.save.currentBox or 1)
    end

    Shell.top(Theme, game, {
      title = spec.title, right = right, caption = caption,
      embellish = emb,
    })
    Shell.list(Theme, game, {
      rows = rows, index = (self.index or 1) - win, scroll = 0,
      t = self.__t or 0, x = MARGIN, y = Shell.CONTENT_Y,
      w = W - MARGIN * 2, row = 30, labelPad = 44, rightPad = 20,
      more = win + VISIBLE < n,
    })
    Shell.footer(Theme, game, { hints = LIST_HINTS })
    Theme.set(C.white)
  end

  -- ====================================================== Gen 2 (Gold) pages
  -- (every function below only ever runs on a Gold boot; on Gen 1 `Gen2` is
  -- false and none of it is reachable)
  --
  -- Gold's PC screens are bespoke classes, not Menu/ListMenu instances, so
  -- there is nothing to decorate field by field: the engine object keeps every
  -- byte of its own behaviour and only :draw / :drawWidescreen move.  The
  -- painters below read the engine's own fields (index, scroll, phase, rows,
  -- message, qtyState, confirm, saving phases) and call the engine's own
  -- accessors (`list`, `total`, `title`, `prompt`, `submenuRows`, `selected`,
  -- `listTotal`, `def`, `cantToss`, `box`, `count`, `savePages`,
  -- `saveYesNoVisible`, `picFor`, `panelColors`) so a change to the engine's
  -- model shows up here automatically.

  -- Gen 2 engine modules, required lazily and only on a Gold boot, so a Gen 1
  -- boot never pulls a Gold module in.
  local function gen2mod(path)
    if not Gen2 then return nil end
    local ok, v = pcall(require, path)
    if ok and type(v) == "table" then return v end
    return nil
  end
  local G2Typer = gen2mod("src.ui.gen2.Typer")
  local G2Save = gen2mod("src.core.gen2.Save")
  local G2Boxes, G2BoxesTried
  local function boxModel()
    if not G2BoxesTried then
      G2BoxesTried = true
      G2Boxes = gen2mod("src.core.gen2.Boxes") or false
    end
    return G2Boxes or nil
  end
  -- the item PC's DEPOSIT phase holds a Gen2PackMenu and draws it INSIDE this
  -- page (the engine's own arrangement: the PACK is this screen's chooser).
  -- ui/bag.lua publishes its page painter on the shared ctx for exactly this,
  -- so the deposit list is the same PACK page the START menu opens.
  local function bagScreen() return ctx.Bag end

  -- the panel geometry: a left rail of actions beside a right-hand card.  The
  -- rail is wider than the START screen's because the PC's own rows
  -- ("MOVE POKéMON W/O MAIL") are long words rather than short menu items.
  local RAIL_W = 328
  local PANEL_X = MARGIN + RAIL_W + 12
  local PANEL_W = W - MARGIN - PANEL_X

  -- ------------------------------------------------------------------ text
  -- An engine label can be a Strings source, a plain string, or a row table;
  -- all of them become display text (the cart's <PK><MN>/#MON macros expanded,
  -- ui/shell.lua's S.display).
  local function g2text(v)
    if v == nil then return nil end
    if type(v) == "table" then v = v.label end
    if v == nil then return nil end
    if type(v) == "string" then
      local s = display(v)
      return (s ~= "" and s) or nil
    end
    local ok, s = pcall(Strings, v)
    if ok and type(s) == "string" and s ~= "" and not s:find("^Source:") then
      return display(s)
    end
    return nil
  end

  -- An engine page as display lines.  A page may be a string (its \n and \v are
  -- line breaks) or a list of lines already.
  local function g2lines(page)
    local out = {}
    local function push(s)
      for part in (tostring(s):gsub("[\v\f]", "\n") .. "\n"):gmatch("(.-)\n") do
        out[#out + 1] = part
      end
    end
    if page == nil then return out end
    if type(page) == "string" then push(page)
    elseif type(page) == "table" then
      for _, line in ipairs(page) do push(line) end
    end
    return out
  end

  -- What the typer has revealed of a page so far (the engine's own typewriter
  -- effect, kept: the card types its lines in exactly as the cart's box did).
  local function g2typed(self, page)
    if G2Typer and type(G2Typer.text) == "function" then
      local ok, visible = pcall(G2Typer.text, self, page)
      if ok and type(visible) == "table" and #visible > 0 then
        local out = {}
        for _, line in ipairs(visible) do out[#out + 1] = line end
        return out
      end
    end
    return g2lines(page)
  end

  local function g2typing(self)
    if G2Typer and type(G2Typer.typing) == "function" then
      local ok, v = pcall(G2Typer.typing, self)
      if ok then return v and true or false end
    end
    return false
  end

  local function g2arrow(self)
    if G2Typer and type(G2Typer.arrowOn) == "function" then
      local ok, v = pcall(G2Typer.arrowOn, self)
      if ok then return v and true or false end
    end
    return ((self.__t or 0) % 40) < 20
  end

  -- ------------------------------------------------------------- page pieces
  local function g2begin(self)
    local game = self.game
    Backdrop.draw(Theme, {
      w = W, h = H, t = self.__t or 0,
      background = opt("ui_background") ~= "false",
      embellishment = opt("ui_embellishment") ~= "false",
    })
    return game, opt("ui_embellishment") ~= "false"
  end

  local function g2wash()
    local C = Theme.col
    Theme.set(C.black, 0.55)
    Theme.rect("fill", 0, 0, W, H, 0)
  end

  -- The suite's two-option answer: YES / NO as rows, LEFT/RIGHT working them as
  -- well as UP/DOWN (the engine's own two-option menus already read both on
  -- Gold, and this is the same promise the choice skin makes).
  local function g2yesno(self, x, y, w, choice, F, C)
    local labels = { g2text("YES") or "YES", g2text("NO") or "NO" }
    for i = 1, 2 do
      local ry = y + (i - 1) * 34
      local on = (choice or 1) == i
      if on then
        Theme.set(C.rowLit, 0.55)
        Theme.rect("fill", x + 12, ry - 3, w - 24, 30, 5)
        Theme.chevrons(x + 22, ry + 4, 18, C.accent,
          0.5 + 0.5 * math.sin((self.__t or 0) * 0.18))
      end
      Theme.text(labels[i], x + 52, ry + 1, F.body, "left",
        on and C.accent or C.ink)
    end
  end

  -- Word-wrap one string to a pixel budget.  A popup card is a fixed-width
  -- panel, so a prompt longer than the card has to wrap onto a second line
  -- rather than being cut to a stub with a trailing ellipsis.
  local function g2wrap(text, font, maxw)
    return Theme.wrap(text, font, maxw)
  end

  -- a centred popup card: an optional title, body lines, an optional row list
  -- with its own cursor, and an optional YES/NO pair under it.  Every Gen 2 PC
  -- message, quantity and question is drawn with this, so they read as one
  -- design.
  local function g2modal(self, F, C, o)
    local lines = o.lines or {}
    local rows = o.rows or {}
    local lh, rh = 28, 34
    local w = o.w or 380
    -- the body is wrapped to the card before its height is measured, so a long
    -- prompt grows the card instead of being cut
    local drawn = {}
    for _, line in ipairs(lines) do
      for _, sub in ipairs(g2wrap(line, F.body, w - 40)) do
        drawn[#drawn + 1] = sub
      end
    end
    local h = 22 + (o.title and 32 or 0)
      + #drawn * lh + #rows * rh + (o.yesno and 2 * rh or 0) + 22
    local x = math.floor((W - w) * 0.5)
    local y = math.floor((H - h) * 0.5)
    Theme.panel(x, y, w, h, { radius = 8, shadow = 8,
      color = C.panelLit, border = C.borderLit })
    if opt("ui_embellishment") ~= "false" then
      Theme.brackets(x + 5, y + 5, w - 10, h - 10, 18, C.accentDim)
    end
    local ty = y + 18
    if o.title then
      Theme.text(Theme.fit(o.title, F.small, w - 28), x + w * 0.5, ty,
        F.small, "center", C.accent)
      ty = ty + 32
    end
    for _, line in ipairs(drawn) do
      Theme.text(line, x + 22, ty, F.body, "left", C.ink)
      ty = ty + lh
    end
    if #rows > 0 then
      for i, row in ipairs(rows) do
        local on = i == (o.index or 1)
        if on then
          Theme.set(C.rowLit, 0.55)
          Theme.rect("fill", x + 12, ty - 3, w - 24, 30, 5)
          Theme.chevrons(x + 22, ty + 4, 18, C.accent,
            0.5 + 0.5 * math.sin((self.__t or 0) * 0.18))
        end
        Theme.text(Theme.fit(row, F.body, w - 76), x + 52, ty + 1, F.body,
          "left", on and C.accent or C.ink)
        ty = ty + rh
      end
    end
    if o.yesno then
      g2yesno(self, x, ty + 4, w, o.yesno, F, C)
    end
    if o.arrow and g2arrow(self) then
      local cx, cy = x + w - 26, y + h - 16
      Theme.set(C.accent, 0.6 + 0.4 * math.sin((self.__t or 0) * 0.2))
      love.graphics.polygon("fill", cx - 7, cy - 5, cx + 7, cy - 5, cx, cy + 5)
    end
  end

  -- a right-hand card of label / value rows (the player's own record beside the
  -- whose-PC list, the active BOX beside the storage menu).  `rows[i].value`
  -- prints gold on the right, `.header` prints a small faint heading, `.row`
  -- overrides the pitch.
  local function g2emblem(x, y, w, h, title, rows, F, C)
    Theme.panel(x, y, w, h, { radius = 8, shadow = 5, color = C.panel,
      border = C.border })
    if opt("ui_embellishment") ~= "false" then
      Theme.brackets(x + 4, y + 4, w - 8, h - 8, 16, C.accentDim)
    end
    Theme.text(Theme.fit(title, F.small, w - 24), x + w * 0.5, y + 12,
      F.small, "center", C.accent)
    Theme.rule(x + 14, y + 34, w - 28, C.border)
    local ry = y + 44
    for _, r in ipairs(rows) do
      if r.header then
        local label = r.text or (type(r.header) == "string" and r.header or "")
        local hf = F.small
        if Theme.w(label, hf) > w - 32 then hf = F.tiny end
        Theme.text(Theme.fit(label, hf, w - 32), x + 16, ry + 4, hf, "left",
          C.inkFaint)
      else
        -- the label and its value share one row inside a narrow panel: when
        -- the pair does not fit at the body size BOTH step down a rung, so a
        -- label is never cut to a stub like "MON…" beside a long ¥ figure
        local value = r.value
        local lf, vf = F.body, F.bold
        local vw = value and (Theme.w(value, vf) + 12) or 0
        if value and Theme.w(r.text, lf) > (w - 32 - vw) then
          lf, vf = F.small, F.smallBold
          vw = Theme.w(value, vf) + 12
        end
        local budget = w - 32 - vw
        Theme.text(Theme.fit(r.text, lf, budget), x + 16, ry, lf, "left",
          r.dim and C.inkFaint or C.ink)
        if value then
          Theme.text(value, x + w - 16, ry, vf, "right",
            r.dim and C.inkFaint or C.gold)
        end
      end
      ry = ry + (r.row or 26)
    end
  end

  -- the trainer's own record (the trainer card's figures, off Gold's own save
  -- summary reader so it can never disagree with the title screen's card)
  local function g2trainerRows(game)
    local save = game and game.save or {}
    local player = save.player or {}
    local badges, caught = 0, 0
    local time = "0:00"
    if G2Save and type(G2Save.summary) == "function" then
      local ok, s = pcall(G2Save.summary, save)
      if ok and type(s) == "table" then
        badges = s.badges or 0
        caught = s.caught or 0
        time = ("%d:%02d"):format(s.hours or 0, s.minutes or 0)
      end
    end
    return {
      { text = "PLAYER", value = tostring(player.name or "GOLD") },
      { text = "BADGES", value = ("%d"):format(badges) },
      { text = "POKéDEX", value = ("%d"):format(caught) },
      { text = "TIME", value = time },
      { text = "MONEY", value = ("¥%d"):format(player.money or save.money or 0) },
    }
  end

  -- a box's own name / occupancy, through the engine's own reader when it has
  -- one (Boxes.name / Boxes.count) and the save's raw tables otherwise
  local function g2boxName(save, i)
    local B = boxModel()
    if B and type(B.name) == "function" then
      local ok, n = pcall(B.name, save, i)
      if ok and type(n) == "string" and n ~= "" then return display(n) end
    end
    local names = save and save.boxNames
    local custom = names and names[i]
    if type(custom) == "string" and custom ~= "" then return display(custom) end
    return ("BOX%d"):format(i)
  end

  local function g2boxCount(save, i)
    local B = boxModel()
    if B and type(B.count) == "function" then
      local ok, n = pcall(B.count, save, i)
      if ok and type(n) == "number" then return n end
    end
    local boxes = save and save.boxes
    local box = boxes and boxes[i]
    return (type(box) == "table") and #box or 0
  end

  local function g2numBoxes(save)
    local B = boxModel()
    if B and type(B.NUM_BOXES) == "number" then return B.NUM_BOXES end
    local boxes = save and save.boxes
    return (type(boxes) == "table" and #boxes) or 14
  end

  local function g2boxCap(save)
    local B = boxModel()
    if B and type(B.MONS_PER_BOX) == "number" then return B.MONS_PER_BOX end
    local cap = save and save.boxCapacity
    return (type(cap) == "number" and cap) or 20
  end

  -- the selected mon's front pic, drawn into a panel at a whole multiple.  The
  -- engine's own pic is four-shade art and needs the mon's GBC palette
  -- (src.world.gen2.Palettes + src.render.GbcPalette); a sprites-mod frame
  -- answers trueColor and is drawn RAW -- the engine's own drawPic rule, and
  -- the reason ui/pokedex.lua's Gen 2 portrait reads the same way.
  local G2Pal
  local function g2pal()
    if G2Pal == nil then
      local okP, P = pcall(require, "src.world.gen2.Palettes")
      local okG, G = pcall(require, "src.render.GbcPalette")
      G2Pal = (okP and okG) and { P = P, G = G } or false
    end
    return G2Pal or nil
  end

  local function g2pic(self, img, trueColor, species, shiny, x, y, w, h)
    if not (img and img.getDimensions) then
      Theme.diamond(x + w * 0.5, y + h * 0.5, 9, Theme.col.accentDim)
      return
    end
    local iw, ih = img:getDimensions()
    -- REAL size: 1:1, the pixels the art was authored at, centred in the
    -- panel -- an integer divisor only when the pic outgrows the panel, never
    -- an up-scale.  Fitting it to the panel would draw every species at the
    -- same on-screen size, whatever its own art is (the "wrong size" look);
    -- the pack's own 1:1 rule (ui/portraits.lua) is the same one here.
    local bw, bh = w - 12, h - 12
    local scale = 1
    if iw > bw or ih > bh then
      scale = 1 / math.max(1, math.ceil(math.max(iw / bw, ih / bh)))
    end
    local dw, dh = iw * scale, ih * scale
    local dx, dy = x + (w - dw) * 0.5, y + (h - dh) * 0.5
    local G = love.graphics
    local function body()
      G.setColor(1, 1, 1, 1)
      G.draw(img, dx, dy, 0, scale, scale)
    end
    if trueColor then body() return end
    local pal = g2pal()
    local colors
    if pal then
      local ok, cols = pcall(pal.P.monColors, self.palettes, species, shiny)
      if ok then colors = cols end
    end
    if colors and pal.G.available and pal.G.available() then
      pal.G.with(colors, body)
    else
      body()
    end
  end

  -- ============================================================ POINTER PC
  -- The whose-PC menu: BILL's PC / <PLAYER>'s PC / PROF.OAK's PC / HALL OF FAME
  -- / TURN OFF, then its own message pages and its PROF.OAK rating YES/NO.
  function M.g2DrawCenter(self)
    local game, emb = g2begin(self)
    local F, C = Theme.fonts(game), Theme.col
    local entries = self.entries or {}
    local rows = {}
    for i, entry in ipairs(entries) do
      rows[#rows + 1] = { label = g2text(entry) or tostring(i) }
    end
    local sel = entries[self.index]
    Shell.top(Theme, game, {
      title = "PC",
      right = ("%d SYSTEM%s"):format(#rows, #rows == 1 and "" or "S"),
      caption = describe(g2text(sel) or "") or "Access whose PC?",
      money = Shell.money(game), embellish = emb,
    })
    if self.booted and #rows > 0 then
      Shell.rows(Theme, game, {
        items = rows, index = self.index, x = MARGIN, y = Shell.CONTENT_Y,
        w = RAIL_W, row = 34, t = self.__t or 0,
      })
      g2emblem(PANEL_X, Shell.CONTENT_Y, PANEL_W, 186, "TRAINER",
        g2trainerRows(game), F, C)
    end
    if self.confirm then
      g2wash()
      g2modal(self, F, C, {
        lines = g2lines(self.confirm.prompt), w = 420,
        yesno = self.confirm.choice,
      })
    elseif self.message then
      g2wash()
      local pages = self.message.pages or {}
      local at = self.message.page or 1
      g2modal(self, F, C, {
        lines = g2typed(self, pages[at]), w = 420,
        arrow = (at < #pages) and not g2typing(self),
      })
    end
    Shell.footer(Theme, game, { hints = {
      { key = "\xe2\x86\x91\xe2\x86\x93", text = "SELECT" },
      { key = "A", text = "OK" },
      { key = "B", text = "TURN OFF" },
    } })
    Theme.set(C.white)
  end

  -- ======================================================== STORAGE (BILL's PC)
  -- The storage system's own menu, its CHANGE BOX picker and the change-box
  -- save prompt (the save-data card with its YES/NO).
  function M.g2DrawStorage(self)
    local game, emb = g2begin(self)
    local F, C = Theme.fonts(game), Theme.col
    local save = self.save
    local box = (save and save.currentBox) or 1
    local total, cap = g2numBoxes(save), g2boxCap(save)
    local count = g2boxCount(save, box)
    local entries = self.entries or {}
    local rows = {}
    for i, entry in ipairs(entries) do
      rows[#rows + 1] = { label = g2text(entry) or tostring(i) }
    end
    local sel = entries[self.index]
    -- the active box's own contents, as the right-hand card
    local boxRows = {
      { header = ("BOX %d/%d"):format(box, total) },
      { text = "SLOTS", value = ("%d/%d"):format(count, cap) },
    }
    local list
    local B = boxModel()
    if B and type(B.box) == "function" then
      local ok, v = pcall(B.box, save, box)
      if ok and type(v) == "table" then list = v end
    end
    if not list then
      local boxes = save and save.boxes
      if type(boxes) == "table" then list = boxes[box] end
    end
    list = list or {}
    if #list == 0 then
      boxRows[#boxRows + 1] = { text = "(empty)", dim = true }
    else
      for i = 1, math.min(#list, 6) do
        local mon = list[i]
        boxRows[#boxRows + 1] = {
          text = display(monName(mon, game)),
          value = mon.level and ("Lv%d"):format(mon.level) or nil,
          row = 24,
        }
      end
    end

    if self.picking then
      local pick = self.pickIndex or 1
      local shown = math.min(8, total)
      local scroll = math.max(0, math.min(pick - shown, total - shown))
      local pros = {}
      for row = 1, shown do
        local i = row + scroll
        if i <= total then
          pros[#pros + 1] = {
            text = g2boxName(save, i),
            right = ("%d/%d"):format(g2boxCount(save, i), cap),
            marker = (i == box),
          }
        end
      end
      local title = self.savePhase and "SAVE DATA" or "CHANGE BOX"
      Shell.top(Theme, game, {
        title = title,
        right = ("%s  %d/%d"):format(g2boxName(save, pick), g2boxCount(save, pick), cap),
        caption = self.savePhase
          and "When you change a BOX, data will be saved."
          or "Which BOX?",
        money = Shell.money(game), embellish = emb,
      })
      Shell.list(Theme, game, {
        rows = pros, index = pick - scroll, scroll = 0, maxVisible = shown,
        x = MARGIN, y = Shell.CONTENT_Y, w = W - MARGIN * 2, row = 30,
        labelPad = 44, rightPad = 20, t = self.__t or 0,
        more = scroll + shown < total,
      })
      if self.savePhase then
        local pages, yesno = {}, false
        if type(self.savePages) == "function" then
          local ok, p = pcall(self.savePages, self)
          if ok and type(p) == "table" then pages = p end
        end
        local at = self.savePage or 1
        if type(self.saveYesNoVisible) == "function" then
          local ok, v = pcall(self.saveYesNoVisible, self, pages)
          yesno = ok and v and true or false
        end
        g2wash()
        g2modal(self, F, C, {
          title = "SAVE DATA",
          lines = g2typed(self, pages[at]),
          yesno = yesno and (self.saveChoice or 1) or nil,
          arrow = (not yesno) and (at < #pages) and not g2typing(self),
          w = 430,
        })
      else
        Shell.footer(Theme, game, { hints = {
          { key = "\xe2\x86\x91\xe2\x86\x93", text = "SELECT" },
          { key = "A", text = "OK" },
          { key = "B", text = "BACK" },
        } })
      end
      Theme.set(C.white)
      return
    end
    Shell.top(Theme, game, {
      title = "STORAGE",
      right = ("%s  %d/%d"):format(g2boxName(save, box), count, cap),
      caption = describe(g2text(sel) or "") or "What do you want to do?",
      money = Shell.money(game), embellish = emb,
    })
    Shell.rows(Theme, game, {
      items = rows, index = self.index, x = MARGIN, y = Shell.CONTENT_Y,
      w = RAIL_W, row = 34, t = self.__t or 0,
    })
    g2emblem(PANEL_X, Shell.CONTENT_Y, PANEL_W, 190, g2boxName(save, box),
      boxRows, F, C)
    if self.message then
      g2wash()
      local pages = self.messagePages or { self.message }
      local at = self.messagePage or 1
      g2modal(self, F, C, {
        lines = g2lines(pages[at]), w = 430,
        arrow = (at < #pages),
      })
    end
    Shell.footer(Theme, game, { hints = {
      { key = "\xe2\x86\x91\xe2\x86\x93", text = "SELECT" },
      { key = "A", text = "OK" },
      { key = "B", text = "SEE YA!" },
    } })
    Theme.set(C.white)
  end

  -- ========================================================= ITEM PC (PLAYER's)
  -- WITHDRAW / DEPOSIT / TOSS ITEM / MAIL BOX / LOG OFF, the item lists behind
  -- them, the quantity picker and the toss YES/NO.  DEPOSIT hands the window to
  -- the PACK (ui/bag.lua's Gen 2 page) the way the engine's own drawPanel did,
  -- with this screen's own popups over it.
  function M.g2DrawItems(self)
    local game, emb = g2begin(self)
    local F, C = Theme.fonts(game), Theme.col
    local phase = self.phase
    local listing = (phase == "withdraw" or phase == "toss")
    local listTotal = 1
    if type(self.listTotal) == "function" then
      local ok, v = pcall(self.listTotal, self)
      if ok and type(v) == "number" then listTotal = v end
    end
    local entry = self.entries and self.entries[self.index]
    local title, right, caption = "ITEM STORAGE", nil, nil
    -- DEPOSIT: the engine holds a Gen2PackMenu as this screen's chooser and
    -- draws it INSIDE this page (its own drawPanel did the same with the cart's
    -- pack panel), so the suite's PACK page IS the page here -- header, list,
    -- description and footer.  This screen then adds only its own popups over
    -- it; painting a second header/footer would double the title, the caption
    -- and the hint row.
    local packOwns = false
    if phase == "deposit" then
      local Bag = bagScreen()
      if Bag and type(Bag.drawGen2) == "function" and self.pack then
        packOwns = pcall(Bag.drawGen2, self.pack)
      end
    end
    if not packOwns then
      if listing then
        local kinds = math.max(0, listTotal - 1)
        title = (phase == "withdraw") and "WITHDRAW ITEM" or "TOSS ITEM"
        right = ("%d STACK%s"):format(kinds, kinds == 1 and "" or "S")
        local row = self.rows and self.rows[self.listIndex]
        local def
        if row and type(self.def) == "function" then
          local ok, v = pcall(self.def, self, row.id)
          if ok then def = v end
        end
        local desc = def and def.description
        if type(desc) == "string" and desc ~= "" then
          -- The engine's description is two lines split by <NEXT>; the caption
          -- rung holds one, so show its FIRST line whole rather than a
          -- fragment cut mid-sentence by the width budget.
          local shown = display(desc)
          caption = shown:match("^(.-)<NEXT>") or (shown:gsub("[\r\n]+", " "))
        end
        caption = caption or "Choose an item."
      else
        caption = describe(g2text(entry) or "") or "What do you want to do?"
      end
      Shell.top(Theme, game, {
        title = title, right = right, caption = caption,
        money = Shell.money(game), embellish = emb,
      })
    end

    if listing then
      -- Eight rows at row 30 is the content band (S.CONTENT_Y 66 ->
      -- S.FOOT_RULE_Y 314); a ninth row's panel would reach 340 and paint the
      -- footer out.
      local visible = 8
      local scroll = self.scroll or 0
      local src = self.rows or {}
      local rows = {}
      for slot = 1, visible do
        local i = scroll + slot
        local row = src[i]
        if row then
          local cant = false
          if type(self.cantToss) == "function" then
            local ok, v = pcall(self.cantToss, self, row.id)
            cant = ok and v or false
          end
          rows[#rows + 1] = {
            text = display(row.name or row.id or "?"),
            right = (not cant) and ("\xc3\x97%d"):format(row.count or 1) or nil,
            marker = (self.switching == i),
          }
        elseif i == listTotal then
          rows[#rows + 1] = { text = "CANCEL", dim = true }
        else
          break
        end
      end
      Shell.list(Theme, game, {
        rows = rows, index = (self.listIndex or 1) - scroll, scroll = 0,
        maxVisible = visible, more = scroll + visible < listTotal,
        x = MARGIN, y = Shell.CONTENT_Y, w = W - MARGIN * 2, row = 30,
        labelPad = 44, rightPad = 20, t = self.__t or 0,
      })
    elseif phase == "deposit" then
      -- when the PACK painter owns the page above this is unreachable; the
      -- fallback text only paints if the pack painter is missing or blew up
      if not packOwns then
        Theme.text("Choose an item to deposit.", W * 0.5, Shell.CONTENT_Y + 20,
          F.body, "center", C.inkFaint)
      end
    else
      local rows = {}
      for i, e in ipairs(self.entries or {}) do
        rows[#rows + 1] = { label = g2text(e) or tostring(i) }
      end
      local stacks, cap = 0, 50
      local store = self.save and self.save.pcItems or {}
      for _ in pairs(store) do stacks = stacks + 1 end
      Shell.rows(Theme, game, {
        items = rows, index = self.index, x = MARGIN, y = Shell.CONTENT_Y,
        w = RAIL_W, row = 34, t = self.__t or 0,
      })
      g2emblem(PANEL_X, Shell.CONTENT_Y, PANEL_W, 160, "PC STORAGE", {
        { text = "STACKS", value = ("%d/%d"):format(stacks, cap) },
        { header = "From your PACK," },
        { header = "or to your PACK." },
      }, F, C)
    end

    if self.qtyState then
      local q = self.qtyState
      g2wash()
      g2modal(self, F, C, {
        title = ("HOW MANY?   \xc3\x97%d"):format(q.qty or 1),
        lines = g2lines(q.prompt), w = 360,
      })
    elseif self.confirm then
      g2wash()
      g2modal(self, F, C, {
        lines = g2lines(self.confirm.prompt), w = 420,
        yesno = self.confirm.choice,
      })
    elseif self.message then
      g2wash()
      local pages = self.message.pages or {}
      local at = self.message.page or 1
      g2modal(self, F, C, {
        lines = g2typed(self, pages[at]), w = 420,
        arrow = (at < #pages) and not g2typing(self),
      })
    end

    local hints
    if self.qtyState then
      hints = { { key = "\xe2\x86\x91\xe2\x86\x93", text = "CHANGE" },
        { key = "\xe2\x86\x90\xe2\x86\x92", text = "TEN" },
        { key = "A", text = "OK" }, { key = "B", text = "BACK" } }
    elseif phase == "deposit" then
      hints = { { key = "\xe2\x86\x90\xe2\x86\x92", text = "POCKET" },
        { key = "A", text = "DEPOSIT" }, { key = "B", text = "BACK" } }
    else
      hints = { { key = "\xe2\x86\x91\xe2\x86\x93", text = "SELECT" },
        { key = "A", text = "OK" }, { key = "B", text = "BACK" } }
    end
    if not packOwns then
      Shell.footer(Theme, game, { hints = hints })
    end
    Theme.set(C.white)
  end

  -- =============================================================== BILL's BOX
  -- The box list: the left mon panel (portrait, level, gender, name), the five
  -- nickname rows, the MOVE / WITHDRAW / DEPOSIT / RELEASE / STATS submenu, the
  -- insert destination cursor and the timed hold.
  function M.g2DrawBox(self)
    local game, emb = g2begin(self)
    local F, C = Theme.fonts(game), Theme.col
    local mode = self.mode or "withdraw"
    local list, total = {}, 1
    if type(self.list) == "function" then
      local ok, v = pcall(self.list, self)
      if ok and type(v) == "table" then list = v end
    end
    if type(self.total) == "function" then
      local ok, v = pcall(self.total, self)
      if ok and type(v) == "number" then total = v end
    end
    local boxIndex = self.boxIndex or 1
    local title, prompt = "BILL's PC", nil
    if type(self.title) == "function" then
      local ok, v = pcall(self.title, self)
      if ok and type(v) == "string" then title = display(v) end
    end
    if type(self.prompt) == "function" then
      local ok, v = pcall(self.prompt, self)
      if ok and type(v) == "string" then prompt = display(v) end
    end
    local inserting = self.phase == "insert"
    if inserting then title = title .. "  \xe2\x86\x92" end
    local right
    if mode == "deposit" then
      right = ("PARTY %d/6"):format(#list)
    else
      right = ("BOX %d/%d   %d/%d"):format(boxIndex, g2numBoxes(self.save),
        #list, g2boxCap(self.save))
    end
    Shell.top(Theme, game, {
      title = title, right = right,
      caption = prompt or "Choose a POKéMON.", money = Shell.money(game),
      embellish = emb,
    })

    -- the left mon panel: the engine's own front pic at 1:1, then the level,
    -- gender and name, exactly the four things PCMonInfo prints
    local mon
    if type(self.panelMon) == "function" then
      local ok, v = pcall(self.panelMon, self)
      if ok then mon = v end
    end
    local PW = 186
    Theme.panel(MARGIN, Shell.CONTENT_Y, PW, 210, { radius = 8, shadow = 5,
      color = C.panel, border = C.border })
    local px, py = MARGIN + 10, Shell.CONTENT_Y + 10
    local pw, ph = PW - 20, 132
    Theme.set(C.voidDeep, 1)
    Theme.rect("fill", px, py, pw, ph, 6)
    if mon then
      -- The PACK's own front art first (the same art the party roster shows, and
      -- for an egg the pack's single egg picture): the engine's own pic is the
      -- fallback, used when g9-battle-sprites is not installed, has no sheet for
      -- this mon, or is still baking its first frame.  The engine draws its pic
      -- through the mon's GBC palette; the pack's art is true-colour, which is
      -- exactly the difference portraits.lua's own draw handles for the roster.
      local drawn = false
      if Portraits and type(Portraits.drawFront) == "function" then
        drawn = Portraits.drawFront(Theme, game, mon, px, py, pw, ph)
      end
      if not drawn then
        local img, trueColor, species = nil, nil, mon.species
        if mon.isEgg then
          local gfx = self.menuGfx and self.menuGfx.eggHatch
          if type(self.image) == "function" and gfx and gfx.egg then
            local ok, v = pcall(self.image, self, gfx.egg)
            if ok then img = v end
          end
        elseif type(self.picFor) == "function" then
          local ok, a, b = pcall(self.picFor, self, mon)
          if ok then img, trueColor = a, b end
        end
        g2pic(self, img, trueColor, species, mon.shiny, px, py, pw, ph)
      end
    end
    local ry = Shell.CONTENT_Y + 150
    if mon then
      local lv = (mon.level and ("Lv %d"):format(mon.level)) or ""
      local gender = (mon.gender == "male" and "\xe2\x99\x82")
        or (mon.gender == "female" and "\xe2\x99\x80") or ""
      Theme.text(lv .. " " .. gender, MARGIN + 12, ry, F.body, "left",
        C.gold)
      Theme.text(Theme.fit(display(monName(mon, game)), F.body, PW - 24),
        MARGIN + 12, ry + 26, F.body, "left", C.ink)
    else
      Theme.text("CANCEL", MARGIN + 12, ry, F.body, "left", C.inkFaint)
    end

    -- the nickname list (five rows, the engine's own window)
    local visible = 5
    local scroll = self.scroll or 0
    local rows = {}
    for slot = 1, visible do
      local i = scroll + slot
      local m = list[i]
      if m then
        local gender = (m.gender == "male" and " \xe2\x99\x82")
          or (m.gender == "female" and " \xe2\x99\x80") or ""
        rows[#rows + 1] = {
          text = display(monName(m, game)),
          right = m.level and (("Lv%d%s"):format(m.level, gender)) or nil,
        }
      elseif inserting then
        rows[#rows + 1] = { text = "\xe2\x80\xa6", dim = true }
      elseif i == total then
        rows[#rows + 1] = { text = "CANCEL", dim = true }
      else
        break
      end
    end
    local LX = MARGIN + PW + 12
    Shell.list(Theme, game, {
      rows = rows, index = (self.index or 1) - scroll, scroll = 0,
      maxVisible = visible, more = scroll + visible < total,
      x = LX, y = Shell.CONTENT_Y, w = W - MARGIN - LX, row = 34,
      labelPad = 42, rightPad = 18, t = self.__t or 0,
    })

    if self.phase == "submenu" then
      local labels = {}
      local subs = self.submenuRows
      if type(subs) == "function" then
        local ok, v = pcall(subs, self)
        if ok and type(v) == "table" then
          for i, row in ipairs(v) do labels[i] = display(row) end
        end
      end
      if #labels == 0 then labels = { "MOVE", "STATS", "CANCEL" } end
      g2wash()
      g2modal(self, F, C, { title = "WHAT'S UP?", rows = labels,
        index = self.submenuIndex or 1, w = 300 })
    elseif self.message then
      g2wash()
      g2modal(self, F, C, { lines = g2lines(self.message), w = 420 })
    end

    -- Each phase names its own keys through the hint chips, and the release key
    -- is a chip of its own: a notice in the footer's right readout is cut to
    -- the space the chips leave, which turned "SELECT: RELEASE" into
    -- "SELECT: RELEA…".
    local hints
    if mode == "withdraw" then
      hints = {
        { key = "\xe2\x86\x91\xe2\x86\x93", text = "SELECT" },
        { key = "SELECT", text = "RELEASE" },
        { key = "A", text = "OK" },
        { key = "B", text = "BACK" },
      }
    elseif inserting then
      hints = {
        { key = "\xe2\x86\x91\xe2\x86\x93", text = "SELECT" },
        { key = "\xe2\x86\x90\xe2\x86\x92", text = "BOX" },
        { key = "A", text = "PLACE" },
        { key = "B", text = "BACK" },
      }
    elseif mode == "move" then
      hints = {
        { key = "\xe2\x86\x91\xe2\x86\x93", text = "SELECT" },
        { key = "\xe2\x86\x90\xe2\x86\x92", text = "BOX" },
        { key = "A", text = "OK" },
        { key = "B", text = "BACK" },
      }
    else
      hints = {
        { key = "\xe2\x86\x91\xe2\x86\x93", text = "SELECT" },
        { key = "A", text = "OK" },
        { key = "B", text = "BACK" },
      }
    end
    Shell.footer(Theme, game, { hints = hints, gap = 18 })
    Theme.set(C.white)
  end

  -- ================================================================ MAILBOX
  function M.g2DrawMail(self)
    local game, emb = g2begin(self)
    local F, C = Theme.fonts(game), Theme.col
    local box, total = {}, 1
    if type(self.box) == "function" then
      local ok, v = pcall(self.box, self)
      if ok and type(v) == "table" then box = v end
    end
    if type(self.count) == "function" then
      local ok, v = pcall(self.count, self)
      if ok and type(v) == "number" then total = v end
    end
    Shell.top(Theme, game, {
      title = "MAIL BOX",
      right = ("%d MAIL"):format(total),
      caption = "Read or clear stored MAIL.", money = Shell.money(game),
      embellish = emb,
    })
    local visible = 8   -- the content band's own row budget (see g2DrawItems)
    local scroll = self.scroll or 0
    local rows = {}
    for slot = 1, visible do
      local i = scroll + slot
      local entry = box[i]
      if entry then
        rows[#rows + 1] = { text = display(entry.author or "\xe2\x80\xa6") }
      else
        break
      end
    end
    if #rows == 0 then
      rows[1] = { text = "No MAIL here.", dim = true }
    end
    Shell.list(Theme, game, {
      rows = rows, index = (self.index or 1) - scroll, scroll = 0,
      maxVisible = visible, more = scroll + visible < total,
      x = MARGIN, y = Shell.CONTENT_Y, w = W - MARGIN * 2, row = 30,
      labelPad = 42, t = self.__t or 0,
    })

    local sub = self.submenu
    if self.message then
      g2wash()
      local pages = self.message.pages or { self.message }
      local at = self.message.page or 1
      g2modal(self, F, C, {
        lines = g2lines(pages[at]), w = 420,
        arrow = (at < #pages),
      })
    elseif self.confirm then
      g2wash()
      local pages = self.confirm.pages or {}
      local at = self.confirm.page or 1
      g2modal(self, F, C, {
        lines = g2lines(pages[at]), w = 420,
        yesno = (at >= #pages) and (self.confirm.choice or 1) or nil,
        arrow = (at < #pages),
      })
    elseif sub then
      -- the engine's own .SubMenuData, off the class (the instance has only
      -- the cursor): READ MAIL / PUT IN PACK / ATTACH MAIL / CANCEL
      local labels = {}
      local cls = getmetatable(self)
      local entries = (type(cls) == "table" and cls.SUB_ENTRIES) or nil
      if type(entries) == "table" then
        for i, entry in ipairs(entries) do
          labels[i] = g2text(entry) or g2text(entry and entry.id) or tostring(i)
        end
      end
      if #labels == 0 then labels = { "READ MAIL", "PUT IN PACK",
        "ATTACH MAIL", "CANCEL" } end
      g2wash()
      g2modal(self, F, C, { title = "MAIL", rows = labels,
        index = sub.index or 1, w = 300 })
    end
    Shell.footer(Theme, game, { hints = {
      { key = "\xe2\x86\x91\xe2\x86\x93", text = "SELECT" },
      { key = "A", text = "OK" },
      { key = "B", text = "BACK" },
    } })
    Theme.set(C.white)
  end

  G2_DRAW.center = M.g2DrawCenter
  G2_DRAW.storage = M.g2DrawStorage
  G2_DRAW.items = M.g2DrawItems
  G2_DRAW.box = M.g2DrawBox
  G2_DRAW.mail = M.g2DrawMail

  -- =========================================================== LEAGUE PC
  -- The HALL OF FAME viewer (engine/menus/league_pc.asm): a bespoke classic
  -- screen the engine pushes from the whose-PC menu.  A steps to the next mon /
  -- team, B closes; there is no cursor and no list, so it is neither a Menu nor
  -- a ListMenu -- it is recognised by its screenId and given this painter.  The
  -- engine keeps running its own :update (the A/B flow and the cry), so this
  -- only replaces the surface: the recorded mon's own front art at REAL size,
  -- its LEVEL/TYPE record, and the team's "No N" index -- the modern page of
  -- exactly the data HallOfFame.drawMonInfo prints on the cart.
  function M.drawLeague(self)
    local game, emb = pageBegin(self)
    local C = Theme.col
    local F = Theme.fonts(game)
    local mon = type(self.currentMon) == "function" and self:currentMon() or nil
    local teams = self.teams or {}
    local team = teams[self.teamIndex or 1] or {}
    local def = mon and game.data and game.data.pokemon
      and game.data.pokemon[mon.species] or nil

    Shell.top(Theme, game, {
      title = "HALL OF FAME",
      right = ("No %d"):format(self.teamIndex or 1),
      caption = mon and (("TEAM %d/%d  MEMBER %d/%d"):format(
        self.teamIndex or 1, #teams, self.monIndex or 1, #team))
        or "No team recorded.",
      embellish = emb,
    })

    -- Left mon panel: the recorded mon's front art at its own REAL size, with
    -- the same rule the PACK and the POKeDEX use -- the pack's whole frame when
    -- a sprites mod answers, else the engine's own HoF pic, else a lozenge.
    local PW = 196
    Theme.panel(MARGIN, Shell.CONTENT_Y, PW, 210, { radius = 8, shadow = 5,
      color = C.panel, border = C.border })
    local px, py = MARGIN + 10, Shell.CONTENT_Y + 10
    local pw, ph = PW - 20, 132
    Theme.set(C.voidDeep, 1)
    Theme.rect("fill", px, py, pw, ph, 6)
    if mon then
      local drawn = false
      if Portraits and type(Portraits.drawFront) == "function" then
        drawn = Portraits.drawFront(Theme, game, mon, px, py, pw, ph)
      end
      if not drawn then
        local img = self.sprites and self.sprites[mon.species] or nil
        local trueColor = self.spriteTrueColor
          and self.spriteTrueColor[mon.species] or nil
        g2pic(self, img, trueColor, mon.species, mon.shiny, px, py, pw, ph)
      end
    end
    local ry = Shell.CONTENT_Y + 150
    if mon then
      local lv = (mon.level and ("Lv %d"):format(mon.level)) or ""
      Theme.text(lv, MARGIN + 12, ry, F.body, "left", C.gold)
      Theme.text(Theme.fit(display(mon.nickname or (def and def.name)
        or mon.species or "?"), F.body, PW - 24), MARGIN + 12, ry + 26,
        F.body, "left", C.ink)
    else
      Theme.text("No record.", MARGIN + 12, ry, F.body, "left", C.inkFaint)
    end

    -- Right card: the mon's record -- the four fields HoFDisplayMonInfo prints
    -- (name / level / type 1 / type 2).  The type names come through the engine's
    -- own reader so a localized game prints its own names, with the raw id as
    -- the fallback when TypeChart is absent (a stripped boot).
    local rx = MARGIN + PW + 12
    local rows = {}
    if mon then
      local okT, TypeChart = pcall(require, "src.battle.TypeChart")
      local function tn(t)
        if not t then return nil end
        if okT and type(TypeChart) == "table"
            and type(TypeChart.displayName) == "function" then
          local okD, s = pcall(TypeChart.displayName, t, game.data)
          if okD and type(s) == "string" then return display(s) end
        end
        return display(tostring(t))
      end
      local name = display(mon.nickname or (def and def.name)
        or mon.species or "?")
      local t1 = def and def.types and def.types[1]
      local t2 = def and def.types and def.types[2]
      rows[#rows + 1] = { text = "NAME", value = name }
      rows[#rows + 1] = { text = "LEVEL", value = tostring(mon.level or "?") }
      rows[#rows + 1] = { text = "TYPE 1", value = tn(t1) or "?" }
      if t2 and t2 ~= t1 then
        rows[#rows + 1] = { text = "TYPE 2", value = tn(t2) }
      end
    else
      rows[1] = { text = "No POKéMON recorded.", dim = true }
    end
    g2emblem(rx, Shell.CONTENT_Y, W - MARGIN - rx, 190, "RECORD", rows, F, C)

    Shell.footer(Theme, game, { hints = {
      { key = "A", text = "NEXT" },
      { key = "B", text = "BACK" },
    } })
    Theme.set(C.white)
  end

  -- ------------------------------------------------------------- openPC wrap
  -- The Pokecenter PC's TOP menu is a Menu built inline in
  -- OverworldState:openPC.  It carries no screen id and no kind, and it is
  -- pushed only LATER -- from the "turned on the PC" text box's own callback --
  -- so we cannot see it at openPC's own stack position.  Wrapping openPC lets
  -- us mark the one Menu it builds (Menu.new is called exactly once there) and
  -- the push wrapper dresses it when it finally arrives.
  local openDepth = 0
  function M.installOpenPc()
    if Gen2 then return false end
    local ok, OW = pcall(require, "src.world.OverworldController")
    if not (ok and type(OW) == "table" and type(OW.openPC) == "function") then
      return false
    end
    if OW.__g9pcOpenWrapped then return true end
    local cls = menuClass()
    if cls == nil or type(cls.new) ~= "function" then return false end
    OW.__g9pcOpenWrapped = true
    local baseOpen = OW.openPC
    local baseNew = cls.new
    OW.openPC = function(self, onDone)
      openDepth = openDepth + 1
      cls.new = function(game, items, opts)
        local menu = baseNew(game, items, opts)
        if openDepth > 0 and type(menu) == "table" then
          menu.__g9pcMain = true
        end
        return menu
      end
      local okRun, err = pcall(baseOpen, self, onDone)
      cls.new = baseNew
      openDepth = openDepth - 1
      if not okRun then error(err) end
    end
    return true
  end

  return M
end
