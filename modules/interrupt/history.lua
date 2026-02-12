------------------------------------------------------------
-- 打断历史记录：按角色存储/读取
------------------------------------------------------------
---@diagnostic disable: undefined-global
local addonName, addon = ...

local MAX_HISTORY_PER_CHAR = 50

------------------------------------------------------------
-- 数据迁移：将旧的全局 interruptHistory 迁移为按角色分类
-- 旧格式: YuxuanUtilsDB.interruptHistory = { record1, record2, ... }
-- 新格式: YuxuanUtilsDB.interruptHistoryByChar = { ["角色-服务器"] = { record1, ... }, ... }
------------------------------------------------------------
local function MigrateOldHistory()
    if not YuxuanUtilsDB.interruptHistory then return end
    if YuxuanUtilsDB.interruptHistoryMigrated then return end

    local oldHistory = YuxuanUtilsDB.interruptHistory
    if #oldHistory > 0 then
        -- 旧数据归入当前角色名下
        local charKey = addon.GetCharacterKey()
        if not YuxuanUtilsDB.interruptHistoryByChar then
            YuxuanUtilsDB.interruptHistoryByChar = {}
        end
        YuxuanUtilsDB.interruptHistoryByChar[charKey] = oldHistory
    end

    -- 标记已迁移，但保留旧数据以防万一
    YuxuanUtilsDB.interruptHistoryMigrated = true
end

------------------------------------------------------------
-- 获取当前角色的历史记录
------------------------------------------------------------
local function GetHistory(charKey)
    charKey = charKey or addon.GetCharacterKey()
    if not YuxuanUtilsDB.interruptHistoryByChar then
        YuxuanUtilsDB.interruptHistoryByChar = {}
    end
    if not YuxuanUtilsDB.interruptHistoryByChar[charKey] then
        YuxuanUtilsDB.interruptHistoryByChar[charKey] = {}
    end
    return YuxuanUtilsDB.interruptHistoryByChar[charKey]
end

------------------------------------------------------------
-- 获取所有角色的 key 列表
------------------------------------------------------------
local function GetAllCharacterKeys()
    if not YuxuanUtilsDB.interruptHistoryByChar then return {} end
    local keys = {}
    for key, _ in pairs(YuxuanUtilsDB.interruptHistoryByChar) do
        table.insert(keys, key)
    end
    table.sort(keys)
    return keys
end

------------------------------------------------------------
-- 保存一条记录到当前角色
------------------------------------------------------------
local function SaveRecord(instanceName, instanceStartTime, instanceStats)
    if not instanceStats or not next(instanceStats) then return end

    MigrateOldHistory()

    local charKey = addon.GetCharacterKey()
    local history = GetHistory(charKey)

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

    table.insert(history, record)
    while #history > MAX_HISTORY_PER_CHAR do
        table.remove(history, 1)
    end
end

------------------------------------------------------------
-- 清空指定角色的历史记录
------------------------------------------------------------
local function ClearHistory(charKey)
    if charKey then
        if YuxuanUtilsDB.interruptHistoryByChar then
            YuxuanUtilsDB.interruptHistoryByChar[charKey] = {}
        end
    else
        -- 清空当前角色
        local key = addon.GetCharacterKey()
        if YuxuanUtilsDB.interruptHistoryByChar then
            YuxuanUtilsDB.interruptHistoryByChar[key] = {}
        end
    end
end

------------------------------------------------------------
-- 清空所有角色的历史记录
------------------------------------------------------------
local function ClearAllHistory()
    YuxuanUtilsDB.interruptHistoryByChar = {}
end

------------------------------------------------------------
-- 导出接口
------------------------------------------------------------
addon.InterruptHistory = {
    Migrate        = MigrateOldHistory,
    GetHistory     = GetHistory,
    GetAllCharKeys = GetAllCharacterKeys,
    Save           = SaveRecord,
    Clear          = ClearHistory,
    ClearAll       = ClearAllHistory,
}
