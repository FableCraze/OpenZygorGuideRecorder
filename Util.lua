local _, NS = ...
NS.Util = NS.Util or {}
local U = NS.Util

function U.Trim(text)
    if text == nil then return "" end
    return tostring(text):match("^%s*(.-)%s*$") or ""
end

function U.SafeName(text)
    text = U.Trim(text)
    text = text:gsub("[\r\n\t]", " ")
    text = text:gsub("%s+", " ")
    return text
end

function U.EscapeZygorText(text)
    text = U.SafeName(text)
    text = text:gsub("\\", "\\\\")
    return text
end

function U.GetNPCIDFromGUID(guid)
    if not guid then return nil end
    local unitType, zero, serverID, instanceID, zoneUID, npcID = strsplit("-", guid)
    if unitType == "Creature" or unitType == "Vehicle" or unitType == "Pet" then
        return tonumber(npcID)
    end
    return nil
end

function U.GetUnitSnapshot(unit)
    if not UnitExists(unit) then return nil end
    local guid = UnitGUID(unit)
    local npcID = U.GetNPCIDFromGUID(guid)
    return {
        unit = unit,
        guid = guid,
        npcID = npcID,
        name = UnitName(unit),
        dead = UnitIsDeadOrGhost(unit) and true or false,
    }
end

function U.GetPlayerPosition()
    if not C_Map or not C_Map.GetBestMapForUnit then return nil end
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return nil end
    local mapInfo = C_Map.GetMapInfo(mapID)
    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    local x, y
    if pos then
        x, y = pos:GetXY()
        if x and y then
            x, y = x * 100, y * 100
        end
    end
    return {
        mapID = mapID,
        mapName = mapInfo and mapInfo.name or ("Map " .. mapID),
        x = x,
        y = y,
    }
end

function U.FormatPosition(pos, aliases)
    if not pos or not pos.mapID then return nil end
    if not pos.x or not pos.y then return nil end
    local mapName = aliases and aliases[pos.mapID] or pos.mapName or ("Map " .. pos.mapID)
    mapName = U.SafeName(mapName)
    return string.format("|goto %s/0 %.2f,%.2f", mapName, pos.x, pos.y)
end

function U.QuestTitle(questID)
    if not questID then return nil end
    local title
    if C_QuestLog and C_QuestLog.GetTitleForQuestID then
        title = C_QuestLog.GetTitleForQuestID(questID)
    end
    if not title and QuestUtils_GetQuestName then
        title = QuestUtils_GetQuestName(questID)
    end
    return title or ("Quest " .. tostring(questID))
end

function U.GetQuestObjectives(questID)
    if not C_QuestLog or not C_QuestLog.GetQuestObjectives then return {} end
    local objectives = C_QuestLog.GetQuestObjectives(questID)
    if type(objectives) ~= "table" then return {} end
    local out = {}
    for i, obj in ipairs(objectives) do
        out[i] = {
            text = obj.text,
            type = obj.type,
            finished = obj.finished and true or false,
            numFulfilled = obj.numFulfilled,
            numRequired = obj.numRequired,
        }
    end
    return out
end

function U.GetQuestIDs()
    local ids = {}
    if not C_QuestLog or not C_QuestLog.GetNumQuestLogEntries or not C_QuestLog.GetInfo then
        return ids
    end
    local n = C_QuestLog.GetNumQuestLogEntries()
    for i = 1, n do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and info.questID then
            ids[#ids + 1] = info.questID
        end
    end
    return ids
end

function U.GetItemFromLink(link)
    if not link then return nil end
    local itemID = tonumber(link:match("item:(%d+)"))
    local itemName = link:match("%[(.-)%]")
    return itemID, itemName
end

function U.DeepCopy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local out = {}
    seen[value] = out
    for k, v in pairs(value) do
        out[U.DeepCopy(k, seen)] = U.DeepCopy(v, seen)
    end
    return out
end

function U.SameObjective(a, b)
    if not a or not b then return false end
    return a.text == b.text
        and a.type == b.type
        and a.finished == b.finished
        and a.numFulfilled == b.numFulfilled
        and a.numRequired == b.numRequired
end

function U.EventSummary(e)
    if not e then return "" end
    if e.type == "QUEST_ACCEPTED" then
        return string.format("Aceitou: %s (#%s)", e.questName or "Quest", e.questID or "?")
    elseif e.type == "QUEST_TURNED_IN" then
        return string.format("Entregou: %s (#%s)", e.questName or "Quest", e.questID or "?")
    elseif e.type == "QUEST_OBJECTIVE" then
        local p = ""
        if e.numFulfilled and e.numRequired then p = string.format(" [%d/%d]", e.numFulfilled, e.numRequired) end
        return string.format("Objetivo: %s%s", e.text or "", p)
    elseif e.type == "GOSSIP_SELECTED" then
        return "Gossip: " .. (e.optionText or ("#" .. tostring(e.optionID or "?")))
    elseif e.type == "WAYPOINT" then
        return "Waypoint: " .. (e.label or "posição atual")
    elseif e.type == "TIP" then
        return "Tip: " .. (e.text or "")
    elseif e.type == "INTERACT" then
        return "Interação: " .. ((e.npc and e.npc.name) or "alvo")
    elseif e.type == "NPC_KILLED" then
        return "Kill: " .. ((e.npc and e.npc.name) or "NPC")
    elseif e.type == "VEHICLE_ENTER" then
        return "Entrou em veículo"
    elseif e.type == "VEHICLE_EXIT" then
        return "Saiu do veículo"
    elseif e.type == "LEVEL_UP" then
        return "Nível " .. tostring(e.level or "?")
    elseif e.type == "ZONE_CHANGED" then
        return "Mapa: " .. ((e.position and e.position.mapName) or "?")
    elseif e.type == "SCENARIO" then
        return "Cenário: " .. (e.text or "atualizado")
    elseif e.type == "SPELLCAST" then
        return "Spell: " .. (e.spellName or tostring(e.spellID or "?"))
    end
    return e.type or "Evento"
end
