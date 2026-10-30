-- PlaceConfig (ModuleScript in ReplicatedStorage) - used by BOTH games: the Lobby place and the Breakline place.
-- Keep the two copies identical. Fill in the two Place IDs (Studio > Game Explorer / Asset Manager > right click the place > Copy Place ID).
local P = {}

P.LOBBY_PLACE_ID     = 85704647759197     -- TODO: Place ID of the LOBBY place (the start place of the experience)
P.BREAKLINE_PLACE_ID = 103313739791329     -- TODO: Place ID of the BREAKLINE place (the gamemode)

P.TEAM_SIZE   = 3            -- players per team (3 = real 3v3). Set 1 to test a 1v1 match with two accounts.
P.MAX_PARTY   = 3            -- biggest party (cannot be bigger than TEAM_SIZE in a real game)
P.QUEUE_TIMEOUT = 300        -- seconds a party can sit in the queue before it is removed

-- Breakline server behavior
P.ROSTER_WAIT = 45           -- seconds a match server waits for everybody in the roster to arrive before it starts anyway
P.REDIRECT_PUBLIC_JOINS = true -- Breakline: players who join Breakline directly (not through the lobby queue) are sent to the lobby (never in Studio)

-- Rewards (Breakline gives these at the end of a match, saved in the shared profile)
P.SOULS_WIN  = 100
P.SOULS_LOSS = 40

return P


