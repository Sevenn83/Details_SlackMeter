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

-- GLOBALS: SlackMeterLog

SM.debug = false
SM.CustomDisplay = {
    name = L["Avoidable Damage Taken"],
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
                    local damage, cnt = _G.Details_SlackMeter:GetRecord(CombatNumber, Actor:guid())
                    if damage > 0 or cnt > 0 then
                        CustomContainer:AddValue(Actor, damage)
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
            _, _, spells = _G.Details_SlackMeter:GetRecord(Combat:GetCombatNumber(), realCombat[1]:GetActor(Actor.nome):guid())
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
        local format_func = Details:GetCurrentToKFunction()
        if _G.Details_SlackMeter then
            local damage, cnt = _G.Details_SlackMeter:GetRecord(Combat:GetCombatNumber(), Actor.my_actor.serial)
            return "" .. format_func(_, damage) .. " (" .. cnt .. ")"
        end
        return ""
    ]],
}

SM.CustomDisplayAuras = {
    name = L["Avoidable Abilities Taken"],
    icon = 132311,
    source = false,
    attribute = false,
    spellid = false,
    target = false,
    author = "Sevenn",
    desc = L["Show how many avoidable abilities hit players."],
    script_version = 1,
    script = [[
        local Combat, CustomContainer, Instance = ...
        local total, top, amount = 0, 0, 0
        if _G.Details_SlackMeter then
            local CombatNumber = Combat:GetCombatNumber()
            local Container = Combat:GetContainer(DETAILS_ATTRIBUTE_MISC)
            for _, Actor in Container:ListActors() do
                if Actor:IsGroupPlayer() then
                    local cnt, _ = _G.Details_SlackMeter:GetAuraRecord(CombatNumber, Actor:guid())
                    if cnt > 0 then
                        CustomContainer:AddValue(Actor, cnt)
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
            _, spells = _G.Details_SlackMeter:GetAuraRecord(Combat:GetCombatNumber(), realCombat[1]:GetActor(Actor.nome):guid())
            for spellID, spelldata in pairs(spells) do
                tinsert(sortedList, {spellID, spelldata.cnt})
            end
            sort(sortedList, Details.Sort2)
            local format_func = Details:GetCurrentToKFunction()
            for _, tbl in ipairs(sortedList) do
                local spellID, cnt = unpack(tbl)
                local spellName, _, spellIcon = Details.GetSpellInfo(spellID)
                GameCooltip:AddLine(spellName, format_func(_, cnt))
                Details:AddTooltipBackgroundStatusbar()
                GameCooltip:AddIcon(spellIcon, 1, 1, _detalhes.tooltip.line_height, _detalhes.tooltip.line_height)
            end
        end
    ]],
    total_script = [[
        local value, top, total, Combat, Instance, Actor = ...
        local format_func = Details:GetCurrentToKFunction()
        if _G.Details_SlackMeter then
            local cnt, _ = _G.Details_SlackMeter:GetAuraRecord(Combat:GetCombatNumber(), Actor.my_actor.serial)
            return "" .. cnt
        end
        return ""
    ]],
}

-- List spell to track
SM.Spells = {
 	--- Mists of Turna Scithe
    [321968] = true,      --- Pollen-stupéfiant
    [323137] = true,      --- Pollen-stupéfiant (boss 1)
    [323250] = true,      --- Flaque d'anima (boss 1)
    [331721] = true,      --- Déluge de lances
    [340304] = true,      --- Sécrétions empoisonnées
    [340311] = true,      --- Bond écrasant
    [321828] = true,      --- Trois petits chats (boss 2)
    [336759] = true,      --- Balle aux prisonniers (boss 2)
    [321893] = true,      --- Explosion givrante (boss 2)
    [326022] = true,      --- Globule d'acide
    [322655] = true,      --- Expulsion d'acide (boss 3)
    [322654] = true,      --- Expulsion d'acide (boss 3)
    [322658] = true,      --- Expulsion d'acide (boss 3)
    [326281] = true,      --- Perte d'anima (boss 3)
    [326263] = true,      --- Perte d'anima (boss 3) 

    --- De Other Side
    [333250] = true,      --- Saccageur
    [333790] = true,      --- Masque enragé
    [334051] = true,      --- Eruption ténébreuse
    [328729] = true,      --- Lotus noir
    [332672] = true,      --- Tempete de lames
    [323118] = true,      --- Barrage de sang (boss)
    [331933] = true,      --- Détraqué
    [331398] = true,      --- Condensateur instable
    [332157] = true,      --- Accélération
    [324010] = true,      --- Eruption (boss)
    [323136] = true,      --- Tempête stellaire d'anima
    [345498] = true,      --- Tempête stellaire d'anima
    [340026] = true,      --- Gémissement de peine
    [324090] = true,      --- Onde explosive déplacée (boss)
    [334913] = true,      --- Maitre de la mort (boss)
    [325691] = true,      --- Effondrement cosmique (boss)

    --- Halls of atonement
    [325523] = true,       --- Poussée mortelle
    [325799] = true,       --- Tir rapide
    [346866] = true,       --- Souffle de pierre
    [326440] = true,       --- Secousse de vice
    [322945] = true,       --- Projection de débris (boss)
    [324044] = true,       --- Lumière viciée réfractée (boss)
    [323001] = true,       --- Éclats de verre (boss)
    [319592] = true,       --- Bond fracasse-pierre (boss)
    [319703] = true,       --- Torrent de sang (boss)
    [326891] = true,       --- Angoisse
    [323236] = true,       --- Souffrance déchaînée (boss)

    --- Theater of pain
    [320180] = true,       --- Spores nocives (boss)
    [323681] = true,       --- Sombre dévastation (boss)
    [339751] = true,       --- Charge fantôme (boss)
    [339550] = true,       --- Écho de bataille (boss)
    [323831] = true,       --- Emprise mortelle (boss)
    [317605] = true,       --- Tourbillon
    [337037] = true,       --- Lame tourbillonnante
    [342125] = true,       --- Bond Brutal
    [332708] = true,       --- Onde de choc
    [317231] = true,       --- Heurt écrasant (boss)
    [320729] = true,       --- Gigantesque fendoir (boss)
    [339415] = true,       --- Choc assourdissant (boss)
    [321041] = true,       --- Explosion abjecte
    [318406] = true,       --- Choc attendrisseur (boss)
    [330614] = true,       --- Éruption infâme (boss)
    [323406] = true,       --- Incision déchiquetée (boss)
    [333297] = true,       --- Vents de mort
    [331243] = true,       --- Pointes d'os
    [331224] = true,       --- Tempête d'os

    --- Plaguefall
    [330404] = true,       --- Frappe des ailes
    [328660] = true,       --- Gelée jaillissantes
    [330513] = true,       --- Champignon funeste
    [327233] = true,       --- Vomissement de peste
    [326242] = true,       --- Vague de gelée (boss)
    [328986] = true,       --- Détonation violente
    [318949] = true,       --- Renvoi putride
    [320519] = true,       --- Pointes déchirante
    [328501] = true,       --- Bombe de peste
    [319070] = true,       --- Bouillie corrosive
    [328662] = true,       --- Couche poisseuse
    [320576] = true,       --- Limon anéantissant
    [333808] = true,       --- Gelée envahissante (boss)
    [330026] = true,       --- Impulsion visqueuse (boss)
    [329217] = true,       --- Impulsion visqueuse (boss)
    [328395] = true,       --- Perce-venin
    [339195] = true,       --- Éruption de peste

    --- Sanguine Depths
    [334563] = true,       --- Piège volatil
    [320991] = true,       --- Elan retentissant
    [334921] = true,       --- Impact ombreux
    [321401] = true,       --- Explosion gloutonne
    [322429] = true,       --- Taillade tranchante
    [322418] = true,       --- Crevasse rocheuse
    [334615] = true,       --- Entaille circulaire
    [334377] = true,       --- Vélin explosif
    [322212] = true,       --- Méfiance croissante
    [323551] = true,       --- Résidu (boss)
    [328494] = true,       --- Anima touché par le vice (boss)
    [323821] = true,       --- Flou perçant (boss)

    --- Spires of ascension
    [317943] = true,       --- Balayage
    [327413] = true,       --- Poing rebelle
    [331251] = true,       --- Connexion profonde (boss)
    [324370] = true,       --- Barrage atténué (boss)
    [321009] = true,       --- Lance chargée (boss)
    [323786] = true,       --- Taillade rapide
    [323645] = true,       --- Bave touchée par l'antre
    [324141] = true,       --- Sombre trait (boss) 
    [324444] = true,       --- Munition empyréenne (Boss)
    [334625] = true,       --- Détonation abyssale (Boss)

    --- The Necrotic Wake
    [320596] = true,       --- Relent ecoeurant (boss)
    [320637] = true,       --- Gaz fétide (boss)
    [345625] = true,       --- Explosion de mort
    [324293] = true,       --- Cri rauque
    [324323] = true,       --- Enchainement atroce
    [324381] = true,       --- Faux glaciale
    [324391] = true,       --- Pointes glaciales
    [333489] = true,       --- Souffle nécrotique (boss)
    [333479] = true,       --- Crachat septique
    [333485] = true,       --- Nuage infectieux
    [320366] = true,       --- Ichor d’embaumement (boss)
    [327952] = true,       --- Crochet à viande (boss)
    [320784] = true,       --- Tempête de comètes (boss)
}

SM.SpellsNoTank = {
    --- Sanguine Depths
    [326997] = true,       --- Puissant balayage
}

SM.Auras = {
    --- Mists of Turna Scithe
    [340160] = true,      --- Souffle radieux

    --- De Other Side
    [326171] = true,      --- Destruction de la réalité (boss)

    --- Plaguefall
    [317898] = true,      --- Grésil aveuglant

    --- Spires of ascension
    [324205] = true,      --- Eclair aveuglant
}

SM.AurasNoTank = {
    --- De Other Side
    [333729] = true,      --- Garde-troll
}

-- Public APIs

function Engine:GetRecord(combatID, playerGUID)
    if SM.db[combatID] and SM.db[combatID][playerGUID] then

        return SM.db[combatID][playerGUID].sum or 0, SM.db[combatID][playerGUID].cnt or 0, SM.db[combatID][playerGUID].spells
    end
    return 0, 0, {}
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
        _G.DEFAULT_CHAT_FRAME:AddMessage("|cFF70B8FFDetails SlackMeter:|r " .. format(...))
    end
end

function SM:COMBAT_LOG_EVENT_UNFILTERED()
    local timestamp, eventType, hideCaster, srcGUID, srcName, srcFlags, srcFlags2, dstGUID, dstName, dstFlags, dstFlags2 = CombatLogGetCurrentEventInfo();

    local eventPrefix, eventSuffix = eventType:match("^(.-)_?([^_]*)$");

    if (eventPrefix:match("^SPELL") or eventPrefix:match("^RANGE")) and eventSuffix == "DAMAGE" then
		local spellId, spellName, spellSchool, sAmount, aOverkill, sSchool, sResisted, sBlocked, sAbsorbed, sCritical, sGlancing, sCrushing, sOffhand, _ = select(12,CombatLogGetCurrentEventInfo())
		SM:SpellDamage(timestamp, eventType, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellId, spellName, spellSchool, sAmount)
    elseif eventPrefix:match("^SWING") and eventSuffix == "DAMAGE" then
        local aAmount, aOverkill, aSchool, aResisted, aBlocked, aAbsorbed, aCritical, aGlancing, aCrushing, aOffhand, _ = select(12,CombatLogGetCurrentEventInfo())
        --- Not implemented
		SM:SwingDamage(timestamp, eventType, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, aAmount)
	elseif eventPrefix:match("^SPELL") and eventSuffix == "MISSED" then
		local spellId, spellName, spellSchool, missType, isOffHand, mAmount  = select(12,CombatLogGetCurrentEventInfo())
		if mAmount then
			SM:SpellDamage(timestamp, eventType, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellId, spellName, spellSchool, mAmount)
		end
	elseif eventType == "SPELL_AURA_APPLIED" then
		local spellId, spellName, spellSchool, auraType = select(12,CombatLogGetCurrentEventInfo())
		SM:AuraApply(timestamp, eventType, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellId, spellName, spellSchool, auraType)
	elseif eventType == "SPELL_AURA_APPLIED_DOSE" then
		local spellId, spellName, spellSchool, auraType, auraAmount = select(12,CombatLogGetCurrentEventInfo())
		SM:AuraApply(timestamp, eventType, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellId, spellName, spellSchool, auraType, auraAmount)
	end
end

function SM:RecordTarget(unitGUID, targetGUID)
    if not self.current then return end

    self:Debug("%s target %s in combat %s", unitGUID, targetGUID, self.current)

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

function SM:SpellDamage(timestamp, eventType, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellId, spellName, spellSchool, aAmount)
    local unitGUID = dstGUID
    if (SM.Spells[spellId] or (SM.SpellsNoTank[spellId] and UnitGroupRolesAssigned(dstName) ~= "TANK")) and UnitIsPlayer(dstName) then
        if not self.db[self.current] then self.db[self.current] = {} end
        if not self.db[self.current][unitGUID] then self.db[self.current][unitGUID] = {
            sum = 0,
            cnt = 0,
            spells = {},
            auras = {},
            auracnt = 0
        } end
        if not self.db[self.current][unitGUID].spells then
            self.db[self.current][unitGUID].spells = {}
        end
        if not self.db[self.current][unitGUID].spells[spellId] then self.db[self.current][unitGUID].spells[spellId] = {
            cnt = 0,
            sum = 0
        } end

        self:Debug("%s get hit by spell %s", unitGUID, self.current)

        self.db[self.current][unitGUID].sum = self.db[self.current][unitGUID].sum + aAmount
        self.db[self.current][unitGUID].cnt = self.db[self.current][unitGUID].cnt + 1
        self.db[self.current][unitGUID].spells[spellId].sum = self.db[self.current][unitGUID].spells[spellId].sum + aAmount
        self.db[self.current][unitGUID].spells[spellId].cnt = self.db[self.current][unitGUID].spells[spellId].cnt + 1

        -- update overall
        if not self.db[self.overall] then self.db[self.overall] = {} end
        if not self.db[self.overall][unitGUID] then self.db[self.overall][unitGUID] = {
            sum = 0,
            cnt = 0,
            spells = {},
            auras = {},
            auracnt = 0
        } end
        if not self.db[self.overall][unitGUID].spells then
            self.db[self.overall][unitGUID].spells = {}
        end
        if not self.db[self.overall][unitGUID].spells[spellId] then self.db[self.overall][unitGUID].spells[spellId] = {
            cnt = 0,
            sum = 0
        } end

        self.db[self.overall][unitGUID].sum = self.db[self.overall][unitGUID].sum + aAmount
        self.db[self.overall][unitGUID].cnt = self.db[self.overall][unitGUID].cnt + 1
        self.db[self.overall][unitGUID].spells[spellId].sum = self.db[self.overall][unitGUID].spells[spellId].sum + aAmount
        self.db[self.overall][unitGUID].spells[spellId].cnt = self.db[self.overall][unitGUID].spells[spellId].cnt + 1
	end
end

function SM:AuraApply(timestamp, eventType, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellId, spellName, spellSchool, auraType, auraAmount)
    local unitGUID = dstGUID
    if (SM.Auras[spellId] or (SM.AurasNoTank[spellId] and UnitGroupRolesAssigned(dstName) ~= "TANK")) and UnitIsPlayer(dstName)  then
        if not self.db[self.current] then self.db[self.current] = {} end
        if not self.db[self.current][unitGUID] then self.db[self.current][unitGUID] = {
            sum = 0,
            cnt = 0,
            spells = {},
            auras = {},
            auracnt = 0
        } end
        if not self.db[self.current][unitGUID].auras[spellId] then self.db[self.current][unitGUID].auras[spellId] = {
            cnt = 0
        } end

        self:Debug("%s get hit by aura %s", unitGUID, self.current)

        self.db[self.current][unitGUID].auracnt = self.db[self.current][unitGUID].auracnt + 1
        self.db[self.current][unitGUID].auras[spellId].cnt = self.db[self.current][unitGUID].auras[spellId].cnt + 1

        -- update overall
        if not self.db[self.overall] then self.db[self.overall] = {} end
        if not self.db[self.overall][unitGUID] then self.db[self.overall][unitGUID] = {
            sum = 0,
            cnt = 0,
            spells = {},
            auras = {},
            auracnt = 0
        } end
        if not self.db[self.overall][unitGUID].auras[spellId] then self.db[self.overall][unitGUID].auras[spellId] = {
            cnt = 0
        } end
        
        self.db[self.overall][unitGUID].auracnt = self.db[self.overall][unitGUID].auracnt + 1
        self.db[self.overall][unitGUID].auras[spellId].cnt = self.db[self.overall][unitGUID].auras[spellId].cnt + 1
	end
end

function SM:SwingDamage(timestamp, eventType, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, aAmount)
end

function SM:RecordHit(unitGUID, targetGUID)
    if not self.current then return end

    self:Debug("%s hit %s in combat %s", unitGUID, targetGUID, self.current)

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
            if not self.db[to][playerGUID] then
                self.db[to][playerGUID] = {
                    sum = 0,
                    cnt = 0,
                    spells = {},
                    auras = {},
                    auracnt = 0
                }
            end

            self.db[to][playerGUID].sum = self.db[to][playerGUID].sum + (tbl.sum or 0)
            self.db[to][playerGUID].cnt = self.db[to][playerGUID].cnt + (tbl.cnt or 0)

            self.db[to][playerGUID].auracnt = self.db[to][playerGUID].auracnt + (tbl.auracnt or 0)


            for spellId, spelltbl in pairs(tbl.spells) do
                
                if not self.db[to][playerGUID].spells[spellId] then self.db[to][playerGUID].spells[spellId] = {
                    cnt = 0,
                    sum = 0
                } end
                self.db[to][playerGUID].spells[spellId].cnt = self.db[to][playerGUID].spells[spellId].cnt + spelltbl.cnt
                self.db[to][playerGUID].spells[spellId].sum = self.db[to][playerGUID].spells[spellId].sum + spelltbl.sum
            end

            for spellId, spelltbl in pairs(tbl.auras) do
                
                if not self.db[to][playerGUID].auras[spellId] then self.db[to][playerGUID].auras[spellId] = {
                    cnt = 0
                } end
                self.db[to][playerGUID].auras[spellId].cnt = self.db[to][playerGUID].auras[spellId].cnt + spelltbl.cnt
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

        if not SM.current or not SM.db[SM.current] then return end

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
    Details:InstallCustomObject(self.CustomDisplayAuras)
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
