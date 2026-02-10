------------------------------------------------------------
-- 导航模块：世界地图坐标输入框
------------------------------------------------------------
---@diagnostic disable: undefined-global
local addonName, addon = ...

local navBox

local function ParseCoords(text)
    if not text or text == "" then return nil, nil end
    text = text:gsub("，", ",")
    local x, y = text:match("([%d%.]+)%s*[,，]%s*([%d%.]+)")
    if not x then
        x, y = text:match("([%d%.]+)%s+([%d%.]+)")
    end
    if not x or not y then return nil, nil end
    x, y = tonumber(x), tonumber(y)
    if not x or not y then return nil, nil end
    if x > 1 or y > 1 then x, y = x / 100, y / 100 end
    if x < 0 or x > 1 or y < 0 or y > 1 then return nil, nil end
    return x, y
end

local function CreateNavBox()
    if navBox then return end
    if not WorldMapFrame then return end

    local titleContainer = WorldMapFrame.BorderFrame
        and WorldMapFrame.BorderFrame.TitleContainer
    local parent = titleContainer or WorldMapFrame
    local f = CreateFrame("Frame", "YuxuanUtilsNavFrame", parent)
    f:SetSize(200, 26)
    f:SetPoint("RIGHT", parent, "RIGHT", -160, 0)
    f:SetFrameLevel(parent:GetFrameLevel() + 10)

    local eb = CreateFrame("EditBox", "YuxuanUtilsNavEditBox", f, "InputBoxTemplate")
    eb:SetSize(180, 20)
    eb:SetPoint("CENTER")
    eb:SetAutoFocus(false)
    eb:SetFontObject(ChatFontNormal)

    eb.hintText = eb:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    eb.hintText:SetPoint("LEFT", eb, "LEFT", 6, 0)
    eb.hintText:SetText("输入坐标，如 45.2, 67.8")
    eb.hintText:SetTextColor(0.5, 0.5, 0.5)

    eb:SetScript("OnEditFocusGained", function(self)
        self.hintText:Hide()
    end)
    eb:SetScript("OnEditFocusLost", function(self)
        if self:GetText() == "" then self.hintText:Show() end
    end)
    eb:SetScript("OnTextChanged", function(self, userInput)
        if userInput and self:GetText() ~= "" then self.hintText:Hide() end
    end)
    eb:SetScript("OnEnterPressed", function(self)
        local text = self:GetText()
        local x, y = ParseCoords(text)
        if not x or not y then
            addon.Msg("|cffff3333坐标格式错误，请使用如 45.2, 67.8 的格式|r")
            return
        end
        local mapID = WorldMapFrame:GetMapID()
        if not mapID then mapID = C_Map.GetBestMapForUnit("player") end
        if not mapID then
            addon.Msg("|cffff3333无法获取当前地图|r"); return
        end
        if C_Map.CanSetUserWaypointOnMap and not C_Map.CanSetUserWaypointOnMap(mapID) then
            addon.Msg("|cffff3333当前地图不支持设置导航点|r"); return
        end
        local point = UiMapPoint.CreateFromCoordinates(mapID, x, y)
        C_Map.SetUserWaypoint(point)
        C_SuperTrack.SetSuperTrackedUserWaypoint(true)
        addon.Msg("|cff00ff00导航点已设置：|r" .. string.format("%.1f, %.1f", x * 100, y * 100))
        self:SetText(""); self:ClearFocus(); self.hintText:Show()
    end)
    eb:SetScript("OnEscapePressed", function(self)
        self:SetText(""); self:ClearFocus(); self.hintText:Show()
    end)

    navBox = f
end

local function UpdateNavBox()
    if not WorldMapFrame then return end
    if YuxuanUtilsDB.enableNavBox then
        CreateNavBox()
        if navBox and WorldMapFrame:IsShown() then navBox:Show() end
    else
        if navBox then navBox:Hide() end
    end
end

local function HookWorldMap()
    if not WorldMapFrame then return end
    if WorldMapFrame.YuxuanUtilsHooked then return end
    WorldMapFrame.YuxuanUtilsHooked = true
    WorldMapFrame:HookScript("OnShow", function() UpdateNavBox() end)
    WorldMapFrame:HookScript("OnHide", function() if navBox then navBox:Hide() end end)
end

------------------------------------------------------------
-- 导出接口
------------------------------------------------------------
addon.Navigation = {
    HookWorldMap = HookWorldMap,
    UpdateNavBox = UpdateNavBox,
}
