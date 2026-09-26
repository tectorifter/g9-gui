-- ui/gold_learner.lua -- Gold's OUT-OF-BATTLE move learner, routed through the
-- suite's own page.
--
-- Gen 1 opens the learner as a SCREEN: src.ui.MoveLearnMenu is pushed by the
-- native battle queue, the bag's TM use and the evolution's learn run, and
-- g9-gui's ui/move_learn.lua takes that screen over.  Gold does not have a
-- learner screen at all: every out-of-battle learn -- a TM used from the PACK
-- (which first opens the party screen to pick the mon), a RARE CANDY's level
-- moves, an evolution's new move, the Goldenrod move tutor's -- funnels through
-- Game2:learnMoveOn, which draws the whole exchange as engine TextBoxes plus
-- the native src.ui.gen2.MoveDeleter forget list.  Registering the MoveLearnMenu
-- id therefore does NOTHING for those flows on Gold (only g9-Battle-Scene's
-- in-battle pause reaches the screen there), which is exactly the report this
-- fixes: the modern learner never appeared when a move was learned from the
-- party flow, on PC or mobile, and the classic forget list was left in the
-- middle of the sequence.
--
-- So this module wraps Game2:learnMoveOn and, for the ONE case that needs the
-- forget sequence (four slots full, the move not already known), pushes the
-- suite's registered learner -- the SAME page the in-battle pause pushes on
-- Gold -- with the caller's own onDone threaded through, so every continuation
-- (the TM's consumption and happiness, the evolution's next move, the tutor's
-- fee) still runs exactly as the engine's flow ran it.  Every other case is
-- left entirely to the engine: a free slot learns outright and prints the
-- engine's "learned X!" line, a move the mon already knows finishes silently,
-- and a build failure falls straight back to Game2:learnMoveOn itself, so a
-- mod that cannot paint one page can never lose the player a move.  Gold only;
-- Gen 1's engine already pushes the screen this suite takes over.
return function(mod, ctx)
  local M = {}

  -- The move's real PP, so the slot the page writes can carry `maxPp` the way
  -- the engine's own Gold entry does (Mon.learnMove).  Gold already falls back
  -- to `pp` wherever it reads maxPp, so this is belt-and-braces, but a save
  -- written by the page should look like one written by the engine.
  local function movePp(game, moveId)
    local def = game and game.data and game.data.moves
      and game.data.moves[moveId]
    if def and type(def.pp) == "number" then return def.pp end
    return nil
  end

  -- Does this learn need the forget sequence at all?  Mirrors the engine's own
  -- decision in src/battle/gen2/Mon.lua's learnMove + Game2:learnMoveOn: only
  -- the four-slots-full case asks; a free slot (fewer than four), a move the
  -- mon already knows ("known") and anything the engine refuses all finish
  -- without a screen, so the engine's own flow must keep them.
  function M.needsForget(mon, moveId)
    if type(mon) ~= "table" or type(moveId) ~= "string" then return false end
    local moves = mon.moves
    if type(moves) ~= "table" or #moves < 4 then return false end
    for _, mv in ipairs(moves) do
      if mv and mv.id == moveId then return false end
    end
    return true
  end

  -- The slot the page wrote, tidied for Gold, and the event the engine's own
  -- Gold forget arm raises: Game2's pushList writes the slot itself and emits
  -- pokemon.move_learned there, so the page's write must emit it too or a mod
  -- counting moves (g9-evolutions, the scene) misses the four-slot case.
  function M.afterLearn(game, mon, moveId)
    if type(mon) ~= "table" or type(mon.moves) ~= "table" then return end
    local pp = movePp(game, moveId)
    for _, mv in ipairs(mon.moves) do
      if mv and mv.id == moveId and mv.maxPp == nil then
        mv.maxPp = pp or mv.pp
      end
    end
    local ok, Runtime = pcall(require, "src.mods.Runtime")
    if ok and type(Runtime) == "table" and type(Runtime.emit) == "function" then
      pcall(Runtime.emit, "pokemon.move_learned", { mon = mon, moveId = moveId })
    end
  end

  -- The learner this suite registered, resolved the one way that can never
  -- mistake the engine's builtin for ours: a registry record the engine itself
  -- stamped `__modOwned` (src/ui/Screens.lua).  A MODERN UI: OFF boot, a failed
  -- sibling or a non-suite learner answers nil, and the caller keeps the
  -- engine's own flow.
  function M.factory(game)
    local ok, Screens = pcall(require, "src.ui.Screens")
    if not ok or type(Screens) ~= "table" or type(Screens.get) ~= "function" then
      return nil
    end
    local id = M.screenId()
    local okG, factory = pcall(Screens.get, game, id)
    if okG and type(factory) == "table" and factory.__modOwned == true
        and type(factory.new) == "function" then
      return factory
    end
    return nil
  end

  function M.screenId()
    local id = mod.exports and mod.exports.moveLearnScreenId
    if type(id) == "string" and id ~= "" then return id end
    return "MoveLearnMenu"
  end

  -- Gold's own "learned the move" fanfare (Game2:learnMoveOn's soundOpts), so
  -- the page's closing box plays the cart's sound rather than the Gen 1 key the
  -- module defaults to -- which resolves to nothing on Gold (Sound.GEN2_ALIASES
  -- carries no such row).  Fail-open: an unknown key simply makes no sound.
  local LEARNED_SOUND = "Sfx_DexFanfare5079"

  -- Wrap the class method once.  Every learn flow constructs its Game2 from
  -- this class (src/core/Game2.lua), so one wrap covers the pack's TM use, the
  -- RARE CANDY, an evolution's new move and the move tutor alike.
  function M.install()
    local ok, Game2 = pcall(require, "src.core.Game2")
    if not ok or type(Game2) ~= "table"
        or type(Game2.learnMoveOn) ~= "function" then
      return false
    end
    if Game2.__g9uiLearner then return true end
    local vanillaLearnMoveOn = Game2.learnMoveOn
    Game2.__g9uiLearner = true
    Game2.learnMoveOn = function(self, mon, moveId, onDone)
      if not M.needsForget(mon, moveId) then
        return vanillaLearnMoveOn(self, mon, moveId, onDone)
      end
      local factory = M.factory(self)
      if not factory then
        return vanillaLearnMoveOn(self, mon, moveId, onDone)
      end
      local function finish(learned)
        if learned then M.afterLearn(self, mon, moveId) end
        if onDone then onDone(learned) end
      end
      local okB, inst = pcall(factory.new, self, mon, moveId, finish,
        LEARNED_SOUND)
      if okB and type(inst) == "table" then
        inst.screenId = inst.screenId or M.screenId()
        self.stack:push(inst)
        return
      end
      -- A learner that is registered but will not build must not cost the
      -- player the move: say why, then run the engine's own flow on top of it.
      warn("g9-gui: the Gold out-of-battle learner failed to build ("
        .. tostring(inst) .. ") -- using the engine's own learn flow")
      return vanillaLearnMoveOn(self, mon, moveId, onDone)
    end
    return true
  end

  return M
end
