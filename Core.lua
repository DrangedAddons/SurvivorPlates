-- SurvivorPlates: size, stacking and target options for SurvivorsDragonUi's nameplates.
-- SurvivorsDragonUi draws each enemy plate as a skin frame (data.style.visual) centred
-- on the native plate's health bar. The game positions the native plates, and already
-- spreads them so their 32 px frames never overlap ("Spread"). This addon resizes the skin
-- and, in Collapse mode, shows one plate per pile of mobs with a count.

SurvivorPlates = {}
local SP = SurvivorPlates
-- This pass's piles of 2+, plus bosses and guardians (every pile, singles too, while world
-- plates are hidden):
-- { id (the pile's first plate, stable while it lives), name, count, health (0-1 average),
--   hp (the members' bar values added up), target, boss (nil, "boss", "final" or "guardian") }
SP.pileList = {}
SP.version = GetAddOnMetadata and GetAddOnMetadata("SurvivorPlates", "Version") or "?"

SP.defaults = {
    -- Stacking
    stackMode = "spread", -- "spread" (the game's own layout) or "collapse" (one plate per pile)
    stackOverlap = 30, -- lower lets a pile pick up same-mob plates from further to the side
    -- Size
    width = 100,
    height = 10,
    scale = 1,
    fontSize = 9,
    namePos = "above", -- "above", "inside" or "hidden"
    healthText = "none", -- "none", "percent", "current" or "both"
    -- Target and priority
    targetScale = 1.2,
    targetHighlight = true,
    fadeOthers = false,
    otherAlpha = 0.6,
    bossScale = 1.3,
    -- Pile bars: a panel listing each collapsed pile as a bar with its count
    pileBars = true,
    pileBarsLocked = true,
    pileBarsMax = 8,
    pileBarsScale = 1,
    pileBarsX = nil, -- saved panel position (screen offset from bottom-left); nil = default
    pileBarsY = nil,
    pileBarsAnchor = "free", -- "free" (where you drag it), "player" (above your character) or "below"
    pileBarsHeight = 80, -- "player": the stack's bottom edge, px above the middle of the screen (+ is up)
    pileBarsBelowY = -80, -- "below": the stack's top edge, px from the middle of the screen (+ is up)
    pileBarsGrow = "up", -- "free": "up" (fixed bottom, most health at the bottom) or "down" (the inverse)
    pileDamageColors = true, -- colour each damage chunk by the class of whoever dealt most of it
    worldPlates = true, -- false: hide every nameplate above the mobs, in any mode
    -- Minimap button (Reset to defaults leaves these alone)
    minimapButton = true,
    minimapAngle = 225, -- degrees around the minimap, 0 = right
}
local KEEP_ON_RESET = { minimapButton = true, minimapAngle = true, pileBarsX = true, pileBarsY = true }

local CHOICES = {
    stackMode = { "spread", "collapse" },
    pileBarsAnchor = { "free", "player", "below" },
    pileBarsGrow = { "up", "down" },
    namePos = { "above", "inside", "hidden" },
    healthText = { "none", "percent", "current", "both" },
}
SP.choices = CHOICES

local db -- this character's settings
local plates = {} -- plate -> data (SurvivorsDragonUi's per-plate table)
-- Collapse mode: plates hidden inside a pile, and the pile size shown on its visible plate.
local pileHidden, pileCount = {}, {}
local installed, warned = false, false
local BASE_TEXT_OFFSET = 2.5 -- SurvivorsDragonUi's name gap above the bar

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffffd100SurvivorPlates:|r " .. msg)
end
SP.Print = Print

local function CharKey()
    local realm = GetRealmName and GetRealmName() or GetCVar("realmName") or "?"
    return (UnitName("player") or "?") .. " - " .. realm
end

local function LoadSettings()
    SurvivorPlatesDB = SurvivorPlatesDB or {}
    SurvivorPlatesDB.chars = SurvivorPlatesDB.chars or {}
    local key = CharKey()
    SurvivorPlatesDB.chars[key] = SurvivorPlatesDB.chars[key] or {}
    db = SurvivorPlatesDB.chars[key]
    for k, v in pairs(SP.defaults) do
        if db[k] == nil then db[k] = v end
    end
    db.combatOnly = nil -- removed in 0.14.2
    -- Drop a choice value an older version saved that this one doesn't know.
    for k, list in pairs(CHOICES) do
        local ok = false
        for i = 1, table.getn(list) do
            if list[i] == db[k] then ok = true end
        end
        if not ok then db[k] = SP.defaults[k] end
    end
end

function SP.Get(key) return db[key] end

-- False until this character's settings have loaded (ADDON_LOADED).
function SP.Ready() return db ~= nil end

function SP.Set(key, value)
    db[key] = value
    SP.RestyleAll()
end

-- Saves without restyling every plate, for values nothing on a plate depends on.
function SP.SetQuiet(key, value) db[key] = value end

function SP.Reset()
    for k, v in pairs(SP.defaults) do
        if not KEEP_ON_RESET[k] then db[k] = v end
    end
    SP.RestyleAll()
end

local function SetFont(label, size)
    local T = DFRL and DFRL.tools
    if T and T.SetFont then
        T.SetFont(label, size, "OUTLINE")
    else
        label:SetFont("Fonts\\FRIZQT__.TTF", size, "OUTLINE")
    end
end

-- Bosses, final bosses and guardians: name -> kind ("boss", "final" or "guardian"), from
-- the game's unit list.
local bigNames = {}
local function RefreshBigNames()
    for k in pairs(bigNames) do bigNames[k] = nil end
    if type(AZS_UNITS) ~= "table" then return end
    for i = 1, table.getn(AZS_UNITS) do
        local u = AZS_UNITS[i]
        if u.kind == "boss" or u.kind == "final" or u.kind == "guardian" then bigNames[u.name] = u.kind end
    end
end

local function PlateName(data)
    return data.nameRegion and data.nameRegion:GetText()
end

-- The game fades every plate but the target's when you have one. A matching name alone
-- would also light up every other mob of the same kind, so both have to agree.
local function IsTarget(plate, data)
    if not UnitExists("target") then return false end
    local name = PlateName(data)
    return name ~= nil and name == UnitName("target") and plate:GetAlpha() > 0.99
end

local function CreateExtras(data)
    local style = data.style
    if style.sp then return style.sp end
    local sp = {}
    local overlay = style.name:GetParent()
    sp.health = overlay:CreateFontString(nil, "OVERLAY")
    sp.health:SetJustifyH("RIGHT")
    sp.health:SetPoint("RIGHT", style.health, "RIGHT", -2, 0)
    sp.health:SetTextColor(1, 1, 1, 1)
    -- Collapse mode's pile size, just right of the bar.
    sp.count = overlay:CreateFontString(nil, "OVERLAY")
    sp.count:SetJustifyH("LEFT")
    sp.count:SetPoint("LEFT", style.health, "RIGHT", 3, 0)
    sp.count:SetTextColor(1, 0.82, 0, 1)
    -- Target highlight: four 1px gold edges just outside the bar's black border.
    sp.edges = {}
    for i = 1, 4 do
        local t = style.visual:CreateTexture(nil, "OVERLAY")
        t:SetTexture("Interface\\Buttons\\WHITE8X8")
        t:SetVertexColor(1, 0.82, 0, 1)
        t:Hide()
        sp.edges[i] = t
    end
    local v = style.visual
    sp.edges[1]:SetPoint("BOTTOMLEFT", v, "TOPLEFT", -1, 0)
    sp.edges[1]:SetPoint("BOTTOMRIGHT", v, "TOPRIGHT", 1, 0)
    sp.edges[1]:SetHeight(1)
    sp.edges[2]:SetPoint("TOPLEFT", v, "BOTTOMLEFT", -1, 0)
    sp.edges[2]:SetPoint("TOPRIGHT", v, "BOTTOMRIGHT", 1, 0)
    sp.edges[2]:SetHeight(1)
    sp.edges[3]:SetPoint("TOPRIGHT", v, "TOPLEFT", 0, 0)
    sp.edges[3]:SetPoint("BOTTOMRIGHT", v, "BOTTOMLEFT", 0, 0)
    sp.edges[3]:SetWidth(1)
    sp.edges[4]:SetPoint("TOPLEFT", v, "TOPRIGHT", 0, 0)
    sp.edges[4]:SetPoint("BOTTOMLEFT", v, "BOTTOMRIGHT", 0, 0)
    sp.edges[4]:SetWidth(1)
    style.sp = sp
    return sp
end

-- Size, fonts and name placement: only redone when a setting changes.
local function ApplyLayout(data)
    local style = data.style
    if not style then return end
    local sp = CreateExtras(data)
    style.visual:SetWidth(db.width)
    style.visual:SetHeight(db.height)
    SetFont(style.name, db.fontSize)
    SetFont(sp.health, db.fontSize)
    SetFont(sp.count, db.fontSize + 2)
    style.name:ClearAllPoints()
    if db.namePos == "inside" then
        style.name:SetPoint("CENTER", style.health, "CENTER", 0, 0)
        style.name:SetJustifyV("MIDDLE")
        style.name:SetWidth(db.width - 4)
        style.name:SetHeight(db.fontSize + 2)
        style.name:Show()
    else
        style.name:SetPoint("BOTTOM", style.health, "TOP", 0.5, -BASE_TEXT_OFFSET)
        style.name:SetJustifyV("BOTTOM")
        style.name:SetWidth(db.width * 2)
        style.name:SetHeight(db.fontSize + 1)
        if db.namePos == "hidden" then style.name:Hide() else style.name:Show() end
    end
    sp.layoutDone = true
end

local function HealthString(data)
    local mode = db.healthText
    if mode == "none" then return "" end
    local low, high = data.bar:GetMinMaxValues()
    local value = data.bar:GetValue() or 0
    local span = (high or 0) - (low or 0)
    local pct = span > 0 and math.floor((value - low) / span * 100 + 0.5) or 0
    -- Vanilla plates usually report health as 0-100. Then "current" is the percent too.
    if mode == "percent" or (high == 100 and low == 0) then return pct .. "%" end
    local function Short(n)
        if n >= 1000000 then return string.format("%.1fm", n / 1000000) end
        if n >= 10000 then return string.format("%.0fk", n / 1000) end
        return tostring(math.floor(n))
    end
    if mode == "current" then return Short(value) end
    return Short(value) .. " / " .. Short(high)
end

-- Per-refresh look: scale, alpha, target edge, health text.
local function ApplyLive(plate, data)
    local style = data.style
    local sp = style.sp
    if not sp or not sp.layoutDone then
        ApplyLayout(data)
        sp = style.sp
    end
    local isTarget = IsTarget(plate, data)
    local scale = db.scale
    if bigNames[PlateName(data) or ""] then scale = scale * db.bossScale end
    if isTarget then scale = scale * db.targetScale end
    if math.abs(style.visual:GetScale() - scale) > 0.001 then style.visual:SetScale(scale) end

    local alpha = 1
    if db.fadeOthers and UnitExists("target") and not isTarget then alpha = db.otherAlpha end
    if pileHidden[plate] or not db.worldPlates then alpha = 0 end
    if math.abs(style.visual:GetAlpha() - alpha) > 0.001 then style.visual:SetAlpha(alpha) end

    local showEdge = isTarget and db.targetHighlight
    if sp.edgeShown ~= showEdge then
        for i = 1, 4 do
            if showEdge then sp.edges[i]:Show() else sp.edges[i]:Hide() end
        end
        sp.edgeShown = showEdge
    end
    local text = HealthString(data)
    if sp.health:GetText() ~= text then sp.health:SetText(text) end
    local count = pileCount[plate] and ("x" .. pileCount[plate]) or ""
    if sp.count:GetText() ~= count then sp.count:SetText(count) end
end

function SP.RestyleAll()
    for plate, data in pairs(plates) do
        if data.style and data.style.sp then data.style.sp.layoutDone = false end
    end
    if SP.UpdateMinimapButton then SP.UpdateMinimapButton() end
    if SP.UpdatePileBars then SP.UpdatePileBars() end
    if SP.RefreshOptions then SP.RefreshOptions() end
end

-- Collapsing ---------------------------------------------------------------------------

local live, byPlate, order, memberName = {}, {}, {}, {}

-- Collapse mode. Mobs in this game never unpile once they've piled up, so piles are built
-- to grab plates easily and practically never let go:
--  * A free plate joins a pile of mobs with the same name when it's within PILE_ROWS of the
--    game's plate rows of any member, and sideways within (1.5 - overlap) plate widths of it
--    (1.2 widths at the default 30%). Bosses and guardians never pile.
--  * Any plate that touches a pile member on screen joins it straight away, whatever the
--    mob, and piles that touch each other merge.
--  * Two piles of the same mob that come within that reach of each other merge.
--  * A member only leaves when its mob dies. A plate the game hides for a while (off screen,
--    out of range) keeps its place for GHOST_TIME and rejoins when it comes back.
--  * Each pile shows one plate (the target, if it's in the pile, else the oldest member)
--    with a count; the rest are hidden and can't be clicked.
local PILE_ROWS, GHOST_TIME = 5, 60
local lastSeen = {}

local function PileReach(e, m, share)
    return math.abs(e.x - m.x) <= (1.5 - share) * math.max(e.w, m.w)
        and math.abs(e.y - m.y) <= PILE_ROWS * math.max(e.row, m.row)
end

-- Two skins touching or overlapping on screen (2 px of slack).
local function Touching(e, m)
    return math.abs(e.x - m.x) <= (e.w + m.w) * 0.5 + 2 and math.abs(e.y - m.y) <= (e.h + m.h) * 0.5 + 2
end

local function Joins(e, m, sameMob, share)
    return Touching(e, m) or (sameMob and PileReach(e, m, share))
end

local function ComputePiles(n, share)
    local now = GetTime()
    -- With the world plates hidden the pile bars list single mobs too, so nothing goes missing.
    local hideAll = not db.worldPlates
    local collapse = db.stackMode == "collapse"
    local piles = {}
    -- Last pass's piles. `ghosts` are members the game has hidden for now.
    for _, list in pairs(order) do
        local pile = { live = {}, ghosts = {} }
        for i = 1, table.getn(list) do
            local plate = list[i]
            local e = byPlate[plate]
            if e and e.name == memberName[plate] and not e.taken then
                table.insert(pile.live, e)
                e.taken = true
            elseif not e and now - (lastSeen[plate] or 0) < GHOST_TIME then
                table.insert(pile.ghosts, plate)
            end
            -- Anything else is a frame the game reused for another mob: it starts afresh.
        end
        pile.name = memberName[list[1]]
        if table.getn(pile.live) + table.getn(pile.ghosts) > 0 then table.insert(piles, pile) end
    end
    -- A hidden plate coming back with the same mob slots back into its pile above. Everything
    -- else that's free, bottom-up: join the nearest pile of the same mob, or start one.
    table.sort(live, function(a, b) return a.y < b.y end)
    for i = 1, n do
        local e = live[i]
        if not e.taken then
            local best, bestD
            if e.name and not bigNames[e.name] then
                for j = 1, table.getn(piles) do
                    local pile = piles[j]
                    if not bigNames[pile.name or ""] then
                        local sameMob = pile.name == e.name
                        for k = 1, table.getn(pile.live) do
                            local m = pile.live[k]
                            if Joins(e, m, sameMob, share) then
                                local d = math.abs(e.x - m.x) + math.abs(e.y - m.y)
                                if not bestD or d < bestD then best, bestD = pile, d end
                            end
                        end
                    end
                end
            end
            if best then
                table.insert(best.live, e)
            else
                table.insert(piles, { live = { e }, ghosts = {}, name = e.name })
            end
            e.taken = true
        end
    end
    -- Merge piles of the same mob that have drifted into reach of each other.
    for a = 1, table.getn(piles) do
        local pa = piles[a]
        if pa.name and not bigNames[pa.name] and table.getn(pa.live) > 0 then
            for b = a + 1, table.getn(piles) do
                local pb = piles[b]
                if not bigNames[pb.name or ""] and table.getn(pb.live) > 0 then
                    local sameMob = pb.name == pa.name
                    local touch = false
                    for i = 1, table.getn(pa.live) do
                        for k = 1, table.getn(pb.live) do
                            if not touch and Joins(pa.live[i], pb.live[k], sameMob, share) then touch = true end
                        end
                    end
                    if touch then
                        for k = 1, table.getn(pb.live) do table.insert(pa.live, pb.live[k]) end
                        for k = 1, table.getn(pb.ghosts) do table.insert(pa.ghosts, pb.ghosts[k]) end
                        pb.live, pb.ghosts = {}, {}
                    end
                end
            end
        end
    end
    -- Remember the piles, and pick the one plate each shows.
    for k in pairs(order) do order[k] = nil end
    for j = 1, table.getn(piles) do
        local pile = piles[j]
        local count = table.getn(pile.live)
        local list = {}
        if count > 0 then
            local shown = pile.live[1]
            for k = 2, count do
                if IsTarget(pile.live[k].plate, plates[pile.live[k].plate]) then shown = pile.live[k] end
            end
            for k = 1, count do
                local e = pile.live[k]
                table.insert(list, e.plate)
                memberName[e.plate] = e.name
                lastSeen[e.plate] = now
                if collapse and e ~= shown then pileHidden[e.plate] = true end
            end
            if collapse and count > 1 then pileCount[shown.plate] = count end
            if count > 1 or hideAll or bigNames[shown.name or ""] then
                -- For the pile bars: the pile's average health and its health added up, read
                -- off each member's bar.
                local sum, hp = 0, 0
                for k = 1, count do
                    local bar = plates[pile.live[k].plate].bar
                    local low, high = bar:GetMinMaxValues()
                    if high and low and high > low then
                        local v = (bar:GetValue() or low) - low
                        sum = sum + v / (high - low)
                        hp = hp + v
                    end
                end
                table.insert(SP.pileList, { id = pile.live[1].plate, name = shown.name or "?", count = count,
                    health = sum / count, hp = hp,
                    target = IsTarget(shown.plate, plates[shown.plate]), boss = bigNames[shown.name or ""] })
            end
        end
        for k = 1, table.getn(pile.ghosts) do table.insert(list, pile.ghosts[k]) end
        if list[1] then order[list[1]] = list end
    end
end

local lastMode
local function ComputeCollapse()
    SP.pileList = {}
    for _, t in ipairs({ pileHidden, pileCount }) do
        for k in pairs(t) do t[k] = nil end
    end
    if lastMode ~= db.stackMode then
        for k in pairs(order) do order[k] = nil end
        lastMode = db.stackMode
    end
    -- Piles feed both Collapse mode and the pile bars; with neither on there's nothing to do.
    if db.stackMode ~= "collapse" and not db.pileBars then
        for k in pairs(order) do order[k] = nil end
        return
    end
    for k in pairs(byPlate) do byPlate[k] = nil end
    local n = 0
    for plate, data in pairs(plates) do
        local style = data.style
        if plate:IsShown() and style and style.visual:IsShown() and not data.presentationMasked then
            local anchor = data.bar
            local x, y = anchor:GetCenter()
            if not x then
                anchor = plate
                x, y = plate:GetCenter()
            end
            if x and y then
                local bs = anchor:GetEffectiveScale()
                local eff = style.visual:GetEffectiveScale()
                local h = db.height * eff
                if db.namePos == "above" then h = h + (db.fontSize + 1) * eff end
                n = n + 1
                local e = live[n] or {}
                live[n] = e
                e.plate, e.x, e.y, e.w, e.h = plate, x * bs, y * bs, db.width * eff, h
                -- One of the game's plate rows: it spreads its plate frames this far apart.
                e.row = (plate:GetHeight() or 32) * plate:GetEffectiveScale()
                e.taken = false
                e.name = PlateName(data)
                byPlate[plate] = e
            end
        end
    end
    for i = n + 1, table.getn(live) do live[i] = nil end
    ComputePiles(n, db.stackOverlap / 100)
end

local sinceCollapse = 0
local function OnUpdate()
    if not installed then return end
    sinceCollapse = sinceCollapse + (arg1 or 0)
    if sinceCollapse >= 0.05 then
        sinceCollapse = 0
        ComputeCollapse()
    end
    for plate, data in pairs(plates) do
        if plate:IsShown() and data.style then
            -- A plate hidden in a pile mustn't be an invisible click target.
            local hidden = (pileHidden[plate] or not db.worldPlates) and not data.presentationMasked
            if hidden and not data.spClickOff then
                plate:SetHitRectInsets(1000000, 1000000, 1000000, 1000000)
                data.spClickOff = true
            elseif not hidden and data.spClickOff then
                plate:SetHitRectInsets(0, 0, 0, 0)
                data.spClickOff = false
            end
            if SP.debug then SP.ShowMarker(plate, data) end
        end
    end
end

-- /asp debug: a cyan dot where the game puts each plate's health bar, including plates
-- hidden in a pile.
function SP.ShowMarker(plate, data)
    local mark = data.spMarker
    if not mark then
        mark = CreateFrame("Frame", nil, plate)
        mark:SetFrameLevel(plate:GetFrameLevel() + 10)
        mark:SetWidth(6)
        mark:SetHeight(6)
        mark:SetPoint("CENTER", data.bar, "CENTER", 0, 0)
        local dot = mark:CreateTexture(nil, "OVERLAY")
        dot:SetTexture("Interface\\Buttons\\WHITE8X8")
        dot:SetVertexColor(0, 1, 1, 1)
        dot:SetAllPoints(mark)
        data.spMarker = mark
    end
    mark:Show()
end

function SP.SetDebug(on)
    SP.debug = on
    if not on then
        for _, data in pairs(plates) do
            if data.spMarker then data.spMarker:Hide() end
        end
    end
end

-- Hooks --------------------------------------------------------------------------------

local function Install()
    if installed then return true end
    local style = DFRL and DFRL.tools and DFRL.tools.NameplateStyle
    if type(style) ~= "table" or type(style.Attach) ~= "function" or type(style.Update) ~= "function" then
        return false
    end
    local attach, update = style.Attach, style.Update
    -- SurvivorsDragonUi's combat text module calls these through the table on every
    -- refresh, so wrapping the fields is enough: no need to touch its locals.
    style.Attach = function(plate, data)
        attach(plate, data)
        if data and data.style then
            plates[plate] = data
            ApplyLayout(data)
        end
    end
    style.Update = function(plate, data)
        update(plate, data)
        if data and data.style then
            plates[plate] = data
            ApplyLive(plate, data)
        end
    end
    installed = true
    return true
end

local events = CreateFrame("Frame", "SurvivorPlatesFrame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("CHAT_MSG_ADDON")
events:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "SurvivorPlates" then
        LoadSettings()
        Install()
        SP.UpdateMinimapButton()
        SP.UpdatePileBars()
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        if not db then LoadSettings() end
        if not Install() and not warned then
            warned = true
            Print("SurvivorsDragonUi's nameplates weren't found, so SurvivorPlates is off. "
                .. "It needs SurvivorsDragonUi with its nameplate skin enabled.")
        end
        RefreshBigNames()
    elseif event == "CHAT_MSG_ADDON" and arg1 == "AZSUNITS" then
        -- The game's parser replaces AZS_UNITS on this same event; read it next frame.
        SP.unitsDirty = true
    end
end)
events:SetScript("OnUpdate", function()
    if SP.unitsDirty then
        SP.unitsDirty = false
        RefreshBigNames()
    end
    -- An error here would stop every plate after the failing one from updating, every frame.
    -- Report the first one in chat instead of failing silently.
    local ok, err = pcall(OnUpdate)
    if not ok and not SP.updateError then
        SP.updateError = err
        Print("|cffff5555error while updating plates:|r " .. tostring(err))
    end
end)

function SP.IsInstalled() return installed end

-- How many plates are on screen, and how many of those are hidden in piles.
function SP.PileStats()
    local seen, hidden = 0, 0
    for plate, data in pairs(plates) do
        if plate:IsShown() and data.style and data.style.visual:IsShown() then
            seen = seen + 1
            if pileHidden[plate] then hidden = hidden + 1 end
        end
    end
    return seen, hidden
end
function SP.PlateCount()
    local shown, all = 0, 0
    for plate in pairs(plates) do
        all = all + 1
        if plate:IsShown() then shown = shown + 1 end
    end
    return shown, all
end
