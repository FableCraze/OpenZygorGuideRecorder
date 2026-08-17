local ADDON_NAME, NS = ...

NS.ADDON_NAME = ADDON_NAME
NS.VERSION = "0.1.0"
NS.DB_VERSION = 1
NS.PREFIX = "OZGR"

OpenZygorGuideRecorder = NS

local defaults = {
    version = NS.DB_VERSION,
    settings = {
        captureQuestObjectives = true,
        captureGossip = true,
        captureCombatKills = true,
        captureVehicle = true,
        captureScenario = true,
        captureLevelUps = true,
        captureZoneChanges = true,
        captureSpellcasts = false,
        factionOnlyExport = true,
        guideRoot = "Leveling Guides\\Custom\\Open Zygor Guide Recorder",
        author = "Open Zygor Guide Recorder",
    },
    sessions = {},
    activeSessionId = nil,
}

local function copyDefaults(src, dst)
    if type(dst) ~= "table" then dst = {} end
    for key, value in pairs(src) do
        if type(value) == "table" then
            dst[key] = copyDefaults(value, dst[key])
        elseif dst[key] == nil then
            dst[key] = value
        end
    end
    return dst
end

function NS:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Open Zygor Guide Recorder|r: " .. tostring(msg))
end

function NS:Debug(msg)
    if self.db and self.db.settings and self.db.settings.debug then
        self:Print("|cffaaaaaa[debug]|r " .. tostring(msg))
    end
end

function NS:GetDB()
    return self.db
end

function NS:GetSettings()
    return self.db and self.db.settings
end

function NS:GetActiveSession()
    if not self.db or not self.db.activeSessionId then return nil end
    return self.db.sessions[self.db.activeSessionId]
end

function NS:NewSession(name)
    local id = tostring(time()) .. "-" .. tostring(math.random(1000, 9999))
    local version, build, buildDate, interface = GetBuildInfo()
    local session = {
        id = id,
        name = (name and name ~= "") and name or ("Guide " .. date("%Y-%m-%d %H:%M")),
        createdAt = time(),
        updatedAt = time(),
        character = UnitName("player"),
        realm = GetRealmName(),
        faction = UnitFactionGroup("player"),
        client = {
            version = version,
            build = build,
            buildDate = buildDate,
            interface = interface,
        },
        events = {},
        recording = false,
        paused = false,
        nextEventId = 1,
        mapAliases = {},
    }
    self.db.sessions[id] = session
    self.db.activeSessionId = id
    return session
end

function NS:SetActiveSession(id)
    if id and self.db.sessions[id] then
        self.db.activeSessionId = id
        return self.db.sessions[id]
    end
end

function NS:DeleteSession(id)
    if not id then return end
    self.db.sessions[id] = nil
    if self.db.activeSessionId == id then
        self.db.activeSessionId = nil
    end
end

function NS:InitializeDB()
    OpenZygorGuideRecorderDB = copyDefaults(defaults, OpenZygorGuideRecorderDB or {})
    self.db = OpenZygorGuideRecorderDB
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local loaded = ...
        if loaded ~= ADDON_NAME then return end
        NS:InitializeDB()
    elseif event == "PLAYER_LOGIN" then
        if not NS.db then NS:InitializeDB() end
        if NS.Recorder then NS.Recorder:Initialize() end
        if NS.UI then NS.UI:Initialize() end
        if NS.Commands then NS.Commands:Initialize() end
        NS:Print("v" .. NS.VERSION .. " carregado. Use |cffffff00/ozgr|r para abrir.")
    end
end)
