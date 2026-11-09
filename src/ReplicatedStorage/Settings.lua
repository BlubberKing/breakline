-- Settings v1 (ModuleScript in ReplicatedStorage, named "Settings") - BOTH games (Lobby + Breakline), keep the two copies identical. NEW in v5.17 (GDD 5.12).
-- The player's own SETTINGS (the round gear button next to the Roblox chat / mic buttons, SettingsClient). Saved in the shared profile key "Settings"
-- (a table of only the values the player changed) and mirrored as the Player attribute SettingsJson, so both places read the same numbers.
--   Settings.LIST                          the settings in menu order: { key, name, col, kind = "slider" | "toggle", min, max, step, default, fmt, note }
--   Settings.Clean(t) -> t                 a checked copy (unknown keys dropped, numbers clamped + snapped, Sens only kept when it is a real number)
--   Settings.Get(player) -> t              every setting with defaults filled in (Sens = nil while the player never touched it)
--   Settings.Sens(player, fallback)        mouse sensitivity multiplier (the player's own, or `fallback` while untouched)
--   Settings.Master() -> SoundGroup        CLIENT only: the group every Sfx sound goes through (its Volume is the master volume)
local HttpService = game:GetService("HttpService")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")

local M = {}
M.DEFAULT_SENS = 0.55 -- MatchConfig.MOUSE_SENS: what the match multiplies your Roblox sensitivity by while the setting is untouched

-- col = which column of the settings panel it sits in
M.LIST = {
	{ key = "Sens", name = "MOUSE SENSITIVITY", col = 1, kind = "slider", min = 0.10, max = 2.00, step = 0.01, default = 0.55, fmt = "%.2f",
		note = "Multiplies your Roblox mouse sensitivity (matches + training zone + lobby)" },
	{ key = "AdsSens", name = "AIM SENSITIVITY", col = 1, kind = "slider", min = 0.20, max = 1.50, step = 0.01, default = 1.00, fmt = "%.2fx",
		note = "Extra multiplier while you aim down sights" },
	{ key = "Fov", name = "FIELD OF VIEW", col = 1, kind = "slider", min = 60, max = 110, step = 1, default = 75, fmt = "%d",
		note = "First person camera (matches + training zone)" },
	{ key = "Volume", name = "MASTER VOLUME", col = 2, kind = "slider", min = 0, max = 1, step = 0.01, default = 1, fmt = "%d%%", scale = 100,
		note = "Gunshots, footsteps, abilities, menus" },
	{ key = "Shake", name = "SCREEN SHAKE", col = 2, kind = "slider", min = 0, max = 1.5, step = 0.05, default = 1, fmt = "%d%%", scale = 100,
		note = "Camera rumble while sliding at speed" },
	{ key = "DamageNumbers", name = "DAMAGE NUMBERS", col = 3, kind = "toggle", default = true, note = "The numbers that pop up when you hit something" },
	{ key = "ShowStats", name = "SHOW FPS + PING", col = 3, kind = "toggle", default = false, note = "A small readout next to the settings button" },
}
M.ByKey = {}
for _, d in M.LIST do M.ByKey[d.key] = d end

local function snap(d, v)
	v = math.clamp(v, d.min, d.max)
	return math.floor(v / d.step + 0.5) * d.step
end

function M.Clean(t)
	local out = {}
	if type(t) ~= "table" then return out end
	for _, d in M.LIST do
		local v = t[d.key]
		if d.kind == "toggle" then
			if type(v) == "boolean" then out[d.key] = v end
		elseif type(v) == "number" and v == v then
			out[d.key] = snap(d, v)
		end
	end
	return out
end

local cache = setmetatable({}, { __mode = "k" }) -- player -> { raw, val }
function M.Get(player)
	local raw = player and player:GetAttribute("SettingsJson")
	if type(raw) ~= "string" then raw = "" end
	local c = player and cache[player]
	if c and c.raw == raw then return c.val end
	local saved = {}
	if raw ~= "" then
		local ok, t = pcall(HttpService.JSONDecode, HttpService, raw)
		if ok then saved = M.Clean(t) end
	end
	local val = {}
	for _, d in M.LIST do
		local v = saved[d.key]
		if v == nil then v = d.default end
		val[d.key] = v
	end
	if saved.Sens == nil then val.Sens = nil end -- untouched: the lobby keeps the normal Roblox feel, a match uses MatchConfig.MOUSE_SENS
	if player then cache[player] = { raw = raw, val = val } end
	return val
end

function M.Sens(player, fallback)
	local s = M.Get(player).Sens
	if type(s) == "number" then return s end
	return fallback
end

function M.Master()
	if not RunService:IsClient() then return nil end
	local g = SoundService:FindFirstChild("BreaklineMaster")
	if not g then
		g = Instance.new("SoundGroup")
		g.Name = "BreaklineMaster"
		g.Volume = 1
		g.Parent = SoundService
	end
	return g
end

return M
