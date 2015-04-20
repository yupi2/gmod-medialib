medialib={} medialib.Modules={} medialib.DEBUG=false function medialib.modulePlaceholder(name) medialib.Modules[name]={} end function medialib.module(name,opts) if medialib.DEBUG then print("[MediaLib] Creating module "..name) end local mod=medialib.Modules[name]or{ name=name, options=opts,} medialib.Modules[name]=mod return mod end  if SERVER then for _,fname in pairs(file.Find("medialib/*","LUA"))do AddCSLuaFile("medialib/"..fname) end end function medialib.load(name) local mod=medialib.Modules[name] if mod then return mod end if medialib.DEBUG then print("[MediaLib] Loading unreferenced module "..name) end local file="medialib/"..name..".lua" include(file) return medialib.Modules[name] end local real_file_meta={ read=function(self) return file.Read(self.lua_path,"LUA") end, load=function(self) include(self.lua_path) end, addcs=function(self) AddCSLuaFile(self.lua_path) end,} real_file_meta.__index=real_file_meta local virt_file_meta={ read=function(self) return self.source end, load=function(self) RunString(self.source) end, addcs=function()end } virt_file_meta.__index=virt_file_meta  medialib.FolderItems={}  function medialib.folderIterator(folder) local files={} for _,fname in pairs(file.Find("medialib/"..folder.."/*","LUA"))do table.insert(files,setmetatable({ name=fname, lua_path="medialib/"..folder.."/"..fname },real_file_meta)) end for k,item in pairs(medialib.FolderItems)do local mfolder=k:match("^([^/]*).+") if mfolder==folder then table.insert(files,setmetatable({ name=k:match("^[^/]*/(.+)"), source=item },virt_file_meta)) end end return pairs(files) end if CLIENT then concommand.Add("medialib_noflash",function() SetClipboardText("http://get.adobe.com/flashplayer/otherversions/") MsgN("[ MediaLib no flash guide ]") MsgN("1. Open this website in your browser (not the ingame Steam browser): http://get.adobe.com/flashplayer/otherversions/") MsgN("   (it has been automatically added to your clipboard)") MsgN("2. Download and install the NSAPI (for Firefox) version") MsgN("3. Restart your Garry's Mod") MsgN("[ ======================= ]") end) end
-- Module oop
medialib.modulePlaceholder("oop")
do
local oop=medialib.module("oop") oop.Classes=oop.Classes or{} function oop.class(name,parent) local cls=oop.Classes[name] if not cls then cls=oop.createClass(name,parent) oop.Classes[name]=cls if medialib.DEBUG then print("[MediaLib] Registering oopclass "..name) end end return cls end function oop.resolveClass(obj) if obj==nil then return oop.Object end local t=type(obj) if t=="string" then local clsobj=oop.Classes[obj] if clsobj then return clsobj end error("Resolving class from inexistent class string '"..tostring(obj).."'") end if t=="table" then return obj end error("Resolving class from invalid object '"..tostring(obj).."'") end  local NIL_PARENT={}  local metamethods={'__add','__call','__concat','__div','__ipairs','__le', '__len','__lt','__mod','__mul','__pairs','__pow','__sub', '__tostring','__unm'} function oop.createClass(name,parent) local cls={}  local par_cls if parent~=NIL_PARENT then par_cls=oop.resolveClass(parent) end  cls.name=name cls.super=par_cls  cls.members=setmetatable({},{__index=cls.super})  cls.members.class=cls cls.members.super=cls.super  local cls_instance_meta={} do cls_instance_meta.__index=cls.members  for _,name in pairs(metamethods)do cls_instance_meta[name]=function(...) local method=cls.members[name] if method then return method(...) end end end end  local class_meta={} do class_meta.__index=cls.members class_meta.__newindex=cls.members class_meta.__tostring=function(self) return "class "..self.name end   function class_meta:__call(...) local instance={} setmetatable(instance,cls_instance_meta)  local ctor=instance.initialize if ctor then ctor(instance,...)end return instance end end  setmetatable(cls,class_meta) return cls end oop.Object=oop.createClass("Object",NIL_PARENT)  function oop.Object:hashCode() local meta=getmetatable(self) local old_tostring=meta.__tostring meta.__tostring=nil local hash=tostring(self):match("table: 0x(.*)") meta.__tostring=old_tostring return hash end function oop.Object:__tostring() return string.format("%s@%s",self.class.name,self:hashCode()) end
end
-- Module mediabase
medialib.modulePlaceholder("mediabase")
do
local oop=medialib.load("oop") local Media=oop.class("Media") function Media:on(event,callback) self._events=self._events or{} self._events[event]=self._events[event]or{} self._events[event][callback]=true end function Media:emit(event,...) if not self._events then return end local callbacks=self._events[event] if not callbacks then return end for k,_ in pairs(callbacks)do k(...) end end function Media:getServiceBase() error("Media:getServiceBase() not implemented!") end function Media:getUrl() return self.unresolvedUrl end    function Media:isValid() return false end  function Media:IsValid() return self:isValid() end  function Media:setVolume(vol)end function Media:getVolume()end    function Media:setQuality(quality)end  function Media:seek(time)end function Media:getTime() return 0 end    function Media:sync(time,margin)  if self._lastSync and self._lastSync>CurTime()-5 then return end local shouldSync=self:shouldSync() if not shouldSync then return end self:seek(time+0.1) self._lastSync=CurTime() end function Media:shouldSync(time,margin)  if not self:isValid()or not self:isPlaying()then return false end margin=margin or 2 local curTime=self:getTime() local diff=math.abs(curTime-time) return diff>margin end    function Media:getState()end  function Media:isPlaying() return self:getState()=="playing" end function Media:play()end function Media:pause()end function Media:stop()end function Media:draw(x,y,w,h)end
end
-- Module servicebase
medialib.modulePlaceholder("servicebase")
do
local oop=medialib.load("oop") local Service=oop.class("Service") function Service:on(event,callback) self._events={} self._events[event]=self._events[event]or{} self._events[event][callback]=true end function Service:emit(event,...) for k,_ in pairs(self._events[event]or{})do k(...) end end function Service:load(url,opts)end function Service:isValidUrl(url)end function Service:query(url,callback)end
end
-- Module timekeeper
medialib.modulePlaceholder("timekeeper")
do
 local oop=medialib.load("oop") local TimeKeeper=oop.class("TimeKeeper") function TimeKeeper:initialize() self:reset() end function TimeKeeper:reset() self.cachedTime=0 self.running=false self.runningTimeStart=0 end function TimeKeeper:getTime() local time=self.cachedTime if self.running then time=time+(RealTime()-self.runningTimeStart) end return time end function TimeKeeper:isRunning() return self.running end function TimeKeeper:play() if self.running then return end self.runningTimeStart=RealTime() self.running=true end function TimeKeeper:pause() if not self.running then return end local runningTime=RealTime()-self.runningTimeStart self.cachedTime=self.cachedTime+runningTime self.running=false end function TimeKeeper:seek(time) self.cachedTime=time if self.running then self.runningTimeStart=RealTime() end end
end
-- Module service_html
medialib.modulePlaceholder("service_html")
do
local oop=medialib.load("oop") medialib.load("timekeeper") local volume3d=medialib.load("volume3d") local HTMLService=oop.class("HTMLService","Service") function HTMLService:load(url,opts) local media=oop.class("HTMLMedia")() media.unresolvedUrl=url self:resolveUrl(url,function(resolvedUrl,resolvedData) media:openUrl(resolvedUrl)  if opts and opts.use3D then volume3d.startThink(media,{pos=opts.pos3D,ent=opts.ent3D,fadeMax=opts.fadeMax3D}) end if resolvedData and resolvedData.start and(not opts or not opts.dontSeek)then media:seek(resolvedData.start)end end) return media end function HTMLService:resolveUrl(url,cb) cb(url,self:parseUrl(url)) end local AwesomiumPool={instances={}} concommand.Add("medialib_awepoolinfo",function() print("AwesomiumPool> Free instance count: "..#AwesomiumPool.instances) end)  timer.Create("MediaLib.AwesomiumPoolCleaner",30,0,function() if #AwesomiumPool.instances<3 then return end local inst=table.remove(AwesomiumPool.instances,1) if IsValid(inst)then inst:Remove()end end) function AwesomiumPool.get() local inst=table.remove(AwesomiumPool.instances,1) if not IsValid(inst)then local pnl=vgui.Create("DHTML") return pnl end return inst end function AwesomiumPool.free(inst) if not IsValid(inst)then return end inst:SetHTML("") table.insert(AwesomiumPool.instances,inst) end local HTMLMedia=oop.class("HTMLMedia","Media") local panel_width,panel_height=1280,720 function HTMLMedia:initialize() self.timeKeeper=oop.class("TimeKeeper")() self.panel=AwesomiumPool.get() local pnl=self.panel pnl:SetPos(0,0) pnl:SetSize(panel_width,panel_height) local hookid="MediaLib.HTMLMedia.FakeThink-"..self:hashCode() hook.Add("Think",hookid,function() if not IsValid(self.panel)then hook.Remove("Think",hookid) return end self.panel:Think() end) local oldcm=pnl._OldCM or pnl.ConsoleMessage pnl._OldCM=oldcm pnl.ConsoleMessage=function(pself,msg)  if string.find(msg,"XMLHttpRequest")then return end if string.find(msg,"Unsafe JavaScript attempt to access")then return end return oldcm(pself,msg) end pnl:SetPaintedManually(true) pnl:SetVisible(false) pnl:AddFunction("medialiblua","Event",function(id,jsonstr) self:handleHTMLEvent(id,util.JSONToTable(jsonstr)) end) end function HTMLMedia:getBaseService() return "html" end function HTMLMedia:openUrl(url) self.panel:OpenURL(url) self.URLChanged=CurTime() end function HTMLMedia:runJS(js,...) local code=string.format(js,...) self.panel:QueueJavascript(code) end function HTMLMedia:handleHTMLEvent(id,event) if id=="stateChange" then local state=event.state local setToState if event.time then self.timeKeeper:seek(event.time) end if state=="playing" then setToState="playing" self.timeKeeper:play() elseif state=="ended" or state=="paused" or state=="buffering" then setToState=state self.timeKeeper:pause() end if setToState then self.state=setToState self:emit(setToState) end end end function HTMLMedia:getState() return self.state end function HTMLMedia:updateTexture()  if self.lastUpdatedFrame~=FrameNumber()then self.panel:UpdateHTMLTexture() self.lastUpdatedFrame=FrameNumber() end end function HTMLMedia:draw(x,y,w,h) self:updateTexture() local mat=self.panel:GetHTMLMaterial() surface.SetMaterial(mat) surface.SetDrawColor(255,255,255) local w_frac,h_frac=panel_width / mat:Width(),panel_height / mat:Height() surface.DrawTexturedRectUV(x or 0,y or 0,w or panel_width,h or panel_height,0,0,w_frac,h_frac) end function HTMLMedia:getTime() return self.timeKeeper:getTime() end function HTMLMedia:setQuality(qual) if self.lastSetQuality and self.lastSetQuality==qual then return end self.lastSetQuality=qual self:runJS("medialibDelegate.run('setQuality', {quality: %q})",qual) end   function HTMLMedia:applyVolume() local ivol=self.internalVolume or 1 local rvol=self.volume or 1 local vol=ivol * rvol if self.lastSetVolume and self.lastSetVolume==vol then return end self.lastSetVolume=vol self:runJS("medialibDelegate.run('setVolume', {vol: %f})",vol) end  function HTMLMedia:setVolume(vol) self.volume=vol self:applyVolume() end function HTMLMedia:seek(time) self:runJS("medialibDelegate.run('seek', {time: %d})",time) end function HTMLMedia:play() self.timeKeeper:play() self:runJS("medialibDelegate.run('play')") end function HTMLMedia:pause() self.timeKeeper:pause() self:runJS("medialibDelegate.run('pause')") end function HTMLMedia:stop() self.timeKeeper:pause() AwesomiumPool.free(self.panel) self.panel=nil self:emit("stopped") end function HTMLMedia:isValid() return IsValid(self.panel) end 
end
-- Module service_bass
medialib.modulePlaceholder("service_bass")
do
local oop=medialib.load("oop") local volume3d=medialib.load("volume3d") local BASSService=oop.class("BASSService","Service") function BASSService:load(url,opts) local media=oop.class("BASSMedia")() media.unresolvedUrl=url self:resolveUrl(url,function(resolvedUrl,resolvedData) if opts and opts.use3D then media.is3D=true media:runCommand(function(chan)  volume3d.startThink(media,{pos=opts.pos3D,ent=opts.ent3D,fadeMax=opts.fadeMax3D}) end) end media:openUrl(resolvedUrl) if resolvedData and resolvedData.start and(not opts or not opts.dontSeek)then media:seek(resolvedData.start)end end) return media end function BASSService:resolveUrl(url,cb) cb(url,self:parseUrl(url)) end local BASSMedia=oop.class("BASSMedia","Media") function BASSMedia:initialize() self.commandQueue={} end function BASSMedia:getBaseService() return "bass" end function BASSMedia:draw(x,y,w,h) surface.SetDrawColor(0,0,0) surface.DrawRect(x,y,w,h) local chan=self.chan if not IsValid(chan)then return end self.fftValues=self.fftValues or{} local valCount=chan:FFT(self.fftValues,FFT_1024) local valsPerX=(valCount==0 and 1 or(w/valCount)) local barw=w /(valCount) for i=1,valCount do surface.SetDrawColor(HSVToColor(i,0.95,0.5)) local barh=self.fftValues[i]*h surface.DrawRect(x+i*barw,y+(h-barh),barw,barh) end end function BASSMedia:openUrl(url) local flags="noplay noblock" if self.is3D then flags=flags.." 3d" end sound.PlayURL(url,flags,function(chan,errId,errName) self:bassCallback(chan,errId,errName) end) end function BASSMedia:openFile(path) local flags="noplay noblock" if self.is3D then flags=flags.." 3d" end sound.PlayFile(path,flags,function(chan,errId,errName) self:bassCallback(chan,errId,errName) end) end function BASSMedia:bassCallback(chan,errId,errName) if not IsValid(chan)then ErrorNoHalt("[MediaLib] BassMedia play failed: ",errName) return end self.chan=chan for _,c in pairs(self.commandQueue)do c(chan) end  self.commandQueue={} end function BASSMedia:runCommand(fn) if IsValid(self.chan)then fn(self.chan) else self.commandQueue[#self.commandQueue+1]=fn end end function BASSMedia:setVolume(vol) self:runCommand(function(chan)chan:SetVolume(vol)end) end function BASSMedia:seek(time) self:runCommand(function(chan)chan:SetTime(time)end) end function BASSMedia:getTime() if self:isValid()then return self.chan:GetTime() end return 0 end function BASSMedia:getState() if not self:isValid()then return "error" end local bassState=self.chan:GetState() if bassState==GMOD_CHANNEL_PLAYING then return "playing" end if bassState==GMOD_CHANNEL_PAUSED then return "paused" end if bassState==GMOD_CHANNEL_STALLED then return "buffering" end if bassState==GMOD_CHANNEL_STOPPED then return "paused" end  return end function BASSMedia:play() self:runCommand(function(chan)chan:Play()self:emit("playing")end) end function BASSMedia:pause() self:runCommand(function(chan)chan:Pause()self:emit("paused")end) end function BASSMedia:stop() self:runCommand(function(chan)chan:Stop()self:emit("stopped")end) end function BASSMedia:isValid() return IsValid(self.chan) end 
end
-- Module media
medialib.modulePlaceholder("media")
do
local media=medialib.module("media") media.Services={} function media.registerService(name,cls) media.Services[name]=cls() end media.RegisterService=media.registerService  function media.service(name) return media.Services[name] end media.Service=media.service  function media.guessService(url) for _,service in pairs(media.Services)do if service:isValidUrl(url)then return service end end end media.GuessService=media.guessService 
end
medialib.FolderItems["services/soundcloud.lua"] = "local oop=medialib.load(\"oop\") local SoundcloudService=oop.class(\"SoundcloudService\",\"BASSService\") local all_patterns={\"^https?://www.soundcloud.com/([A-Za-z0-9_%-]+/[A-Za-z0-9_%-]+)/?$\",\"^https?://soundcloud.com/([A-Za-z0-9_%-]+/[A-Za-z0-9_%-]+)/?$\",} function SoundcloudService:parseUrl(url)for _,pattern in pairs(all_patterns)do local id=string.match(url,pattern)if id then return{id=id}end end end function SoundcloudService:isValidUrl(url)return self:parseUrl(url)~=nil end function SoundcloudService:resolveUrl(url,callback)local urlData=self:parseUrl(url) http.Fetch(string.format(\"https://api.soundcloud.com/resolve.json?url=http://soundcloud.com/%s&client_id=YOUR_CLIENT_ID\",urlData.id),function(data)local sound_id=util.JSONToTable(data).id callback(string.format(\"https://api.soundcloud.com/tracks/%s/stream?client_id=YOUR_CLIENT_ID\",sound_id),{})end)end function SoundcloudService:query(url,callback)local urlData=self:parseUrl(url)local metaurl=string.format(\"http://api.soundcloud.com/resolve.json?url=http://soundcloud.com/%s&client_id=YOUR_CLIENT_ID\",urlData.id) http.Fetch(metaurl,function(result,size)if size==0 then callback(\"http body size = 0\")return end local entry=util.JSONToTable(result) if entry.errors then local msg=entry.errors[1].error_message or \"error\" local translated=msg if string.StartWith(msg,\"404\")then translated=\"Invalid id\" end callback(translated)return end callback(nil,{title=entry.title,duration=tonumber(entry.duration)/ 1000})end,function(err)callback(\"HTTP: \"..err)end)end medialib.load(\"media\").registerService(\"soundcloud\",SoundcloudService)"
medialib.FolderItems["services/twitch.lua"] = "local oop=medialib.load(\"oop\") local TwitchService=oop.class(\"TwitchService\",\"HTMLService\") local all_patterns={\"https?://www.twitch.tv/([A-Za-z0-9_%-]+)\",\"https?://twitch.tv/([A-Za-z0-9_%-]+)\"} function TwitchService:parseUrl(url)for _,pattern in pairs(all_patterns)do local id=string.match(url,pattern)if id then return{id=id}end end end function TwitchService:isValidUrl(url)return self:parseUrl(url)~=nil end local player_url=\"http://wyozi.github.io/gmod-medialib/twitch.html?channel=%s\" function TwitchService:resolveUrl(url,callback)local urlData=self:parseUrl(url)local playerUrl=string.format(player_url,urlData.id) callback(playerUrl,{start=urlData.start})end function TwitchService:query(url,callback)local urlData=self:parseUrl(url)local metaurl=string.format(\"https://api.twitch.tv/kraken/channels/%s\",urlData.id) http.Fetch(metaurl,function(result,size)if size==0 then callback(\"http body size = 0\")return end local data={}data.id=urlData.id local jsontbl=util.JSONToTable(result) if jsontbl then if jsontbl.error then callback(jsontbl.message)return else data.title=jsontbl.display_name..\": \"..jsontbl.status end else data.title=\"ERROR\" end callback(nil,data)end,function(err)callback(\"HTTP: \"..err)end)end medialib.load(\"media\").registerService(\"twitch\",TwitchService)"
medialib.FolderItems["services/vimeo.lua"] = "local oop=medialib.load(\"oop\") local VimeoService=oop.class(\"VimeoService\",\"HTMLService\") local all_patterns={\"https?://www.vimeo.com/([0-9]+)\",\"https?://vimeo.com/([0-9]+)\"} function VimeoService:parseUrl(url)for _,pattern in pairs(all_patterns)do local id=string.match(url,pattern)if id then return{id=id}end end end function VimeoService:isValidUrl(url)return self:parseUrl(url)~=nil end local player_url=\"http://wyozi.github.io/gmod-medialib/vimeo.html?id=%s\" function VimeoService:resolveUrl(url,callback)local urlData=self:parseUrl(url)local playerUrl=string.format(player_url,urlData.id) callback(playerUrl,{start=urlData.start})end function VimeoService:query(url,callback)local urlData=self:parseUrl(url)local metaurl=string.format(\"http://vimeo.com/api/v2/video/%s.json\",urlData.id) http.Fetch(metaurl,function(result,size,headers,httpcode)if size==0 then callback(\"http body size = 0\")return end if httpcode==404 then callback(\"Invalid id\")return end local data={}data.id=urlData.id local jsontbl=util.JSONToTable(result) if jsontbl then data.title=jsontbl[1].title data.duration=jsontbl[1].duration else data.title=\"ERROR\" end callback(nil,data)end,function(err)callback(\"HTTP: \"..err)end)end medialib.load(\"media\").registerService(\"vimeo\",VimeoService)"
medialib.FolderItems["services/webaudio.lua"] = "local oop=medialib.load(\"oop\")local WebAudioService=oop.class(\"WebAudioService\",\"BASSService\") local all_patterns={\"^https?://(.*)%.mp3\",\"^https?://(.*)%.ogg\",} function WebAudioService:parseUrl(url)for _,pattern in pairs(all_patterns)do local id=string.match(url,pattern)if id then return{id=id}end end end function WebAudioService:isValidUrl(url)return self:parseUrl(url)~=nil end function WebAudioService:resolveUrl(url,callback)callback(url,{})end local id3parser=medialib.load(\"id3parser\")local mp3duration=medialib.load(\"mp3duration\")function WebAudioService:query(url,callback)if string.EndsWith(url,\".mp3\")and(id3parser or mp3duration)then http.Fetch(url,function(data)local title,duration if id3parser then local parsed=id3parser.readtags_data(data)if parsed and parsed.title then title=parsed.title if parsed.artist then title=parsed.artist..\" - \"..title end if parsed.length then local length=tonumber(parsed.length)if length then duration=length / 1000 end end end end if mp3duration then duration=mp3duration.estimate_data(data)or duration end callback(nil,{title=title or url:match(\"([^/]+)$\"),duration=duration})end)return end callback(nil,{title=url:match(\"([^/]+)$\")})end medialib.load(\"media\").registerService(\"webaudio\",WebAudioService)"
medialib.FolderItems["services/webradio.lua"] = "local oop=medialib.load(\"oop\")local WebRadioService=oop.class(\"WebRadioService\",\"BASSService\") local all_patterns={\"^https?://(.*)%.pls\",\"^https?://(.*)%.m3u\"} function WebRadioService:parseUrl(url)for _,pattern in pairs(all_patterns)do local id=string.match(url,pattern)if id then return{id=id}end end end function WebRadioService:isValidUrl(url)return self:parseUrl(url)~=nil end function WebRadioService:resolveUrl(url,callback)callback(url,{})end function WebRadioService:query(url,callback)callback(nil,{title=url:match(\"([^/]+)$\")})end medialib.load(\"media\").registerService(\"webradio\",WebRadioService)"
medialib.FolderItems["services/youtube.lua"] = "local oop=medialib.load(\"oop\") local YoutubeService=oop.class(\"YoutubeService\",\"HTMLService\") local raw_patterns={\"^https?://[A-Za-z0-9%.%-]*%.?youtu%.be/([A-Za-z0-9_%-]+)\",\"^https?://[A-Za-z0-9%.%-]*%.?youtube%.com/watch%?.*v=([A-Za-z0-9_%-]+)\",\"^https?://[A-Za-z0-9%.%-]*%.?youtube%.com/v/([A-Za-z0-9_%-]+)\",}local all_patterns={} for k,p in pairs(raw_patterns)do local function with_sep(sep)table.insert(all_patterns,p..sep..\"t=(%d+)m(%d+)s\")table.insert(all_patterns,p..sep..\"t=(%d+)s?\")end with_sep(\"#\")with_sep(\"&\")with_sep(\"?\") table.insert(all_patterns,p)end function YoutubeService:parseUrl(url)for _,pattern in pairs(all_patterns)do local id,time1,time2=string.match(url,pattern)if id then local time_sec=0 if time1 and time2 then time_sec=tonumber(time1)*60+tonumber(time2)else time_sec=tonumber(time1)end return{id=id,start=time_sec}end end end function YoutubeService:isValidUrl(url)return self:parseUrl(url)~=nil end local player_url=\"http://wyozi.github.io/gmod-medialib/youtube.html?id=%s\" function YoutubeService:resolveUrl(url,callback)local urlData=self:parseUrl(url)local playerUrl=string.format(player_url,urlData.id) callback(playerUrl,{start=urlData.start})end function YoutubeService:query(url,callback)local urlData=self:parseUrl(url)local metaurl=string.format(\"http://gdata.youtube.com/feeds/api/videos/%s?alt=json\",urlData.id) http.Fetch(metaurl,function(result,size)if size==0 then callback(\"http body size = 0\")return end local data={}data.id=urlData.id local jsontbl=util.JSONToTable(result) if jsontbl and jsontbl.entry then local entry=jsontbl.entry data.title=entry[\"title\"][\"$t\"]data.duration=tonumber(entry[\"media$group\"][\"yt$duration\"][\"seconds\"])else callback(result)return end callback(nil,data)end,function(err)callback(\"HTTP: \"..err)end)end medialib.load(\"media\").registerService(\"youtube\",YoutubeService)"
-- Module serviceloader
medialib.modulePlaceholder("serviceloader")
do
medialib.load("servicebase") medialib.load("service_html") medialib.load("service_bass")  for _,file in medialib.folderIterator("services")do if medialib.DEBUG then print("[MediaLib] Registering service "..file.name) end if SERVER then file:addcs()end file:load() end
end
-- Module __loader
medialib.modulePlaceholder("__loader")
do
  medialib.load("mediabase") medialib.load("serviceloader") medialib.load("media")
end