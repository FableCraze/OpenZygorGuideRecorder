local _, NS = ...
NS.UI = NS.UI or {}
local UI = NS.UI
local U = NS.Util

local function createButton(parent, text, width, height)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width or 100, height or 24)
    b:SetText(text)
    return b
end

local function createEditBox(parent, width, height)
    local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    e:SetSize(width or 180, height or 24)
    e:SetAutoFocus(false)
    e:SetFontObject(ChatFontNormal)
    return e
end

function UI:CreateMainFrame()
    local f = CreateFrame("Frame", "OpenZygorGuideRecorderFrame", UIParent, "BackdropTemplate")
    f:SetSize(620, 500)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOP", 0, -16)
    title:SetText("Open Zygor Guide Recorder")

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -5, -5)

    local status = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    status:SetPoint("TOPLEFT", 24, -48)
    f.status = status

    local sessionLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sessionLabel:SetPoint("TOPLEFT", 24, -75)
    sessionLabel:SetText("Nome da sessão")

    local sessionEdit = createEditBox(f, 350, 24)
    sessionEdit:SetPoint("TOPLEFT", 24, -91)
    sessionEdit:SetMaxLetters(100)
    f.sessionEdit = sessionEdit

    local count = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    count:SetPoint("LEFT", sessionEdit, "RIGHT", 16, 0)
    f.count = count

    local startBtn = createButton(f, "Iniciar", 92, 26)
    startBtn:SetPoint("TOPLEFT", 24, -126)
    startBtn:SetScript("OnClick", function()
        local s = NS:GetActiveSession()
        if s and s.recording then
            NS.Recorder:Stop()
        else
            NS.Recorder:Start(sessionEdit:GetText())
        end
    end)
    f.startBtn = startBtn

    local pauseBtn = createButton(f, "Pausar", 92, 26)
    pauseBtn:SetPoint("LEFT", startBtn, "RIGHT", 6, 0)
    pauseBtn:SetScript("OnClick", function()
        local s = NS:GetActiveSession()
        if not s or not s.recording then return end
        if s.paused then NS.Recorder:Resume() else NS.Recorder:Pause() end
    end)
    f.pauseBtn = pauseBtn

    local waypointBtn = createButton(f, "+ Waypoint", 100, 26)
    waypointBtn:SetPoint("LEFT", pauseBtn, "RIGHT", 6, 0)
    waypointBtn:SetScript("OnClick", function()
        NS.Recorder:AddWaypoint(f.noteEdit:GetText())
        f.noteEdit:SetText("")
    end)

    local interactBtn = createButton(f, "+ Interação", 100, 26)
    interactBtn:SetPoint("LEFT", waypointBtn, "RIGHT", 6, 0)
    interactBtn:SetScript("OnClick", function() NS.Recorder:ManualInteract() end)

    local undoBtn = createButton(f, "Desfazer", 86, 26)
    undoBtn:SetPoint("LEFT", interactBtn, "RIGHT", 6, 0)
    undoBtn:SetScript("OnClick", function() NS.Recorder:Undo() end)

    local noteLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    noteLabel:SetPoint("TOPLEFT", 24, -166)
    noteLabel:SetText("Texto para Tip / rótulo do Waypoint")

    local noteEdit = createEditBox(f, 460, 24)
    noteEdit:SetPoint("TOPLEFT", 24, -182)
    f.noteEdit = noteEdit

    local tipBtn = createButton(f, "+ Tip", 86, 24)
    tipBtn:SetPoint("LEFT", noteEdit, "RIGHT", 8, 0)
    tipBtn:SetScript("OnClick", function()
        NS.Recorder:AddTip(noteEdit:GetText())
        noteEdit:SetText("")
    end)

    local logLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    logLabel:SetPoint("TOPLEFT", 24, -220)
    logLabel:SetText("Eventos gravados")

    local log = CreateFrame("ScrollingMessageFrame", nil, f)
    log:SetPoint("TOPLEFT", 24, -241)
    log:SetPoint("BOTTOMRIGHT", -24, 78)
    log:SetFontObject(ChatFontNormal)
    log:SetJustifyH("LEFT")
    log:SetFading(false)
    log:SetMaxLines(500)
    log:EnableMouseWheel(true)
    log:SetScript("OnMouseWheel", function(self, delta)
        if delta > 0 then self:ScrollUp() else self:ScrollDown() end
    end)
    f.log = log

    local exportBtn = createButton(f, "Exportar Zygor", 130, 28)
    exportBtn:SetPoint("BOTTOMLEFT", 24, 26)
    exportBtn:SetScript("OnClick", function() UI:ShowExport(false) end)

    local rawBtn = createButton(f, "Exportar log", 110, 28)
    rawBtn:SetPoint("LEFT", exportBtn, "RIGHT", 8, 0)
    rawBtn:SetScript("OnClick", function() UI:ShowExport(true) end)

    local clearBtn = createButton(f, "Limpar sessão", 110, 28)
    clearBtn:SetPoint("LEFT", rawBtn, "RIGHT", 8, 0)
    clearBtn:SetScript("OnClick", function() NS.Recorder:ClearSession() end)

    local newBtn = createButton(f, "Nova sessão", 110, 28)
    newBtn:SetPoint("LEFT", clearBtn, "RIGHT", 8, 0)
    newBtn:SetScript("OnClick", function()
        local old = NS:GetActiveSession()
        if old and old.recording then NS.Recorder:Stop() end
        NS:NewSession(sessionEdit:GetText())
        UI:RefreshAll()
    end)

    f:Hide()
    self.frame = f
end

function UI:CreateExportFrame()
    local f = CreateFrame("Frame", "OpenZygorGuideRecorderExportFrame", UIParent, "BackdropTemplate")
    f:SetSize(760, 620)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOP", 0, -16)
    title:SetText("Exportação")

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -5, -5)

    local help = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    help:SetPoint("TOPLEFT", 24, -48)
    help:SetPoint("TOPRIGHT", -24, -48)
    help:SetJustifyH("LEFT")
    help:SetText("Ctrl+A e Ctrl+C para copiar. O exportador gera um esqueleto compatível com a sintaxe observada nos guias Zygor Retail; revise coordenadas, aliases de mapa, sticky steps e condições complexas antes de publicar.")

    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 24, -82)
    scroll:SetPoint("BOTTOMRIGHT", -48, 55)

    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject(ChatFontNormal)
    edit:SetWidth(670)
    edit:SetTextInsets(4, 4, 4, 4)
    edit:SetScript("OnEscapePressed", function() f:Hide() end)
    edit:SetScript("OnTextChanged", function(self)
        local h = math.max(500, self:GetStringHeight() + 30)
        self:SetHeight(h)
    end)
    scroll:SetScrollChild(edit)
    f.edit = edit

    local selectAll = createButton(f, "Selecionar tudo", 120, 26)
    selectAll:SetPoint("BOTTOMLEFT", 24, 20)
    selectAll:SetScript("OnClick", function()
        edit:SetFocus()
        edit:HighlightText()
    end)

    local closeBottom = createButton(f, "Fechar", 90, 26)
    closeBottom:SetPoint("LEFT", selectAll, "RIGHT", 8, 0)
    closeBottom:SetScript("OnClick", function() f:Hide() end)

    f:Hide()
    self.exportFrame = f
end

function UI:RefreshLog()
    if not self.frame then return end
    local log = self.frame.log
    log:Clear()
    local s = NS:GetActiveSession()
    if not s then return end
    local first = math.max(1, #s.events - 200)
    for i = first, #s.events do
        local e = s.events[i]
        log:AddMessage(string.format("|cff888888%03d|r  %s", i, U.EventSummary(e)))
    end
    log:ScrollToBottom()
end

function UI:RefreshAll()
    if not self.frame then return end
    local s = NS:GetActiveSession()
    if s then
        self.frame.sessionEdit:SetText(s.name or "")
        self.frame.count:SetText("Eventos: " .. tostring(#s.events))
        if s.recording and s.paused then
            self.frame.status:SetText("Status: |cffffff00PAUSADO|r")
            self.frame.startBtn:SetText("Parar")
            self.frame.pauseBtn:SetText("Retomar")
        elseif s.recording then
            self.frame.status:SetText("Status: |cff00ff00● REC|r")
            self.frame.startBtn:SetText("Parar")
            self.frame.pauseBtn:SetText("Pausar")
        else
            self.frame.status:SetText("Status: |cffaaaaaaIDLE|r")
            self.frame.startBtn:SetText("Iniciar")
            self.frame.pauseBtn:SetText("Pausar")
        end
    else
        self.frame.status:SetText("Status: |cffaaaaaaSEM SESSÃO|r")
        self.frame.count:SetText("Eventos: 0")
        self.frame.startBtn:SetText("Iniciar")
        self.frame.pauseBtn:SetText("Pausar")
    end
    self:RefreshLog()
end

function UI:OnRecordedEvent()
    self:RefreshAll()
end

function UI:ShowExport(raw)
    if not self.exportFrame then self:CreateExportFrame() end
    local s = NS:GetActiveSession()
    local text
    if raw then text = NS.Exporter:BuildRawSession(s) else text = NS.Exporter:BuildGuide(s) end
    self.exportFrame.edit:SetText(text or "")
    self.exportFrame.edit:SetCursorPosition(0)
    self.exportFrame:Show()
end

function UI:Toggle()
    if not self.frame then self:CreateMainFrame() end
    if self.frame:IsShown() then self.frame:Hide() else self.frame:Show(); self:RefreshAll() end
end

function UI:Initialize()
    if self.initialized then return end
    self.initialized = true
    self:CreateMainFrame()
    self:CreateExportFrame()
    self:RefreshAll()
end
