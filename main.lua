------------------------------------------------------------
-- 雨轩工具箱  V0.0.7
-- 核心初始化和事件管理
------------------------------------------------------------
---@diagnostic disable: undefined-global
local addonName, addon = ...

addon.VERSION = "0.0.7"
addon.playerGUID = nil
addon.playerName = nil

------------------------------------------------------------
-- SavedVariables 初始化
------------------------------------------------------------
YuxuanUtilsDB = YuxuanUtilsDB or {}

local function InitDefaults()
    if YuxuanUtilsDB.enableNavBox == nil then YuxuanUtilsDB.enableNavBox = true end
end

------------------------------------------------------------
-- 工具函数
------------------------------------------------------------
function addon.Msg(text)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00d1ff雨轩工具箱|r：" .. text)
end

------------------------------------------------------------
-- 初始化
------------------------------------------------------------
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

initFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        InitDefaults()
        addon.Options.Create()
    elseif event == "PLAYER_ENTERING_WORLD" then
        addon.playerGUID = UnitGUID("player")
        addon.playerName = UnitName("player")
        addon.Navigation.HookWorldMap()
        addon.Navigation.UpdateNavBox()

        DEFAULT_CHAT_FRAME:AddMessage(
            "|cff00d1ff雨轩工具箱|r：|cff00ff00已加载|r |cffffcc00V" .. addon.VERSION .. "|r"
        )

        self:UnregisterEvent("ADDON_LOADED")
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    end
end)
