-----------------------------------------------------------------------------------------------
-- Client Lua Script for Instigator
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
 
require "Window"

-----------------------------------------------------------------------------------------------
-- Instigator Module Definition
-----------------------------------------------------------------------------------------------
local Instigator = {}
local GeminiTimer

-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
local knChannelListHeight = 500
local stealthId = 38784

function split(str, delim)
    local result,pat,lastPos = {},"(.-)" .. delim .. "()",1
    for part, pos in string.gfind(str, pat) do
        table.insert(result, part); lastPos = pos
    end
    table.insert(result, string.sub(str, lastPos))
    return result
end
 
-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function Instigator:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self 

  return o
end

function Instigator:Init()
	local bHasConfigureFunction = false
	local strConfigureButtonText = ""
	local tDependencies = {
		-- "UnitOrPackageName",
	}
  Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)

  Apollo.RegisterEventHandler("PvpKillNotification", "OnPvpKillEvent", self)

  self.emoteTimer = ApolloTimer.Create(0.2, true, "OnEmoteTimer", self)
  self.emoteTimer:Stop()
end
 

-----------------------------------------------------------------------------------------------
-- Instigator OnLoad
-----------------------------------------------------------------------------------------------
function Instigator:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("Instigator.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
  Apollo.GetPackage("Gemini:Timer-1.0").tPackage:Embed(self)
end

-----------------------------------------------------------------------------------------------
-- Instigator OnDocLoaded
-----------------------------------------------------------------------------------------------
function Instigator:OnDocLoaded()
	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
    self.wndMain = Apollo.LoadForm(self.xmlDoc, "InstigatorForm", nil, self)
		if self.wndMain == nil then
			Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
			return
		end

    self:InitConfigOptions()

    if self.pinWindow then 
      self.wndMain:Show(true)
    else
      self.wndMain:Show(false)
    end

    self:ConfigMainWindow()
    self:ConfigChannels()
    self:ConfigEmoter()
    self:ConfigRepeater()
    self:ConfigSpammer()
	end
end

--===================== Configuration =======================--
function Instigator:InitConfigOptions() 
  Apollo.RegisterSlashCommand("mad", "OnInstigatorOn", self)
  Apollo.RegisterSlashCommand("MAD", "OnInstigatorOn", self)

  if not self.pinWindow then self.pinWindow = false end
  if not self.targetEmote then self.targetEmote = false end
  if not self.killingBlowEmote then self.killingBlowEmote = false end
  if not self.killingBlowEmoteString then self.killingBlowEmoteString = "/laugh" end
  if not self.targetEmoteString then self.targetEmoteString = "/laugh" end

  self.wndMain:FindChild("BGFrame:PinButton"):SetCheck(self.pinWindow)
end

function Instigator:ConfigMainWindow()
  self.emoterTabButton = self.wndMain:FindChild("BGFrame:ToggleEmoterBtn")
  self.spammerTabButton = self.wndMain:FindChild("BGFrame:ToggleSpammerBtn")
  self.repeaterTabButton = self.wndMain:FindChild("BGFrame:ToggleRepeaterBtn")

  self.emoterTabButton:SetCheck(true)

  self.emoterContainer = self.wndMain:FindChild("EmoterContainer")
  self.repeaterContainer = self.wndMain:FindChild("RepeaterContainer")
  self.spammerContainer = self.wndMain:FindChild("SpammerContainer")

  self.repeaterContainer:Show(false)
  self.spammerContainer:Show(false)
end

function Instigator:ConfigEmoter()
  self.targetEmoteContainer = self.emoterContainer:FindChild("TargetEmoteContainer")
  self.killingBlowEmoteContainer = self.emoterContainer:FindChild("KillingBlowEmoteContainer")

  self.targetEmoteContainer:FindChild("RadioButton"):SetCheck(self.targetEmote)
  self.killingBlowEmoteContainer:FindChild("RadioButton"):SetCheck(self.killingBlowEmote)

  self.targetEmoteContainer:FindChild("EmoteInputContainer:emoteInput"):SetText(self.targetEmoteString)
  self.killingBlowEmoteContainer:FindChild("EmoteInputContainer:emoteInput"):SetText(self.killingBlowEmoteString)
end

function Instigator:ConfigRepeater()
  self.repeaterList = self.repeaterContainer:FindChild("RepeaterList")
  self.repeaterControls = self.repeaterContainer:FindChild("RepeaterControls")

  if self.savedRepeaters then
    for _,repeater in pairs(self.savedRepeaters) do
      self:AddRepeaterItem(repeater.timerDelay, repeater.timerStr, repeater.channel)
    end
  else
    self:AddRepeaterItem()  
  end
end

function Instigator:ConfigSpammer()
  self.spammerContainer:FindChild("PasteControls"):SetData({channel = "s"})
  self.spamTextWindow = self.spammerContainer:FindChild("InputContainer:PasteTextArea")
  local wndInputMenu = self.wndMain:FindChild("SpammerContainer:PasteControls:InputWindow")
  local left, top, right, bottom = wndInputMenu:GetAnchorOffsets()

  wndInputMenu:SetData({
    left = left,
    top = top,
    right = right,
    bottom = bottom
  })

  if self.savedSpamText ~= nil then
    self.spamTextWindow:SetText(self.savedSpamText)
  end
end

function Instigator:ConfigChannels()
  for _,channel in pairs(ChatSystemLib.GetChannels()) do
    if channel:GetType() == ChatSystemLib.ChatChannel_Command then
      self.commandChannel = channel
    end
  end

  self.arChatColor =
  {
    [ChatSystemLib.ChatChannel_Command]     = ApolloColor.new("ChatCommand"),
    [ChatSystemLib.ChatChannel_System]      = ApolloColor.new("ChatSystem"),
    [ChatSystemLib.ChatChannel_Debug]       = ApolloColor.new("ChatDebug"),
    [ChatSystemLib.ChatChannel_Say]       = ApolloColor.new("ChatSay"),
    [ChatSystemLib.ChatChannel_Yell]      = ApolloColor.new("ChatShout"),
    [ChatSystemLib.ChatChannel_Whisper]     = ApolloColor.new("ChatWhisper"),
    [ChatSystemLib.ChatChannel_Party]       = ApolloColor.new("ChatParty"),
    [ChatSystemLib.ChatChannel_AnimatedEmote]   = ApolloColor.new("ChatEmote"),
    [ChatSystemLib.ChatChannel_Zone]      = ApolloColor.new("ChatZone"),
    [ChatSystemLib.ChatChannel_ZonePvP]     = ApolloColor.new("ChatPvP"),
    [ChatSystemLib.ChatChannel_Trade]       = ApolloColor.new("ChatTrade"),
    [ChatSystemLib.ChatChannel_Guild]       = ApolloColor.new("ChatGuild"),
    [ChatSystemLib.ChatChannel_GuildOfficer]  = ApolloColor.new("ChatGuildOfficer"),
    [ChatSystemLib.ChatChannel_Society]     = ApolloColor.new("ChatCircle2"),
    [ChatSystemLib.ChatChannel_Custom]      = ApolloColor.new("ChatCustom"),
    [ChatSystemLib.ChatChannel_NPCSay]      = ApolloColor.new("ChatNPC"),
    [ChatSystemLib.ChatChannel_NPCYell]     = ApolloColor.new("ChatNPC"),
    [ChatSystemLib.ChatChannel_NPCWhisper]    = ApolloColor.new("ChatNPC"),
    [ChatSystemLib.ChatChannel_Datachron]     = ApolloColor.new("ChatNPC"),
    [ChatSystemLib.ChatChannel_Combat]      = ApolloColor.new("ChatGeneral"),
    [ChatSystemLib.ChatChannel_Realm]       = ApolloColor.new("ChatSupport"),
    [ChatSystemLib.ChatChannel_Loot]      = ApolloColor.new("ChatLoot"),
    [ChatSystemLib.ChatChannel_Emote]       = ApolloColor.new("ChatEmote"),
    [ChatSystemLib.ChatChannel_PlayerPath]    = ApolloColor.new("ChatGeneral"),
    [ChatSystemLib.ChatChannel_Instance]    = ApolloColor.new("ChatParty"),
    [ChatSystemLib.ChatChannel_WarParty]    = ApolloColor.new("ChatWarParty"),
    [ChatSystemLib.ChatChannel_WarPartyOfficer] = ApolloColor.new("ChatWarPartyOfficer"),
    [ChatSystemLib.ChatChannel_Advice]      = ApolloColor.new("ChatAdvice"),
    [ChatSystemLib.ChatChannel_AccountWhisper]  = ApolloColor.new("ChatAccountWisper"),
  }
end

--===================== Emoter =======================--
function Instigator:OnEmoteTimer()
  local emote = self.wndMain:FindChild("EmoterContainer:DelayContainer:EmoteInputContainer:emoteInput"):GetText()
  self:DoEmote(emote)
end

function Instigator:OnEmoteDelayChange(windowHandler, windowControl, strText)
  local repeatDelay = tonumber(strText)
  if repeatDelay ~= nil then
    self.emoteTimer:Set(repeatDelay, true, "OnEmoteTimer")
    self.emoteTimer:Stop()
  end
end

function Instigator:OnTargetEmoteChange(windowHandler, windowControl, strText)
  self.targetEmoteString = strText
end

function Instigator:OnKillingBlowEmoteChange(windowHandler, windowControl, strText)
  self.killingBlowEmoteString = strText
end

function Instigator:OnEmoteStart()
  self:OnEmoteTimer()
  self.emoteTimer:Start()
end

function Instigator:OnEmoteStop()
  self.emoteTimer:Stop()
end

function Instigator:DoEmote(emote)
  if not self:IsPlayerStealthed() then
    self.commandChannel:Send(String_GetWeaselString(Apollo.GetString("ChatLog_SlashPrefix"), emote:gsub("/", "")))
  end
end

function Instigator:OnPvpKillEvent(victimName, reason, killerName, killerClass, victimTeam)
  local emote
  local playerUnit = GameLib.GetPlayerUnit()

  if self.targetEmote then
    local playerTarget = playerUnit:GetTarget()

    if playerTarget then
      emote = self.targetEmoteContainer:FindChild("EmoteInputContainer:emoteInput"):GetText()

      if victimName == playerTarget:GetName() then
        self:DoEmote(emote)
      end
    end
  end

  if self.killingBlowEmote and killerName == playerUnit:GetName() then
    emote = self.killingBlowEmoteContainer:FindChild("EmoteInputContainer:emoteInput"):GetText()
    self:DoEmote(emote)
  end
end

function Instigator:IsPlayerStealthed()
  local unitPlayer = GameLib.GetPlayerUnit()
  if not unitPlayer or unitPlayer:GetClassId() ~= 5 then 
    return false
  end

  local buffs = unitPlayer:GetBuffs()
  if buffs then
    for k, v in pairs(buffs.arBeneficial) do
      if v.splEffect:GetId() == stealthId then
        return true
      end

      return false
    end
  end
end

function Instigator:OnTargetEmoteCheck()
  self.targetEmote = true
end

function Instigator:OnTargetEmoteUncheck()
  self.targetEmote = false
end

function Instigator:OnKillingBlowEmoteCheck()
  self.killingBlowEmote = true
end

function Instigator:OnKillingBlowEmoteUncheck()
  self.killingBlowEmote = false
end

--===================== Repeater =======================--
function Instigator:OnRepeatTimer(str, channel)
  if str ~= nil and channel ~= nil then
    self:SendText(str, channel)
  else
    Print("Error: OnRepeatTimer str or channel is nil")
  end
end

function Instigator:OnNewTimerButton()
  self:AddRepeaterItem()
end

function Instigator:AddRepeaterItem(delay, str, channel)
  local wnd = Apollo.LoadForm(self.xmlDoc, "RepeaterListItem", self.repeaterList, self)
  local timerDelay, timerStr, timerChannel

  if delay ~= nil then
    timerDelay = delay
  else
    timerDelay = 15
  end

  if str ~= nil then
    timerStr = str
  else
    timerStr = "Hodor"
  end

  if channel ~= nil then
    timerChannel = channel
  else
    timerChannel = "s"
  end

  wnd:SetData({timerDelay = timerDelay, timerStr = timerStr, channel = timerChannel})

  wnd:FindChild("InputContainer:delayInput"):SetText(timerDelay)
  wnd:FindChild("RepeatMessageContainer:msgInput"):SetText(timerStr)
  local channelObj = self:FindChannelByAbbrev(timerChannel)

  if channelObj ~= nil then
    local crText = self.arChatColor[channelObj:GetType()] or ApolloColor.new("white")
    wnd:FindChild("InputTypeBtn:InputType"):SetText(channelObj:GetCommand())
    wnd:FindChild("InputTypeBtn:InputType"):SetTextColor(crText)
  else
    wnd:FindChild("InputTypeBtn:InputType"):SetText(timerChannel)
  end
  
  self.repeaterList:ArrangeChildrenVert()

  local repeaterInputMenu = wnd:FindChild("InputWindow")
  local left, top, right, bottom = repeaterInputMenu:GetAnchorOffsets()

  repeaterInputMenu:SetData({
    left = left,
    top = top,
    right = right,
    bottom = bottom
  })
end

function Instigator:FindChannelByAbbrev(command)
  for _,channel in pairs(ChatSystemLib.GetChannels()) do
    if channel:GetAbbreviation() == command or channel:GetCommand() == command then
      return channel
    end
  end
end

function Instigator:OnRepeatStart(windowHandler, windowControl)
  local repeaterData = windowHandler:GetParent():GetData()
  local timer = self:ScheduleRepeatingTimer("OnRepeatTimer", repeaterData.timerDelay, repeaterData.timerStr, repeaterData.channel)

  -- Set the timer id on the play/stop button window data
  windowHandler:SetData({timer = timer})

  self:SendText(repeaterData.timerStr, repeaterData.channel)
end

function Instigator:OnRepeatStop(windowHandler, windowControl)
  self:CancelTimer(windowHandler:GetData().timer)
end

function Instigator:OnRepeatStringChange(windowHandler, windowControl, strText)
  local repeater = windowHandler:GetParent():GetParent()

  if strText ~= nil then
    local data = repeater:GetData()
    data['timerStr'] = strText
    repeater:SetData(data)
  end
end

function Instigator:OnRepeatDelayChange(windowHandler, windowControl, strText)
  local repeater = windowHandler:GetParent():GetParent()

  local repeatDelay = tonumber(strText)
  if repeatDelay ~= nil then
    local data = repeater:GetData()
    data['timerDelay'] = repeatDelay
    repeater:SetData(data)
  end
end

function Instigator:OnDeleteAllTimersButton()
  local repeaters = self.repeaterList:GetChildren()

  for _,repeater in pairs(repeaters) do
    local timerWnd = repeater:FindChild("PlayStopButton")
    if timerWnd:IsChecked() then
      self:CancelTimer(timerWnd:GetData().timer)
    end
    
    repeater:Destroy()
  end

  self:AddRepeaterItem()
end

--===================== Spammer =======================--
function Instigator:OnSpamButton()
  local spammerContainer = self.wndMain:FindChild("SpammerContainer")
  local text = spammerContainer:FindChild("InputContainer:PasteTextArea"):GetText()
  local lines = split(text, "\n")
  local channel = spammerContainer:FindChild("PasteControls"):GetData().channel

  local tChannels = ChatSystemLib.GetChannels()

  for _,channelCurrent in pairs(tChannels) do
    local strCommand = channelCurrent:GetAbbreviation()

    if strCommand == "" or strCommand == nil then
      strCommand = channelCurrent:GetCommand()
    end

    if strCommand == channel then
      for _,line in ipairs(lines) do
        channelCurrent:Send(line)
      end
      break
    end
  end
end

--===================== General Functions =======================--
function Instigator:OnInstigatorOn()
  self.wndMain:Invoke() -- show the window
end

function Instigator:OnClose()
  self.wndMain:Close()
end

function Instigator:OnPinButtonCheck()
  self.pinWindow = true
end

function Instigator:OnPinButtonUncheck()
  self.pinWindow = false
end

function Instigator:OnTopTabBtn(wndHandler, wndControl)
  self.emoterContainer:Show(false)
  self.repeaterContainer:Show(false)
  self.spammerContainer:Show(false)

  if self.emoterTabButton:IsChecked() then
    self.emoterContainer:Show(true)
  elseif self.spammerTabButton:IsChecked() then
    self.spammerContainer:Show(true)
  elseif self.repeaterTabButton:IsChecked() then
    self.repeaterContainer:Show(true)
  end
end

function Instigator:SendText(text, channel)
  local tChannels = ChatSystemLib.GetChannels()

  for _,channelCurrent in pairs(tChannels) do
    local strCommand = channelCurrent:GetAbbreviation()

    if strCommand == "" or strCommand == nil then
      strCommand = channelCurrent:GetCommand()
    end

    if strCommand == channel then
      channelCurrent:Send(text)
    end
  end
end

function Instigator:OnInputTypeCheck(wndHandler, wndControl)
  local wndParent = wndControl:GetParent()
  local wndMenu = wndParent:FindChild("InputWindow")

  if wndHandler:IsChecked() then
    wndMenu:Invoke()
  else
    wndMenu:Close()
  end

  if wndHandler:IsChecked() then
    self:BuildInputTypeMenu(wndParent)
  end
end

function Instigator:BuildInputTypeMenu(wndParent)
  local wndInputMenu = wndParent:FindChild("InputWindow")
  local wndContent = wndInputMenu:FindChild("InputMenuContent")
  wndContent:DestroyChildren()

  local tChannels = ChatSystemLib.GetChannels()
  local nEntryHeight = 26 --height of the entry wnd
  local nCount = 0 --number of joined channels

  for _,channelCurrent in pairs(tChannels) do -- gives us our viewed channels
    if channelCurrent:GetCommand() ~= nil and channelCurrent:GetCommand() ~= "" then -- make sure it's a channelCurrent that can be spoken into
      local strCommand = channelCurrent:GetAbbreviation()

      if strCommand == "" or strCommand == nil then
        strCommand = channelCurrent:GetCommand()
      end

      local wndEntry = Apollo.LoadForm(self.xmlDoc, "InputMenuEntry", wndContent, self)

      local strType = ""
      if channelCurrent:GetType() == ChatSystemLib.ChatChannel_Custom then
        strType = Apollo.GetString("ChatLog_CustomLabel")
      end

      wndEntry:FindChild("NameText"):SetText(channelCurrent:GetName())
      wndEntry:FindChild("CommandText"):SetText(String_GetWeaselString(Apollo.GetString("ChatLog_SlashPrefix"), strCommand))
      wndEntry:SetData(channelCurrent) -- set the channelCurrent

      local crText = self.arChatColor[channelCurrent:GetType()] or ApolloColor.new("white")
      wndEntry:FindChild("CommandText"):SetTextColor(crText)
      wndEntry:FindChild("NameText"):SetTextColor(crText)

      nCount = nCount + 1
    end
  end

  if nCount == 0 then
    local wndEntry = Apollo.LoadForm(self.xmlDoc, "InputMenuEntry", wndContent, self)
    wndEntry:Enable(false)
    wndEntry:FindChild("NameText"):SetText(Apollo.GetString("CRB_No_Channels_Visible"))
    nCount = 1
  end

  nEntryHeight = nEntryHeight * nCount
  
  local pos = wndInputMenu:GetData()
  wndInputMenu:SetAnchorOffsets(pos.left, math.max(-knChannelListHeight , pos.top - nEntryHeight), pos.right, pos.bottom)

  wndContent:ArrangeChildrenVert()
end

function Instigator:OnInputMenuEntry(wndHandler, wndControl)
  local channelCurrent = wndControl:GetData()
  local wndParentControls = wndControl:GetParent():GetParent():GetParent()
  local strCommand = channelCurrent:GetAbbreviation()

  if strCommand == "" or strCommand == nil then
    strCommand = channelCurrent:GetCommand()
  end

  local crText = self.arChatColor[channelCurrent:GetType()] or ApolloColor.new("white")
  local wndInputType = wndParentControls:FindChild("InputTypeBtn:InputType")
  wndInputType:SetText(channelCurrent:GetCommand())
  wndInputType:SetTextColor(crText)

  wndControl:GetParent():GetParent():Show(false)
  wndParentControls:FindChild("InputTypeBtn"):SetCheck(false)

  local data = wndParentControls:GetData()
  data['channel'] = strCommand
  wndParentControls:SetData(data)
end

-----------------------------------------------------------------------------------------------
-- Carbine Event Callbacks
-----------------------------------------------------------------------------------------------
function Instigator:OnSave(saveLevel)
  if saveLevel ~= GameLib.CodeEnumAddonSaveLevel.Character then
    return nil
  end

  local repeaters = {}
  for idx,repeater in pairs(self.repeaterList:GetChildren()) do
    table.insert(repeaters, repeater:GetData())
  end

  local savedData = {}
  savedData.repeaters = repeaters
  savedData.spamText = self.spamTextWindow:GetText()
  savedData.pinWindow = self.pinWindow
  savedData.killingBlowEmote = self.killingBlowEmote
  savedData.targetEmote = self.targetEmote
  savedData.killingBlowEmoteString = self.killingBlowEmoteString
  savedData.targetEmoteString = self.targetEmoteString

  return savedData
end

function Instigator:OnRestore(saveLevel, savedData)
  self.savedRepeaters = savedData.repeaters
  self.savedSpamText = savedData.spamText
  self.pinWindow = savedData.pinWindow
  self.killingBlowEmote = savedData.killingBlowEmote
  self.targetEmote = savedData.targetEmote
  self.killingBlowEmoteString = savedData.killingBlowEmoteString
  self.targetEmoteString = savedData.targetEmoteString
end

function Instigator:OnWindowManagementReady()
  Event_FireGenericEvent("WindowManagementAdd", {wnd = self.mainWindow, strName = "Instigator"})
end

-----------------------------------------------------------------------------------------------
-- Instigator Instance
-----------------------------------------------------------------------------------------------
local InstigatorInst = Instigator:new()
InstigatorInst:Init()
