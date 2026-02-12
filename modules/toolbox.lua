------------------------------------------------------------
-- 工具箱窗口：美化版选项卡式界面
------------------------------------------------------------
---@diagnostic disable: undefined-global
local addonName, addon = ...

local toolboxFrame
local toolboxPages = {}

------------------------------------------------------------
-- 样式常量
------------------------------------------------------------
local FRAME_W, FRAME_H = 380, 340
local TAB_H = 28
local TITLE_H = 28
local ACCENT_R, ACCENT_G, ACCENT_B = 0, 0.82, 1       -- 主色调 #00d1ff
local BG_R, BG_G, BG_B, BG_A = 0.06, 0.06, 0.10, 0.94 -- 深色背景

------------------------------------------------------------
-- 工具函数
------------------------------------------------------------
--- 创建带圆角的纯色背景
local function ApplyBackdropStyle(frame, r, g, b, a, borderR, borderG, borderB, borderA)
    frame:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets   = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    frame:SetBackdropColor(r or BG_R, g or BG_G, b or BG_B, a or BG_A)
    frame:SetBackdropBorderColor(borderR or 0.25, borderG or 0.25, borderB or 0.30, borderA or 0.8)
end

--- 创建分组标题（带左侧色条装饰）
local function CreateSectionHeader(parent, text, anchor, offsetX, offsetY, anchorPoint)
    local bar = parent:CreateTexture(nil, "ARTWORK")
    bar:SetSize(3, 14)
    bar:SetPoint("TOPLEFT", anchor, anchorPoint or "BOTTOMLEFT", (offsetX or 0), (offsetY or -16))
    bar:SetColorTexture(ACCENT_R, ACCENT_G, ACCENT_B, 1)

    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", bar, "RIGHT", 6, 0)
    label:SetText("|cff00d1ff" .. text .. "|r")

    return bar, label
end

--- 创建美化按钮
local function CreateStyledButton(parent, width, height, text)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(width, height)

    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetAllPoints()
    btn.bg:SetColorTexture(0.15, 0.35, 0.55, 0.9)

    btn.highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    btn.highlight:SetAllPoints()
    btn.highlight:SetColorTexture(1, 1, 1, 0.08)

    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btn.text:SetPoint("CENTER")
    btn.text:SetText(text)

    btn:SetScript("OnMouseDown", function(self)
        self.bg:SetColorTexture(0.1, 0.25, 0.4, 1)
    end)
    btn:SetScript("OnMouseUp", function(self)
        self.bg:SetColorTexture(0.15, 0.35, 0.55, 0.9)
    end)

    return btn
end

------------------------------------------------------------
-- 创建工具箱主框体
------------------------------------------------------------
local function CreateToolboxFrame()
    if toolboxFrame then return toolboxFrame end

    local f = CreateFrame("Frame", "YuxuanUtilsToolbox", UIParent, "BackdropTemplate")
    f:SetSize(FRAME_W, FRAME_H)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    ApplyBackdropStyle(f)

    -- ===== 标题栏 =====
    f.titleBar = f:CreateTexture(nil, "ARTWORK")
    f.titleBar:SetHeight(TITLE_H)
    f.titleBar:SetPoint("TOPLEFT", 2, -2)
    f.titleBar:SetPoint("TOPRIGHT", -2, -2)
    f.titleBar:SetColorTexture(0.08, 0.20, 0.35, 1)

    -- 标题栏底部高亮线
    f.titleLine = f:CreateTexture(nil, "ARTWORK", nil, 2)
    f.titleLine:SetHeight(1)
    f.titleLine:SetPoint("TOPLEFT", f.titleBar, "BOTTOMLEFT", 0, 0)
    f.titleLine:SetPoint("TOPRIGHT", f.titleBar, "BOTTOMRIGHT", 0, 0)
    f.titleLine:SetColorTexture(ACCENT_R, ACCENT_G, ACCENT_B, 0.6)

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("LEFT", f.titleBar, "LEFT", 10, 0)
    f.title:SetText("|cff00d1ff雨轩工具箱|r")

    f.verText = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.verText:SetPoint("LEFT", f.title, "RIGHT", 6, 0)
    f.verText:SetText("V" .. addon.VERSION)

    -- 关闭按钮
    f.closeBtn = CreateFrame("Button", nil, f)
    f.closeBtn:SetSize(TITLE_H - 4, TITLE_H - 4)
    f.closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)

    f.closeBtn.x = f.closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.closeBtn.x:SetPoint("CENTER", 0, 0)
    f.closeBtn.x:SetText("|cffaaaaaax|r")

    f.closeBtn:SetScript("OnClick", function() f:Hide() end)
    f.closeBtn:SetScript("OnEnter", function(self)
        self.x:SetText("|cffff4444x|r")
    end)
    f.closeBtn:SetScript("OnLeave", function(self)
        self.x:SetText("|cffaaaaaax|r")
    end)

    -- ===== 选项卡系统 =====
    local tabs = {}
    local tabNames = { "打断", "组队", "常用功能", "预留" }
    local activeTab = 1

    local tabStartY = -(TITLE_H + 4)

    local function ShowPage(index)
        activeTab = index
        for _, page in pairs(toolboxPages) do
            if page then page:Hide() end
        end
        if toolboxPages[index] then
            toolboxPages[index]:Show()
        end
        for i, tab in ipairs(tabs) do
            if i == index then
                tab.bg:SetColorTexture(0.12, 0.12, 0.16, 1)
                tab.text:SetTextColor(ACCENT_R, ACCENT_G, ACCENT_B)
                tab.indicator:Show()
            else
                tab.bg:SetColorTexture(0.08, 0.08, 0.11, 1)
                tab.text:SetTextColor(0.5, 0.5, 0.5)
                tab.indicator:Hide()
            end
        end
    end

    local tabW = (FRAME_W - 8) / #tabNames
    for i, name in ipairs(tabNames) do
        local tab = CreateFrame("Button", nil, f)
        tab:SetSize(tabW, TAB_H)
        if i == 1 then
            tab:SetPoint("TOPLEFT", f, "TOPLEFT", 4, tabStartY)
        else
            tab:SetPoint("LEFT", tabs[i - 1], "RIGHT", 0, 0)
        end

        tab.bg = tab:CreateTexture(nil, "BACKGROUND")
        tab.bg:SetAllPoints()
        tab.bg:SetColorTexture(0.08, 0.08, 0.11, 1)

        tab.text = tab:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        tab.text:SetPoint("CENTER", 0, 1)
        tab.text:SetText(name)

        -- 底部指示条
        tab.indicator = tab:CreateTexture(nil, "ARTWORK", nil, 2)
        tab.indicator:SetHeight(2)
        tab.indicator:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 6, 0)
        tab.indicator:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -6, 0)
        tab.indicator:SetColorTexture(ACCENT_R, ACCENT_G, ACCENT_B, 1)
        tab.indicator:Hide()

        tab:SetScript("OnClick", function() ShowPage(i) end)
        tab:SetScript("OnEnter", function(self)
            if i ~= activeTab then
                self.bg:SetColorTexture(0.12, 0.14, 0.18, 1)
            end
        end)
        tab:SetScript("OnLeave", function(self)
            if i ~= activeTab then
                self.bg:SetColorTexture(0.08, 0.08, 0.11, 1)
            end
        end)
        tabs[i] = tab
    end

    -- 选项卡下方分隔线
    local tabSep = f:CreateTexture(nil, "ARTWORK")
    tabSep:SetHeight(1)
    tabSep:SetPoint("TOPLEFT", f, "TOPLEFT", 4, tabStartY - TAB_H)
    tabSep:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, tabStartY - TAB_H)
    tabSep:SetColorTexture(0.3, 0.3, 0.35, 0.5)

    local contentTop = tabStartY - TAB_H - 2

    local function CreatePage()
        local page = CreateFrame("Frame", nil, f)
        page:SetPoint("TOPLEFT", f, "TOPLEFT", 8, contentTop)
        page:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 8)
        page:Hide()
        return page
    end

    -- ===== 页面1：打断工具 =====
    local page2 = CreatePage()
    toolboxPages[1] = page2

    local _, intLabel = CreateSectionHeader(page2, "打断提示", page2, 4, -8, "TOPLEFT")

    local intToggle = CreateFrame("CheckButton", "YuxuanUtilsToolboxIntCheck", page2, "UICheckButtonTemplate")
    intToggle:SetPoint("TOPLEFT", intLabel, "BOTTOMLEFT", -6, -8)
    intToggle.Text:SetText("开启打断提示（进入副本自动记录打断统计）")
    intToggle:SetChecked(YuxuanUtilsDB.enableInterruptAlert)
    intToggle:SetScript("OnClick", function(self)
        YuxuanUtilsDB.enableInterruptAlert = self:GetChecked() and true or false
        addon.Interrupt.UpdateState()
        if YuxuanUtilsDB.enableInterruptAlert then
            addon.Msg("|cff00ff00打断提示已开启|r")
        else
            addon.Msg("|cffff3333打断提示已关闭|r")
        end
        if YuxuanUtilsIntCheck then
            YuxuanUtilsIntCheck:SetChecked(YuxuanUtilsDB.enableInterruptAlert)
        end
    end)

    local intInfo = page2:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    intInfo:SetPoint("TOPLEFT", intToggle, "BOTTOMLEFT", 26, -2)
    intInfo:SetText("进入副本自动记录打断次数\n离开副本时保存历史，可手动发送统计到聊天")

    local autoShowCheck = CreateFrame("CheckButton", "YuxuanUtilsAutoShowStatsCheck", page2, "UICheckButtonTemplate")
    autoShowCheck:SetPoint("TOPLEFT", intInfo, "BOTTOMLEFT", -26, -8)
    autoShowCheck.Text:SetText("进副本自动打开统计窗口")
    autoShowCheck:SetChecked(YuxuanUtilsDB.autoShowStatsFrame ~= false)
    autoShowCheck:SetScript("OnClick", function(self)
        YuxuanUtilsDB.autoShowStatsFrame = self:GetChecked() and true or false
    end)

    -- 状态指示器
    local statusDot = page2:CreateTexture(nil, "ARTWORK")
    statusDot:SetSize(8, 8)
    statusDot:SetPoint("TOPLEFT", autoShowCheck, "BOTTOMLEFT", 4, -14)

    local statusLabel = page2:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    statusLabel:SetPoint("LEFT", statusDot, "RIGHT", 6, 0)

    local statsBtn = CreateStyledButton(page2, 150, 24, "显示/隐藏统计窗口")
    statsBtn:SetPoint("TOPLEFT", statusDot, "BOTTOMLEFT", -4, -10)
    statsBtn:SetScript("OnClick", function()
        local status = addon.Interrupt.GetStatus()
        if not status.tracking then
            addon.Msg("|cff888888不在副本中，无法显示统计窗口|r")
            return
        end
        if YuxuanInterruptStats and YuxuanInterruptStats:IsShown() then
            addon.Interrupt.HideStats()
        else
            addon.Interrupt.ShowStats()
        end
    end)

    local function UpdateStatusLabel()
        local status = addon.Interrupt.GetStatus()
        if status.tracking then
            statusDot:SetColorTexture(0, 1, 0, 1)
            statusLabel:SetText("|cff00ff00正在记录|r - |cffffcc00" .. (status.name or "未知副本") .. "|r")
            statsBtn:Enable()
            statsBtn.bg:SetColorTexture(0.15, 0.35, 0.55, 0.9)
        else
            statusDot:SetColorTexture(0.4, 0.4, 0.4, 1)
            statusLabel:SetText("|cff888888未在副本中|r")
            statsBtn:Disable()
            statsBtn.bg:SetColorTexture(0.15, 0.15, 0.15, 0.6)
        end
    end
    page2:SetScript("OnShow", UpdateStatusLabel)

    -- ===== 页面2：组队邀请 =====
    local page1 = CreatePage()
    toolboxPages[2] = page1

    local _, invLabel = CreateSectionHeader(page1, "邀请组队", page1, 4, -8, "TOPLEFT")

    local nameLabel = page1:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    nameLabel:SetPoint("TOPLEFT", invLabel, "BOTTOMLEFT", 0, -12)
    nameLabel:SetText("角色名：")

    local nameBox = CreateFrame("EditBox", "YuxuanUtilsInviteNameBox", page1, "InputBoxTemplate")
    nameBox:SetSize(180, 22)
    nameBox:SetPoint("LEFT", nameLabel, "RIGHT", 4, 0)
    nameBox:SetAutoFocus(false)
    nameBox:SetFontObject(ChatFontNormal)

    local invBtn = CreateStyledButton(page1, 60, 22, "邀请")
    invBtn:SetPoint("LEFT", nameBox, "RIGHT", 6, 0)

    local invResult = page1:CreateFontString("YuxuanUtilsInviteResult", "ARTWORK", "GameFontHighlightSmall")
    invResult:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, -14)
    invResult:SetText("")

    local function DoInvite()
        local name = strtrim(nameBox:GetText() or "")
        if name == "" then
            invResult:SetText("|cffff3333请输入角色名|r")
            return
        end
        local nameWithRealm = name
        if not name:find("-") then
            local realm = (GetNormalizedRealmName and GetNormalizedRealmName()) or (GetRealmName and GetRealmName()) or
                ""
            if realm ~= "" then
                nameWithRealm = name .. "-" .. realm
            end
        end

        local invited = false
        if C_PartyInfo and C_PartyInfo.InviteUnit then
            pcall(function() C_PartyInfo.InviteUnit(nameWithRealm) end)
            invited = true
        elseif InviteUnit then
            pcall(function() InviteUnit(nameWithRealm) end)
            invited = true
        else
            local ok = pcall(function()
                local edit = ChatEdit_GetActiveWindow() or DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.editBox or
                    _G.ChatFrame1EditBox
                if edit then
                    edit:SetText("/invite " .. nameWithRealm)
                    ChatEdit_SendText(edit, 0)
                end
            end)
            invited = ok
        end

        if invited then
            invResult:SetText("|cff00ff00已向 |cffffcc00" .. nameWithRealm .. "|r |cff00ff00发送组队邀请|r")
        else
            invResult:SetText("|cffff3333无法自动邀请，请手动 /invite " .. nameWithRealm .. "|r")
        end
        nameBox:SetText("")
        nameBox:SetFocus()
        C_Timer.After(4, function()
            if invResult and invResult:GetText() ~= "" then
                invResult:SetText("")
            end
        end)
    end

    invBtn:SetScript("OnClick", DoInvite)
    nameBox:SetScript("OnEnterPressed", function() DoInvite() end)
    nameBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    -- ===== 页面3：常用功能 =====
    local page3 = CreatePage()
    toolboxPages[3] = page3

    local _, utilLabel = CreateSectionHeader(page3, "常用功能", page3, 4, -8, "TOPLEFT")

    local vaultBtn = CreateStyledButton(page3, 150, 28, "打开宏伟宝库")
    vaultBtn:SetPoint("TOPLEFT", utilLabel, "BOTTOMLEFT", 0, -12)
    vaultBtn:SetScript("OnClick", function()
        if WeeklyRewardsFrame and WeeklyRewardsFrame:IsShown() then
            WeeklyRewardsFrame:Hide()
            return
        end
        if WeeklyRewards_ShowUI then
            WeeklyRewards_ShowUI()
        elseif C_AddOns and C_AddOns.LoadAddOn then
            C_AddOns.LoadAddOn("Blizzard_WeeklyRewards")
            if WeeklyRewards_ShowUI then
                WeeklyRewards_ShowUI()
            end
        else
            addon.Msg("|cffff3333无法打开宏伟宝库，请确保已解锁|r")
        end
    end)

    -- ===== 页面4：预留 =====
    local page4 = CreatePage()
    toolboxPages[4] = page4

    local p4text = page4:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    p4text:SetPoint("CENTER", 0, 20)
    p4text:SetText("|cff555555此页面预留，后续功能开发中...|r")

    ShowPage(1)

    f:Hide()
    toolboxFrame = f
    return f
end

local function ToggleToolbox()
    local f = CreateToolboxFrame()
    if f:IsShown() then
        f:Hide()
    else
        f:Show()
        if YuxuanUtilsInviteNameBox then
            YuxuanUtilsInviteNameBox:SetFocus()
        end
    end
end

------------------------------------------------------------
-- 导出接口
------------------------------------------------------------
addon.Toolbox = {
    Toggle = ToggleToolbox,
}
