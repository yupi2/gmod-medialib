local oop = medialib.load("oop")
medialib.load("timekeeper")

local HTMLService = oop.class("HTMLService", "Service")
function HTMLService:load(url, opts)
	local media = oop.class("HTMLMedia")()
	self:loadMediaObject(media, url, opts)
	return media
end

-- Whether or not we can trust that the HTML panel will send 'playing', 'paused'
-- and other playback related events. If this returns true, 'timekeeper' will
-- not be updated in playback related methods (except stop).
function HTMLService:hasReliablePlaybackEvents(media)
	return false
end

local AwesomiumPool = {instances = {}}
concommand.Add("medialib_awepoolinfo", function()
	print("AwesomiumPool> Free instance count: " .. #AwesomiumPool.instances)
end)
-- If there's bunch of awesomium instances in pool, we clean one up every 30 seconds
timer.Create("MediaLib.AwesomiumPoolCleaner", 30, 0, function()
	if #AwesomiumPool.instances < 3 then return end

	local inst = table.remove(AwesomiumPool.instances, 1)
	if IsValid(inst) then inst:Remove() end
end)
function AwesomiumPool.get()
	local inst = table.remove(AwesomiumPool.instances, 1)
	if not IsValid(inst) then
		local pnl = vgui.Create("DHTML")
		return pnl
	end
	return inst
end
function AwesomiumPool.free(inst)
	if not IsValid(inst) then return end
	inst:SetHTML("")

	table.insert(AwesomiumPool.instances, inst)
end

local HTMLMedia = oop.class("HTMLMedia", "Media")

local panel_width, panel_height = 1280, 720
function HTMLMedia:initialize()
	self.timeKeeper = oop.class("TimeKeeper")()

	self.panel = AwesomiumPool.get()

	local pnl = self.panel
	pnl:SetPos(0, 0)
	pnl:SetSize(panel_width, panel_height)

	local hookid = "MediaLib.HTMLMedia.FakeThink-" .. self:hashCode()
	hook.Add("Think", hookid, function()
		if not IsValid(self.panel) then
			hook.Remove("Think", hookid)
			return
		end

		self.panel:Think()
	end)

	local oldcm = pnl._OldCM or pnl.ConsoleMessage
	pnl._OldCM = oldcm
	pnl.ConsoleMessage = function(pself, msg)
		if msg then
			-- Filter some things out
			if string.find(msg, "XMLHttpRequest") then return end
			if string.find(msg, "Unsafe JavaScript attempt to access") then return end
			if string.find(msg, "Unable to post message to") then return end
		end

		return oldcm(pself, msg)
	end

	pnl:SetPaintedManually(true)
	pnl:SetVisible(false)

	pnl:AddFunction("medialiblua", "Event", function(id, jsonstr)
		self:handleHTMLEvent(id, util.JSONToTable(jsonstr))
	end)
end

function HTMLMedia:getBaseService()
	return "html"
end

function HTMLMedia:openUrl(url)
	self.panel:OpenURL(url)

	self.URLChanged = CurTime()
end
function HTMLMedia:runJS(js, ...)
	local code = string.format(js, ...)
	self.panel:QueueJavascript(code)
end

function HTMLMedia:handleHTMLEvent(id, event)
	if id == "stateChange" then
		local state = event.state
		local setToState

		if event.time then
			self.timeKeeper:seek(event.time)
		end
		if state == "playing" then
			setToState = "playing"
			self.timeKeeper:play()
		elseif state == "ended" or state == "paused" or state == "buffering" then
			setToState = state
			self.timeKeeper:pause()
		end

		if setToState then
			self.state = setToState
			self:emit(setToState)
		end
	elseif id == "playerLoaded" then
		for _,fn in pairs(self.commandQueue or {}) do
			fn()
		end
	elseif id == "error" then
		self:emit("error", {errorId = "service_error", errorName = "Error from service: " .. tostring(event.message)})
	else
		MsgN("[MediaLib] Unhandled HTML event " .. tostring(id))
	end
end
function HTMLMedia:getState()
	return self.state
end

local cvar_updatestride = CreateConVar("medialib_html_updatestride", "1", FCVAR_ARCHIVE)
function HTMLMedia:updateTexture()
	local framenumber = FrameNumber()

	local framesSinceUpdate = (framenumber - (self.lastUpdatedFrame or 0))
	if framesSinceUpdate >= cvar_updatestride:GetInt() then
		self.panel:UpdateHTMLTexture()
		self.lastUpdatedFrame = framenumber
	end
end

function HTMLMedia:getHTMLMaterial()
	if self._htmlMat then
		return self._htmlMat
	end
	local mat = self.panel:GetHTMLMaterial()
	self._htmlMat = mat
	return mat
end

function HTMLMedia:draw(x, y, w, h)
	self:updateTexture()

	local mat = self:getHTMLMaterial()
	surface.SetMaterial(mat)
	surface.SetDrawColor(255, 255, 255)

	local w_frac, h_frac = panel_width / mat:Width(), panel_height / mat:Height()
	surface.DrawTexturedRectUV(x or 0, y or 0, w or panel_width, h or panel_height, 0, 0, w_frac, h_frac)
end

function HTMLMedia:getTime()
	return self.timeKeeper:getTime()
end

function HTMLMedia:setQuality(qual)
	if self.lastSetQuality and self.lastSetQuality == qual then
		return
	end
	self.lastSetQuality = qual

	self:runJS("medialibDelegate.run('setQuality', {quality: %q})", qual)
end

-- This applies the volume to the HTML panel
-- There is a undocumented 'internalVolume' variable, that can be used by eg 3d vol
function HTMLMedia:applyVolume()
	local ivol = self.internalVolume or 1
	local rvol = self.volume or 1

	local vol = ivol * rvol

	if self.lastSetVolume and self.lastSetVolume == vol then
		return
	end
	self.lastSetVolume = vol

	self:runJS("medialibDelegate.run('setVolume', {vol: %f})", vol)
end

-- This sets a volume variable
function HTMLMedia:setVolume(vol)
	self.volume = vol
	self:applyVolume()
end

function HTMLMedia:getVolume()
	-- could cookies potentially set the volume to something other than 1?
	return self.volume or 1
end

function HTMLMedia:seek(time)
	self:runJS("medialibDelegate.run('seek', {time: %.1f})", time)
end

-- See HTMLService:hasReliablePlaybackEvents()
function HTMLMedia:hasReliablePlaybackEvents()
	local service = self:getService()
	return service and service:hasReliablePlaybackEvents(self)
end

function HTMLMedia:play()
	if not self:hasReliablePlaybackEvents() then
		self.timeKeeper:play()
	end

	self:runJS("medialibDelegate.run('play')")
end
function HTMLMedia:pause()
	if not self:hasReliablePlaybackEvents() then
		self.timeKeeper:pause()
	end

	self:runJS("medialibDelegate.run('pause')")
end
function HTMLMedia:stop()
	AwesomiumPool.free(self.panel)
	self.panel = nil

	self.timeKeeper:pause()
	self:emit("ended", {stopped = true})
	self:emit("destroyed")
end

function HTMLMedia:runCommand(fn)
	if self._playerLoaded then
		fn()
	else
		self.commandQueue = self.commandQueue or {}
		self.commandQueue[#self.commandQueue+1] = fn
	end
end

function HTMLMedia:isValid()
	return IsValid(self.panel)
end
