------------------------------------------------------------
-- 选项面板：设置界面和历史记录查看
------------------------------------------------------------
---@diagnostic disable: undefined-global
local addonName, addon = ...

local function CreateOptionsPanel()
    local configFrame = CreateFrame("Frame", "YuxuanUtilsOptionsFrame", UIParent)
    configFrame:Hide()

    local title = configFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("|cff00d1ff雨轩工具箱|r")

    local ver = configFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    ver:SetPoint("LEFT", title, "RIGHT", 8, 0)
    ver:SetText("|cff888888V" .. addon.VERSION .. "|r")

    local subtitle = configFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetText("一些常用的工具")

    -- 导航工具
    local sep1 = configFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    sep1:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -16)
    sep1:SetText("|cffffcc00【 导航工具 】|r")

    local navCheck = CreateFrame("CheckButton", "YuxuanUtilsNavCheck", configFrame, "UICheckButtonTemplate")
    navCheck:SetPoint("TOPLEFT", sep1, "BOTTOMLEFT", 0, -8)
    navCheck.Text:SetText("开启导航框（在世界地图上显示坐标输入框）")
    navCheck:SetChecked(YuxuanUtilsDB.enableNavBox)
    navCheck:SetScript("OnClick", function(self)
        YuxuanUtilsDB.enableNavBox = self:GetChecked() and true or false
        addon.Navigation.UpdateNavBox()
    end)

    local navDesc = configFrame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    navDesc:SetPoint("TOPLEFT", navCheck, "BOTTOMLEFT", 26, -4)
    navDesc:SetText("打开世界地图后，在地图顶部可输入坐标设置导航点")

    -- 战斗工具
    local sep2 = configFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    sep2:SetPoint("TOPLEFT", navDesc, "BOTTOMLEFT", -26, -16)
    sep2:SetText("|cffffcc00【 战斗工具 】|r")

    local intCheck = CreateFrame("CheckButton", "YuxuanUtilsIntCheck", configFrame, "UICheckButtonTemplate")
    intCheck:SetPoint("TOPLEFT", sep2, "BOTTOMLEFT", 0, -8)
    intCheck.Text:SetText("打断提示（在聊天框显示队友的打断信息）")
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

    local intDesc = configFrame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    intDesc:SetPoint("TOPLEFT", intCheck, "BOTTOMLEFT", 26, -4)
    intDesc:SetText("队友成功打断技能时，在聊天框输出打断信息\n进入副本自动记录，离开时输出统计")

    -- 命令提示
    local cmdTitle = configFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    cmdTitle:SetPoint("TOPLEFT", intDesc, "BOTTOMLEFT", -26, -20)
    cmdTitle:SetText("|cffffcc00【 斜杠命令 】|r")

    local cmdDesc = configFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    cmdDesc:SetPoint("TOPLEFT", cmdTitle, "BOTTOMLEFT", 0, -8)
    cmdDesc:SetText("|cff00ff00/yxt|r - 打开工具箱窗口\n|cff00ff00/yxt dd|r - 开启/关闭打断提示")

    -- ============ 打断历史记录 ============
    local histTitle = configFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    histTitle:SetPoint("TOPLEFT", cmdDesc, "BOTTOMLEFT", 0, -20)
    histTitle:SetText("|cffffcc00【 打断历史记录 】|r")

    local clearBtn = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
    clearBtn:SetSize(80, 20)
    clearBtn:SetPoint("LEFT", histTitle, "RIGHT", 10, 0)
    clearBtn:SetText("清空记录")
    clearBtn:SetScript("OnClick", function()
        YuxuanUtilsDB.interruptHistory = {}
        addon.Msg("|cff888888历史记录已清空|r")
        if configFrame.RefreshHistory then configFrame:RefreshHistory() end
    end)

    local histBg = CreateFrame("Frame", nil, configFrame, "TooltipBackdropTemplate")
    histBg:SetPoint("TOPLEFT", histTitle, "BOTTOMLEFT", 0, -6)
    histBg:SetPoint("RIGHT", configFrame, "RIGHT", -16, 0)
    histBg:SetHeight(200)

    local histScroll = CreateFrame("ScrollFrame", "YuxuanUtilsHistScroll", histBg, "UIPanelScrollFrameTemplate")
    histScroll:SetPoint("TOPLEFT", 6, -6)
    histScroll:SetPoint("BOTTOMRIGHT", -24, 6)

    local histContent = CreateFrame("Frame", nil, histScroll)
    histContent:SetWidth(histBg:GetWidth() - 36)
    histContent:SetHeight(1)
    histScroll:SetScrollChild(histContent)

    function configFrame:RefreshHistory()
        for _, region in pairs({ histContent:GetRegions() }) do
            region:Hide()
            region:SetParent(nil)
        end

        local history = YuxuanUtilsDB.interruptHistory or {}
        if #history == 0 then
            local nodata = histContent:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
            nodata:SetPoint("TOPLEFT", 4, -4)
            nodata:SetText("暂无记录")
            histContent:SetHeight(20)
            return
        end

        local yOffset = -4
        for i = #history, 1, -1 do
            local record = history[i]

            local header = histContent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            header:SetPoint("TOPLEFT", 4, yOffset)
            local durationStr = ""
            if record.duration and record.duration > 0 then
                local mins = math.floor(record.duration / 60)
                local secs = math.floor(record.duration % 60)
                durationStr = string.format("  (%d分%d秒)", mins, secs)
            end
            header:SetText("|cffffcc00" ..
            (record.time or "") .. "|r - |cff00d1ff" .. (record.instance or "未知") .. "|r" .. durationStr)
            yOffset = yOffset - 14

            if record.stats then
                for _, stat in ipairs(record.stats) do
                    local line = histContent:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
                    line:SetPoint("TOPLEFT", 16, yOffset)
                    line:SetText("|cff00ff00" .. stat.name .. "|r：" .. stat.count .. " 次")
                    yOffset = yOffset - 12
                end
            end

            yOffset = yOffset - 6
        end

        histContent:SetHeight(math.abs(yOffset) + 10)
    end

    configFrame:SetScript("OnShow", function(self)
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
