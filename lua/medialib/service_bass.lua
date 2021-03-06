local oop = medialib.load("oop")

local BASSService = oop.class("BASSService", "Service")
function BASSService:load(url, opts)
	local media = oop.class("BASSMedia")()
	self:loadMediaObject(media, url, opts)
	return media
end

local BASSMedia = oop.class("BASSMedia", "Media")

function BASSMedia:initialize()
	self.bassPlayOptions = {"noplay", "noblock"}
	self.commandQueue = {}
end

function BASSMedia:getBaseService()
	return "bass"
end

function BASSMedia:updateFFT()
	local curFrame = FrameNumber()
	if self._lastFFTUpdate and self._lastFFTUpdate == curFrame then return end
	self._lastFFTUpdate = curFrame

	local chan = self.chan
	if not IsValid(chan) then return end

	self.fftValues = self.fftValues or {}
	chan:FFT(self.fftValues, FFT_512)
end

function BASSMedia:getFFT()
	return self.fftValues
end

function BASSMedia:draw(x, y, w, h)
	surface.SetDrawColor(0, 0, 0)
	surface.DrawRect(x, y, w, h)

	self:updateFFT()
	local fftValues = self:getFFT()
	if not fftValues then return end

	local valCount = #fftValues
	local valsPerX = (valCount == 0 and 1 or (w/valCount))

	local barw = w / (valCount)
	for i=1, valCount do
		surface.SetDrawColor(HSVToColor(i, 0.9, 0.5))

		local barh = fftValues[i]*h
		surface.DrawRect(x + i*barw, y + (h-barh), barw, barh)
	end
end

function BASSMedia:openUrl(url)
	local flags = table.concat(self.bassPlayOptions, " ")

	sound.PlayURL(url, flags, function(chan, errId, errName)
		self:bassCallback(chan, errId, errName)
	end)
end
function BASSMedia:openFile(path)
	local flags = table.concat(self.bassPlayOptions, " ")

	sound.PlayFile(path, flags, function(chan, errId, errName)
		self:bassCallback(chan, errId, errName)
	end)
end

function BASSMedia:bassCallback(chan, errId, errName)
	if not IsValid(chan) then
		ErrorNoHalt("[MediaLib] BassMedia play failed: ", errName)
		self._stopped = true

		self:emit("error", "loading_failed", string.format("BASS error id: %s; name: %s", errId, errName))
		return
	end

	-- Check if media was stopped before loading
	if self._stopped then
		chan:Stop()
		return
	end

	self.chan = chan

	for _,c in pairs(self.commandQueue) do
		c(chan)
	end

	-- Empty queue
	self.commandQueue = {}

	self:startStateChecker()
end

function BASSMedia:startStateChecker()
	local timerId = "MediaLib_BASS_EndChecker_" .. self:hashCode()
	timer.Create(timerId, 1, 0, function()
		if IsValid(self.chan) and self.chan:GetState() == GMOD_CHANNEL_STOPPED then
			self:emit("ended")
			timer.Destroy(timerId)
		end
	end)
end

function BASSMedia:runCommand(fn)
	if IsValid(self.chan) then
		fn(self.chan)
	else
		self.commandQueue[#self.commandQueue+1] = fn
	end
end

function BASSMedia:setVolume(vol)
	self.volume = vol
	self:runCommand(function(chan) chan:SetVolume(vol) end)
end

function BASSMedia:getVolume()
	return self.volume or 1
end

function BASSMedia:seek(time)
	self:runCommand(function(chan)
		if chan:IsBlockStreamed() then return end

		self._seekingTo = time

		local timerId = "MediaLib_BASSMedia_Seeker_" .. time .. "_" .. self:hashCode()
		local function AttemptSeek()
				-- someone used :seek with other time
			if  self._seekingTo ~= time or
				-- chan not valid
				not IsValid(chan) then

				timer.Destroy(timerId)
				return
			end

			chan:SetTime(time)

			-- seek succeeded
			if math.abs(chan:GetTime() - time) < 0.25 then
				timer.Destroy(timerId)
			end
		end
		timer.Create(timerId, 0.2, 0, AttemptSeek)
		AttemptSeek()
	end)
end
function BASSMedia:getTime()
	if self:isValid() and IsValid(self.chan) then
		return self.chan:GetTime()
	end
	return 0
end

function BASSMedia:getState()
	if not self:isValid() then return "error" end

	if not IsValid(self.chan) then return "loading" end

	local bassState = self.chan:GetState()
	if bassState == GMOD_CHANNEL_PLAYING then return "playing" end
	if bassState == GMOD_CHANNEL_PAUSED then return "paused" end
	if bassState == GMOD_CHANNEL_STALLED then return "buffering" end
	if bassState == GMOD_CHANNEL_STOPPED then return "paused" end -- umm??
	return
end

function BASSMedia:play()
	self:runCommand(function(chan)
		chan:Play()
		self:emit("playing")
	end)
end
function BASSMedia:pause()
	self:runCommand(function(chan)
		chan:Pause()
		self:emit("paused")
	end)
end
function BASSMedia:stop()
	self._stopped = true
	self:runCommand(function(chan)
		chan:Stop()
		self:emit("ended", {stopped = true})
		self:emit("destroyed")
	end)
end

function BASSMedia:isValid()
	return not self._stopped
end
