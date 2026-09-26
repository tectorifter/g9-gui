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

  -- ui/pc.lua's own fallback front-pic painter for the box page's mon card (the
  -- Gen 2 arm's picFor reader).  Forward-declared because the grid page -- which
  -- every generation's box arm draws -- is defined before the Gold section that
  -- assigns it.
  local g2pic

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

  -- The three of those that are BILL's PC's own mon lists -- the storage box's
  -- withdraw / deposit / release pages.  They are drawn as the modern box GRID
  -- (M.drawBoxList) rather than as the classic nickname rows; the item lists
  -- above them keep the row page.
  local BOX_LIST_KINDS = {
    pc_box_withdraw = true, pc_box_deposit = true, pc_box_release = true,
  }

  -- The engine builds these lists out of plain view rows (src/ui/BoxMenu.lua's
  -- monRow: label, :L<level>, the slot index in `value`), so a row carries no
  -- MON.  The modern slot page reads the save's arrays directly and needs none,
  -- but the engine's own mon-submenu card (isMonSubmenu) and any mod reading a
  -- pushed list still expect the pair, so each row's mon is resolved ONCE, at
  -- the push, and hung on the row.
  local function enrichBoxItems(state)
    local game = state and state.game
    local save = game and game.save
    if not save then return end
    local items = state.items
    if type(items) ~= "table" then return end
    local deposit = (state.kind == "pc_box_deposit")
    local box
    if not deposit then
      local okB, B = pcall(require, "src.pokemon.Boxes")
      if okB and type(B) == "table" and type(B.active) == "function" then
        local okA, v = pcall(B.active, save)
        if okA and type(v) == "table" then box = v end
      end
    end
    for _, it in ipairs(items) do
      if type(it) == "table" and not it.cancel and it.mon == nil then
        local slot = tonumber(it.value)
        local mon
        if slot then
          if deposit then
            mon = save.party and save.party[slot]
          elseif box then
            mon = box[slot]
          end
        end
        if mon then it.mon = mon end
      end
    end
  end

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
  -- `updateFn` replaces the engine's own update where the page owns its cursor
  -- and its writes (the box SLOT page, both generations); without it the engine
  -- update keeps running beneath the frame ticker.
  local function decorate(state, drawFn, updateFn)
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
      if updateFn then return updateFn(self) end
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
      -- the storage menu's DEPOSIT POKéMON row is gone: depositing is done on
      -- the slot page by moving a party mon into a box (see M.g2TameStorage)
      if kind == "storage" then M.g2TameStorage(state) end
      state.__g9pcDressed = true
      state.__g9gui = true
      state.__t = 0
      local baseUpdate = state.update
      state.update = function(self, dt)
        -- BILL's BOX: the slot page owns its own cursor and its own writes
        -- (see M.g2BoxUpdate), so the engine's packed-list model is not driven
        -- at all here -- the whole update is replaced, not wrapped.
        self.__t = (self.__t or 0) + 1
        if kind == "box" then return M.g2BoxUpdate(self) end
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
      -- BILL's PC's own menu: retune its MOVE/DEPOSIT rows (see
      -- M.g1TameBoxMenu) before the page takes over
      if state.screenId == "BoxMenu" then M.g1TameBoxMenu(state) end
      decorate(state, M.drawMenu)
    elseif isList(state) then
      if BOX_LIST_KINDS[state.kind] then
        -- a Bill's PC mon list is the modern SLOT page on Gen 1 too: it owns
        -- its own cursor and its own writes (see M.g1BoxUpdate), so the
        -- engine's packed ListMenu model is never driven.  Each row's own MON
        -- is resolved once here for the legacy engine mon-submenu card.
        enrichBoxItems(state)
        decorate(state, M.drawList, M.g1BoxUpdate)
      else
        decorate(state, M.drawList)
      end
    elseif state.screenId == "LeaguePC" then
      -- the HALL OF FAME viewer: a bespoke classic screen, not a Menu/list
      decorate(state, M.drawLeague)
    end
    -- anything else carrying a pc kind (the CHANGE BOX confirmation TextBox)
    -- is left to the dialogue skin
  end

  -- ---------------------------------------------------------------- display
  local function display(s) return Shell.display(s) end

  -- A single word of the suite's own chrome, localized through the translation
  -- layer (ui/shell.lua's S.ui).  The COMPOSED readouts -- "BOX 1/50",
  -- "PARTY 6/6", the ACTIVE-BOX line -- are one string the lexicon cannot match
  -- as a whole, so their WORDS are looked up here and the figures spliced in.
  local function word(s) return Shell.ui(s) end

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

  -- The Bill's PC row that opens the box page is called MOVE now -- the page IS
  -- a move/slot page -- so its engine label ("WITHDRAW POKéMON") is renamed on
  -- the way to the screen.  The item PC's "WITHDRAW ITEM" is a different screen
  -- and is left alone (the pattern only matches "WITHDRAW POK").
  local function pcMoveLabel(label)
    if type(label) ~= "string" then return label end
    local out = (label:gsub("^WITHDRAW POK", "MOVE POK"))
    if out == "WITHDRAW" then out = "MOVE" end
    return out
  end

  -- one-line caption for a menu row, matched on the engine's English source
  -- labels; an unrecognised (i.e. localized) label simply has no caption
  local function describe(label)
    local s = display(label or ""):upper()
    if s:find("LOG OFF") or s:find("SEE YA") then return "Turn the PC off." end
    if s:find("W/O MAIL") then return "Move a POKéMON without MAIL." end
    if s == "MOVE" then return "Move a POKéMON between BOXes." end
    if s:find("MOVE POK") then return "Move a POKéMON between BOXes." end
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

  -- forward declaration: the grid painter below runs before the page helpers
  -- (pageBegin) are defined further down, but is only *called* later, so a
  -- forward local keeps pageBegin in its lexical scope
  local pageBegin

  -- ============================================================ the box GRID
  -- THE MODERN BOX PAGE.  Bill's PC's box is drawn the way every game from
  -- Generation III on draws it: a WALL of cells -- one per storage slot, each
  -- holding the creature's own mini-icon -- instead of the classic column of
  -- nickname rows (or, on Gold, the nickname rows beside a mon panel) this page
  -- used to be.  Each generation's box page owns its own cursor and its own
  -- writes now -- the engine's packed list is not driven (see M.g1BoxUpdate for
  -- Gen 1 and M.g2BoxUpdate for Gold) -- and both arms call the one painter
  -- below, so the two can never drift apart.
  --
  -- Geometry.  The left third is the mon card -- the modern PC's PKMN DATA
  -- panel: the selected creature's front art, its name, its level and its
  -- types.  The right two thirds are the grid, with the BOX banner (the loaded
  -- box's own name, with the switch arrows beside it) as a strip above it.
  -- Six columns is the modern PC's own column count; `spec.cellH` lets each
  -- caller size the wall's rows for its own `Boxes.CAPACITY` (five rows at 30
  -- with g9-boxes, four at the bare 20).
  local COLS = 6
  local DETAIL_W = 156
  local CELL_GAP = 4
  -- the icon's inset inside its slot face.  The slot is small (52x38 at 30
  -- slots) and the pack's creature has to be READ in it, so the padding is
  -- tight: every pixel here is a pixel the icon loses (portraits.lua crops the
  -- pack's transparent cell margins away and fits the creature to this window)
  local CELL_PAD = 3
  local GRID_X = MARGIN + DETAIL_W + 12
  local GRID_W = (W - MARGIN) - GRID_X
  local STRIP_Y = Shell.CONTENT_Y
  local STRIP_H = 30
  local GRID_Y = Shell.CONTENT_Y + STRIP_H + 4
  local GRID_H = Shell.FOOT_RULE_Y - GRID_Y
  local CELL_W = math.floor(GRID_W / COLS)
  local CELL_H = math.floor(GRID_H / 4)
  local DETAIL_H = Shell.FOOT_RULE_Y - Shell.CONTENT_Y

  -- The box's own capacity, off whatever the game data exposes (a mod may raise
  -- it) and off the engine's own constant as the fallback.
  local function boxCapacity(game)
    local f = game and game.data and game.data.field
    local n = f and (f.boxCapacity or f.pokemonBoxCap)
    if type(n) == "number" and n > 0 then return n end
    local okB, B = pcall(require, "src.pokemon.Boxes")
    if okB and type(B) == "table" and type(B.CAPACITY) == "number" then
      return B.CAPACITY
    end
    return 20
  end

  -- A single vector arrow.  The bundled face (Saira, and Plain Pixel before it)
  -- has no U+25C0/U+25B6 glyphs, so the banner's switch arrows are triangles --
  -- the same choice Theme.hints makes for an arrow key.
  local function arrow(dir, cx, cy, r, color)
    Theme.set(color or Theme.col.accent)
    if dir == "left" then
      love.graphics.polygon("fill", cx - r, cy, cx + r * 0.6, cy - r,
        cx + r * 0.6, cy + r)
    else
      love.graphics.polygon("fill", cx + r, cy, cx - r * 0.6, cy - r,
        cx - r * 0.6, cy + r)
    end
  end

  -- A mon's own type names, through the engine's reader so a localized game
  -- prints its own words; nil when the record has no types (a stripped boot, or
  -- a mon the data does not know).  Mirrors the HALL OF FAME painter's rule.
  local function monTypes(game, mon)
    local data = game and game.data
    local def = data and data.pokemon and data.pokemon[mon and mon.species]
    local types = def and def.types
    if type(types) ~= "table" then return nil end
    local okT, TypeChart = pcall(require, "src.battle.TypeChart")
    local function tn(t)
      if t == nil then return nil end
      if okT and type(TypeChart) == "table"
          and type(TypeChart.displayName) == "function" then
        local okD, s = pcall(TypeChart.displayName, t, game.data)
        if okD and type(s) == "string" and s ~= "" then return display(s) end
      end
      return display(tostring(t))
    end
    local a, b = tn(types[1]), tn(types[2])
    if not a then return nil end
    if b and b ~= a then return a .. "/" .. b end
    return a
  end

  -- The selected creature's front art in the card's window, as the WHOLE
  -- creature at its own pixels (real size, whole-integer steps -- the suite's
  -- one size rule), from the pack first and the engine's own pic as the
  -- fall-back, the same order every other portrait here uses.
  local function monArt(self, game, mon, x, y, w, h)
    if Portraits and type(Portraits.drawFront) == "function" then
      if Portraits.drawFront(Theme, game, mon, x, y, w, h) then return true end
    end
    if Gen2 and type(self.picFor) == "function" and g2pic then
      local ok, img, trueColor = pcall(self.picFor, self, mon)
      if ok and img then
        g2pic(self, img, trueColor, mon.species, mon.shiny, x, y, w, h)
        return true
      end
      return false
    end
    local okS, Sprites = pcall(require, "src.pokemon.Sprites")
    local okA, Assets = pcall(require, "src.render.Assets")
    if not (okS and okA and type(Sprites) == "table") then return false end
    local okP, path = pcall(Sprites.path, game.data, mon.species, "front",
      { mon = mon, kind = "summary" })
    if not (okP and path) then return false end
    local okI, img = pcall(Assets.image, path)
    if not (okI and img) then return false end
    local iw, ih = img:getDimensions()
    if not (iw and ih and iw > 0 and ih > 0) then return false end
    local d = 1
    if iw > w or ih > h then
      d = math.max(1, math.ceil(math.max(iw / w, ih / h)))
    end
    local s = 1 / d
    Theme.set(Theme.col.white)
    love.graphics.draw(img, math.floor(x + (w - iw * s) * 0.5),
      math.floor(y + (h - ih * s) * 0.5), 0, s, s)
    return true
  end

  -- The mon card: the art window, then the four lines the modern PC's panel
  -- prints -- name, species, level + gender, types.
  local function drawMonCard(self, game, mon, x, y, w, h)
    local C, F = Theme.col, Theme.fonts(game)
    Theme.panel(x, y, w, h, { radius = 8, shadow = 5, color = C.panel,
      border = C.border })
    if opt("ui_embellishment") ~= "false" then
      Theme.brackets(x + 4, y + 4, w - 8, h - 8, 16, C.accentDim)
    end
    local px, py = x + 11, y + 13
    local pw, ph = w - 22, 116
    Theme.set(C.voidDeep, 1)
    Theme.rect("fill", px, py, pw, ph, 6)
    if mon and not monArt(self, game, mon, px, py, pw, ph) then
      Theme.diamond(px + pw * 0.5, py + ph * 0.5, 8, C.accentDim)
    end
    local ty = py + ph + 12
    if not mon then
      Theme.text("—", x + 12, ty, F.body, "left", C.inkFaint)
      return
    end
    -- the name steps DOWN a size rather than being cut: the PKMN DATA panel
    -- must always show the whole name, and Theme.fit's ellipsis would leave a
    -- half-word where the player expects their own creature's name
    local nm = display(monName(mon, game))
    local nf = F.body
    if Theme.w(nm, F.body) > w - 24 then nf = F.small end
    if Theme.w(nm, nf) > w - 24 then nf = F.tiny end
    Theme.text(Theme.fit(nm, nf, w - 24), x + 12, ty, nf, "left", C.ink)
    ty = ty + 26
    local data = game and game.data
    local def = data and data.pokemon and data.pokemon[mon.species]
    local sp = display((def and def.name) or mon.species or "")
    Theme.text(Theme.fit("/" .. sp, F.small, w - 24), x + 12, ty, F.small,
      "left", C.inkFaint)
    ty = ty + 20
    local lv = mon.level and ("Lv%d"):format(mon.level) or "Lv?"
    Theme.text(lv, x + 12, ty, F.body, "left", C.gold)
    local gender = (mon.gender == "male" and "\xe2\x99\x82")
      or (mon.gender == "female" and "\xe2\x99\x80") or nil
    if gender then
      Theme.text(gender, x + w - 14, ty, F.body, "right",
        mon.gender == "female" and C.bad or C.accent)
    end
    ty = ty + 28
    local types = monTypes(game, mon)
    if types then
      Theme.text(Theme.fit(types, F.small, w - 24), x + 12, ty, F.small,
        "left", C.inkDim)
    end
  end

  -- One grid cell: the slot's face, the creature's mini-icon when the slot
  -- holds one, its held-item pip, and the cursor's own lit face + accent border.
  local function drawCell(game, x, y, item, selected, F, ch)
    local C = Theme.col
    local cellH = ch or CELL_H
    local fx = x + CELL_GAP * 0.5
    local fy = y + CELL_GAP * 0.5
    local fw = CELL_W - CELL_GAP
    local fh = cellH - CELL_GAP
    local mon = item and item.mon or nil
    if selected then
      Theme.panel(fx, fy, fw, fh, { radius = 6, shadow = 3,
        color = C.panelLit, border = C.borderLit })
    else
      Theme.set(C.panelDeep, mon and 0.85 or 0.45)
      Theme.rect("fill", fx, fy, fw, fh, 6)
      Theme.set(C.border, mon and 0.55 or 0.32)
      Theme.rect("line", fx + 0.5, fy + 0.5, fw - 1, fh - 1, 5)
    end
    if mon then
      local iw, ih = fw - CELL_PAD * 2, fh - CELL_PAD * 2
      local drew = Portraits and type(Portraits.drawIcon) == "function"
        and Portraits.drawIcon(Theme, game, mon, fx + CELL_PAD, fy + CELL_PAD,
          iw, ih)
      if not drew then
        Theme.diamond(fx + fw * 0.5, fy + fh * 0.5, 7, C.accentDim)
      end
      local held = mon.heldItem or mon.item
      if type(held) == "number" and held > 0 then
        Theme.set(C.gold)
        Theme.rect("fill", fx + fw - 13, fy + fh - 13, 5, 5, 2)
      end
    elseif item and item.cancel then
      Theme.text(Theme.fit(display(item.text or Strings("CANCEL")), F.tiny,
        fw - 4), fx + fw * 0.5, fy + (fh - Theme.capOf(F.tiny)) * 0.5,
        F.tiny, "center", selected and C.accent or C.inkFaint)
    end
    if selected then
      Theme.set(C.accent, 0.85)
      Theme.rect("line", fx + 0.5, fy + 0.5, fw - 1, fh - 1, 6)
    end
  end

  -- The whole page.  `spec` carries the view each arm builds out of its own
  -- engine state:
  --   items        { { mon=, text=, cancel= }, ... }  one per engine row
  --   index        the engine's cursor, counted in those rows
  --   boxLabel     the banner's name (a box's own name, or "PARTY POKéMON")
  --   canSwitchBox draw the banner's ◀ ▶ (the caller handles L/R itself)
  --   detail       the mon the card shows (nil on the CANCEL row, and while a
  --                Gold message has cleared the panel)
  --   hints        the footer chips
  local function drawBoxGrid(self, game, spec)
    local C, F = Theme.col, Theme.fonts(game)
    local items = spec.items or {}
    local index = spec.index or 0

    -- the box banner: the modern PC's own header strip, naming the loaded box
    local sx, sw = GRID_X + 30, GRID_W - 60
    Theme.panel(sx, STRIP_Y, sw, STRIP_H, { radius = 6, shadow = 2,
      color = C.panelLit, border = C.border })
    local label = Theme.fit(display(spec.boxLabel or ""), F.body, sw - 76)
    Theme.text(label, sx + sw * 0.5, STRIP_Y + 7, F.body, "center", C.accent)
    if spec.canSwitchBox then
      arrow("left", sx + 17, STRIP_Y + STRIP_H * 0.5, 7, C.accent)
      arrow("right", sx + sw - 17, STRIP_Y + STRIP_H * 0.5, 7, C.accent)
    end
    -- the cursor can sit ON the banner (row 0), where LEFT/RIGHT change BOX;
    -- light the strip so it reads as the selected row
    if spec.bannerCursor then
      Theme.set(C.accent, 0.9)
      Theme.rect("line", sx + 2.5, STRIP_Y + 2.5, sw - 5, STRIP_H - 5, 6)
    end

    -- the wall: every row of cells, the empty ones included, so a partial box
    -- still reads as a box with room in it.  `spec.rows` fixes the wall's own
    -- row count independently of `#items` -- the PARTY is six mons but it is
    -- drawn on the SAME rows a box is, so a party cell is the size of a box
    -- cell and the rest of the wall is simply empty.
    local rows = math.max(1, spec.rows or math.ceil(#items / COLS))
    local ch = spec.cellH or math.floor(GRID_H / rows)
    for i = 1, rows * COLS do
      local col = (i - 1) % COLS
      local row = math.floor((i - 1) / COLS)
      drawCell(game, GRID_X + col * CELL_W, GRID_Y + row * ch,
        items[i], i == index, F, ch)
    end

    -- the mon in hand, lifted off the wall: the SAME mini-icon, raised and
    -- with a shadow under it, drawn over the cursor's own lit cell.  Its home
    -- cell is empty while it is held (the caller leaves it out of `items`).
    if spec.held and spec.bannerCursor then
      -- carrying a mon on the banner: it rides the strip while the boxes flip
      local iw = STRIP_H - 8
      local ix, iy = sx + sw - 56, STRIP_Y + 4
      Theme.set(C.black, 0.28)
      Theme.rect("fill", ix + 3, iy + iw - 5, iw - 6, 4, 2)
      local drew = Portraits and type(Portraits.drawIcon) == "function"
        and Portraits.drawIcon(Theme, game, spec.held, ix, iy, iw, iw)
      if not drew then
        Theme.diamond(ix + iw * 0.5, iy + iw * 0.5, 6, C.accentDim)
      end
    elseif spec.held then
      local i = math.max(1, math.min(index or 1, rows * COLS))
      local col = (i - 1) % COLS
      local row = math.floor((i - 1) / COLS)
      local fx = GRID_X + col * CELL_W + CELL_GAP * 0.5
      local fy = GRID_Y + row * ch + CELL_GAP * 0.5
      local fw, fh = CELL_W - CELL_GAP, ch - CELL_GAP
      local lift = 7
      Theme.set(C.black, 0.28)
      Theme.rect("fill", fx + 5, fy + fh - 12, fw - 10, 6, 3)
      local iw, ih = fw - CELL_PAD * 2, fh - CELL_PAD * 2
      local drew = Portraits and type(Portraits.drawIcon) == "function"
        and Portraits.drawIcon(Theme, game, spec.held,
          fx + CELL_PAD, fy + CELL_PAD - lift, iw, ih)
      if not drew then
        Theme.diamond(fx + fw * 0.5, fy + fh * 0.5 - lift, 7, C.accentDim)
      end
    end

    drawMonCard(self, game, spec.detail, MARGIN, Shell.CONTENT_Y, DETAIL_W,
      DETAIL_H)
    Shell.footer(Theme, game, { hints = spec.hints or MENU_HINTS,
      gap = spec.gap, right = spec.notice })
    Theme.set(C.white)
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

  -- ===================================================== the Gen 1 box SLOT page
  -- Gen 1's Bill's PC mon lists (src/ui/BoxMenu.lua's withdraw / deposit /
  -- release rows) are the SAME modern slot page Gold gets (see the Gen 2
  -- controller below, whose model this mirrors exactly): a box is a fixed
  -- six-column wall of `Boxes.CAPACITY` cells (30 with g9-boxes, 20 without),
  -- a mon's cell rides the mon (`mon.boxSlot`) so a hole in the middle of a box
  -- survives a save, and the page owns its own cursor and its own writes -- the
  -- engine's packed ListMenu is no longer driven (M.g1BoxUpdate replaces its
  -- update).  The arrays run PARTY (0), BOX 1 .. BOX Boxes.COUNT, wrapping; the
  -- banner row switches between them.  All three of Gen 1's box lists -- the
  -- withdraw (renamed MOVE), the deposit and the release -- open this one page;
  -- the deposit list simply starts the cursor on the PARTY.
  local G1_PARTY_CELLS = 6
  local G1_BOX_MENU_ROWS = { "MOVE", "STATS", "RELEASE", "CANCEL" }

  local function g1boxes()
    local ok, B = pcall(require, "src.pokemon.Boxes")
    if ok and type(B) == "table" then return B end
    return nil
  end

  local function g1boxCount()
    local B = g1boxes()
    local n = B and tonumber(B.COUNT)
    return (n and n > 0) and n or 12
  end

  local function g1slotState(self)
    local S = self.__g9slot
    if S then return S end
    local save = self.game and self.game.save
    local start = 1
    if self.kind == "pc_box_deposit" then
      start = 0
    elseif save and tonumber(save.currentBox) then
      start = math.max(1, math.min(g1boxCount(), math.floor(save.currentBox)))
    end
    S = { idx = start, row = 1, col = 0, menu = nil, ask = nil,
      askYes = true, held = nil, from = nil, notice = nil }
    self.__g9slot = S
    return S
  end

  -- a save's box table, materialised/typed before it is indexed (Boxes.ensure,
  -- which g9-boxes widens to the whole box count; a bare save still gets 12)
  local function g1ensureBoxes(save)
    local B = g1boxes()
    if B and type(B.ensure) == "function" then
      local ok, boxes = pcall(B.ensure, save)
      if ok and type(boxes) == "table" then return boxes end
    end
    save.boxes = save.boxes or {}
    return save.boxes
  end

  -- The array a loaded index names: 0 is the PARTY, 1..COUNT a box.  A box is
  -- handed back LIVE (created on demand), so a write here lands on the save.
  local function g1arrayAt(self, i)
    local save = (self.game and self.game.save) or {}
    if i == 0 then
      save.party = save.party or {}
      return save.party
    end
    local boxes = g1ensureBoxes(save)
    if type(boxes[i]) ~= "table" then boxes[i] = {} end
    return boxes[i]
  end

  local function g1capacityAt(self, i)
    if i == 0 then return G1_PARTY_CELLS end
    return boxCapacity(self.game)
  end

  local function g1arrayName(self, i)
    if i == 0 then return "PARTY POKéMON" end
    local save = self.game and self.game.save
    local names = save and save.boxNames
    local custom = names and names[i]
    if type(custom) == "string" and custom ~= "" then return display(custom) end
    return ("%s %d"):format(word("BOX"), i)
  end

  local function g1packedIndex(list, mon)
    for i = 1, #list do if list[i] == mon then return i end end
    return nil
  end

  -- keep the SAVE's active box in step with the loaded array (no CHANGE BOX
  -- prompt on the modern page; the engine writes the same byte through it)
  local function g1setCurrent(self, i)
    local save = self.game and self.game.save
    if save and i >= 1 then save.currentBox = i end
  end

  local function g1playCry(self, mon)
    if type(mon) ~= "table" or not mon.species then return end
    local game = self.game
    local ok, Sound = pcall(require, "src.core.Sound")
    if ok and type(Sound) == "table" and type(Sound.playCry) == "function"
        and game and game.data then
      pcall(Sound.playCry, game.data, mon.species)
    end
  end

  -- A mon leaving a BOX for the PARTY gets its stat block computed: a boxed
  -- mon carries none (box_struct stops before MON_STATS), which the engine's
  -- own withdraw does after _MoveMon's tail -- see src/ui/BoxMenu.lua's comment.
  local function g1healForParty(game, mon)
    if type(mon) ~= "table" then return end
    local ok, Stats = pcall(require, "src.pokemon.Stats")
    if not (ok and type(Stats) == "table" and type(Stats.ensure) == "function") then
      return
    end
    local def = game and game.data and game.data.pokemon
      and game.data.pokemon[mon.species]
    pcall(Stats.ensure, def, mon)
  end

  -- the slot -> mon map for the loaded array, EXCLUDING the mon in hand (its
  -- home cell reads empty while it is picked up).  A box mon with no valid
  -- cell gets the first free one written onto it, so positions persist.
  local function g1cells(self, S)
    local cap = g1capacityAt(self, S.idx)
    local list = g1arrayAt(self, S.idx)
    local held = S.held
    local bySlot = {}
    if S.idx == 0 then
      for i = 1, math.min(#list, cap) do
        if list[i] ~= held then bySlot[i] = list[i] end
      end
      return bySlot, list, cap
    end
    local used, unplaced = {}, {}
    for i = 1, #list do
      local mon = list[i]
      if mon ~= held then
        local s = tonumber(mon.boxSlot)
        if s and s == math.floor(s) and s >= 1 and s <= cap and not used[s] then
          used[s] = true
          bySlot[s] = mon
        else
          mon.boxSlot = nil
          unplaced[#unplaced + 1] = mon
        end
      end
    end
    local n = 1
    for _, mon in ipairs(unplaced) do
      while bySlot[n] do n = n + 1 end
      if n > cap then break end
      bySlot[n] = mon
      mon.boxSlot = n
    end
    return bySlot, list, cap
  end

  local function g1cursorCell(S, cap)
    local cell = (S.row - 1) * COLS + S.col + 1
    if cell > cap then cell = cap end
    if cell < 1 then cell = 1 end
    return cell
  end

  -- The arrays run PARTY, BOX 1, ..., BOX N and wrap: the last box's right step
  -- lands on the PARTY and the PARTY's right on BOX 1 (left is the mirror).
  local function g1switchArray(self, S, delta, stay)
    local span = g1boxCount() + 1
    S.idx = (S.idx + delta) % span
    g1setCurrent(self, S.idx)
    if stay then
      S.row, S.col = 0, 0
    else
      S.row, S.col = 1, 0
    end
  end

  -- MOVE's drop: the mon in hand goes into `slot`, swapping with whatever is
  -- there (across arrays included).  A cross-array drop into the party needs a
  -- free party cell; a cross-array drop on a full array is refused.
  local function g1placeHeld(self, S, slot)
    local mon, from = S.held, S.from
    if not (mon and from) then return end
    local game = self.game
    local idx = S.idx
    local bySlot, list, cap = g1cells(self, S)
    local occupied = bySlot[slot]
    if from.idx == idx then
      if idx == 0 then
        local a = g1packedIndex(list, mon)
        if occupied then
          local b = g1packedIndex(list, occupied)
          if a and b then list[a], list[b] = list[b], list[a] end
        elseif a then
          table.remove(list, a)
          table.insert(list, math.min(slot, #list + 1), mon)
        end
      elseif occupied then
        local s = mon.boxSlot
        mon.boxSlot = occupied.boxSlot
        occupied.boxSlot = s
      else
        mon.boxSlot = slot
      end
    else
      local src = from.idx
      local srcList = g1arrayAt(self, src)
      if occupied then
        local si = g1packedIndex(srcList, mon)
        local di = g1packedIndex(list, occupied)
        if si and di then
          table.remove(srcList, si)
          table.remove(list, di)
          table.insert(list, math.min(di, #list + 1), mon)
          table.insert(srcList, math.min(si, #srcList + 1), occupied)
          mon.boxSlot = (idx == 0) and nil or slot
          occupied.boxSlot = (src == 0) and nil or from.slot
          if idx == 0 then g1healForParty(game, mon) end
        end
      elseif idx == 0 then
        if #list < G1_PARTY_CELLS then
          local si = g1packedIndex(srcList, mon)
          table.remove(srcList, si)
          table.insert(list, mon)
          mon.boxSlot = nil
          g1healForParty(game, mon)
        else
          S.notice = "The PARTY is full."
        end
      else
        local si = g1packedIndex(srcList, mon)
        table.remove(srcList, si)
        table.insert(list, mon)
        mon.boxSlot = slot
      end
    end
    S.held, S.from, S.ask = nil, nil, nil
  end

  -- A same-array BOX swap keeps a mon IN HAND (the displaced mon becomes the
  -- one picked up), exactly as on Gold -- see g2swapHeldBox below.
  local function g1swapHeldBox(self, S, slot)
    local mon = S.held
    local bySlot = g1cells(self, S)
    local other = bySlot[slot]
    if not (mon and other) then return end
    local origin = mon.boxSlot
    mon.boxSlot = other.boxSlot
    other.boxSlot = origin
    S.held = other
    S.from = { idx = S.idx, slot = origin }
    S.ask = nil
  end

  local function g1releaseMon(self, S, mon)
    local list = g1arrayAt(self, S.idx)
    local packed = g1packedIndex(list, mon)
    if not packed then return end
    table.remove(list, packed)
    g1playCry(self, mon)
    S.notice = "Released "
      .. (mon.nickname or mon.name or mon.species or "?") .. "."
  end

  -- the engine's own Gen 1 status screen over the selected mon
  local function g1openStatsMon(self, mon)
    local game = self.game
    if not (mon and game) then return end
    local okS, Screens = pcall(require, "src.ui.Screens")
    if not (okS and type(Screens) == "table"
        and type(Screens.push) == "function") then return end
    pcall(Screens.push, game, "SummaryMenu", mon)
  end

  local function g1chooseMenu(self, S)
    local bySlot, list, cap = g1cells(self, S)
    local cell = g1cursorCell(S, cap)
    local mon = bySlot[cell]
    local row = S.menu
    S.menu = nil
    if row == 1 then
      if mon then
        S.held = mon
        S.from = { idx = S.idx, slot = cell }
      end
    elseif row == 2 then
      if mon then g1openStatsMon(self, mon) end
    elseif row == 3 then
      if mon then
        if mon.isEgg then
          S.notice = "You can't release an EGG!"
        else
          S.ask = { kind = "release", mon = mon }
          S.askYes = true
        end
      end
    end
  end

  local function g1askLines(S)
    local ask = S.ask
    if not ask then return {} end
    if ask.kind == "leave" then return { "Cancel box operations?" } end
    if ask.kind == "swap" then return { "Swap POKéMON?" } end
    if ask.kind == "release" then
      local name = ask.mon
        and (ask.mon.nickname or ask.mon.name or ask.mon.species) or "?"
      return { "Release " .. name .. "?" }
    end
    return {}
  end

  local function g1resolveAsk(self, S)
    local ask, yes = S.ask, S.askYes
    S.ask = nil
    if not ask then return end
    if ask.kind == "leave" then
      if yes then
        local onCancel = self.onCancel
        if type(self.close) == "function" then pcall(self.close, self)
        else
          local stack = self.game and self.game.stack
          if stack and type(stack.pop) == "function" then pcall(stack.pop, stack) end
        end
        if type(onCancel) == "function" then pcall(onCancel) end
      end
    elseif ask.kind == "swap" then
      if yes then
        if S.idx >= 1 and S.from and S.from.idx == S.idx then
          g1swapHeldBox(self, S, ask.target)
        else
          g1placeHeld(self, S, ask.target)
        end
      end
    elseif ask.kind == "release" then
      if yes then g1releaseMon(self, S, ask.mon) end
    end
  end

  -- The Gen 1 box page's own input.  Replaces the engine's ListMenu:update
  -- entirely: the engine's packed cursor and its CANCEL row are gone from this
  -- page, so nothing else may drive it.
  function M.g1BoxUpdate(self)
    local input = self.game and self.game.input
    if not (input and type(input.wasPressed) == "function") then return end
    local S = g1slotState(self)

    if S.notice then
      if input:wasPressed("a") or input:wasPressed("b") then S.notice = nil end
      return
    end
    if S.ask then
      if input:wasPressed("up") or input:wasPressed("down")
          or input:wasPressed("left") or input:wasPressed("right") then
        S.askYes = not S.askYes
      end
      if input:wasPressed("b") then S.ask = nil return end
      if input:wasPressed("a") then g1resolveAsk(self, S) end
      return
    end
    if S.menu then
      if input:wasPressed("up") then
        S.menu = S.menu > 1 and S.menu - 1 or #G1_BOX_MENU_ROWS
      elseif input:wasPressed("down") then
        S.menu = S.menu < #G1_BOX_MENU_ROWS and S.menu + 1 or 1
      elseif input:wasPressed("a") then
        g1chooseMenu(self, S)
      elseif input:wasPressed("b") then
        S.menu = nil
      end
      return
    end

    local bySlot, list, cap = g1cells(self, S)
    local rows = math.max(1, math.ceil(cap / COLS))
    if S.row > 0 and S.row > rows then S.row = rows end
    if S.col > COLS - 1 then S.col = COLS - 1 end

    if input:wasPressed("up") then
      if S.row > 0 then S.row = S.row - 1 end
    elseif input:wasPressed("down") then
      if S.row == 0 then S.row = 1 else S.row = math.min(rows, S.row + 1) end
    elseif input:wasPressed("left") then
      if S.row == 0 then
        g1switchArray(self, S, -1, true)
      else
        local cell = g1cursorCell(S, cap) - 1
        if cell < 1 then cell = cap end
        S.row = math.floor((cell - 1) / COLS) + 1
        S.col = (cell - 1) % COLS
      end
    elseif input:wasPressed("right") then
      if S.row == 0 then
        g1switchArray(self, S, 1, true)
      else
        local cell = g1cursorCell(S, cap) + 1
        if cell > cap then cell = 1 end
        S.row = math.floor((cell - 1) / COLS) + 1
        S.col = (cell - 1) % COLS
      end
    elseif input:wasPressed("a") then
      if S.row == 0 then
        -- the banner is a box picker, not a cell: A does nothing on it
      else
        local cell = g1cursorCell(S, cap)
        local mon = bySlot[cell]
        if S.held then
          if not mon then
            g1placeHeld(self, S, cell)
          elseif mon ~= S.held then
            S.ask = { kind = "swap", target = cell, mon = mon }
            S.askYes = true
          end
        elseif mon then
          S.menu = 1
        end
      end
    elseif input:wasPressed("b") then
      if S.held then
        S.notice = "You can't leave while holding a POKéMON."
      else
        S.ask = { kind = "leave" }
        S.askYes = true
      end
    end
  end

  -- A Bill's PC mon list as the slot page.  The engine's ListMenu is still on
  -- the stack (and still holds the push/close contract), but its packed rows
  -- are ignored: the page reads the save's arrays through mon.boxSlot, the way
  -- Gold's does.
  function M.drawBoxList(self)
    local game, emb = pageBegin(self)
    local S = g1slotState(self)
    local bySlot, list, cap = g1cells(self, S)
    local items = {}
    for i = 1, cap do items[i] = { mon = bySlot[i] } end
    local onBanner = (S.row == 0)
    local index = onBanner and 0 or g1cursorCell(S, cap)
    local selected = bySlot[index]
    local banner = g1arrayName(self, S.idx)
    local right
    if S.idx == 0 then
      right = ("%s %d/%d"):format(word("PARTY"), #list, cap)
    else
      right = ("%s %d/%d   %d/%d"):format(word("BOX"), S.idx, g1boxCount(), #list, cap)
    end
    local caption = "Choose a POKéMON."
    if S.held then
      caption = onBanner and "Pick a BOX to move it to."
        or "Choose a slot to place it in."
    elseif onBanner then
      caption = "Pick a BOX."
    elseif S.ask and S.ask.kind == "leave" then
      caption = "Cancel box operations?"
    end
    Shell.top(Theme, game, {
      title = "BILL's PC", right = right, caption = caption,
      money = Shell.money(game), embellish = emb,
    })
    local hints
    if S.held then
      hints = {
        { key = "\xe2\x86\x90\xe2\x86\x92", text = "BOX" },
        { key = "A", text = "PLACE" },
        { key = "B", text = "BACK" },
      }
    else
      hints = {
        { key = "\xe2\x86\x90\xe2\x86\x92", text = "BOX" },
        { key = "A", text = "OK" },
        { key = "B", text = "CANCEL" },
      }
    end
    local rows = math.max(1, math.ceil(boxCapacity(game) / COLS))
    drawBoxGrid(self, game, {
      items = items, index = index, boxLabel = banner,
      canSwitchBox = true, detail = S.held or selected,
      held = S.held, bannerCursor = onBanner, hints = hints, gap = 18,
      rows = rows,
    })    if S.menu then
      local rows = {}
      for _, label in ipairs(G1_BOX_MENU_ROWS) do
        rows[#rows + 1] = { text = label }
      end
      pcCard(self, { title = "WHAT'S UP?", rows = rows, index = S.menu,
        w = 300 })
    elseif S.ask then
      pcCard(self, { lines = g1askLines(S), yesno = S.askYes and 1 or 2,
        w = 420 })
    elseif S.notice then
      pcCard(self, { lines = { S.notice }, w = 420 })
    end
    Theme.set(Theme.col.white)
  end

  -- ============================================== Bill's PC's own MENU rows
  -- BILL's PC's top menu (screenId "BoxMenu") is the engine's own Menu: its
  -- first row is WITHDRAW POKéMON, which the suite relabels MOVE because the
  -- page it opens is the modern move/slot page.  Two of the engine's rows are
  -- retuned before that page is dressed:
  --
  --   * MOVE -- the engine's `withdraw(game)` refuses outright when the party
  --     is full (`#party >= Party.MAX`), which made sense when the list could
  --     only pull a mon OUT to the party.  The slot page MOVES a mon anywhere
  --     (box to box included), so a full party is no reason to refuse it.  The
  --     row's onSelect is replaced with `M.g1openMoveList`, which pushes the
  --     very same `pc_box_withdraw` ListMenu -- empty-box message and all --
  --     without the party gate.  The suite dresses that list into the slot page.
  --   * DEPOSIT POKéMON -- dropped entirely: depositing is what the slot page's
  --     PARTY array already does (pick a party mon up, drop it in a box), so the
  --     row has nothing left to do.  Gold's storage menu loses the same row
  --     (see M.g2TameStorage).
  --
  -- Row identity: the engine appends these in a fixed order (WITHDRAW,
  -- DEPOSIT, RELEASE, CHANGE BOX, [PRINT BOX], SEE YA!), so the position is
  -- the fallback and the (display-expanded) label is the sanity check -- a
  -- localized cart still gets the right two rows.
  function M.g1TameBoxMenu(state)
    local items = state and state.items
    if type(items) ~= "table" then return end
    local move, deposit
    for i, it in ipairs(items) do
      if type(it) == "table" then
        local label = display(it.label or "")
        if not move and label:find("^WITHDRAW POK") then move = i end
        if not deposit and label:find("^DEPOSIT POK") then deposit = i end
      end
    end
    move = move or 1
    deposit = deposit or 2
    local moveItem = items[move]
    if type(moveItem) == "table" then
      -- Rename the row to MOVE here, by POSITION, not by its (possibly
      -- translated) label: under a translation mod the engine's "WITHDRAW
      -- POKéMON" reads e.g. "SACAR POKéMON" and `pcMoveLabel`'s English
      -- pattern never matches, so the row kept saying "withdraw".  The suite's
      -- own "MOVE" is then localized at draw like any other lexicon word.
      moveItem.label = "MOVE"
      -- keep the engine's keepOpen contract (hollow cursor while a child is up)
      -- and open the gate-free list instead of withdraw(game)
      moveItem.onSelect = function()
        state.hollowIndex = state.index
        M.g1openMoveList(state)
      end
    end
    if items[deposit] then table.remove(items, deposit) end
    if (state.index or 1) > #items then state.index = 1 end
  end

  -- The engine's BoxMenu.withdraw, minus its party-full refusal: push the
  -- `pc_box_withdraw` list (the slot page takes it over in M.dress).  A box that
  -- has no POKéMON in it keeps the cart's own "What? There are no POKéMON here!"
  -- message, exactly as the engine's version prints it.
  function M.g1openMoveList(state)
    local game = state and state.game
    if not game or not game.stack then return end
    local LM = listClass()
    if not LM then return end
    local save = game.save
    local box = {}
    local B = g1boxes()
    if B and type(B.active) == "function" then
      if type(B.ensure) == "function" then pcall(B.ensure, save) end
      local ok, v = pcall(B.active, save)
      if ok and type(v) == "table" then box = v end
    elseif type(save) == "table" and type(save.boxes) == "table" then
      box = save.boxes[save.currentBox or 1] or {}
    end
    if #box == 0 then
      local okT, TextBox = pcall(require, "src.render.TextBox")
      if okT and type(TextBox) == "table"
          and type(TextBox.new) == "function" then
        local t = game.data and game.data.text
        game.stack:push(TextBox.new(game, (t and t._NoMonText)
          or Strings("What? There are\nno POKéMON here!")))
        return
      end
    end
    local items = {}
    for i, mon in ipairs(box) do
      items[#items + 1] = {
        label = monName(mon, game),
        sub = Strings(":L%d", mon.level or 0),
        value = i,
      }
    end
    items[#items + 1] = { cancel = true, label = Strings("CANCEL") }
    game.stack:push(LM.new(game, nil, items, {
      noSound = true, kind = "pc_box_withdraw", itemBox = true,
    }))
  end

  -- Gold's storage menu (Gen2PcMenu, screenId "Gen2PcMenu", the screen BILL's PC
  -- opens): its DEPOSIT POKéMON row goes the way of Gen 1's -- the slot page's
  -- PARTY array is the deposit route.  `state.entries` drives both the drawn rail
  -- (M.g2DrawStorage) and the engine's own cursor/choose in PcMenu:update, so
  -- dropping the one entry here is all it takes; SEE YA! and MAIL BOX stay.
  function M.g2TameStorage(state)
    local entries = state and state.entries
    if type(entries) ~= "table" then return end
    local out = {}
    for _, entry in ipairs(entries) do
      if type(entry) ~= "table" or entry.id ~= "deposit" then
        out[#out + 1] = entry
      end
    end
    state.entries = out
    if (state.index or 1) > #out then state.index = math.max(1, #out) end
  end

  -- --------------------------------------------------------------- page draw
  pageBegin = function(self)
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
        rows[#rows + 1] = { text = pcMoveLabel(display(it.label or "")) }
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
          text = display(it.label or ("%s%2d"):format(word("BOX"), i)),
          right = (count > 0) and tostring(count) or nil,
          marker = (i == box),
        }
      end
      title = "CHANGE BOX"
      right = ("%s %d ACTIVE"):format(word("BOX"), box)
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
    -- Bill's PC's own WITHDRAW row opens the (now) move page: it reads MOVE
    if sid == "BoxMenu" then
      for _, r in ipairs(rows) do r.text = pcMoveLabel(r.text) end
    end
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
      right = ("%s %d  %d/%d"):format(word("BOX"), game.save.currentBox or 1, n,
        (cap or (okB and B.CAPACITY) or 20))
    else
      title = "PC"
      right = nil
    end

    local sel = self.items and self.items[self.index]
    caption = sel and describe(pcMoveLabel(sel.label)) or nil

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
    -- Bill's PC's own mon lists are the modern box GRID (see M.drawBoxList)
    if BOX_LIST_KINDS[self.kind] then return M.drawBoxList(self) end
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
      right = ("%s %d"):format(word("BOX"), game.save.currentBox or 1)
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

  -- A menu ENTRY as the row it draws.  The withdraw row is renamed to MOVE
  -- (the page it opens is a move/slot page) and that identity comes from the
  -- entry's STABLE ID, never its text: under a translation mod the engine
  -- renders "WITHDRAW POKéMON" as e.g. "SACAR POKéMON", which the English-only
  -- `pcMoveLabel` pattern below cannot match -- the old text-based rename
  -- silently did nothing and the row stayed "withdraw".  Everything else keeps
  -- the engine's own (already localized) label.
  local function entryLabel(entry, i)
    if type(entry) == "table" and entry.id == "withdraw" then return "MOVE" end
    return pcMoveLabel(g2text(entry) or tostring(i))
  end

  local function entryDescribe(entry)
    if type(entry) == "table" and entry.id == "withdraw" then
      return "Move a POKéMON between BOXes."
    end
    return describe(pcMoveLabel(g2text(entry) or ""))
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
    return ("%s%d"):format(word("BOX"), i)
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

  g2pic = function(self, img, trueColor, species, shiny, x, y, w, h)
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
      rows[#rows + 1] = { label = entryLabel(entry, i) }
    end
    local sel = entries[self.index]
    Shell.top(Theme, game, {
      title = "PC",
      right = ("%d %s"):format(#rows,
        word(#rows == 1 and "SYSTEM" or "SYSTEMS")),
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
      rows[#rows + 1] = { label = entryLabel(entry, i) }
    end
    local sel = entries[self.index]
    -- the active box's own contents, as the right-hand card
    local boxRows = {
      { header = ("%s %d/%d"):format(word("BOX"), box, total) },
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
      caption = entryDescribe(sel) or "What do you want to do?",
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
  -- The box page is a MODERN SLOT PC now.  A box is a fixed 6x5 wall of
  -- SLOT_COUNT cells; a mon's cell rides the mon itself (mon.boxSlot), so an
  -- empty cell in the middle of a box survives a save -- which a packed list
  -- cannot express.  The page owns its own cursor and its own input:
  --   * A on a mon opens MOVE / STATS / RELEASE / CANCEL
  --   * MOVE picks the icon up (the same mini-icon, lifted, with a shadow);
  --     A on an empty cell drops it there; A on an occupied cell asks
  --     "Swap POKéMON?" and, on YES, the two mons trade cells -- and, when
  --     they are in different arrays, trade arrays too; the displaced mon
  --     becomes the one in hand
  --   * the arrow keys walk the grid; at a cell's edge they WRAP inside the
  --     array, and only at the array's own first/last cell do they step to the
  --     previous/next array -- the boxes AND the PARTY (box 0) -- so holding a
  --     mon and stepping to another array is how it crosses between a box and
  --     the party
  --   * B asks "Cancel box operations?" with YES/NO; trying to leave while
  --     holding a mon is refused with a warning instead
  -- The engine's own BoxMenu model (its packed list, its insert cursor, its
  -- phases) is left in place but not driven: this controller reads the save's
  -- arrays directly and writes them itself.
  local SLOT_COLS = 6
  local PARTY_CELLS = 6
  local BOX_MENU_ROWS = { "MOVE", "STATS", "RELEASE", "CANCEL" }

  -- The controller's own state, hung on the engine's BoxMenu object.  `idx` is
  -- the loaded array: 0 is the PARTY, 1..NUM_BOXES a box.
  local function g2slotState(self)
    local S = self.__g9slot
    if S then return S end
    S = {
      idx = (self.mode == "deposit") and 0 or (self.boxIndex or 1),
      row = 1, col = 0,
      menu = nil, ask = nil, askYes = true, held = nil, from = nil,
      notice = nil,
    }
    self.__g9slot = S
    -- listAt(0) must mean the PARTY from here on, and stepBox's own walk must
    -- be able to reach box 0.
    self.mode = "move"
    return S
  end

  local function g2arrayAt(self, i)
    if i == 0 then
      self.save.party = self.save.party or {}
      return self.save.party
    end
    local B = boxModel()
    if B and type(B.box) == "function" then
      local ok, v = pcall(B.box, self.save, i)
      if ok and type(v) == "table" then return v end
    end
    self.save.boxes = self.save.boxes or {}
    self.save.boxes[i] = self.save.boxes[i] or {}
    return self.save.boxes[i]
  end

  local function g2capacityAt(self, i)
    if i == 0 then return PARTY_CELLS end
    return g2boxCap(self.save)
  end

  local function g2numArrays(self)
    local B = boxModel()
    return (B and type(B.NUM_BOXES) == "number" and B.NUM_BOXES) or 14
  end

  local function g2arrayName(self, i)
    if i == 0 then return "PARTY POKéMON" end
    return g2boxName(self.save, i)
  end

  local function g2packedIndex(list, mon)
    for i = 1, #list do if list[i] == mon then return i end end
    return nil
  end

  local function g2partyMailFix(save, slot)
    if not slot then return end
    local ok, Mail = pcall(require, "src.core.gen2.Mail")
    if ok and type(Mail) == "table" and type(Mail.removeSlot) == "function" then
      pcall(Mail.removeSlot, save, slot)
    end
  end

  local function g2healForBox(mon)
    if type(mon) ~= "table" then return end
    local B = boxModel()
    if B and type(B.enterBox) == "function" then
      pcall(B.enterBox, mon)
      return
    end
    mon.status, mon.statusTurns = nil, nil
    mon.hp = mon.isEgg and 0 or (mon.maxHp or mon.hp)
  end

  local function g2healForParty(mon)
    if type(mon) ~= "table" then return end
    mon.status, mon.statusTurns = nil, nil
    mon.hp = mon.isEgg and 0 or (mon.maxHp or mon.hp)
  end

  -- the slot -> mon map for the loaded array, EXCLUDING the mon in hand (so
  -- its home cell reads empty while it is picked up).  A box mon with no valid
  -- cell gets the first free one written onto it, so positions persist.
  local function g2cells(self, S)
    local cap = g2capacityAt(self, S.idx)
    local list = g2arrayAt(self, S.idx)
    local held = S.held
    local bySlot = {}
    if S.idx == 0 then
      for i = 1, math.min(#list, cap) do
        if list[i] ~= held then bySlot[i] = list[i] end
      end
      return bySlot, list, cap
    end
    local used, unplaced = {}, {}
    for i = 1, #list do
      local mon = list[i]
      if mon ~= held then
        local s = tonumber(mon.boxSlot)
        if s and s == math.floor(s) and s >= 1 and s <= cap and not used[s] then
          used[s] = true
          bySlot[s] = mon
        else
          mon.boxSlot = nil
          unplaced[#unplaced + 1] = mon
        end
      end
    end
    local n = 1
    for _, mon in ipairs(unplaced) do
      while bySlot[n] do n = n + 1 end
      if n > cap then break end
      bySlot[n] = mon
      mon.boxSlot = n
    end
    return bySlot, list, cap
  end

  local function g2cursorCell(S, cap)
    local cell = (S.row - 1) * SLOT_COLS + S.col + 1
    if cell > cap then cell = cap end
    if cell < 1 then cell = 1 end
    return cell
  end

  -- The arrays run PARTY, BOX 1, ..., BOX N and wrap: the last box's right step
  -- lands on the PARTY and the PARTY's right on BOX 1 (left is the mirror).
  local function g2switchArray(self, S, delta, stay)
    local span = g2numArrays(self) + 1
    S.idx = (S.idx + delta) % span
    self.boxIndex = S.idx
    local B = boxModel()
    if S.idx >= 1 and B and type(B.setCurrent) == "function" then
      pcall(B.setCurrent, self.save, S.idx)
    end
    -- on the BOX banner the cursor stays there (so a held mon is carried across
    -- the boxes); otherwise land on the new array's first cell
    if stay then
      S.row, S.col = 0, 0
    else
      S.row, S.col = 1, 0
    end
  end

  -- MOVE's drop: the mon in hand goes into `slot`, swapping with whatever is
  -- there (across arrays included).  A cross-array drop that lands in the party
  -- needs a free party slot; a cross-array drop on a full array is refused.
  local function g2placeHeld(self, S, slot)
    local mon, from = S.held, S.from
    if not (mon and from) then return end
    local idx = S.idx
    local bySlot, list, cap = g2cells(self, S)
    local occupied = bySlot[slot]
    if from.idx == idx then
      if idx == 0 then
        local a = g2packedIndex(list, mon)
        if occupied then
          local b = g2packedIndex(list, occupied)
          if a and b then list[a], list[b] = list[b], list[a] end
        elseif a then
          table.remove(list, a)
          table.insert(list, math.min(slot, #list + 1), mon)
        end
      elseif occupied then
        local s = mon.boxSlot
        mon.boxSlot = occupied.boxSlot
        occupied.boxSlot = s
      else
        mon.boxSlot = slot
      end
    else
      local src = from.idx
      local srcList = g2arrayAt(self, src)
      if occupied then
        local si = g2packedIndex(srcList, mon)
        local di = g2packedIndex(list, occupied)
        if si and di then
          table.remove(srcList, si)
          table.remove(list, di)
          table.insert(list, math.min(di, #list + 1), mon)
          table.insert(srcList, math.min(si, #srcList + 1), occupied)
          mon.boxSlot = (idx == 0) and nil or slot
          occupied.boxSlot = (src == 0) and nil or from.slot
          if idx >= 1 then g2healForBox(mon) end
          if src >= 1 then g2healForBox(occupied) end
        end
      elseif idx == 0 then
        if #list < PARTY_CELLS then
          local si = g2packedIndex(srcList, mon)
          table.remove(srcList, si)
          g2partyMailFix(self.save, si)
          table.insert(list, mon)
          mon.boxSlot = nil
          g2healForParty(mon)
        else
          S.notice = "The PARTY is full."
        end
      else
        local si = g2packedIndex(srcList, mon)
        table.remove(srcList, si)
        if src == 0 then g2partyMailFix(self.save, si) end
        table.insert(list, mon)
        mon.boxSlot = slot
        g2healForBox(mon)
      end
    end
    S.held, S.from, S.ask = nil, nil, nil
  end

  -- A same-array BOX swap keeps a mon IN HAND: the held mon takes the target
  -- cell and the mon that was there becomes the one picked up -- its saved cell
  -- is the held mon's old cell, so the two positions are exchanged and no cell
  -- is ever shown holding two mons.  That is what the cart's own move does:
  -- drop on an occupied cell, confirm the swap, and you are now carrying the
  -- mon that used to be there.  A cross-array drop, or a swap inside the party
  -- (whose array is packed and has no cells to trade), is the plain exchange in
  -- g2placeHeld instead.
  local function g2swapHeldBox(self, S, slot)
    local mon = S.held
    local bySlot = g2cells(self, S)
    local other = bySlot[slot]
    if not (mon and other) then return end
    local origin = mon.boxSlot
    mon.boxSlot = other.boxSlot
    other.boxSlot = origin
    S.held = other
    S.from = { idx = S.idx, slot = origin }
    S.ask = nil
  end

  local function g2releaseMon(self, S, mon)
    local idx = S.idx
    local list = g2arrayAt(self, idx)
    local packed = g2packedIndex(list, mon)
    if not packed then return end
    local B = boxModel()
    local released = false
    if idx == 0 and B and type(B.releaseFromParty) == "function" then
      local pok, ok2 = pcall(B.releaseFromParty, self.save, packed)
      released = pok and ok2 and true or false
    elseif idx >= 1 and B and type(B.release) == "function" then
      local pok, ok2 = pcall(B.release, self.save, idx, packed)
      released = pok and ok2 and true or false
    end
    if not released then table.remove(list, packed) end
    if type(self.playMonCry) == "function" then pcall(self.playMonCry, self, mon) end
    S.notice = "Released " .. (mon.nickname or mon.name or mon.species or "?") .. "."
  end

  local function g2openStatsMon(self, mon)
    local game = self.game
    if not (mon and game) then return end
    local okS, Screens = pcall(require, "src.ui.Screens")
    if not (okS and type(Screens) == "table" and type(Screens.push) == "function") then
      return
    end
    local okGet = pcall(Screens.get, game, "Gen2SummaryMenu")
    if not okGet then return end
    pcall(Screens.push, game, "Gen2SummaryMenu", {
      mon = mon, save = self.save,
      onClose = function() game.stack:pop() end,
    })
  end

  local function g2chooseMenu(self, S)
    local bySlot, list, cap = g2cells(self, S)
    local cell = g2cursorCell(S, cap)
    local mon = bySlot[cell]
    local row = S.menu
    S.menu = nil
    if row == 1 then
      if mon then
        S.held = mon
        S.from = { idx = S.idx, packed = g2packedIndex(list, mon), slot = cell }
      end
    elseif row == 2 then
      if mon then g2openStatsMon(self, mon) end
    elseif row == 3 then
      if mon then
        if mon.isEgg then
          S.notice = "You can't release an EGG!"
        else
          S.ask = { kind = "release", mon = mon }
          S.askYes = true
        end
      end
    end
  end

  local function g2askLines(S)
    local ask = S.ask
    if not ask then return {} end
    if ask.kind == "leave" then return { "Cancel box operations?" } end
    if ask.kind == "swap" then return { "Swap POKéMON?" } end
    if ask.kind == "release" then
      local name = ask.mon and (ask.mon.nickname or ask.mon.name or ask.mon.species)
        or "?"
      return { "Release " .. name .. "?" }
    end
    return {}
  end

  local function g2resolveAsk(self, S)
    local ask, yes = S.ask, S.askYes
    S.ask = nil
    if not ask then return end
    if ask.kind == "leave" then
      if yes then
        if type(self.onClose) == "function" then pcall(self.onClose, self)
        else
          local stack = self.game and self.game.stack
          if stack and type(stack.pop) == "function" then pcall(stack.pop, stack) end
        end
      end
    elseif ask.kind == "swap" then
      if yes then
        if S.idx >= 1 and S.from and S.from.idx == S.idx then
          g2swapHeldBox(self, S, ask.target)
        else
          g2placeHeld(self, S, ask.target)
        end
      end
    elseif ask.kind == "release" then
      if yes then g2releaseMon(self, S, ask.mon) end
    end
  end

  -- The box page's own input.  Replaces the engine's BoxMenu:update entirely:
  -- the engine's packed cursor, its insert phase and its CANCEL row are gone
  -- from this page, so nothing else may drive it.
  function M.g2BoxUpdate(self)
    local input = self.game and self.game.input
    if not (input and type(input.wasPressed) == "function") then return end
    local S = g2slotState(self)

    if S.notice then
      if input:wasPressed("a") or input:wasPressed("b") then S.notice = nil end
      return
    end
    if S.ask then
      if input:wasPressed("up") or input:wasPressed("down")
          or input:wasPressed("left") or input:wasPressed("right") then
        S.askYes = not S.askYes
      end
      if input:wasPressed("b") then S.ask = nil return end
      if input:wasPressed("a") then g2resolveAsk(self, S) end
      return
    end
    if S.menu then
      if input:wasPressed("up") then
        S.menu = S.menu > 1 and S.menu - 1 or #BOX_MENU_ROWS
      elseif input:wasPressed("down") then
        S.menu = S.menu < #BOX_MENU_ROWS and S.menu + 1 or 1
      elseif input:wasPressed("a") then
        g2chooseMenu(self, S)
      elseif input:wasPressed("b") then
        S.menu = nil
      end
      return
    end

    local bySlot, list, cap = g2cells(self, S)
    local rows = math.max(1, math.ceil(cap / SLOT_COLS))
    -- row 0 is the BOX banner (a row ABOVE the wall); 1..rows are the wall's own
    if S.row > 0 and S.row > rows then S.row = rows end
    if S.col > SLOT_COLS - 1 then S.col = SLOT_COLS - 1 end

    if input:wasPressed("up") then
      -- up off the wall's top row moves onto the BOX banner
      if S.row > 0 then S.row = S.row - 1 end
    elseif input:wasPressed("down") then
      if S.row == 0 then S.row = 1 else S.row = math.min(rows, S.row + 1) end
    elseif input:wasPressed("left") then
      if S.row == 0 then
        -- on the banner LEFT is the previous BOX (PARTY after BOX 1)
        g2switchArray(self, S, -1, true)
      else
        local cell = g2cursorCell(S, cap) - 1
        if cell < 1 then cell = cap end
        S.row = math.floor((cell - 1) / SLOT_COLS) + 1
        S.col = (cell - 1) % SLOT_COLS
      end
    elseif input:wasPressed("right") then
      if S.row == 0 then
        -- on the banner RIGHT is the next BOX (the PARTY after the last BOX)
        g2switchArray(self, S, 1, true)
      else
        local cell = g2cursorCell(S, cap) + 1
        if cell > cap then cell = 1 end
        S.row = math.floor((cell - 1) / SLOT_COLS) + 1
        S.col = (cell - 1) % SLOT_COLS
      end
    elseif input:wasPressed("a") then
      if S.row == 0 then
        -- the banner is a box picker, not a cell: A does nothing on it
      else
        local cell = g2cursorCell(S, cap)
        local mon = bySlot[cell]
        if S.held then
          if not mon then
            g2placeHeld(self, S, cell)
          elseif mon ~= S.held then
            S.ask = { kind = "swap", target = cell, mon = mon }
            S.askYes = true
          end
        elseif mon then
          S.menu = 1
        end
      end
    elseif input:wasPressed("b") then
      if S.held then
        S.notice = "You can't leave while holding a POKéMON."
      else
        S.ask = { kind = "leave" }
        S.askYes = true
      end
    end
  end

  function M.g2DrawBox(self)
    local game, emb = g2begin(self)
    local F, C = Theme.fonts(game), Theme.col
    local S = g2slotState(self)
    local bySlot, list, cap = g2cells(self, S)
    local items = {}
    for i = 1, cap do items[i] = { mon = bySlot[i] } end
    local onBanner = (S.row == 0)
    local index = onBanner and 0 or g2cursorCell(S, cap)
    local selected = bySlot[index]
    local banner = g2arrayName(self, S.idx)
    local right
    if S.idx == 0 then
      right = ("%s %d/%d"):format(word("PARTY"), #list, cap)
    else
      right = ("%s %d/%d   %d/%d"):format(word("BOX"), S.idx, g2numArrays(self), #list, cap)
    end
    local caption = "Choose a POKéMON."
    if S.held then
      caption = onBanner and "Pick a BOX to move it to."
        or "Choose a slot to place it in."
    elseif onBanner then
      caption = "Pick a BOX."
    elseif S.ask and S.ask.kind == "leave" then
      caption = "Cancel box operations?"
    end
    Shell.top(Theme, game, {
      title = "BILL's PC", right = right, caption = caption,
      money = Shell.money(game), embellish = emb,
    })
    local hints
    if S.held then
      hints = {
        { key = "\xe2\x86\x90\xe2\x86\x92", text = "BOX" },
        { key = "A", text = "PLACE" },
        { key = "B", text = "BACK" },
      }
    else
      hints = {
        { key = "\xe2\x86\x90\xe2\x86\x92", text = "BOX" },
        { key = "A", text = "OK" },
        { key = "B", text = "CANCEL" },
      }
    end
    local rows = math.max(1, math.ceil(g2boxCap(game.save) / COLS))
    drawBoxGrid(self, game, {
      items = items, index = index, boxLabel = banner,
      canSwitchBox = true, detail = S.held or selected,
      held = S.held, bannerCursor = onBanner, hints = hints, gap = 18,
      rows = rows,
    })
    if S.menu then
      g2wash()
      g2modal(self, F, C, { title = "WHAT'S UP?", rows = BOX_MENU_ROWS,
        index = S.menu, w = 300 })
    elseif S.ask then
      g2wash()
      g2modal(self, F, C, { lines = g2askLines(S),
        yesno = S.askYes and 1 or 2, w = 420 })
    elseif S.notice then
      g2wash()
      g2modal(self, F, C, { lines = g2lines(S.notice), w = 420 })
    end
    Theme.set(C.white)
  end


  -- The modern box switch: LEFT/RIGHT on the BOX page step the loaded box with
  -- NO save in between (the CHANGE BOX picker's save prompt is the ritual the
  -- modern PC drops).  The engine's own walk, BoxMenu:stepBox, is reached on
  -- the cart only from MOVE's dpad, so LEFT/RIGHT are free on the withdraw and
  -- deposit pages; where the engine does use them (MOVE, and the insert
  -- cursor's box step) this stands down and leaves the pair to it.
  function M.g2StepBox(self)
    if type(self) ~= "table" then return end
    if self.phase or self.message or self.messageFrames or self.cryWait then
      return
    end
    if self.mode == "move" then return end
    if type(self.stepBox) ~= "function" then return end
    local input = self.game and self.game.input
    if not (input and type(input.wasPressed) == "function") then return end
    local dir = 0
    if input:wasPressed("left") then dir = -1
    elseif input:wasPressed("right") then dir = 1 end
    if dir == 0 then return end
    if not pcall(self.stepBox, self, dir) then return end
    if type(self.clampIndex) == "function" then pcall(self.clampIndex, self) end
    -- keep the SAVE's active box in step with the loaded one, so the switch is
    -- real and not just a preview: the cart only writes wCurBox through the
    -- CHANGE BOX menu, which is exactly the prompt this page does not show.
    local save = self.save
    if save and type(self.boxIndex) == "number" then
      local okB, B = pcall(require, "src.core.gen2.Boxes")
      if okB and type(B) == "table" and type(B.setCurrent) == "function" then
        pcall(B.setCurrent, save, self.boxIndex)
      end
    end
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
