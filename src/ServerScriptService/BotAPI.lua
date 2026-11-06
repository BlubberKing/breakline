-- BotAPI (ModuleScript in ServerScriptService, named "BotAPI") - BREAKLINE place only. NEW in v5.7.
-- An empty table that MatchServer FILLS with functions and BotServer USES (both require the same ModuleScript, so they share it).
-- It exists so the bot code never has to reach into MatchServer's private variables. MatchServer sets:
--   BotAPI.Phase()                   -> current phase name
--   BotAPI.Mode                      -> "Breakline" | "1v1"
--   BotAPI.Teams                     -> { "Red", "Blue" }
--   BotAPI.SpawnCF(team, slot)       -> CFrame on that team's finish line (slot picks one of the 3 spawn spots)
--   BotAPI.RandomSpot(team, enemy)   -> a free spot on the team's half of the map (or the other half when enemy = true)
--   BotAPI.LooseBoxes()              -> list of loose box Parts
--   BotAPI.EmptyHoles(team)          -> list of world positions of that team's empty holes
--   BotAPI.GrabBox(model, part)      -> true if the bot now carries that box (it auto-plugs when it reaches an empty hole on its own side)
--   BotAPI.DropBox(model)            -> the bot lets go of its box (also call it when the bot dies)
--   BotAPI.IsCarrying(model)         -> true while the bot carries a box
--   BotAPI.AddBotKill(team)          -> a bot of `team` killed somebody (counts for the 1v1 kill race)
--   BotAPI.ResetBotKills()           -> new match
local API = {}
return API
