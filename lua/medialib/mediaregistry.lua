local mediaregistry = medialib.module("mediaregistry")

local cache = setmetatable({}, {__mode = "v"})

function mediaregistry.add(media)
	table.insert(cache, media)
end

concommand.Add("medialib_stopall", function()
	for _,v in pairs(cache) do
		v:stop()
	end

	table.Empty(cache)
end)

local cvar_debug = CreateConVar("medialib_debugmedia", "0")
hook.Add("HUDPaint", "MediaLib_DebugMedia", function()
	if not cvar_debug:GetBool() then return end

	local i = 0
	for _,media in pairs(cache) do
		local t = string.format("#%d %s", i, media:getDebugInfo())
		draw.SimpleText(t, "DermaDefault", 10, 10 + i*15)

		i=i+1
	end
end)
