-- Updated WarmUp by Cybeloras of Mal'Ganis. Uses debugprofile start/stop instead of GetTime because it seems that GetTime() is not updated during loading screens anymore.
-- Further updated by Phanx for WoW 6.x (https://github.com/phanx-wow/Warmup)
-- Addon forked by tomchapin to work with WoW 7.1
-- tomchapin - Fixed CreateTitleRegion error so addon works with WoW 7.1 
-- tomchapin - Renamed addon so it has a zero at the front and hopefully will load first.
-- tomchapin - Fixed the CreateFrame function (per recommendation from Bezal1)
-- Forked by ZZumMallen for WoW 11.0 prepatch
-- ZZumMallen - updated varrios Addon() functions to include the C_AddOns namespace to blizz change and restore functionality
-- ZZumMallen - added annotations to fix random type and param check errors
-- ZZumMallen - fixed debugger, timerlocked was not defined and causing errors 
-- ZZumMallen - fixed debugger reset, was setting the timer to nil and unable to resume
-- ZZumMallen - updated slashcommand to refer to containerFrame class instead of the name paramter

---@type any
local bdTemplate = BackdropTemplateMixin and "BackdropTemplate" -- this parameter combo was causing errors when used inside the container, redefined as single parameter

local containerFrame = CreateFrame("Frame", "WarmupOutputFrame", UIParent, bdTemplate)
containerFrame:Hide()

local outputFrame = CreateFrame("ScrollingMessageFrame", "WarmupChatFrame", containerFrame, bdTemplate)
outputFrame:SetFontObject("ChatFontNormal")
outputFrame:SetMaxLines(512)

containerFrame:SetScript("OnShow", function(self)
	self:SetScript("OnShow", nil)

	self:SetPoint("LEFT", 50, 100)
	self:SetSize(525, 390)
	self:EnableMouse(true)
	self:SetMovable(true)

	outputFrame:SetPoint("TOPLEFT", 12, -7 - 22)
	outputFrame:SetPoint("BOTTOMRIGHT", -8, 12)
	outputFrame:SetJustifyH("LEFT")

	self:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 16,
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16,
		insets = { left = 4, right = 4, top = 4,  bottom = 4 },
	})
	self:SetBackdropColor(0, 0, 0)
	self:SetBackdropBorderColor(0.8, 0.8, 0.8)

	local bg = self:CreateTexture(nil, "BORDER")
	bg:SetPoint("BOTTOMLEFT", 5, 5)
	bg:SetPoint("TOPRIGHT", -5, -5)
	bg:SetAtlas("collections-background-tile")
	bg:SetAlpha(0.9)
	--bg:SetVertexColor(204/255, 225/255, 1)

	local close = CreateFrame("Button", nil, self, "UIPanelCloseButton", bdTemplate)
	close:SetPoint("TOPRIGHT")

	local title = self:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", 12, -2)
	title:SetPoint("RIGHT", close, "LEFT", -6, 0)
	title:SetHeight(close:GetHeight())
	title:SetJustifyH("LEFT")
	title:SetText("Warmup")

	local div = self:CreateTexture(nil, "ARTWORK")
	div:SetPoint("TOPLEFT", 8, -26)
	div:SetPoint("TOPRIGHT", -8, -26)
	div:SetHeight(8)
	div:SetTexture("Interface\\Common\\UI-TooltipDivider-Transparent")

	-- local tr = self:CreateTitleRegion()
	-- tr:SetPoint("TOPLEFT")
	-- tr:SetPoint("TOPRIGHT")
	-- tr:SetPoint("BOTTOM", div)

	outputFrame:SetFading(false)
	outputFrame:EnableMouseWheel(true)
	outputFrame:SetScript("OnMouseWheel", function(self, delta)
		if IsControlKeyDown() then
			return delta > 0 and self:PageUp() or delta < 0 and self:PageDown()
		end
		local n = IsShiftKeyDown() and self:GetNumMessages() or 5
		if delta > 0 then
			for i = 1, n do
				self:ScrollUp()
			end
		elseif delta < 0 then
			for i = 1, n do
				self:ScrollDown()
			end
		end
	end)
end)

collectgarbage("stop")
collectgarbage("collect")
local initmem = collectgarbage("count")
local longesttime, biggestmem, totalmem, totalgarbage, mostgarbage, gctime = 0, 0, 0, 0, 0, 0
local totaltime = 0
local eventcounts = {}
local eventargs = {}
local threshtimes, threshmems = {1.0, 0.5, 0.1}, {1000, 500, 100}
local threshcolors = {"|cffff0000", "|cffff8000", "|cffffff80", "|cff80ff80"}
local sv, intransit, reloading, longestaddon, biggestaddon, varsloadtime, logging, mostgarbageaddon, leftworld
local memstack = {initmem}

local timerIsLocked = debugprofilestop()
local previousTimer

local function start()
	-- resets the timer - do not us debugprofilestart() for ... reasons. Use debugprofile stop like you would GetTime()
	if previousTimer then
		previousTimer = nil
	end

	if timerIsLocked then
		-- outputFrame:AddMessage("ATTEMPTED TO START TIMER WHILE LOCKED")
		-- outputFrame:AddMessage(debugstack())
	end

	timerIsLocked = debugprofilestop()
end

local function stop()
	if not timerIsLocked then
		-- outputFrame:AddMessage("ATTEMPTED TO STOP TIMER WHILE UNLOCKED")
		-- outputFrame:AddMessage(debugstack())
	end

	local elapsed = debugprofilestop() - timerIsLocked
	previousTimer = timerIsLocked -- redefines old timer for reset
	return elapsed, previousTimer
end

start()

	--[[ (insert a space between the dashes and brackets)
	LoadAddOn("Blizzard_DebugTools")
	EventTraceFrame_HandleSlashCmd ("")
	EVENT_TRACE_MAX_ENTRIES = 10000
	--]]

local frame = CreateFrame("Frame", "WarmupFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate")
Warmup = {}

frame:SetScript("OnEvent", function(self, event, ...)
	if eventcounts then
		eventcounts[event] = (eventcounts[event] or 0) + 1
		eventargs[event] = max(select("#", ...), eventargs[event] or 0)
	end
	if Warmup[event] then Warmup[event](Warmup, ...) end
end)


local function GetThreshColor(set, value)
	local t = set == "mem" and threshmems or threshtimes
	for i,v in pairs(t) do
		if value >= v then return threshcolors[i] end
	end
	return threshcolors[4]
end


local function PutOut(txt, color, time, mem, gc)
	local outstr = (time and format("%.3f sec | ", time) or "") ..
		color .. txt ..
		(mem and format(" (%d KiB", mem) or "") ..
		(gc and format(" - %d KiB)", gc) or mem and ")" or "")
	outputFrame:AddMessage(outstr)
end


local function PutOutAO(name, time, mem, garbage)
	outputFrame:AddMessage(format("%s%.3f sec|r | %s (%s%d KiB|r - %s%d KiB|r)", GetThreshColor("time", time), time,
		name, GetThreshColor("mem", mem), mem, GetThreshColor("mem", garbage), garbage))
	return format("%.3f sec | %s (%d KiB - %d KiB)", time, name, mem, garbage)
end



do
	local loadandpop = function(...)
		local newm, newt = tremove(memstack)
		local oldm, oldt = tremove(memstack)
		local origm, origt = tremove(memstack)
		tinsert(memstack, (origm or 0) + newm - oldm)
		return ...
	end
	local lao = LoadAddOn
	LoadAddOn = function (...)
		if timerIsLocked then
			stop() -- stop any runaway timers
		end

		start()
		collectgarbage("collect")
		gctime = gctime + stop()/1000

		local newmem = collectgarbage("count")
		tinsert(memstack, newmem)
		tinsert(memstack, newmem)
		start() -- start the timer for ADDON_LOADED to finish
		return loadandpop(lao(...))
	end
end

do
	-- These functions were all added to the C_AddOns namespace and no longer work unless parent is referenced
	for i=1,C_AddOns.GetNumAddOns() do
		if C_AddOns.IsAddOnLoaded(i) then
			if C_AddOns.GetAddOnInfo(i) ~= "!!Warmup" then
				outputFrame:AddMessage("Addon loaded before Warmup: " .. C_AddOns.GetAddOnInfo(i))
			end
		end
	end
end

function Warmup:Init()
	if not WarmupSV then WarmupSV = {} end
	sv = WarmupSV
	sv.addoninfo = {}

	local _ReloadUI = ReloadUI
	function ReloadUI()
		sv.reloadingUI = true
		_ReloadUI()
	end
end


function Warmup:DumpEvents()
	local sortt = {}
	for ev,val in pairs(eventcounts) do tinsert(sortt, ev) end

	table.sort(sortt)

	for i,ev in pairs(sortt) do
		outputFrame:AddMessage(format(threshcolors[1].."%d|r (%d) | %s%s|r", eventcounts[ev], eventargs[ev], threshcolors[4], ev))
	end
	outputFrame:AddMessage("------------")
end


function Warmup:ADDON_LOADED(addon)
	local addonmem = collectgarbage("count")
	local lastmem = tremove(memstack) or 0
	local lasttime = stop()/1000
	local diff = addonmem - lastmem

	totaltime = totaltime + lasttime

	start()
	collectgarbage("collect")
	gctime = gctime + stop()/1000

	local gcmem = collectgarbage("count")
	local garbage = addonmem - gcmem

	if not sv then self:Init() end

	tinsert(sv.addoninfo, PutOutAO(addon, lasttime, diff - garbage, garbage))

	if lasttime > longesttime then
		longesttime = lasttime
		longestaddon = addon
	end
	if (diff - garbage) > biggestmem then
		biggestmem = diff - garbage
		biggestaddon = addon
	end
	if garbage > mostgarbage then
		mostgarbage = garbage
		mostgarbageaddon = addon
	end
	totalgarbage = totalgarbage + garbage
	totalmem = totalmem + diff
	tinsert(memstack, gcmem)
	start()
end


function Warmup:VARIABLES_LOADED()
	if varsloadtime then return end
	stop() -- stop the timer (it is still running from the last addon loaded

	start()
	collectgarbage("collect")
	gctime = gctime + stop()/1000

	local lastmem = collectgarbage("count")

	varsloadtime = GetTime()
	PutOut("Addon Loadup", threshcolors[4], totaltime, lastmem - initmem, totalgarbage)
	PutOut("Warmup's Garbage Collection", threshcolors[4], gctime)
	PutOut("Longest addon: ".. longestaddon, threshcolors[2], longesttime)
	PutOut("Biggest addon: ".. biggestaddon, threshcolors[2], nil, biggestmem)
	PutOut("Most Garbage: "..mostgarbageaddon, threshcolors[2], nil, mostgarbage)

	frame:RegisterEvent("PLAYER_LOGIN")
--[[
	SlashCmdList["RELOAD"] = ReloadUI
	SLASH_RELOAD1 = "/rl"

	SlashCmdList["RELOADNODISABLE"] = function()
		sv.time = GetTime()
		reloading = true
		EnableAddOn("!!Warmup")
		ReloadUI()
	end
	SLASH_RELOADNODISABLE1 = "/rlnd"
]]
	SlashCmdList["WARMUP"] = function()
		containerFrame:SetShown(not containerFrame:IsShown()) -- was not working with the containerFrame name identifier
	end

	SLASH_WARMUP1 = "/wu"
	SLASH_WARMUP2 = "/warmup"

	collectgarbage("restart")
	--DisableAddOn("!!Warmup")
	start()
end


function Warmup:PLAYER_LOGIN()
	tinsert(UISpecialFrames, "WarmupOutputFrame")
	if sv.reloadingUI then
		sv.reloadingUI = nil
	else
		C_Timer.After(2, function() -- auto open window on login, delay required because of UISpecialFrames
			if not UnitAffectingCombat("player") then
				containerFrame:Show()
			end
		end)
	end
	logging = true
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
end


function Warmup:PLAYER_ENTERING_WORLD()
	if logging then
		local entrytime = stop()/1000
		PutOut("World entry", threshcolors[4], entrytime)
		PutOut("Total time", threshcolors[4], entrytime + totaltime + gctime)
		sv.time = nil
		varsloadtime = nil
	elseif leftworld then
		PutOut("Zoning", threshcolors[4], stop()/1000)
		leftworld = nil
	end

	logging = nil
	frame:RegisterAllEvents()
	frame:UnregisterEvent("PLAYER_LOGIN")
	frame:UnregisterEvent("PLAYER_LOGOUT")
	frame:UnregisterEvent("PLAYER_ENTERING_WORLD")

	--self:DumpEvents()
	eventcounts = nil
end


function Warmup:PLAYER_LEAVING_WORLD()
	sv.time = GetTime()
	frame:RegisterAllEvents()
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	frame:RegisterEvent("PLAYER_LOGOUT")

	eventcounts = {}
	if timerIsLocked then
		stop() -- stop any runaway timers
	end
	start()
	leftworld = true
end


function Warmup:PLAYER_LOGOUT()
	if not sv.reloadingUI then sv.time = nil end
end

frame:RegisterAllEvents()