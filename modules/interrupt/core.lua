------------------------------------------------------------
-- 打断核心逻辑：事件监听、C_DamageMeter 数据处理、副本追踪
--
-- WoW 12.0+ (Midnight) 适配：
--   - 战斗中数据加密（issecretvalue），脱战后解密读取
--   - 参照 Details! parser_nocleu1.lua 策略
------------------------------------------------------------
---@diagnostic disable: undefined-global, redundant-return-value
local addonName, addon       = ...

local issecretvalue          = issecretvalue or function() return false end

------------------------------------------------------------
-- 状态变量
------------------------------------------------------------
local interruptFrame         = CreateFrame("Frame")
local interruptEnabled       = false

-- C_DamageMeter 状态
local currentSessionId       = nil
local interruptCache         = {} -- [playerName] = 当前 session 已知打断次数
local inCombatLockdown       = false
local pendingInterruptEvents = 0

-- 副本追踪
local instanceTracking       = false
local instanceStats          = {} -- [playerName] = count
local instanceName           = nil
local instanceStartTime      = nil
local wasInInstance          = false

------------------------------------------------------------
-- 副本检测
------------------------------------------------------------
local function IsTrackableInstance()
    local name, iType = GetInstanceInfo()
    if iType == "party" or iType == "raid" or iType == "scenario" then
        return true, name
    end
    return false
end

------------------------------------------------------------
-- 打断记录（仅更新数据+刷新面板，不输出聊天）
------------------------------------------------------------
local function RecordInterrupt(name, delta)
    if not instanceTracking or not name then return end
    delta = delta or 1
    instanceStats[name] = (instanceStats[name] or 0) + delta
    addon.StatsFrame.Refresh()
    addon.StatsFrame.Flash(name)
end

------------------------------------------------------------
-- 副本进出逻辑
------------------------------------------------------------
local function OnEnterInstance()
    local trackable, name = IsTrackableInstance()
    if not trackable or instanceTracking then return end
    if not YuxuanUtilsDB.enableInterruptAlert then return end

    instanceTracking = true
    instanceName = name
    instanceStartTime = GetTime()
    wipe(instanceStats)
    wipe(interruptCache)
    currentSessionId = nil
    inCombatLockdown = false
    pendingInterruptEvents = 0

    -- 仅提示开始记录
    addon.Msg("|cff00ff00【打断记录开始】|r |cffffcc00" .. (name or "未知") .. "|r")

    if YuxuanUtilsDB.autoShowStatsFrame ~= false then
        addon.StatsFrame.Show()
    end
end

local function OnLeaveInstance()
    if not instanceTracking then return end

    -- 仅提示结束记录
    addon.Msg("|cffff6600【打断记录结束】|r |cffffcc00" .. (instanceName or "未知") .. "|r")

    -- 保存历史记录（不自动发送到聊天）
    addon.InterruptHistory.Save(instanceName, instanceStartTime, instanceStats)

    -- 清空所有数据
    instanceTracking = false
    instanceName = nil
    instanceStartTime = nil
    wipe(instanceStats)
    wipe(interruptCache)
    currentSessionId = nil
    inCombatLockdown = false
    pendingInterruptEvents = 0

    -- 关闭统计窗口
    addon.StatsFrame.Hide()
end

------------------------------------------------------------
-- 副本区域检测
------------------------------------------------------------
local instanceZoneFrame = CreateFrame("Frame")

local function CheckInstanceZone()
    if not YuxuanUtilsDB.enableInterruptAlert then
        if instanceTracking then
            OnLeaveInstance()
        end
        wasInInstance = false
        return
    end

    local trackable = IsTrackableInstance()
    if trackable and not wasInInstance then
        wasInInstance = true
        OnEnterInstance()
    elseif not trackable and wasInInstance then
        wasInInstance = false
        OnLeaveInstance()
    end
end

instanceZoneFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
instanceZoneFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
instanceZoneFrame:SetScript("OnEvent", function()
    C_Timer.After(1, CheckInstanceZone)
end)

-- 队伍变化时刷新统计窗口（不移除已离开队友的数据）
local groupFrame = CreateFrame("Frame")
groupFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
groupFrame:SetScript("OnEvent", function()
    if instanceTracking then
        addon.StatsFrame.Refresh()
    end
end)

------------------------------------------------------------
-- C_DamageMeter 打断检测（V6 适配 issecretvalue）
------------------------------------------------------------
local function EnsureDamageMeterEnabled()
    if C_CVar and C_CVar.GetCVarBool then
        if not C_CVar.GetCVarBool("damageMeterEnabled") then
            C_CVar.SetCVar("damageMeterEnabled", "1")
        end
    end
end

local function EnableInterruptAlert()
    if interruptEnabled then return end
    interruptEnabled = true
    EnsureDamageMeterEnabled()
    interruptFrame:RegisterEvent("DAMAGE_METER_COMBAT_SESSION_UPDATED")
    interruptFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    interruptFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
end

local function DisableInterruptAlert()
    if not interruptEnabled then return end
    interruptEnabled = false
    interruptFrame:UnregisterEvent("DAMAGE_METER_COMBAT_SESSION_UPDATED")
    interruptFrame:UnregisterEvent("PLAYER_REGEN_DISABLED")
    interruptFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
    interruptFrame:SetScript("OnUpdate", nil)
end

--- 检查数据是否仍然加密
local function IsDataStillSecret()
    if not C_DamageMeter or not Enum or not Enum.DamageMeterType then return false end

    local ok, container = pcall(
        C_DamageMeter.GetCombatSessionFromType,
        Enum.DamageMeterSessionType.Current,
        Enum.DamageMeterType.Interrupts
    )
    if ok and container and container.combatSources then
        for i = 1, #container.combatSources do
            local source = container.combatSources[i]
            if issecretvalue(source.name) or issecretvalue(source.totalAmount) then
                return true
            end
        end
    end

    ok, container = pcall(
        C_DamageMeter.GetCombatSessionFromType,
        Enum.DamageMeterSessionType.Current,
        Enum.DamageMeterType.DamageDone
    )
    if ok and container and container.combatSources then
        for i = 1, #container.combatSources do
            local source = container.combatSources[i]
            if issecretvalue(source.name) or issecretvalue(source.totalAmount) then
                return true
            end
        end
    end

    return false
end

--- 读取当前打断数据
local function ReadInterruptData()
    if not C_DamageMeter or not Enum or not Enum.DamageMeterType then return nil end

    if Enum.DamageMeterSessionType then
        local ok, container = pcall(
            C_DamageMeter.GetCombatSessionFromType,
            Enum.DamageMeterSessionType.Current,
            Enum.DamageMeterType.Interrupts
        )
        if ok and container and container.combatSources and #container.combatSources > 0 then
            return container
        end
    end

    if currentSessionId and currentSessionId ~= 0 then
        local ok, container = pcall(
            C_DamageMeter.GetCombatSessionFromID,
            currentSessionId,
            Enum.DamageMeterType.Interrupts
        )
        if ok and container and container.combatSources and #container.combatSources > 0 then
            return container
        end
    end

    return nil
end

--- 脱战后处理打断数据：读取明文数据，与缓存对比，仅更新统计面板
local function ProcessInterruptDataAfterCombat()
    local container = ReadInterruptData()
    if not container or not container.combatSources then return end

    for i = 1, #container.combatSources do
        local source = container.combatSources[i]
        local name = source.name

        if name and not issecretvalue(name) and not issecretvalue(source.totalAmount) then
            local shortName = Ambiguate(name, "short")
            local newCount  = source.totalAmount or 0
            local oldCount  = interruptCache[shortName] or 0

            if newCount > oldCount then
                local delta = newCount - oldCount
                interruptCache[shortName] = newCount
                -- 仅更新统计面板数据，不输出到聊天
                RecordInterrupt(shortName, delta)
            end
        end
    end
end

local secretPollTimer = nil

interruptFrame:SetScript("OnEvent", function(self, event, ...)
    if not interruptEnabled then return end

    if event == "DAMAGE_METER_COMBAT_SESSION_UPDATED" then
        local damageMeterType, sessionId = ...

        if sessionId and sessionId ~= 0 then
            if not currentSessionId or sessionId > currentSessionId then
                currentSessionId = sessionId
            end
        end

        if damageMeterType == Enum.DamageMeterType.Interrupts then
            pendingInterruptEvents = pendingInterruptEvents + 1

            if not inCombatLockdown then
                -- 不在战斗中，尝试直接读取
                ProcessInterruptDataAfterCombat()
            end
            -- 战斗中不做任何聊天输出
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        inCombatLockdown = true
        pendingInterruptEvents = 0

        if secretPollTimer then
            secretPollTimer:Cancel()
            secretPollTimer = nil
        end

        if C_DamageMeter and C_DamageMeter.GetAvailableCombatSessions then
            local sessions = C_DamageMeter.GetAvailableCombatSessions()
            if sessions and #sessions > 0 then
                local latestSession = sessions[#sessions]
                if latestSession and latestSession.sessionID then
                    currentSessionId = latestSession.sessionID
                end
            end
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombatLockdown = false

        local pollCount = 0
        secretPollTimer = C_Timer.NewTicker(0.3, function(ticker)
            pollCount = pollCount + 1

            if not IsDataStillSecret() then
                ProcessInterruptDataAfterCombat()
                ticker:Cancel()
                secretPollTimer = nil
            elseif pollCount >= 20 then
                ProcessInterruptDataAfterCombat()
                ticker:Cancel()
                secretPollTimer = nil
            end
        end)
    end
end)

------------------------------------------------------------
-- 导出接口
------------------------------------------------------------
local function UpdateInterruptState()
    if YuxuanUtilsDB.enableInterruptAlert then
        EnableInterruptAlert()
        local trackable = IsTrackableInstance()
        if trackable and not instanceTracking then
            wasInInstance = true
            OnEnterInstance()
        end
    else
        DisableInterruptAlert()
        if instanceTracking then
            -- 关闭开关时也保存历史
            addon.InterruptHistory.Save(instanceName, instanceStartTime, instanceStats)

            instanceTracking = false
            instanceName = nil
            instanceStartTime = nil
            wipe(instanceStats)
            wipe(interruptCache)
            currentSessionId = nil
            inCombatLockdown = false
            pendingInterruptEvents = 0
            if secretPollTimer then
                secretPollTimer:Cancel()
                secretPollTimer = nil
            end
            addon.StatsFrame.Hide()
        end
        wasInInstance = false
    end
end

local function GetInstanceStatus()
    return { tracking = instanceTracking, name = instanceName }
end

local function GetInstanceStats()
    return instanceStats
end

addon.Interrupt = {
    UpdateState      = UpdateInterruptState,
    GetStatus        = GetInstanceStatus,
    GetInstanceStats = GetInstanceStats,
    ShowStats        = function() addon.StatsFrame.Show() end,
    HideStats        = function() addon.StatsFrame.Hide() end,
    RefreshStats     = function() addon.StatsFrame.Refresh() end,
}
