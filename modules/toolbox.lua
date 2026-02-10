------------------------------------------------------------
-- 工具箱窗口：选项卡式界面
------------------------------------------------------------
---@diagnostic disable: undefined-global
local addonName, addon = ...

local toolboxFrame
local toolboxPages = {}

local function CreateToolboxFrame()
    if toolboxFrame then return toolboxFrame end

    local FRAME_W, FRAME_H = 360, 320
    local TAB_H = 24

    local f = CreateFrame("Frame", "YuxuanUtilsToolbox", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(FRAME_W, FRAME_H)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.title:SetPoint("LEFT", f.TitleBg, "LEFT", 6, 0)
    f.title:SetText("|cff00d1ff雨轩工具箱|r |cff888888V" .. addon.VERSION .. "|r")

    -- ============ 选项卡系统 ============
    local tabs = {}
    local tabNames = { "打断", "组队", "预留1", "预留2" }
    local activeTab = 1

    local function ShowPage(index)
        activeTab = index
        for i, page in pairs(toolboxPages) do
            if page then page:Hide() end
        end
        if toolboxPages[index] then
            toolboxPages[index]:Show()
        end
        for i, tab in ipairs(tabs) do
            if i == index then
                tab.bg:SetColorTexture(0.2, 0.4, 0.6, 0.9)
                tab.text:SetTextColor(1, 1, 1)
            else
                tab.bg:SetColorTexture(0.15, 0.15, 0.15, 0.8)
                tab.text:SetTextColor(0.6, 0.6, 0.6)
            end
        end
    end

    for i, name in ipairs(tabNames) do
        local tab = CreateFrame("Button", nil, f)
        tab:SetSize((FRAME_W - 16 - (#tabNames - 1) * 4) / #tabNames, TAB_H)
        if i == 1 then
            tab:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -22)
        else
            tab:SetPoint("LEFT", tabs[i - 1], "RIGHT", 4, 0)
        end

        tab.bg = tab:CreateTexture(nil, "BACKGROUND")
        tab.bg:SetAllPoints()
        tab.bg:SetColorTexture(0.15, 0.15, 0.15, 0.8)

        tab.text = tab:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        tab.text:SetPoint("CENTER")
        tab.text:SetText(name)

        tab:SetScript("OnClick", function() ShowPage(i) end)
        tab:SetScript("OnEnter", function(self)
            if i ~= activeTab then
                self.bg:SetColorTexture(0.25, 0.25, 0.25, 0.9)
            end
        end)
        tab:SetScript("OnLeave", function(self)
            if i ~= activeTab then
                self.bg:SetColorTexture(0.15, 0.15, 0.15, 0.8)
            end
        end)
        tabs[i] = tab
    end

    local contentTop = -22 - TAB_H - 4

    local function CreatePage()
        local page = CreateFrame("Frame", nil, f)
        page:SetPoint("TOPLEFT", f, "TOPLEFT", 8, contentTop)
        page:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 8)
        page:Hide()
        return page
    end

    -- ============ 页面1：组队邀请 ============
    local page1 = CreatePage()
    toolboxPages[2] = page1

    local invSep = page1:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    invSep:SetPoint("TOPLEFT", 4, -8)
    invSep:SetText("|cffffcc00【 邀请组队 】|r")

    local nameLabel = page1:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    nameLabel:SetPoint("TOPLEFT", invSep, "BOTTOMLEFT", 0, -10)
    nameLabel:SetText("角色名：")

    local nameBox = CreateFrame("EditBox", "YuxuanUtilsInviteNameBox", page1, "InputBoxTemplate")
    nameBox:SetSize(180, 22)
    nameBox:SetPoint("LEFT", nameLabel, "RIGHT", 4, 0)
    nameBox:SetAutoFocus(false)
    nameBox:SetFontObject(ChatFontNormal)

    local invResult = page1:CreateFontString("YuxuanUtilsInviteResult", "ARTWORK", "GameFontHighlightSmall")
    invResult:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, -14)
    invResult:SetText("")

    local invBtn = CreateFrame("Button", nil, page1, "UIPanelButtonTemplate")
    invBtn:SetSize(60, 22)
    invBtn:SetPoint("LEFT", nameBox, "RIGHT", 4, 0)
    invBtn:SetText("邀请")

    local function DoInvite()
        local name = strtrim(nameBox:GetText() or "")
        if name == "" then
            invResult:SetText("|cffff3333请输入角色名|r")
            return
        end
        InviteUnit(name)
        invResult:SetText("|cff00ff00✓ 已向 |cffffcc00" .. name .. "|r |cff00ff00发送组队邀请|r")
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

    -- ============ 页面2：打断工具 ============
    local page2 = CreatePage()
    toolboxPages[1] = page2

    local intSep = page2:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    intSep:SetPoint("TOPLEFT", 4, -8)
    intSep:SetText("|cffffcc00【 打断提示 】|r")

    local intToggle = CreateFrame("CheckButton", "YuxuanUtilsToolboxIntCheck", page2, "UICheckButtonTemplate")
    intToggle:SetPoint("TOPLEFT", intSep, "BOTTOMLEFT", 0, -6)
    intToggle.Text:SetText("开启打断提示（在聊天框显示打断信息）")
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
    intInfo:SetPoint("TOPLEFT", intToggle, "BOTTOMLEFT", 26, -4)
    intInfo:SetText("进入副本自动记录打断次数，自动弹出统计窗口\n离开副本时输出统计并保存历史")

    local statusLabel = page2:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    statusLabel:SetPoint("TOPLEFT", intInfo, "BOTTOMLEFT", -26, -14)

    local statsBtn = CreateFrame("Button", nil, page2, "UIPanelButtonTemplate")
    statsBtn:SetSize(120, 22)
    statsBtn:SetPoint("TOPLEFT", statusLabel, "BOTTOMLEFT", 0, -10)
    statsBtn:SetText("显示/隐藏统计窗口")
    statsBtn:SetScript("OnClick", function()
        local status = addon.Interrupt.GetStatus()
        if not status.tracking then
            addon.Msg("|cff888888不在副本中，无法显示统计窗口|r")
            return
        end

        -- 切换显示/隐藏
        if addon.Interrupt and addon.Interrupt.GetStatus then
            -- 如果窗口已显示则隐藏，否则显示
            if YuxuanInterruptStats and YuxuanInterruptStats:IsShown() then
                addon.Interrupt.HideStats()
            else
                addon.Interrupt.ShowStats()
            end
        else
            addon.Interrupt.ShowStats()
        end
    end)

    local function UpdateStatusLabel()
        local status = addon.Interrupt.GetStatus()
        if status.tracking then
            statusLabel:SetText("|cff00ff00● 正在记录|r - |cffffcc00" .. (status.name or "未知副本") .. "|r")
            statsBtn:Enable()
        else
            statusLabel:SetText("|cff888888● 未在副本中|r")
            statsBtn:Disable()
        end
    end
    page2:SetScript("OnShow", UpdateStatusLabel)

    -- ============ 页面3：预留1 ============
    local page3 = CreatePage()
    toolboxPages[3] = page3

    local p3text = page3:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    p3text:SetPoint("CENTER")
    p3text:SetText("|cff888888此页面预留，后续功能开发中...|r")

    -- ============ 页面4：预留2 ============
    local page4 = CreatePage()
    toolboxPages[4] = page4

    local p4text = page4:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    p4text:SetPoint("CENTER")
    p4text:SetText("|cff888888此页面预留，后续功能开发中...|r")

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
