local _, NS = ...
NS.Exporter = NS.Exporter or {}
local E = NS.Exporter
local U = NS.Util

local function append(lines, value)
    if value and value ~= "" then lines[#lines + 1] = value end
end

local function zName(s)
    return U.SafeName(s or "")
end

local function luaString(s)
    s = tostring(s or "")
    s = s:gsub("\\", "\\\\")
    s = s:gsub('"', '\\"')
    s = s:gsub("\r", " "):gsub("\n", " ")
    return s
end

local function npcLine(prefix, npc)
    if not npc or not npc.npcID then return nil end
    return string.format("%s %s##%d", prefix, zName(npc.name or "NPC"), npc.npcID)
end

local function gotoFor(session, event)
    return U.FormatPosition(event.position, session.mapAliases)
end

local function lineWithGoto(text, session, event)
    local g = gotoFor(session, event)
    if g then return text .. " " .. g end
    return text
end

local function normalizeObjectiveText(text)
    text = U.SafeName(text or "Complete the objective")
    text = text:gsub("^%s*%d+/%d+%s+", "")
    return text
end

local function buildObjectiveGroups(events)
    local groups, order = {}, {}
    for _, ev in ipairs(events) do
        if ev.type == "QUEST_OBJECTIVE" and ev.questID and ev.objectiveIndex then
            local key = tostring(ev.questID) .. ":" .. tostring(ev.objectiveIndex)
            local g = groups[key]
            if not g then
                g = { first = ev, last = ev, events = {} }
                groups[key] = g
                order[#order + 1] = key
            end
            g.last = ev
            g.events[#g.events + 1] = ev
        end
    end
    return groups, order
end

local function objectiveAnchor(group)
    for _, ev in ipairs(group.events) do
        if ev.numFulfilled and ev.numFulfilled > 0 then return ev end
    end
    return group.last or group.first
end

local function makeObjectiveBlock(session, group)
    local ev = group.last or group.first
    local anchor = objectiveAnchor(group) or ev
    local lines = { "step" }
    local text = normalizeObjectiveText(ev.text)
    local qref = string.format("|q %d/%d", ev.questID, ev.objectiveIndex)
    local objectiveType = tostring(ev.objectiveType or ""):lower()
    local relatedNpc = anchor.relatedNpc or ev.relatedNpc
    local relatedLoot = anchor.relatedLoot or ev.relatedLoot

    if objectiveType:find("monster") or objectiveType:find("kill") then
        if relatedNpc and relatedNpc.npcID then
            append(lines, npcLine("kill", relatedNpc))
        end
    elseif objectiveType:find("item") then
        if relatedLoot and relatedLoot.itemID then
            append(lines, string.format("collect %s##%d", zName(relatedLoot.name or "Quest Item"), relatedLoot.itemID))
        end
    elseif objectiveType:find("object") and relatedNpc and relatedNpc.npcID then
        append(lines, npcLine("clicknpc", relatedNpc))
    end

    local main = text .. " " .. qref
    main = lineWithGoto(main, session, anchor)
    if ev.numRequired and ev.numRequired > 1 and not text:find("#%d+#") then
        append(lines, string.format("|tip Recorded objective target: %d total.", ev.numRequired))
    end
    append(lines, main)
    return table.concat(lines, "\n")
end

local function renderEvent(session, ev)
    local lines = { "step" }
    if ev.type == "QUEST_ACCEPTED" then
        if ev.npc and ev.npc.npcID then append(lines, npcLine("talk", ev.npc)) end
        local line = string.format("accept %s##%d", zName(ev.questName or ("Quest " .. ev.questID)), ev.questID)
        append(lines, lineWithGoto(line, session, ev))
        if ev.automatic then append(lines, "|tip Automatically.") end
    elseif ev.type == "QUEST_TURNED_IN" then
        if ev.npc and ev.npc.npcID then append(lines, npcLine("talk", ev.npc)) end
        local line = string.format("turnin %s##%d", zName(ev.questName or ("Quest " .. ev.questID)), ev.questID)
        append(lines, lineWithGoto(line, session, ev))
    elseif ev.type == "GOSSIP_SELECTED" then
        if ev.npc and ev.npc.npcID then append(lines, npcLine("talk", ev.npc)) end
        local txt = ev.optionText and ('Select _"' .. zName(ev.optionText) .. '"_') or "Select the dialogue option"
        if ev.optionID then txt = txt .. " |gossip " .. tostring(ev.optionID) end
        append(lines, lineWithGoto(txt, session, ev))
    elseif ev.type == "WAYPOINT" then
        local label = zName(ev.label)
        if label == "" then label = "Go to the recorded location" end
        append(lines, lineWithGoto(label, session, ev))
    elseif ev.type == "INTERACT" then
        if ev.npc and ev.npc.npcID then
            append(lines, npcLine("clicknpc", ev.npc))
            append(lines, lineWithGoto("Interact with " .. zName(ev.npc.name or "the target"), session, ev))
        else
            append(lines, lineWithGoto("Interact with the target", session, ev))
        end
    elseif ev.type == "VEHICLE_ENTER" then
        local line = "Enter the vehicle |invehicle"
        append(lines, lineWithGoto(line, session, ev))
    elseif ev.type == "VEHICLE_EXIT" then
        local line = "Exit the vehicle |outvehicle"
        append(lines, lineWithGoto(line, session, ev))
    elseif ev.type == "LEVEL_UP" then
        append(lines, string.format("Reach Level %d |ding %d", ev.level or 1, ev.level or 1))
    elseif ev.type == "SCENARIO" then
        append(lines, zName(ev.text or "Continue the scenario"))
        append(lines, "|tip Scenario state was recorded here; review this step and add |scenariogoal if needed.")
        append(lines, lineWithGoto("Click Here to Continue |confirm", session, ev))
    elseif ev.type == "SPELLCAST" then
        append(lines, string.format("Use %s", zName(ev.spellName or ("spell " .. tostring(ev.spellID or "")))))
        append(lines, lineWithGoto("Click Here to Continue |confirm", session, ev))
    else
        return nil
    end
    return table.concat(lines, "\n")
end

function E:BuildGuide(session)
    if not session then return "-- No active Open Zygor Guide Recorder session." end
    local settings = NS:GetSettings()
    local out = {}
    append(out, "local ZygorGuidesViewer=ZygorGuidesViewer")
    append(out, "if not ZygorGuidesViewer then return end")
    if settings.factionOnlyExport and session.faction then
        append(out, string.format('if UnitFactionGroup("player")~="%s" then return end', session.faction))
    end
    append(out, "")
    append(out, 'ZygorGuidesViewer.GuideMenuTier = "SHA"')
    append(out, "")

    local root = settings.guideRoot or "Leveling Guides\\Custom\\Open Zygor Guide Recorder"
    local guideName = luaString(zName(session.name))
    append(out, string.format('ZygorGuidesViewer:RegisterGuide("%s\\\\%s",{', luaString(root), guideName))
    append(out, string.format('author="%s",', luaString(zName(settings.author or "Open Zygor Guide Recorder"))))
    append(out, string.format('description="Recorded with Open Zygor Guide Recorder on WoW %s.",', luaString(zName(session.client and session.client.version or "Retail"))))
    append(out, "},[[")

    local groups = buildObjectiveGroups(session.events)
    local emittedObjectives = {}
    local lastBlockIndex = nil

    for _, ev in ipairs(session.events) do
        if ev.type == "QUEST_OBJECTIVE" then
            local key = tostring(ev.questID) .. ":" .. tostring(ev.objectiveIndex)
            if not emittedObjectives[key] then
                emittedObjectives[key] = true
                local block = makeObjectiveBlock(session, groups[key])
                append(out, block)
                lastBlockIndex = #out
            end
        elseif ev.type == "TIP" then
            if lastBlockIndex then
                out[lastBlockIndex] = out[lastBlockIndex] .. "\n|tip " .. zName(ev.text)
            else
                append(out, "step\n" .. "|tip " .. zName(ev.text) .. "\nconfirm")
                lastBlockIndex = #out
            end
        elseif ev.type ~= "ZONE_CHANGED" and ev.type ~= "NPC_KILLED" then
            local block = renderEvent(session, ev)
            if block then
                append(out, block)
                lastBlockIndex = #out
            end
        end
    end

    append(out, "]])")
    return table.concat(out, "\n")
end

function E:BuildRawSession(session)
    if not session then return "-- no active session" end
    local out = {}
    append(out, "-- Open Zygor Guide Recorder raw event dump")
    append(out, "-- Session: " .. zName(session.name))
    for i, ev in ipairs(session.events) do
        local pos = ev.position
        local where = ""
        if pos and pos.mapID then
            where = string.format(" map=%s(%s) %.2f,%.2f", pos.mapName or "?", pos.mapID, pos.x or 0, pos.y or 0)
        end
        append(out, string.format("%04d %s%s", i, U.EventSummary(ev), where))
    end
    return table.concat(out, "\n")
end
