local _, NS = ...
NS.Commands = NS.Commands or {}
local C = NS.Commands
local U = NS.Util

local function help()
    NS:Print("Comandos:")
    NS:Print("|cffffff00/ozgr|r - abre/fecha a interface")
    NS:Print("|cffffff00/ozgr start [nome]|r - inicia a gravação")
    NS:Print("|cffffff00/ozgr stop|r - encerra a gravação")
    NS:Print("|cffffff00/ozgr pause|r / |cffffff00resume|r - pausa/retoma")
    NS:Print("|cffffff00/ozgr tip TEXTO|r - adiciona uma dica")
    NS:Print("|cffffff00/ozgr waypoint [rótulo]|r - grava a posição atual")
    NS:Print("|cffffff00/ozgr interact|r - grava o NPC selecionado como interação")
    NS:Print("|cffffff00/ozgr undo|r - remove o último evento")
    NS:Print("|cffffff00/ozgr export|r - abre a exportação Zygor")
    NS:Print("|cffffff00/ozgr raw|r - abre o log bruto")
    NS:Print("|cffffff00/ozgr clear|r - limpa os eventos da sessão atual")
end

function C:Handle(msg)
    msg = U.Trim(msg or "")
    local cmd, rest = msg:match("^(%S+)%s*(.-)$")
    cmd = (cmd or ""):lower()

    if cmd == "" then
        NS.UI:Toggle()
    elseif cmd == "start" then
        NS.Recorder:Start(rest)
    elseif cmd == "stop" then
        NS.Recorder:Stop()
    elseif cmd == "pause" then
        NS.Recorder:Pause()
    elseif cmd == "resume" then
        NS.Recorder:Resume()
    elseif cmd == "tip" then
        NS.Recorder:AddTip(rest)
    elseif cmd == "waypoint" or cmd == "wp" then
        NS.Recorder:AddWaypoint(rest)
    elseif cmd == "interact" then
        NS.Recorder:ManualInteract()
    elseif cmd == "undo" then
        NS.Recorder:Undo()
    elseif cmd == "export" then
        NS.UI:ShowExport(false)
    elseif cmd == "raw" then
        NS.UI:ShowExport(true)
    elseif cmd == "clear" then
        NS.Recorder:ClearSession()
    elseif cmd == "status" then
        local s = NS:GetActiveSession()
        if not s then NS:Print("Nenhuma sessão ativa.")
        else NS:Print(string.format("%s | eventos=%d | recording=%s | paused=%s", s.name, #s.events, tostring(s.recording), tostring(s.paused))) end
    elseif cmd == "help" then
        help()
    else
        NS:Print("Comando desconhecido: " .. cmd)
        help()
    end
end

function C:Initialize()
    SLASH_OPENZYGORGUIDERECORDER1 = "/ozgr"
    SLASH_OPENZYGORGUIDERECORDER2 = "/openzygor"
    SlashCmdList.OPENZYGORGUIDERECORDER = function(msg) C:Handle(msg) end
end
