local _, NS = ...
NS.Recorder = NS.Recorder or {}
local R = NS.Recorder
local U = NS.Util

R.initialized = false
R.questSnapshot = {}
R.lastTarget = nil
R.lastInteraction = nil
R.lastKill = nil
R.lastLoot = nil
R.lastGossipOptions = {}
R.suppressObjectiveScanUntil = 0

local function nowPrecise()
    return GetTime and GetTime() or 0
end

function R:IsRecording()
    local s = NS:GetActiveSession()
    return s and s.recording and not s.paused
end

function R:GetSession()
    return NS:GetActiveSession()
end

function R:TouchSession()
    local s = self:GetSession()
    if s then s.updatedAt = time() end
end

function R:Record(eventType, data)
    if not self:IsRecording() then return nil end
    local s = self:GetSession()
    if not s then return nil end
    data = data or {}
    data.id = s.nextEventId or (#s.events + 1)
    s.nextEventId = data.id + 1
    data.type = eventType
    data.timestamp = time()
    data.clock = nowPrecise()
    data.position = data.position or U.GetPlayerPosition()
    s.events[#s.events + 1] = data
    self:TouchSession()
    if NS.UI then NS.UI:OnRecordedEvent(data) end
    return data
end

function R:Start(name)
    local s = self:GetSession()
    if not s or (#s.events > 0 and not s.recording and name and name ~= "" and name ~= s.name) then
        s = NS:NewSession(name)
    elseif not s then
        s = NS:NewSession(name)
    elseif name and name ~= "" then
        s.name = name
    end
    s.recording = true
    s.paused = false
    self:BuildQuestSnapshot()
    self.lastTarget = U.GetUnitSnapshot("target")
    NS:Print("Gravação iniciada: |cffffff00" .. s.name .. "|r")
    if NS.UI then NS.UI:RefreshAll() end
    return s
end

function R:Pause()
    local s = self:GetSession()
    if not s or not s.recording then return end
    s.paused = true
    NS:Print("Gravação pausada.")
    if NS.UI then NS.UI:RefreshAll() end
end

function R:Resume()
    local s = self:GetSession()
    if not s or not s.recording then return end
    s.paused = false
    self:BuildQuestSnapshot()
    NS:Print("Gravação retomada.")
    if NS.UI then NS.UI:RefreshAll() end
end

function R:Stop()
    local s = self:GetSession()
    if not s then return end
    s.recording = false
    s.paused = false
    s.updatedAt = time()
    NS:Print("Gravação finalizada. Eventos: " .. tostring(#s.events))
    if NS.UI then NS.UI:RefreshAll() end
end

function R:ClearSession()
    local s = self:GetSession()
    if not s then return end
    wipe(s.events)
    s.nextEventId = 1
    s.updatedAt = time()
    NS:Print("Eventos da sessão atual apagados.")
    if NS.UI then NS.UI:RefreshAll() end
end

function R:Undo()
    local s = self:GetSession()
    if not s or #s.events == 0 then
        NS:Print("Não há eventos para desfazer.")
        return
    end
    local e = table.remove(s.events)
    NS:Print("Removido: " .. U.EventSummary(e))
    if NS.UI then NS.UI:RefreshAll() end
end

function R:GetLikelyNPC(maxAge)
    maxAge = maxAge or 8
    local t = nowPrecise()
    if self.lastInteraction and self.lastInteraction.clock and t - self.lastInteraction.clock <= maxAge then
        return U.DeepCopy(self.lastInteraction.npc)
    end
    local target = U.GetUnitSnapshot("target")
    if target and target.npcID then return target end
    if self.lastTarget and self.lastTarget.clock and t - self.lastTarget.clock <= maxAge then
        return U.DeepCopy(self.lastTarget.npc)
    end
    return nil
end

function R:RememberTarget()
    local npc = U.GetUnitSnapshot("target")
    if npc and npc.npcID then
        self.lastTarget = { clock = nowPrecise(), npc = npc }
    end
end

function R:RememberInteraction(source)
    local npc = U.GetUnitSnapshot("target")
    if npc and npc.npcID then
        self.lastInteraction = { clock = nowPrecise(), npc = npc, source = source }
    end
end

function R:ManualInteract()
    local npc = U.GetUnitSnapshot("target")
    if not npc or not npc.npcID then
        NS:Print("Selecione um NPC/objeto com GUID de criatura antes de registrar a interação.")
        return
    end
    self.lastInteraction = { clock = nowPrecise(), npc = npc, source = "manual" }
    self:Record("INTERACT", { npc = npc, manual = true })
end

function R:AddWaypoint(label)
    self:Record("WAYPOINT", { label = U.SafeName(label or "") })
end

function R:AddTip(text)
    text = U.Trim(text)
    if text == "" then
        NS:Print("Digite um texto para a dica.")
        return
    end
    self:Record("TIP", { text = text })
end

function R:BuildQuestSnapshot()
    self.questSnapshot = {}
    for _, questID in ipairs(U.GetQuestIDs()) do
        self.questSnapshot[questID] = U.GetQuestObjectives(questID)
    end
end

function R:ScanQuestObjectives()
    if not self:IsRecording() then return end
    if GetTime() < (self.suppressObjectiveScanUntil or 0) then return end
    local currentIDs = {}
    for _, questID in ipairs(U.GetQuestIDs()) do
        currentIDs[questID] = true
        local before = self.questSnapshot[questID] or {}
        local after = U.GetQuestObjectives(questID)
        for i, obj in ipairs(after) do
            local old = before[i]
            if not old or not U.SameObjective(old, obj) then
                local progressed = (obj.numFulfilled or 0) ~= (old and old.numFulfilled or 0)
                    or obj.finished ~= (old and old.finished or false)
                if progressed then
                    local relatedNpc
                    if self.lastKill and self.lastKill.clock and nowPrecise() - self.lastKill.clock <= 4 then
                        relatedNpc = U.DeepCopy(self.lastKill.npc)
                    elseif self.lastInteraction and self.lastInteraction.clock and nowPrecise() - self.lastInteraction.clock <= 4 then
                        relatedNpc = U.DeepCopy(self.lastInteraction.npc)
                    end
                    local relatedLoot
                    if self.lastLoot and self.lastLoot.clock and nowPrecise() - self.lastLoot.clock <= 4 then
                        relatedLoot = U.DeepCopy(self.lastLoot.item)
                    end
                    self:Record("QUEST_OBJECTIVE", {
                        questID = questID,
                        questName = U.QuestTitle(questID),
                        objectiveIndex = i,
                        text = obj.text,
                        objectiveType = obj.type,
                        finished = obj.finished,
                        numFulfilled = obj.numFulfilled,
                        numRequired = obj.numRequired,
                        relatedNpc = relatedNpc,
                        relatedLoot = relatedLoot,
                    })
                end
            end
        end
        self.questSnapshot[questID] = after
    end
    for questID in pairs(self.questSnapshot) do
        if not currentIDs[questID] then self.questSnapshot[questID] = nil end
    end
end

function R:OnQuestAccepted(...)
    if not self:IsRecording() then return end
    local a, b = ...
    local questID = tonumber(b) or tonumber(a)
    if not questID then return end
    local npc = self:GetLikelyNPC(8)
    self:Record("QUEST_ACCEPTED", {
        questID = questID,
        questName = U.QuestTitle(questID),
        npc = npc,
        automatic = npc == nil,
    })
    self.questSnapshot[questID] = U.GetQuestObjectives(questID)
    self.suppressObjectiveScanUntil = GetTime() + 0.25
end

function R:OnQuestTurnedIn(questID)
    if not self:IsRecording() or not questID then return end
    local npc = self:GetLikelyNPC(8)
    self:Record("QUEST_TURNED_IN", {
        questID = questID,
        questName = U.QuestTitle(questID),
        npc = npc,
    })
    self.questSnapshot[questID] = nil
    self.suppressObjectiveScanUntil = GetTime() + 0.25
end

function R:OnGossipShow()
    if not self:IsRecording() then return end
    self:RememberInteraction("gossip")
    wipe(self.lastGossipOptions)
    if C_GossipInfo and C_GossipInfo.GetOptions then
        local options = C_GossipInfo.GetOptions() or {}
        for _, opt in ipairs(options) do
            if opt and opt.gossipOptionID then
                self.lastGossipOptions[opt.gossipOptionID] = opt.name or opt.text
            end
        end
    end
end

function R:OnGossipSelected(optionID)
    if not self:IsRecording() or not optionID then return end
    local text = self.lastGossipOptions[optionID]
    self:Record("GOSSIP_SELECTED", {
        optionID = optionID,
        optionText = text,
        npc = self:GetLikelyNPC(12),
    })
end

function R:OnCombatLog()
    if not self:IsRecording() or not NS:GetSettings().captureCombatKills then return end
    local timestamp, subevent, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName = CombatLogGetCurrentEventInfo()
    if subevent ~= "PARTY_KILL" and subevent ~= "UNIT_DIED" then return end
    local npcID = U.GetNPCIDFromGUID(destGUID)
    if not npcID then return end
    local npc = { guid = destGUID, npcID = npcID, name = destName }
    self.lastKill = { clock = nowPrecise(), npc = npc }
    -- Do not create a standalone event for every mob. It is correlated with objective progress.
end

function R:OnLootOpened()
    if not self:IsRecording() then return end
    if not GetNumLootItems or not GetLootSlotLink then return end
    for slot = 1, GetNumLootItems() do
        local link = GetLootSlotLink(slot)
        local itemID, itemName = U.GetItemFromLink(link)
        if itemID then
            self.lastLoot = { clock = nowPrecise(), item = { itemID = itemID, name = itemName } }
        end
    end
end

function R:OnVehicle(enter)
    if not self:IsRecording() or not NS:GetSettings().captureVehicle then return end
    self:Record(enter and "VEHICLE_ENTER" or "VEHICLE_EXIT", {
        npc = self:GetLikelyNPC(5),
    })
end

function R:OnScenarioUpdate()
    if not self:IsRecording() or not NS:GetSettings().captureScenario then return end
    local text = "Scenario updated"
    local scenarioType, name
    if C_Scenario and C_Scenario.GetInfo then
        local info = C_Scenario.GetInfo()
        if type(info) == "table" then
            name = info.name
            scenarioType = info.type
        else
            name = info
        end
    end
    if name then text = name end
    self:Record("SCENARIO", { text = text, scenarioType = scenarioType })
end

function R:OnLevelUp(level)
    if not self:IsRecording() or not NS:GetSettings().captureLevelUps then return end
    self:Record("LEVEL_UP", { level = tonumber(level) or UnitLevel("player") })
end

function R:OnZoneChanged()
    if not self:IsRecording() or not NS:GetSettings().captureZoneChanges then return end
    self:Record("ZONE_CHANGED", {})
end

function R:OnSpellcast(unit, _, spellID)
    if unit ~= "player" or not self:IsRecording() or not NS:GetSettings().captureSpellcasts then return end
    local spellName = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)
    self:Record("SPELLCAST", { spellID = spellID, spellName = spellName })
end

function R:InitializeHooks()
    if self.hooksInitialized then return end
    self.hooksInitialized = true

    if C_GossipInfo and C_GossipInfo.SelectOption and hooksecurefunc then
        hooksecurefunc(C_GossipInfo, "SelectOption", function(optionID)
            R:OnGossipSelected(optionID)
        end)
    end

    if type(InteractUnit) == "function" and hooksecurefunc then
        hooksecurefunc("InteractUnit", function(unit)
            if unit == "target" or unit == "mouseover" then
                local npc = U.GetUnitSnapshot(unit)
                if npc and npc.npcID then
                    R.lastInteraction = { clock = nowPrecise(), npc = npc, source = "InteractUnit" }
                end
            end
        end)
    end
end

function R:Initialize()
    if self.initialized then return end
    self.initialized = true
    self:InitializeHooks()

    local f = CreateFrame("Frame")
    self.frame = f
    local events = {
        "PLAYER_TARGET_CHANGED",
        "QUEST_ACCEPTED",
        "QUEST_TURNED_IN",
        "QUEST_LOG_UPDATE",
        "QUEST_WATCH_UPDATE",
        "QUEST_POI_UPDATE",
        "GOSSIP_SHOW",
        "QUEST_DETAIL",
        "QUEST_PROGRESS",
        "QUEST_COMPLETE",
        "COMBAT_LOG_EVENT_UNFILTERED",
        "LOOT_OPENED",
        "UNIT_ENTERED_VEHICLE",
        "UNIT_EXITED_VEHICLE",
        "SCENARIO_UPDATE",
        "SCENARIO_CRITERIA_UPDATE",
        "PLAYER_LEVEL_UP",
        "ZONE_CHANGED_NEW_AREA",
        "UNIT_SPELLCAST_SUCCEEDED",
    }
    for _, e in ipairs(events) do pcall(f.RegisterEvent, f, e) end

    local scanPending = false
    local function scheduleScan()
        if scanPending then return end
        scanPending = true
        C_Timer.After(0.15, function()
            scanPending = false
            R:ScanQuestObjectives()
        end)
    end

    f:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_TARGET_CHANGED" then
            R:RememberTarget()
        elseif event == "QUEST_ACCEPTED" then
            R:OnQuestAccepted(...)
        elseif event == "QUEST_TURNED_IN" then
            R:OnQuestTurnedIn(...)
        elseif event == "QUEST_LOG_UPDATE" or event == "QUEST_WATCH_UPDATE" or event == "QUEST_POI_UPDATE" then
            if NS:GetSettings().captureQuestObjectives then scheduleScan() end
        elseif event == "GOSSIP_SHOW" then
            if NS:GetSettings().captureGossip then R:OnGossipShow() end
        elseif event == "QUEST_DETAIL" or event == "QUEST_PROGRESS" or event == "QUEST_COMPLETE" then
            R:RememberInteraction(event)
        elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
            R:OnCombatLog()
        elseif event == "LOOT_OPENED" then
            R:OnLootOpened()
        elseif event == "UNIT_ENTERED_VEHICLE" then
            local unit = ...
            if unit == "player" then R:OnVehicle(true) end
        elseif event == "UNIT_EXITED_VEHICLE" then
            local unit = ...
            if unit == "player" then R:OnVehicle(false) end
        elseif event == "SCENARIO_UPDATE" or event == "SCENARIO_CRITERIA_UPDATE" then
            R:OnScenarioUpdate()
        elseif event == "PLAYER_LEVEL_UP" then
            R:OnLevelUp(...)
        elseif event == "ZONE_CHANGED_NEW_AREA" then
            R:OnZoneChanged()
        elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
            R:OnSpellcast(...)
        end
    end)
end
