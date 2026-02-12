------------------------------------------------------------
-- 选项面板：美化版设置界面和历史记录查看（按角色分类）
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

    -- 顶部色条
    local topLine = card:CreateTexture(nil, "ARTWORK", nil, 2)
    topLine:SetHeight(2)
    topLine:SetPoint("TOPLEFT", card, "TOPLEFT", 2, -2)
    topLine:SetPoint("TOPRIGHT", card, "TOPRIGHT", -2, -2)
    topLine:SetColorTexture(ACCENT_R, ACCENT_G, ACCENT_B, 0.8)

    -- 标题
    local label = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", 10, -10)
    label:SetText("|cff00d1ff" .. title .. "|r")

    card.label = label
    return card
end

local function CreateOptionsPanel()
    local configFrame = CreateFrame("Frame", "YuxuanUtilsOptionsFrame", UIParent)
    configFrame:Hide()

    -- ===== 顶部标题区域 =====
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
    subtitle:SetText("|cffaaaaaa一些常用的工具  ·  /yxt 打开工具箱  ·  /yxt dd 切换打断|r")

    -- 分隔线
    local headerLine = configFrame:CreateTexture(nil, "ARTWORK")
    headerLine:SetHeight(1)
    headerLine:SetPoint("TOPLEFT", 16, -58)
    headerLine:SetPoint("TOPRIGHT", -16, -58)
    headerLine:SetColorTexture(ACCENT_R, ACCENT_G, ACCENT_B, 0.4)

    -- ===== 导航工具区 =====
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

    -- ===== 战斗工具区 =====
    local combatCard = CreateSection(configFrame, "战斗工具", navCard, 0, -8)
    combatCard:SetHeight(130)

    local intCheck = CreateFrame("CheckButton", "YuxuanUtilsIntCheck", combatCard, "UICheckButtonTemplate")
    intCheck:SetPoint("TOPLEFT", combatCard.label, "BOTTOMLEFT", -4, -6)
    intCheck.Text:SetText("打断提示（进入副本自动记录打断统计）")
    intCheck:SetChecked(YuxuanUtilsDB.enableInterruptAlert)
    intCheck:SetScript("OnClick", function(self)
        YuxuanUtilsDB.enableInterruptAlert = self:GetChecked() and true or false
        addon.Interrupt.UpdateState()
        if YuxuanUtilsDB.enableInterruptAlert then
            addon.Msg("|cff00ff00打断提示已开启|r")
        else
            addon.Msg("|cffff3333打断提示已关闭|r")
        end
    end)

    local intDesc = combatCard:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    intDesc:SetPoint("TOPLEFT", intCheck, "BOTTOMLEFT", 26, -1)
    intDesc:SetText("进入副本自动记录打断次数，离开副本时保存历史\n可通过统计窗口手动发送到聊天")

    local autoShowCheck = CreateFrame("CheckButton", "YuxuanUtilsAutoShowCheck", combatCard, "UICheckButtonTemplate")
    autoShowCheck:SetPoint("TOPLEFT", intDesc, "BOTTOMLEFT", -26, -4)
    autoShowCheck.Text:SetText("进副本自动打开统计窗口")
    autoShowCheck:SetChecked(YuxuanUtilsDB.autoShowStatsFrame ~= false)
    autoShowCheck:SetScript("OnClick", function(self)
        YuxuanUtilsDB.autoShowStatsFrame = self:GetChecked() and true or false
    end)

    -- ===== 打断历史记录区 =====
    local histCard = CreateSection(configFrame, "打断历史记录", combatCard, 0, -8)
    histCard:SetHeight(240)

    -- 角色选择行
    local charLabel = histCard:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    charLabel:SetPoint("TOPLEFT", histCard.label, "BOTTOMLEFT", 0, -10)
    charLabel:SetText("|cffcccccc角色：|r")

    local selectedCharKey = nil

    local charDropdown = CreateFrame("Frame", "YuxuanUtilsCharDropdown", histCard, "UIDropDownMenuTemplate")
    charDropdown:SetPoint("LEFT", charLabel, "RIGHT", -12, -2)

    -- 按钮行
    local btnRow = CreateFrame("Frame", nil, histCard)
    btnRow:SetSize(200, 22)
    btnRow:SetPoint("LEFT", charDropdown, "RIGHT", -4, 2)

    local clearBtn = CreateFrame("Button", nil, btnRow, "UIPanelButtonTemplate")
    clearBtn:SetSize(70, 20)
    clearBtn:SetPoint("LEFT", 0, 0)
    clearBtn:SetText("清空记录")
    clearBtn:SetScript("OnClick", function()
        local charKey = selectedCharKey or addon.GetCharacterKey()
        addon.InterruptHistory.Clear(charKey)
        addon.Msg("|cff888888" .. charKey .. " 的历史记录已清空|r")
        if configFrame.RefreshHistory then configFrame:RefreshHistory() end
    end)

    local clearAllBtn = CreateFrame("Button", nil, btnRow, "UIPanelButtonTemplate")
    clearAllBtn:SetSize(70, 20)
    clearAllBtn:SetPoint("LEFT", clearBtn, "RIGHT", 4, 0)
    clearAllBtn:SetText("清空全部")
    clearAllBtn:SetScript("OnClick", function()
        addon.InterruptHistory.ClearAll()
        addon.Msg("|cff888888所有角色的历史记录已清空|r")
        if configFrame.RefreshHistory then configFrame:RefreshHistory() end
    end)

    -- 历史记录滚动区域
    local histBg = CreateFrame("Frame", nil, histCard, "BackdropTemplate")
    histBg:SetPoint("TOPLEFT", charLabel, "BOTTOMLEFT", 0, -26)
    histBg:SetPoint("RIGHT", histCard, "RIGHT", -10, 0)
    histBg:SetPoint("BOTTOM", histCard, "BOTTOM", 0, 6)
    histBg:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
        insets   = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    histBg:SetBackdropColor(0.04, 0.04, 0.06, 0.8)
    histBg:SetBackdropBorderColor(0.2, 0.2, 0.25, 0.5)

    local histScroll = CreateFrame("ScrollFrame", "YuxuanUtilsHistScroll", histBg, "UIPanelScrollFrameTemplate")
    histScroll:SetPoint("TOPLEFT", 6, -6)
    histScroll:SetPoint("BOTTOMRIGHT", -24, 6)

    local histContent = CreateFrame("Frame", nil, histScroll)
    histContent:SetWidth(histBg:GetWidth() - 36)
    histContent:SetHeight(1)
    histScroll:SetScrollChild(histContent)

    local expandedRecords = {}

    -- 初始化下拉菜单
    local function InitCharDropdown()
        local charKeys = addon.InterruptHistory.GetAllCharKeys()
        local currentKey = addon.GetCharacterKey()

        local hasCurrentKey = false
        for _, key in ipairs(charKeys) do
            if key == currentKey then
                hasCurrentKey = true; break
            end
        end
        if not hasCurrentKey then
            table.insert(charKeys, 1, currentKey)
        end

        if not selectedCharKey then
            selectedCharKey = currentKey
        end

        UIDropDownMenu_Initialize(charDropdown, function(self, level)
            for _, key in ipairs(charKeys) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = key
                if key == currentKey then
                    info.text = key .. " |cff00ff00(当前)|r"
                end
                info.value = key
                info.checked = (key == selectedCharKey)
                info.func = function(btn)
                    selectedCharKey = btn.value
                    UIDropDownMenu_SetText(charDropdown, btn.value == currentKey and btn.value .. " (当前)" or btn.value)
                    wipe(expandedRecords)
                    configFrame:RefreshHistory()
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end)

        local displayText = selectedCharKey
        if selectedCharKey == currentKey then
            displayText = selectedCharKey .. " (当前)"
        end
        UIDropDownMenu_SetText(charDropdown, displayText)
        UIDropDownMenu_SetWidth(charDropdown, 150)
    end

    function configFrame:RefreshHistory()
        for _, child in pairs({ histContent:GetChildren() }) do
            child:Hide()
            child:SetParent(nil)
        end
        for _, region in pairs({ histContent:GetRegions() }) do
            region:Hide()
            region:SetParent(nil)
        end

        local charKey = selectedCharKey or addon.GetCharacterKey()
        local history = addon.InterruptHistory.GetHistory(charKey)

        if #history == 0 then
            local nodata = histContent:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
            nodata:SetPoint("TOPLEFT", 8, -8)
            nodata:SetText("|cff555555暂无记录|r")
            histContent:SetHeight(24)
            return
        end

        local yOffset = -4
        for i = #history, 1, -1 do
            local record = history[i]
            local recordId = i
            local isExpanded = expandedRecords[recordId]

            -- 折叠按钮
            local toggleBtn = CreateFrame("Button", nil, histContent)
            toggleBtn:SetSize(14, 14)
            toggleBtn:SetPoint("TOPLEFT", 4, yOffset)

            toggleBtn.tex = toggleBtn:CreateTexture(nil, "ARTWORK")
            toggleBtn.tex:SetAllPoints()
            if isExpanded then
                toggleBtn.tex:SetTexture("Interface\\Buttons\\UI-MinusButton-Up")
            else
                toggleBtn.tex:SetTexture("Interface\\Buttons\\UI-PlusButton-Up")
            end
            toggleBtn:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight")

            -- 记录标题
            local header = histContent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            header:SetPoint("LEFT", toggleBtn, "RIGHT", 4, 0)
            local durationStr = ""
            if record.duration and record.duration > 0 then
                local mins = math.floor(record.duration / 60)
                local secs = math.floor(record.duration % 60)
                durationStr = string.format("  |cff888888(%d分%d秒)|r", mins, secs)
            end

            local totalCount = 0
            if record.stats then
                for _, stat in ipairs(record.stats) do
                    totalCount = totalCount + (stat.count or 0)
                end
            end

            header:SetText("|cffffcc00" .. (record.time or "") ..
                "|r  |cff00d1ff" .. (record.instance or "未知") ..
                "|r" .. durationStr ..
                "  |cffffff00[" .. totalCount .. "次]|r")
            yOffset = yOffset - 18

            toggleBtn:SetScript("OnClick", function()
                expandedRecords[recordId] = not expandedRecords[recordId]
                configFrame:RefreshHistory()
            end)

            if isExpanded and record.stats then
                for _, stat in ipairs(record.stats) do
                    local line = histContent:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
                    line:SetPoint("TOPLEFT", 28, yOffset)
                    local classColor = addon.GetClassColor(stat.name)
                    line:SetText("|cff" .. classColor .. stat.name .. "|r：|cffffff00" .. stat.count .. "|r 次")
                    yOffset = yOffset - 14
                end
                yOffset = yOffset - 4
            end
        end

        histContent:SetHeight(math.abs(yOffset) + 10)
    end

    configFrame:SetScript("OnShow", function(self)
        InitCharDropdown()
        self:RefreshHistory()
    end)

    local category = Settings.RegisterCanvasLayoutCategory(configFrame, "雨轩工具箱")
    Settings.RegisterAddOnCategory(category)
end

------------------------------------------------------------
-- 导出接口
------------------------------------------------------------
addon.Options = {
    Create = CreateOptionsPanel,
}
