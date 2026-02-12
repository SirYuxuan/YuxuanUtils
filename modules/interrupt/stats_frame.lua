------------------------------------------------------------
-- 打断统计浮动窗口 UI（美化版）
------------------------------------------------------------
---@diagnostic disable: undefined-global
local addonName, addon = ...

local statsFrame = nil

local ROW_H = 22
local FRAME_W = 260
local SEND_BTN_H = 24
local TITLE_H = 24
local ACCENT_R, ACCENT_G, ACCENT_B = 0, 0.82, 1

------------------------------------------------------------
-- 创建统计窗口
------------------------------------------------------------
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
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets   = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    f:SetBackdropColor(0.04, 0.04, 0.08, 0.92)
    f:SetBackdropBorderColor(0.2, 0.4, 0.7, 0.6)

    -- ===== 标题栏（渐变感） =====
    f.titleBar = f:CreateTexture(nil, "ARTWORK")
    f.titleBar:SetHeight(TITLE_H)
    f.titleBar:SetPoint("TOPLEFT", 2, -2)
    f.titleBar:SetPoint("TOPRIGHT", -2, -2)
    f.titleBar:SetColorTexture(0.06, 0.18, 0.32, 1)

    -- 标题底部高亮线
    f.titleLine = f:CreateTexture(nil, "ARTWORK", nil, 2)
    f.titleLine:SetHeight(1)
    f.titleLine:SetPoint("TOPLEFT", f.titleBar, "BOTTOMLEFT", 0, 0)
    f.titleLine:SetPoint("TOPRIGHT", f.titleBar, "BOTTOMRIGHT", 0, 0)
    f.titleLine:SetColorTexture(ACCENT_R, ACCENT_G, ACCENT_B, 0.5)

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.title:SetPoint("LEFT", f.titleBar, "LEFT", 8, 0)
    f.title:SetText("|cff00d1ff打断统计|r")

    f.instName = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.instName:SetPoint("RIGHT", f.titleBar, "RIGHT", -22, 0)

    -- 关闭按钮
    f.closeBtn = CreateFrame("Button", nil, f)
    f.closeBtn:SetSize(16, 16)
    f.closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -5)

    f.closeBtn.x = f.closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.closeBtn.x:SetPoint("CENTER")
    f.closeBtn.x:SetText("|cff888888x|r")

    f.closeBtn:SetScript("OnClick", function() f:Hide() end)
    f.closeBtn:SetScript("OnEnter", function(self)
        self.x:SetText("|cffff4444x|r")
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
        GameTooltip:SetText("关闭统计窗口")
        GameTooltip:Show()
    end)
    f.closeBtn:SetScript("OnLeave", function(self)
        self.x:SetText("|cff888888x|r")
        GameTooltip:Hide()
    end)

    -- ===== 发送按钮（美化） =====
    f.sendBtn = CreateFrame("Button", nil, f)
    f.sendBtn:SetSize(FRAME_W - 10, SEND_BTN_H)
    f.sendBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 5, -(TITLE_H + 5))

    f.sendBtn.bg = f.sendBtn:CreateTexture(nil, "BACKGROUND")
    f.sendBtn.bg:SetAllPoints()
    f.sendBtn.bg:SetColorTexture(0.12, 0.30, 0.50, 0.8)

    f.sendBtn.highlight = f.sendBtn:CreateTexture(nil, "HIGHLIGHT")
    f.sendBtn.highlight:SetAllPoints()
    f.sendBtn.highlight:SetColorTexture(1, 1, 1, 0.06)

    f.sendBtn.text = f.sendBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.sendBtn.text:SetPoint("CENTER")
    f.sendBtn.text:SetText("|cffdddddd发送统计到聊天|r")

    f.sendBtn:SetScript("OnMouseDown", function(self)
        self.bg:SetColorTexture(0.08, 0.20, 0.35, 1)
    end)
    f.sendBtn:SetScript("OnMouseUp", function(self)
        self.bg:SetColorTexture(0.12, 0.30, 0.50, 0.8)
    end)

    f.sendBtn:SetScript("OnClick", function()
        local instanceStats = addon.Interrupt.GetInstanceStats()
        if not instanceStats or not next(instanceStats) then
            addon.Msg("|cff888888没有打断数据可发送|r")
            return
        end
        local sorted = {}
        for name, count in pairs(instanceStats) do
            table.insert(sorted, { name = name, count = count })
        end
        table.sort(sorted, function(a, b)
            if a.count ~= b.count then return a.count > b.count end
            return a.name < b.name
        end)

        local channel = addon.GetCurrentChatChannel()
        SendChatMessage("雨轩工具箱-打断统计", channel)
        SendChatMessage("====================", channel)
        for i, e in ipairs(sorted) do
            SendChatMessage(i .. ". " .. e.name .. ": " .. e.count .. "次", channel)
        end
        SendChatMessage("====================", channel)
    end)

    f.rows = {}
    statsFrame = f
    return f
end

------------------------------------------------------------
-- 创建带闪烁效果和 hover 高亮的行
------------------------------------------------------------
local function CreateRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW_H)
    row:EnableMouse(true)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()

    -- hover 高亮
    row.hoverBg = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    row.hoverBg:SetAllPoints()
    row.hoverBg:SetColorTexture(1, 1, 1, 0.04)
    row.hoverBg:Hide()

    row:SetScript("OnEnter", function(self) self.hoverBg:Show() end)
    row:SetScript("OnLeave", function(self) self.hoverBg:Hide() end)

    -- 排名标记
    row.rankText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.rankText:SetPoint("LEFT", 6, 0)
    row.rankText:SetWidth(18)
    row.rankText:SetJustifyH("RIGHT")

    row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.nameText:SetPoint("LEFT", 28, 0)

    row.countText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.countText:SetPoint("RIGHT", -8, 0)

    -- 闪烁光圈
    row.flash = row:CreateTexture(nil, "ARTWORK")
    row.flash:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.flash:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    row.flash:SetColorTexture(ACCENT_R, ACCENT_G, ACCENT_B, 1)
    row.flash:SetAlpha(0)
    row.flash:SetBlendMode("ADD")
    row.flash:SetDrawLayer("ARTWORK", 7)

    -- 闪烁动画
    row.flashAnim = row.flash:CreateAnimationGroup()
    local fadeIn = row.flashAnim:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0)
    fadeIn:SetToAlpha(0.7)
    fadeIn:SetDuration(0.1)
    fadeIn:SetOrder(1)

    local fadeOut = row.flashAnim:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(0.7)
    fadeOut:SetToAlpha(0)
    fadeOut:SetDuration(0.4)
    fadeOut:SetOrder(2)

    local fadeIn2 = row.flashAnim:CreateAnimation("Alpha")
    fadeIn2:SetFromAlpha(0)
    fadeIn2:SetToAlpha(0.5)
    fadeIn2:SetDuration(0.1)
    fadeIn2:SetOrder(3)
    fadeIn2:SetStartDelay(0.05)

    local fadeOut2 = row.flashAnim:CreateAnimation("Alpha")
    fadeOut2:SetFromAlpha(0.5)
    fadeOut2:SetToAlpha(0)
    fadeOut2:SetDuration(0.3)
    fadeOut2:SetOrder(4)

    row.flashAnim:SetScript("OnFinished", function()
        row.flash:SetAlpha(0)
    end)

    return row
end

------------------------------------------------------------
-- 刷新统计窗口数据
------------------------------------------------------------
local function RefreshStatsFrame()
    if not statsFrame or not statsFrame:IsShown() then return end

    local status = addon.Interrupt.GetStatus()
    local instanceStats = addon.Interrupt.GetInstanceStats()

    statsFrame.instName:SetText("|cff666666" .. (status.name or "") .. "|r")

    -- 收集所有有数据的玩家 + 当前队伍成员（合并显示）
    local nameSet = {}
    local members = addon.GetGroupMembers()
    for _, name in ipairs(members) do
        nameSet[name] = true
    end
    for name, _ in pairs(instanceStats) do
        nameSet[name] = true
    end

    local data = {}
    for name, _ in pairs(nameSet) do
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

    local rowStartY = -(TITLE_H + 5 + SEND_BTN_H + 4)

    for i, entry in ipairs(data) do
        local row = statsFrame.rows[i]
        if not row then
            row = CreateRow(statsFrame, i)
            statsFrame.rows[i] = row
        end

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", statsFrame, "TOPLEFT", 4, rowStartY - (i - 1) * ROW_H)
        row:SetPoint("RIGHT", statsFrame, "RIGHT", -4, 0)

        -- 交替行背景
        if i % 2 == 0 then
            row.bg:SetColorTexture(0.08, 0.08, 0.12, 0.5)
        else
            row.bg:SetColorTexture(0, 0, 0, 0)
        end

        -- 排名高亮（前三名用特殊颜色）
        local rankColors = { "ffd700", "c0c0c0", "cd7f32" } -- 金银铜
        if i <= 3 and entry.count > 0 then
            row.rankText:SetText("|cff" .. rankColors[i] .. i .. "|r")
        else
            row.rankText:SetText("|cff555555" .. i .. "|r")
        end

        local classColor = addon.GetClassColor(entry.name)
        row.nameText:SetText("|cff" .. classColor .. entry.name .. "|r")
        row.playerName = entry.name

        if entry.count > 0 then
            row.countText:SetText("|cffffff00" .. entry.count .. "|r")
        else
            row.countText:SetText("|cff444444" .. entry.count .. "|r")
        end

        row:Show()
    end

    local totalRows = math.max(#data, 1)
    statsFrame:SetHeight((TITLE_H + 5) + (SEND_BTN_H + 4) + totalRows * ROW_H + 6)
end

------------------------------------------------------------
-- 闪烁指定玩家行
------------------------------------------------------------
local function FlashPlayerRow(name)
    if not statsFrame or not statsFrame:IsShown() or not name then return end
    for _, row in ipairs(statsFrame.rows) do
        if row:IsShown() and row.playerName == name then
            if row.flashAnim then
                row.flashAnim:Stop()
                row.flash:SetAlpha(1)
                row.flashAnim:Play()
            end
            break
        end
    end
end

------------------------------------------------------------
-- 显示 / 隐藏
------------------------------------------------------------
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

------------------------------------------------------------
-- 导出接口
------------------------------------------------------------
addon.StatsFrame = {
    Show    = ShowStatsFrame,
    Hide    = HideStatsFrame,
    Refresh = RefreshStatsFrame,
    Flash   = FlashPlayerRow,
}
