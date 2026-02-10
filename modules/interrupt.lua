------------------------------------------------------------
-- 打断模块 V2：精简版
--
-- WoW 12.0 适配：
--   - 不使用 CLEU（会导致 taint）
--   - 敌方 NPC 名和技能名在 12.0 中为 secret value，无法可靠获取
--   - 只关注 "谁用什么技能打断了"，不再显示敌方信息
--   - 所有表操作用 pcall 保护
--
-- 事件流程：
--   UNIT_SPELLCAST_SUCCEEDED(友方) → 记录打断技能释放
--   UNIT_SPELLCAST_INTERRUPTED(敌方) → 配对 → 输出
------------------------------------------------------------
---@diagnostic disable: undefined-global, redundant-return-value
local addonName, addon = ...

local issecretvalue = issecretvalue or function() return false end

------------------------------------------------------------
-- 职业颜色表
------------------------------------------------------------
local CLASS_COLORS = {
    ["WARRIOR"]     = "c79c6e",
    ["PALADIN"]     = "f58cba",
    ["HUNTER"]      = "abd473",
    ["ROGUE"]       = "fff569",
    ["PRIEST"]      = "ffffff",
    ["DEATHKNIGHT"] = "c41f3b",
    ["SHAMAN"]      = "0070de",
    ["MAGE"]        = "69ccf0",
    ["WARLOCK"]     = "9482c9",
    ["MONK"]        = "00ff96",
    ["DRUID"]       = "ff7d0a",
    ["DEMONHUNTER"] = "a330c9",
    ["EVOKER"]      = "33937f",
}

local function GetClassColor(name)
    if not name then return "a0a0a0" end

    -- 尝试从队伍中获取职业
    local unit = nil
    if UnitName("player") == name then
        unit = "player"
    elseif IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            if UnitName("raid" .. i) == name then
                unit = "raid" .. i
                break
            end
        end
    elseif IsInGroup() then
        for i = 1, 4 do
            if UnitName("party" .. i) == name then
                unit = "party" .. i
                break
            end
        end
    end

    if unit then
        local _, class = UnitClass(unit)
        if class and CLASS_COLORS[class] then
            return CLASS_COLORS[class]
        end
    end

    return "a0a0a0" -- 默认灰色
end

------------------------------------------------------------
-- 已知打断技能（本地表，不受 secret value 影响）
------------------------------------------------------------
local INTERRUPT_SPELLS = {
    [1766]   = "脚踢",
    [2139]   = "法术反制",
    [6552]   = "拳击",
    [19647]  = "法术封锁",
    [47528]  = "心灵冰冻",
    [57994]  = "风剪",
    [78675]  = "日光术",
    [89766]  = "投掷利斧",
    [96231]  = "责难",
    [106839] = "迎头痛击",
    [116705] = "切喉手",
    [147362] = "反制射击",
    [183752] = "瓦解",
    [187707] = "压制",
    [351338] = "镇压咆哮",
}

------------------------------------------------------------
-- 安全工具
------------------------------------------------------------
local function SafeSet(tbl, key, val)
    if not key then return end
    pcall(function() tbl[key] = val end)
end

local function SafeGet(tbl, key)
    if not key then return nil end
    local ok, v = pcall(function() return tbl[key] end)
    return ok and v or nil
end

local function SafeStr(val)
    if not val or type(val) ~= "string" or issecretvalue(val) then return nil end
    return val
end

------------------------------------------------------------
-- 状态
------------------------------------------------------------
local interruptFrame = CreateFrame("Frame")
local interruptEnabled = false

-- 最近的友方打断技能释放: [guid] = { name, spellName, time }
local recentCasts = {}

-- 去重: [destGUID] = time
local recentOutputs = {}

------------------------------------------------------------
-- Unit 判断
------------------------------------------------------------
local function IsGroupUnit(unit)
    if not unit then return false end
    if UnitIsUnit(unit, "player") then return true end
    local p = string.match(unit, "^(%a+)")
    if p == "party" or p == "raid" then return true end
    if p == "nameplate" then return UnitIsFriend("player", unit) end
    return false
end

local function IsEnemyUnit(unit)
    return unit and UnitCanAttack("player", unit)
end

------------------------------------------------------------
-- 副本统计系统
------------------------------------------------------------
local instanceTracking = false
local instanceStats = {} -- [playerName] = count
local instanceName = nil
local instanceStartTime = nil

-- ======== 统计浮动窗口 ========
local statsFrame = nil

local function GetGroupMembers()
    local members = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name = GetRaidRosterInfo(i)
            if name then
                table.insert(members, Ambiguate(name, "short"))
            end
        end
    elseif IsInGroup() then
        local me = UnitName("player")
        if me then table.insert(members, me) end
        for i = 1, 4 do
            local name = UnitName("party" .. i)
            if name then table.insert(members, name) end
        end
    else
        local me = UnitName("player")
        if me then table.insert(members, me) end
    end
    return members
end

local ROW_H = 20
local FRAME_W = 180

local function CreateStatsFrame()
    if statsFrame then return statsFrame end

    local f = CreateFrame("Frame", "YuxuanInterruptStats", UIParent, "BackdropTemplate")
    f:SetSize(FRAME_W, 60)
    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -200)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        YuxuanUtilsDB.statsFramePos = { point, relPoint, x, y }
    end)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)

    f:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    f:SetBackdropColor(0.05, 0.05, 0.1, 0.85)
    f:SetBackdropBorderColor(0.3, 0.6, 1.0, 0.7)

    -- 标题栏
    f.titleBar = f:CreateTexture(nil, "ARTWORK")
    f.titleBar:SetHeight(ROW_H)
    f.titleBar:SetPoint("TOPLEFT", 2, -2)
    f.titleBar:SetPoint("TOPRIGHT", -2, -2)
    f.titleBar:SetColorTexture(0.1, 0.3, 0.6, 0.6)

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.title:SetPoint("LEFT", f.titleBar, "LEFT", 6, 0)
    f.title:SetText("|cff00d1ff打断统计|r")

    f.instName = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.instName:SetPoint("RIGHT", f.titleBar, "RIGHT", -4, 0)

    f.rows = {}
    statsFrame = f
    return f
end

local function RefreshStatsFrame()
    if not statsFrame or not statsFrame:IsShown() then return end

    local members = GetGroupMembers()

    statsFrame.instName:SetText("|cff888888" .. (instanceName or "") .. "|r")

    -- 按打断次数排序
    local data = {}
    for _, name in ipairs(members) do
        table.insert(data, { name = name, count = instanceStats[name] or 0 })
    end
    table.sort(data, function(a, b)
        if a.count ~= b.count then return a.count > b.count end
        return a.name < b.name
    end)

    -- 隐藏多余行
    for i = #data + 1, #statsFrame.rows do
        if statsFrame.rows[i] then statsFrame.rows[i]:Hide() end
    end

    -- 创建/更新行
    for i, entry in ipairs(data) do
        local row = statsFrame.rows[i]
        if not row then
            row = CreateFrame("Frame", nil, statsFrame)
            row:SetHeight(ROW_H)
            row:SetPoint("TOPLEFT", statsFrame, "TOPLEFT", 4, -(ROW_H + 2) - (i - 1) * ROW_H)
            row:SetPoint("RIGHT", statsFrame, "RIGHT", -4, 0)

            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints()

            row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.nameText:SetPoint("LEFT", 4, 0)

            row.countText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.countText:SetPoint("RIGHT", -4, 0)

            -- 添加闪烁光圈
            row.flash = row:CreateTexture(nil, "OVERLAY")
            row.flash:SetAllPoints()
            row.flash:SetColorTexture(1, 1, 0, 0) -- 黄色，初始透明
            row.flash:SetBlendMode("ADD")

            -- 创建动画组
            row.flashAnim = row.flash:CreateAnimationGroup()
            local fadeIn = row.flashAnim:CreateAnimation("Alpha")
            fadeIn:SetFromAlpha(0)
            fadeIn:SetToAlpha(0.6)
            fadeIn:SetDuration(0.15)
            fadeIn:SetOrder(1)

            local fadeOut = row.flashAnim:CreateAnimation("Alpha")
            fadeOut:SetFromAlpha(0.6)
            fadeOut:SetToAlpha(0)
            fadeOut:SetDuration(0.35)
            fadeOut:SetOrder(2)

            statsFrame.rows[i] = row
        end

        -- 交替行背景
        if i % 2 == 0 then
            row.bg:SetColorTexture(0.1, 0.1, 0.15, 0.4)
        else
            row.bg:SetColorTexture(0, 0, 0, 0)
        end

        local isPlayer = (entry.name == addon.playerName)
        local classColor = GetClassColor(entry.name)
        local color = "|cff" .. classColor
        row.nameText:SetText(color .. entry.name .. "|r")
        row.playerName = entry.name -- 保存名字用于闪烁匹配

        if entry.count > 0 then
            row.countText:SetText("|cffffff00" .. entry.count .. "|r")
        else
            row.countText:SetText("|cff555555" .. entry.count .. "|r")
        end

        row:Show()
    end

    -- 调整窗口高度
    local totalRows = math.max(#data, 1)
    statsFrame:SetHeight((ROW_H + 2) + totalRows * ROW_H + 4)
end

local function ShowStatsFrame()
    local f = CreateStatsFrame()
    if YuxuanUtilsDB.statsFramePos then
        local pos = YuxuanUtilsDB.statsFramePos
        f:ClearAllPoints()
        f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    end
    f:Show()
    RefreshStatsFrame()
end

local function HideStatsFrame()
    if statsFrame then statsFrame:Hide() end
end

-- ======== 副本进出逻辑 ========
local function IsTrackableInstance()
    local name, iType = GetInstanceInfo()
    if iType == "party" or iType == "raid" or iType == "scenario" then
        return true, name
    end
    return false
end

local function FlashPlayerRow(name)
    if not statsFrame or not statsFrame:IsShown() or not name then return end

    -- 查找对应的行并触发闪烁
    for _, row in ipairs(statsFrame.rows) do
        if row:IsShown() and row.playerName == name then
            if row.flashAnim then
                row.flashAnim:Stop()
                row.flashAnim:Play()
            end
            break
        end
    end
end

local function RecordInterrupt(name)
    if not instanceTracking or not name then return end
    instanceStats[name] = (instanceStats[name] or 0) + 1
    RefreshStatsFrame()
    FlashPlayerRow(name) -- 触发闪烁效果
end

local function OutputInterruptStats()
    if not instanceStats or not next(instanceStats) then
        addon.Msg("|cff888888本次副本没有记录到打断|r")
        return
    end

    local sorted = {}
    for name, count in pairs(instanceStats) do
        table.insert(sorted, { name = name, count = count })
    end
    table.sort(sorted, function(a, b) return a.count > b.count end)

    local parts = { "|cff00d1ff雨轩工具箱|r - |cffff6600[打断统计]|r" }
    for _, e in ipairs(sorted) do
        local c = (e.name == addon.playerName) and "|cff00ffff" or "|cff00ff00"
        table.insert(parts, c .. e.name .. "|r:|cffffff00" .. e.count .. "|r次")
    end
    DEFAULT_CHAT_FRAME:AddMessage(table.concat(parts, " "))
end

local function SaveToHistory()
    if not instanceStats or not next(instanceStats) then return end
    if not YuxuanUtilsDB.interruptHistory then YuxuanUtilsDB.interruptHistory = {} end

    local record = {
        instance = instanceName or "未知副本",
        time = date("%Y-%m-%d %H:%M"),
        duration = instanceStartTime and (GetTime() - instanceStartTime) or 0,
        stats = {},
    }
    for name, count in pairs(instanceStats) do
        table.insert(record.stats, { name = name, count = count })
    end
    table.sort(record.stats, function(a, b) return a.count > b.count end)

    table.insert(YuxuanUtilsDB.interruptHistory, record)
    while #YuxuanUtilsDB.interruptHistory > 50 do
        table.remove(YuxuanUtilsDB.interruptHistory, 1)
    end
end

local function OnEnterInstance()
    local trackable, name = IsTrackableInstance()
    if not trackable or instanceTracking then return end

    instanceTracking = true
    instanceName = name
    instanceStartTime = GetTime()
    wipe(instanceStats)
    addon.Msg("|cff00ff00【打断记录开始】|r |cffffcc00" .. (name or "未知") .. "|r")
    ShowStatsFrame()
end

local function OnLeaveInstance()
    if not instanceTracking then return end

    addon.Msg("|cffff6600【打断记录结束】|r |cffffcc00" .. (instanceName or "未知") .. "|r")
    OutputInterruptStats()
    SaveToHistory()

    instanceTracking = false
    instanceName = nil
    instanceStartTime = nil
    wipe(instanceStats)
    HideStatsFrame()
end

local instanceZoneFrame = CreateFrame("Frame")
local wasInInstance = false

local function CheckInstanceZone()
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

-- 队伍变化时刷新窗口
local groupFrame = CreateFrame("Frame")
groupFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
groupFrame:SetScript("OnEvent", function()
    if instanceTracking then RefreshStatsFrame() end
end)

------------------------------------------------------------
-- 打断事件（精简版：只用两个事件）
------------------------------------------------------------
local function EnableInterruptAlert()
    if interruptEnabled then return end
    interruptEnabled = true
    interruptFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    interruptFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
end

local function DisableInterruptAlert()
    if not interruptEnabled then return end
    interruptEnabled = false
    interruptFrame:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    interruptFrame:UnregisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    wipe(recentCasts)
    wipe(recentOutputs)
end

interruptFrame:SetScript("OnEvent", function(self, event, unit, castGUID, spellID)
    if not interruptEnabled then return end

    -- ========================================
    -- 友方释放了打断技能
    -- ========================================
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        if not IsGroupUnit(unit) then return end
        if not spellID or type(spellID) ~= "number" or issecretvalue(spellID) then return end

        -- 查本地打断技能表（绝对安全，不查远程 API）
        local spellName = SafeGet(INTERRUPT_SPELLS, spellID)
        if not spellName then return end

        local guid = SafeStr(UnitGUID(unit))
        local name = SafeStr(UnitName(unit))
        if not guid or not name then return end

        SafeSet(recentCasts, guid, {
            name = name,
            spellName = spellName,
            time = GetTime(),
        })
        return
    end

    -- ========================================
    -- 敌方施法被打断
    -- ========================================
    if event == "UNIT_SPELLCAST_INTERRUPTED" then
        if not IsEnemyUnit(unit) then return end

        -- 去重
        local destGUID = SafeStr(UnitGUID(unit))
        if destGUID then
            local now = GetTime()
            local last = SafeGet(recentOutputs, destGUID)
            if last and (now - last) < 0.5 then return end
            SafeSet(recentOutputs, destGUID, now)
        end

        -- 配对打断者：找最近的友方打断技能释放
        local now = GetTime()
        local bestGUID, bestInfo, bestDiff = nil, nil, 999

        local keys = {}
        pcall(function()
            for g in pairs(recentCasts) do
                if type(g) == "string" then keys[#keys + 1] = g end
            end
        end)

        for _, g in ipairs(keys) do
            local info = SafeGet(recentCasts, g)
            if info then
                local diff = now - info.time
                if diff < 1.0 and diff < bestDiff then
                    bestGUID, bestInfo, bestDiff = g, info, diff
                end
                if diff > 3.0 then SafeSet(recentCasts, g, nil) end
            end
        end

        -- 清理过期去重
        local okeys = {}
        pcall(function()
            for g in pairs(recentOutputs) do
                if type(g) == "string" then okeys[#okeys + 1] = g end
            end
        end)
        for _, g in ipairs(okeys) do
            local t = SafeGet(recentOutputs, g)
            if t and (now - t) > 2.0 then SafeSet(recentOutputs, g, nil) end
        end

        if not bestInfo then return end

        SafeSet(recentCasts, bestGUID, nil)
        RecordInterrupt(bestInfo.name)

        -- 输出
        local isMe = (bestGUID == addon.playerGUID)
        local c = isMe and "|cff00ffff" or "|cff00ff00"
        local msg = c .. bestInfo.name .. "|r 使用 |cffffff00" .. bestInfo.spellName .. "|r 打断成功！"
        DEFAULT_CHAT_FRAME:AddMessage("|cff00d1ff雨轩工具箱|r - |cffff6600[打断]|r " .. msg)
    end
end)

------------------------------------------------------------
-- 导出接口
------------------------------------------------------------
local function UpdateInterruptState()
    if YuxuanUtilsDB.enableInterruptAlert then
        EnableInterruptAlert()
    else
        DisableInterruptAlert()
    end
end

local function GetInstanceStatus()
    return { tracking = instanceTracking, name = instanceName }
end

addon.Interrupt = {
    UpdateState = UpdateInterruptState,
    GetStatus = GetInstanceStatus,
    ShowStats = ShowStatsFrame,
    HideStats = HideStatsFrame,
    RefreshStats = RefreshStatsFrame,
}
