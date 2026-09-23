-- ui/hp_guard.lua -- the party-HP sentinel (round 309).
--
-- WHY THIS EXISTS
-- A user report, and the reason it is a SENTINEL rather than a one-line fix:
-- with one Pokemon in some state the reporter could not identify, moving the
-- cursor from the START rail onto the POKeMON page with LEFT/RIGHT knocked
-- exactly 1 HP off that mon EVERY time the page turned.  The turn is a pure
-- VIEW change -- ui/start_menu.lua pops the START menu and pushes the
-- engine's own PartyMenu (Gen 2's src/ui/gen2/PartyMenu.lua runs
-- `Mon.refreshStats` over every party member in its constructor) -- so no HP
-- should move at all, and nothing in THIS mod ever writes `mon.hp` (verified
-- by grep).  The writer is therefore somewhere else in the mod stack, and
-- until it is pinned down the suite needs a net under the player.
--
-- WHAT IT DOES
-- Watches the party's HP across a g9-gui menu session.  The moment a value
-- DROPS while the player is only browsing -- no battle, no medicine
-- animation, no item/TM/stone targeting -- it puts the old value back and
-- logs exactly what changed and what state the mon was in, so the report can
-- be pinned down from the log instead of guessed at:
--
--   g9-gui: HP GUARD tripped (party->menu): species=... level=.. hp=30 max=38
--   status=string:PSN nick=... -- hp 30 -> 29, restored [top=g9gui slot=2]
--
-- The `status=<type>:<value>` field is deliberate: the report says the mon is
-- in an "unknown condition", so a raw type+value (e.g. a status this engine
-- has no label for) is the single most useful thing to print.
--
-- HOW IT IS WIRED
-- ui/start_menu.lua and ui/party_menu.lua call G.keep() when their page is
-- BUILT and G.tick() from their own update.  `keep` snapshots the party once
-- and, crucially, a SECOND keep (the destination page of a turn) does NOT
-- re-snapshot: the pre-turn numbers are exactly what the destination page's
-- first tick must be compared against, and a page could otherwise snapshot
-- AFTER the writer already ran.  A single module-level baseline is what makes
-- the guard survive the turn it is guarding.
--
-- The `eligible` gate keeps the sentinel out of every use of the same page
-- that may legitimately move HP -- a battle switch, an item target, a
-- TM/HM or evolution-stone "ABLE?" list, the medicine picker -- so it can
-- only ever object to a change made while the player is merely LOOKING at the
-- party.  A real-time gap between ticks (the player was on another screen: a
-- battle, the bag, the TRAIN editor, a level-up) re-baselines instead of
-- comparing, so a legitimate change made elsewhere is never undone.
--
-- MODE (Mod Manager row `ui_hp_guard`)
--   CATCH (default) -- detect, restore the old HP, log.
--   LOG ONLY        -- detect and log, never touch the value.
--   OFF             -- install nothing.
--
-- Everything here fails open: a nil party, a mon without a numeric hp, a
-- timer that is not available -- all degrade to "no opinion", never to an
-- error or a wrongly restored value.
return function(mod)
  local G = {}

  -- Seconds between ticks past which we assume the player was looking at
  -- another screen (where HP may legitimately have moved) rather than at
  -- this page.  Two full seconds is far longer than one page's update gap.
  local GAP_SECONDS = 0.35
  -- Rate limit for the full diagnostic line: the count keeps climbing past
  -- this, only the log text stops, so one runaway writer cannot fill a log.
  local MAX_LOGS = 12

  local mode = "catch"
  local armed = nil
  local stats = { armed = 0, trips = 0, restored = 0, healed = 0, logs = 0 }

  local function esc(s)
    return (tostring(s):gsub("%%", "%%%%"))
  end

  local function timeNow()
    if love and love.timer and love.timer.getTime then
      local ok, t = pcall(love.timer.getTime)
      if ok and type(t) == "number" then return t end
    end
    if os and os.clock then
      local ok, t = pcall(os.clock)
      if ok and type(t) == "number" then return t end
    end
    return nil
  end

  local function maxHpOf(mon)
    return (mon and mon.maxHp) or (mon and mon.stats and mon.stats.hp) or 0
  end

  -- The diagnostic fingerprint of one mon.  `status` is printed as TYPE plus
  -- value on purpose: an "unknown condition" is exactly what the report is
  -- chasing, and a table or an unrecognised id both read plainly this way.
  local function describe(mon)
    local parts = {
      "species=" .. tostring(mon.species),
      "level=" .. tostring(mon.level),
      "hp=" .. tostring(mon.hp),
      "max=" .. tostring(maxHpOf(mon)),
      "status=" .. type(mon.status) .. ":" .. tostring(mon.status),
    }
    if mon.nickname then parts[#parts + 1] = "nick=" .. tostring(mon.nickname) end
    if mon.isEgg then parts[#parts + 1] = "EGG" end
    if mon.g9TrainEdited then parts[#parts + 1] = "g9TrainEdited" end
    if mon.modernStatsInitialized then parts[#parts + 1] = "modernStats" end
    if mon.g9EggNormalized then parts[#parts + 1] = "eggNormalized" end
    if mon.pokerus then parts[#parts + 1] = "pokerus" end
    return table.concat(parts, " ")
  end

  local function partyOf(game, party)
    if type(party) == "table" then return party end
    return (game and game.save and game.save.party) or nil
  end

  -- A page that is only BROWSING the party may be guarded.  Every other use
  -- of the same engine page -- a battle switch, an item target, a TM/HM or
  -- evolution-stone "ABLE?" list, the medicine picker -- either moves HP for
  -- real or is driven by a fill animation, so the guard stands down there and
  -- never second-guesses it.  Each menu page sets `__g9guard` on itself (see
  -- ui/start_menu.lua and ui/party_menu.lua), so this is one explicit flag
  -- rather than a guess at the engine's per-context option names.
  function G.eligible(state)
    return type(state) == "table" and state.__g9guard == true
  end

  local function snapshot(party)
    local out = {}
    if type(party) ~= "table" then return out end
    for i = 1, #party do
      local mon = party[i]
      if type(mon) == "table" then
        out[#out + 1] = { mon = mon, hp = tonumber(mon.hp) }
      end
    end
    return out
  end

  -- Adopt whatever is on the party RIGHT NOW as the baseline.  Used when the
  -- guard (re)starts and when a real-time gap says a legitimate change
  -- happened on another screen.
  local function rebaseline()
    if not armed then return end
    for i = 1, #armed.entries do
      local e = armed.entries[i]
      if type(e.mon) == "table" then e.hp = tonumber(e.mon.hp) end
    end
    armed.t = timeNow()
  end

  function G.arm(game, reason, party)
    if mode == "off" then return end
    local entries = snapshot(partyOf(game, party))
    if #entries == 0 then armed = nil return end
    armed = { entries = entries, reason = reason or "?", t = timeNow(), ticks = 0 }
    stats.armed = stats.armed + 1
  end

  -- Arm only if nothing is armed yet.  The START screen calls this when it is
  -- built and the POKeMON page calls it when IT is built; the second call
  -- must not re-snapshot, because the pre-turn values are the whole point.
  -- A later call may still RE-TAG the reason (the page turn names the
  -- direction the sentinel is currently watching).
  --
  -- It must NOT touch `armed.t`: that timestamp is how a tick knows the player
  -- spent time on a different screen (where HP may legitimately have moved).
  -- Refreshing it here would hide that gap and let a stale baseline be
  -- compared against a mon healed or hurt elsewhere.
  function G.keep(game, reason, party)
    if mode == "off" then return end
    if armed then
      if reason then armed.reason = reason end
      return
    end
    G.arm(game, reason, party)
  end

  function G.setMode(m)
    mode = (m == "off" or m == "log") and m or "catch"
    if mode == "off" then armed = nil end
    return mode
  end

  function G.disarm() armed = nil end
  function G.stats() return stats end
  function G.armedReason() return armed and armed.reason or nil end

  -- One page tick.  `state` is the page doing the looking (only its shallow
  -- eligibility flags are read).  Returns nothing; never raises.
  function G.tick(game, state)
    local a = armed
    if not a or mode == "off" then return end
    -- A page that is not merely browsing (a battle switch, a picker) is
    -- skipped, not disarmed: the baseline stays for the field page the player
    -- returns to, where a real-time gap then re-baselines it anyway.
    if state and not G.eligible(state) then return end

    local t = timeNow()
    if t and a.t and (t - a.t) > GAP_SECONDS then
      rebaseline()
      return
    end
    a.t = t
    a.ticks = (a.ticks or 0) + 1

    for i = 1, #a.entries do
      local e = a.entries[i]
      local mon = e.mon
      if type(mon) == "table" then
        local hp = tonumber(mon.hp)
        if hp and e.hp and hp ~= e.hp then
          if hp < e.hp then
            stats.trips = stats.trips + 1
            local head = "?"
            local top = game and game.stack and game.stack:top()
            if top then
              head = tostring(top.screenId
                or (top.__g9gui and "g9gui") or "?")
            end
            if stats.logs < MAX_LOGS then
              stats.logs = stats.logs + 1
              mod.log:warn(esc(("g9-gui: HP GUARD tripped (%s): %s -- hp %d"
                .. " -> %d%s [top=%s slot=%d]")
                :format(a.reason, describe(mon), e.hp, hp,
                  mode == "log" and " (log only)" or ", restored", head, i)))
            end
            if mode ~= "log" then
              mon.hp = e.hp
              stats.restored = stats.restored + 1
            end
          else
            -- An increase is not the reported leak (a page turn cannot heal),
            -- so it is never undone -- adopt it and keep watching.
            stats.healed = stats.healed + 1
            e.hp = hp
          end
        end
      end
    end
  end

  -- Published for the Mod Manager / a future in-game report and for the
  -- studio's own probes: counts plus the reason the baseline is armed.
  mod.exports.hpGuard = {
    stats = function() return stats end,
    reason = function() return armed and armed.reason or nil end,
    mode = function() return mode end,
  }

  return G
end
