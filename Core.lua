local addon, Engine = ...
local SM = LibStub('AceAddon-3.0'):NewAddon(addon, 'AceEvent-3.0', 'AceHook-3.0')
local L = Engine.L

Engine.Core = SM
_G[addon] = Engine

-- Lua functions
local _G = _G
local format, ipairs, pairs, select, strsplit, tonumber, type = format, ipairs, pairs, select, strsplit, tonumber, type
local bit_band = bit.band

-- WoW API / Variables
local C_ChallengeMode_GetActiveKeystoneInfo = C_ChallengeMode.GetActiveKeystoneInfo
local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo
local CreateFrame = CreateFrame
local UnitGUID = UnitGUID

local tContains = tContains

local Details = _G.Details

-- GLOBALS: SlackMeter

SM.debug = true
EO.CustomDisplay = {
    name = L["EAvoidable Damage Taken"],
    icon = 3565723,
    source = false,
    attribute = false,
    spellid = false,
    target = false,
    author = "Sevenn",
    desc = L["Show how much avoidable damage was taken."],
    script_version = 1,
    script = [[
        local Combat, CustomContainer, Instance = ...
        local total, top, amount = 0, 0, 0

        if _G.Details_SlackMeter then
            local CombatNumber = Combat:GetCombatNumber()
            local Container = Combat:GetContainer(DETAILS_ATTRIBUTE_MISC)
            for _, Actor in Container:ListActors() do
                if Actor:IsGroupPlayer() then
                    -- we only record the players in party
                    local target, hit = _G.Details_SlackMeter:GetRecord(CombatNumber, Actor:guid())
                    if target > 0 or hit > 0 then
                        CustomContainer:AddValue(Actor, hit)
                    end
                end
            end

            total, top = CustomContainer:GetTotalAndHighestValue()
            amount = CustomContainer:GetNumActors()
        end

        return total, top, amount
    ]],
    tooltip = [[
        local Actor, Combat, Instance = ...
        local GameCooltip = GameCooltip

        if _G.Details_SlackMeter then
            local realCombat
            for i = -1, 25 do
                local current = Details:GetCombat(i)
                if current and current:GetCombatNumber() == Combat.combat_counter then
                    realCombat = current
                    break
                end
            end

            if not realCombat then return end

            local sortedList = {}

            _, _, spells = _G.Details_Elitism:GetRecord(Combat:GetCombatNumber(), realCombat[1]:GetActor(Actor.nome):guid())
            for spellID, spelldata in pairs(spells) do
                tinsert(sortedList, {spellID, spelldata.sum})
            end

            sort(sortedList, Details.Sort2)

            local format_func = Details:GetCurrentToKFunction()
            for _, tbl in ipairs(sortedList) do
                local spellID, amount = unpack(tbl)
                local spellName, _, spellIcon = Details.GetSpellInfo(spellID)

                GameCooltip:AddLine(spellName, format_func(_, amount))
                Details:AddTooltipBackgroundStatusbar()
                GameCooltip:AddIcon(spellIcon, 1, 1, _detalhes.tooltip.line_height, _detalhes.tooltip.line_height)
            end
        end
    ]],
    total_script = [[
        local value, top, total, Combat, Instance, Actor = ...

        if _G.Details_SlackMeter then
            local damage, cnt = _G.Details_SlackMeter:GetRecord(Combat:GetCombatNumber(), Actor.my_actor.serial)
            return "" .. format_func(_, damage) .. " (" .. cnt .. ")"
        end
        return ""
    ]],
}

-- Public APIs

function Engine:GetRecord(combatID, playerGUID)
    if SM.db[combatID] and SM.db[combatID][playerGUID] then
        return SM.db[combatID][playerGUID].target or 0, SM.db[combatID][playerGUID].hit or 0
    end
    return 0, 0
end

function Engine:GetAuraRecord(combatID, playerGUID)
    if SM.db[combatID] and SM.db[combatID][playerGUID] then
        return SM.db[combatID][playerGUID].auracnt or 0, SM.db[combatID][playerGUID].auras
    end
    return 0, {}
end

function Engine:GetDisplayText(combatID, playerGUID)
    if SM.db[combatID] and SM.db[combatID][playerGUID] then
        return L["Target: "] .. (SM.db[combatID][playerGUID].target or 0) .. " " .. L["Hit: "] .. (SM.db[combatID][playerGUID].hit or 0)
    end
    return L["Target: "] .. "0 " .. L["Hit: "] .. "0"
end

function Engine:FormatDisplayText(target, hit)
    return L["Target: "] .. (target or 0) .. " " .. L["Hit: "] .. (hit or 0)
end

-- Private Functions

function SM:Debug(...)
    if self.debug then
        _G.DEFAULT_CHAT_FRAME:AddMessage("|cFF70B8FFDetails Explosive Orbs:|r " .. format(...))
    end
end

function SM:COMBAT_LOG_EVENT_UNFILTERED()
    local _, subEvent, _, sourceGUID, sourceName, sourceFlag, _, destGUID = CombatLogGetCurrentEventInfo()
    if (
        subEvent == 'SPELL_DAMAGE' or subEvent == 'RANGE_DAMAGE' or subEvent == 'SWING_DAMAGE' or
        subEvent == 'SPELL_PERIODIC_DAMAGE' or subEvent == 'SPELL_BUILDING_DAMAGE'
    ) then
        local npcID = select(6, strsplit('-', destGUID))
        if npcID == self.orbID then
            if bit_band(sourceFlag, COMBATLOG_OBJECT_TYPE_PET) > 0 then
                -- source is pet, don't track guardian which is automaton
                local Combat = Details:GetCombat(0)
                if Combat then
                    local Container = Combat:GetContainer(_G.DETAILS_ATTRIBUTE_DAMAGE)
                    local ownerActor = select(2, Container:PegarCombatente(sourceGUID, sourceName, sourceFlag, true))
                    if ownerActor then
                        -- Details implements two cache method of pet and its owner,
                        -- one is in parser which is shared inside parser (damage_cache_petsOwners),
                        -- it will be wiped in :ClearParserCache, but I have no idea when,
                        -- the other is in container,
                        -- which :PegarCombatente will try to fetch owner from it first,
                        -- so in this case, simply call :PegarCombatente and use its cache,
                        -- and no need to implement myself like parser
                        sourceGUID = ownerActor:guid()
                    end
                end
            end
            EO:RecordHit(sourceGUID, destGUID)
        end
    end
end

function SM:RecordTarget(unitGUID, targetGUID)
    if not self.current then return end

    -- self:Debug("%s target %s in combat %s", unitGUID, targetGUID, self.current)

    if not self.db[self.current] then self.db[self.current] = {} end
    if not self.db[self.current][unitGUID] then self.db[self.current][unitGUID] = {} end
    if not self.db[self.current][unitGUID][targetGUID] then self.db[self.current][unitGUID][targetGUID] = 0 end

    if self.db[self.current][unitGUID][targetGUID] ~= 1 and self.db[self.current][unitGUID][targetGUID] ~= 3 then
        self.db[self.current][unitGUID][targetGUID] = self.db[self.current][unitGUID][targetGUID] + 1
        self.db[self.current][unitGUID].target = (self.db[self.current][unitGUID].target or 0) + 1

        -- update overall
        if not self.db[self.overall] then self.db[self.overall] = {} end
        if not self.db[self.overall][unitGUID] then self.db[self.overall][unitGUID] = {} end

        self.db[self.overall][unitGUID].target = (self.db[self.overall][unitGUID].target or 0) + 1
    end
end

function SM:RecordHit(unitGUID, targetGUID)
    if not self.current then return end

    -- self:Debug("%s hit %s in combat %s", unitGUID, targetGUID, self.current)

    if not self.db[self.current] then self.db[self.current] = {} end
    if not self.db[self.current][unitGUID] then self.db[self.current][unitGUID] = {} end
    if not self.db[self.current][unitGUID][targetGUID] then self.db[self.current][unitGUID][targetGUID] = 0 end

    if self.db[self.current][unitGUID][targetGUID] ~= 2 and self.db[self.current][unitGUID][targetGUID] ~= 3 then
        self.db[self.current][unitGUID][targetGUID] = self.db[self.current][unitGUID][targetGUID] + 2
        self.db[self.current][unitGUID].hit = (self.db[self.current][unitGUID].hit or 0) + 1

        -- update overall
        if not self.db[self.overall] then self.db[self.overall] = {} end
        if not self.db[self.overall][unitGUID] then self.db[self.overall][unitGUID] = {} end

        self.db[self.overall][unitGUID].hit = (self.db[self.overall][unitGUID].hit or 0) + 1
    end
end

function SM:InitDataCollection()
    self:RegisterEvent('COMBAT_LOG_EVENT_UNFILTERED')
end

function SM:MergeCombat(to, from)
    if self.db[from] then
        self:Debug("Merging combat %s into %s", from, to)
        if not self.db[to] then self.db[to] = {} end
        for playerGUID, tbl in pairs(self.db[from]) do

            --- todo : work here

            if type(tbl) == 'table' then
                if not self.db[to][playerGUID] then
                    self.db[to][playerGUID] = {}
                end
                self.db[to][playerGUID].target = (self.db[to][playerGUID].target or 0) + (tbl.target or 0)
                self.db[to][playerGUID].hit = (self.db[to][playerGUID].hit or 0) + (tbl.hit or 0)
            end
        end
    end
end

function SM:MergeSegmentsOnEnd()
    self:Debug("on Details MergeSegmentsOnEnd")

    -- at the end of a Mythic+ Dungeon
    -- Details Combat:
    -- n+1 - other combat
    -- n   - first combat
    -- ...
    -- 3   - combat (likely final boss trash)
    -- 2   - combat (likely final boss)
    -- 1   - overall combat

    local overallCombat = Details:GetCombat(1)
    local overall = overallCombat:GetCombatNumber()
    local runID = select(2, overallCombat:IsMythicDungeon())
    for i = 2, 25 do
        local combat = Details:GetCombat(i)
        if not combat then break end

        local combatRunID = select(2, combat:IsMythicDungeon())
        if not combatRunID or combatRunID ~= runID then break end

        self:MergeCombat(overall, combat:GetCombatNumber())
    end

    self:CleanDiscardCombat()
end

function SM:MergeTrashCleanup()
    self:Debug("on Details MergeTrashCleanup")

    -- after boss fight
    -- Details Combat:
    -- 3   - other combat
    -- 2   - boss trash combat
    -- 1   - boss combat

    local runID = select(2, Details:GetCombat(1):IsMythicDungeon())

    local baseCombat = Details:GetCombat(2)
    -- killed boss before any combat
    if not baseCombat then return end

    local baseCombatRunID = select(2, baseCombat:IsMythicDungeon())
    -- killed boss before any trash combats
    if not baseCombatRunID or baseCombatRunID ~= runID then return end

    local base = baseCombat:GetCombatNumber()
    local prevCombat = Details:GetCombat(3)
    if prevCombat then
        local prev = prevCombat:GetCombatNumber()
        for i = prev + 1, base - 1 do
            if i ~= self.overall then
                self:MergeCombat(base, i)
            end
        end
    else
        -- fail to find other combat, merge all combat with same run id in database
        for combatID, data in pairs(self.db) do
            if data.runID and data.runID == runID then
                self:MergeCombat(base, combatID)
            end
        end
    end

    self:CleanDiscardCombat()
end

function SM:MergeRemainingTrashAfterAllBossesDone()
    self:Debug("on Details MergeRemainingTrashAfterAllBossesDone")

    -- before the end of a Mythic+ Dungeon, and finish all trash after final boss fight
    -- Details Combat:
    -- 3   - prev boss combat
    -- 2   - final boss trash combat
    -- 1   - final boss combat
    -- current combat is removed

    local prevTrash = Details:GetCombat(2)
    if prevTrash then
        local prev = prevTrash:GetCombatNumber()
        self:MergeCombat(prev, self.current)
    end

    self:CleanDiscardCombat()
end

function SM:ResetOverall()
    self:Debug("on Details Reset Overall (Details.historico.resetar_overall)")

    if self.overall and self.db[self.overall] then
        self.db[self.overall] = nil
    end
    self.overall = Details:GetCombat(-1):GetCombatNumber()
end

function SM:CleanDiscardCombat()
    local remain = {}
    remain[self.overall] = true

    for i = 1, 25 do
        local combat = Details:GetCombat(i)
        if not combat then break end

        remain[combat:GetCombatNumber()] = true
    end

    for key in pairs(self.db) do
        if not remain[key] then
            self.db[key] = nil
        end
    end
end

function SM:OnDetailsEvent(event, combat)
    -- self here is not SM, this function is called from SM.EventListener
    if event == 'COMBAT_PLAYER_ENTER' then
        SM.current = combat:GetCombatNumber()
        SM:Debug("COMBAT_PLAYER_ENTER: %s", SM.current)
    elseif event == 'COMBAT_PLAYER_LEAVE' then
        SM.current = combat:GetCombatNumber()
        SM:Debug("COMBAT_PLAYER_LEAVE: %s", SM.current)

        if not SM.current or not SM.db[EO.current] then return end

    elseif event == 'DETAILS_DATA_RESET' then
        SM:Debug("DETAILS_DATA_RESET")
        self.overall = Details:GetCombat(-1):GetCombatNumber()
        SM:CleanDiscardCombat()
    end
end

function SM:LoadHooks()
    self:SecureHook(_G.DetailsMythicPlusFrame, 'MergeSegmentsOnEnd')
    self:SecureHook(_G.DetailsMythicPlusFrame, 'MergeTrashCleanup')
    self:SecureHook(_G.DetailsMythicPlusFrame, 'MergeRemainingTrashAfterAllBossesDone')

    self:SecureHook(Details.historico, 'resetar_overall', 'ResetOverall')
    self.overall = Details:GetCombat(-1):GetCombatNumber()

    self.EventListener = Details:CreateEventListener()
    self.EventListener:RegisterEvent('COMBAT_PLAYER_ENTER')
    self.EventListener:RegisterEvent('COMBAT_PLAYER_LEAVE')
    self.EventListener:RegisterEvent('DETAILS_DATA_RESET')
    self.EventListener.OnDetailsEvent = self.OnDetailsEvent

    Details:InstallCustomObject(self.CustomDisplay)
    Details:InstallCustomObject(self.CustomDisplayAura)
    self:CleanDiscardCombat()
end

function SM:OnInitialize()
    -- load database
    self.db = SlackMeterLog or {}
    SlackMeterLog = self.db

    self:RegisterEvent('PLAYER_ENTERING_WORLD', 'InitDataCollection')
    self:RegisterEvent('CHALLENGE_MODE_START', 'InitDataCollection')

    self:SecureHook(Details, 'StartMeUp', 'LoadHooks')
end
