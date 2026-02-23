------------------------------------------------------------
-- 选项面板：仅保留地图导航开关
------------------------------------------------------------
---@diagnostic disable: undefined-global
local addonName, addon = ...

------------------------------------------------------------
-- 样式常量
------------------------------------------------------------
local ACCENT_R, ACCENT_G, ACCENT_B = 0, 0.82, 1 -- #00d1ff

--- 创建带装饰的分区卡片
local function CreateSection(parent, title, anchorFrame, offsetX, offsetY, width)
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", offsetX or 0, offsetY or -12)
    if width then
        card:SetWidth(width)
    else
        card:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
    end
    card:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
        insets   = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    card:SetBackdropColor(0.08, 0.08, 0.12, 0.7)
    card:SetBackdropBorderColor(0.25, 0.25, 0.30, 0.6)

    local topLine = card:CreateTexture(nil, "ARTWORK", nil, 2)
    topLine:SetHeight(2)
    topLine:SetPoint("TOPLEFT", card, "TOPLEFT", 2, -2)
    topLine:SetPoint("TOPRIGHT", card, "TOPRIGHT", -2, -2)
    topLine:SetColorTexture(ACCENT_R, ACCENT_G, ACCENT_B, 0.8)

    local label = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", 10, -10)
    label:SetText("|cff00d1ff" .. title .. "|r")

    card.label = label
    return card
end

local function CreateOptionsPanel()
    local configFrame = CreateFrame("Frame", "YuxuanUtilsOptionsFrame", UIParent)
    configFrame:Hide()

    local headerBg = configFrame:CreateTexture(nil, "BACKGROUND")
    headerBg:SetHeight(60)
    headerBg:SetPoint("TOPLEFT", 0, 0)
    headerBg:SetPoint("TOPRIGHT", 0, 0)
    headerBg:SetColorTexture(0.06, 0.06, 0.10, 0.6)

    local title = configFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 20, -14)
    title:SetText("|cff00d1ff雨轩工具箱|r")

    local ver = configFrame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    ver:SetPoint("LEFT", title, "RIGHT", 8, 0)
    ver:SetText("V" .. addon.VERSION)

    local subtitle = configFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    subtitle:SetText("|cffaaaaaa地图工具设置|r")

    local headerLine = configFrame:CreateTexture(nil, "ARTWORK")
    headerLine:SetHeight(1)
    headerLine:SetPoint("TOPLEFT", 16, -58)
    headerLine:SetPoint("TOPRIGHT", -16, -58)
    headerLine:SetColorTexture(ACCENT_R, ACCENT_G, ACCENT_B, 0.4)

    local navCard = CreateSection(configFrame, "导航工具", headerLine, 0, -8)
    navCard:SetHeight(70)

    local navCheck = CreateFrame("CheckButton", "YuxuanUtilsNavCheck", navCard, "UICheckButtonTemplate")
    navCheck:SetPoint("TOPLEFT", navCard.label, "BOTTOMLEFT", -4, -6)
    navCheck.Text:SetText("开启导航框（在世界地图上显示坐标输入框）")
    navCheck:SetChecked(YuxuanUtilsDB.enableNavBox)
    navCheck:SetScript("OnClick", function(self)
        YuxuanUtilsDB.enableNavBox = self:GetChecked() and true or false
        addon.Navigation.UpdateNavBox()
    end)

    local navDesc = navCard:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    navDesc:SetPoint("TOPLEFT", navCheck, "BOTTOMLEFT", 26, -1)
    navDesc:SetText("打开世界地图后，在地图顶部可输入坐标设置导航点")

    local category = Settings.RegisterCanvasLayoutCategory(configFrame, "雨轩工具箱")
    Settings.RegisterAddOnCategory(category)
end

------------------------------------------------------------
-- 导出接口
------------------------------------------------------------
addon.Options = {
    Create = CreateOptionsPanel,
}
