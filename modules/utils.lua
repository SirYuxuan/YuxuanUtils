------------------------------------------------------------
-- 通用工具模块：颜色表、频道判断等共用函数
------------------------------------------------------------
---@diagnostic disable: undefined-global
local addonName, addon = ...

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

--- 根据角色名获取职业颜色十六进制字符串
function addon.GetClassColor(name)
    if not name then return "a0a0a0" end

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

    return "a0a0a0"
end

--- 获取当前适合的聊天频道
function addon.GetCurrentChatChannel()
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE_CHAT"
    elseif IsInRaid() then
        return "RAID"
    elseif IsInGroup() then
        return "PARTY"
    else
        return "SAY"
    end
end

--- 获取当前队伍成员列表
function addon.GetGroupMembers()
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

--- 获取当前角色的唯一标识（角色名-服务器名）
function addon.GetCharacterKey()
    local name = UnitName("player")
    local realm = GetNormalizedRealmName and GetNormalizedRealmName() or GetRealmName() or ""
    return (name or "Unknown") .. "-" .. realm
end
