-- Pile bars: a panel that lists each collapsed pile as its own bar, like boss bars.
-- Each bar shows the mob's name, how many are in the pile and their average health.
-- Click a bar to target one of that mob. Works in either nameplate mode. It sits where
-- you drag it, or above your character: the camera follows you, so that's a fixed height
-- above the middle of the screen (the game tells addons nothing better).
local SP = SurvivorPlates
local BAR_W, BAR_H, SPACING = 200, 16, 3
-- The same bar texture SurvivorsDragonUi gives its plates.
local BAR_TEX = "Interface\\AddOns\\SurvivorsDragonUi\\media\\tex\\nameplates\\kui_bar.blp"
-- The skull SurvivorsDragonUi's run timer uses; red for the final boss, gold for guardians.
local SKULL = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull"
local SKULL_COLOR = { boss = { 1, 1, 1 }, final = { 1, 0.3, 0.3 }, guardian = { 1, 0.82, 0 } }

local panel = CreateFrame("Frame", "SurvivorPlatesPileBars", UIParent)
panel:SetWidth(BAR_W)
panel:SetHeight(BAR_H)
-- Over SurvivorsDragonUi's combat text, which it draws in HIGH.
panel:SetFrameStrata("HIGH")
panel:SetFrameLevel(100)
panel:SetMovable(true)
panel:RegisterForDrag("LeftButton")
panel:Hide()

-- Shown only while unlocked: a strip on the fixed edge to grab (under the bars when they
-- grow up, over them when they grow down),
-- and a backdrop marking the area.
local header = CreateFrame("Frame", nil, panel)
header:SetHeight(16)
header:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
header:SetBackdropColor(0, 0, 0, 0.7)
local headerText = header:CreateFontString(nil, "OVERLAY")
headerText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
headerText:SetPoint("CENTER", header, "CENTER", 0, 0)
headerText:SetTextColor(1, 0.82, 0)
headerText:SetText("Pile bars - drag to move")
panel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })

local function Font(label, size)
    local T = DFRL and DFRL.tools
    if T and T.SetFont then
        T.SetFont(label, size, "OUTLINE")
    else
        label:SetFont("Fonts\\FRIZQT__.TTF", size, "OUTLINE")
    end
end

-- Damage chunk: a pale bar behind the health that holds where the health was for HOLD
-- seconds after a hit, then drains down to it, so each hit shows how much it took off.
local HOLD = 0.4
local lagOf = {} -- pile id -> { v = where the pale bar is, last = health last refresh, hold }

-- Who's hitting what, read from the combat log: mob name -> { source name -> damage },
-- reset when that mob has gone DAMAGE_WINDOW seconds without a hit. A chunk takes the
-- class colour of whoever dealt most of it. Your own hits always show; your coop partner's
-- only if the game sends them as PARTY or FRIENDLYPLAYER combat log events.
local DAMAGE_WINDOW = 0.8
local CHUNK_COLOR = { 1, 0.9, 0.55 } -- no colouring, or a hit from someone unknown
local hitsOn = {}

local CLASS_COLOR = {
    WARRIOR = { 0.78, 0.61, 0.43 }, PALADIN = { 0.96, 0.55, 0.73 }, HUNTER = { 0.67, 0.83, 0.45 },
    ROGUE = { 1, 0.96, 0.41 }, PRIEST = { 1, 1, 1 }, SHAMAN = { 0, 0.44, 0.87 },
    MAGE = { 0.41, 0.8, 0.94 }, WARLOCK = { 0.58, 0.51, 0.79 }, DRUID = { 1, 0.49, 0.04 },
}

-- A player or pet name -> its player's class colour, from you, your party and their pets.
local UNITS = { "player", "party1", "party2", "party3", "party4" }
local PETS = { "pet", "partypet1", "partypet2", "partypet3", "partypet4" }
local function ColorOf(name)
    for i = 1, 5 do
        if UnitName(UNITS[i]) == name or (UnitExists(PETS[i]) and UnitName(PETS[i]) == name) then
            local _, class = UnitClass(UNITS[i])
            local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class or ""]
            if c then return { c.r, c.g, c.b } end
            return CLASS_COLOR[class or ""] or CHUNK_COLOR
        end
    end
    return CHUNK_COLOR
end

local function TopDamagerColor(mob)
    local rec = hitsOn[mob]
    if not rec or GetTime() - rec.at > DAMAGE_WINDOW then return CHUNK_COLOR end
    local best, most
    for source, amount in pairs(rec.by) do
        if not most or amount > most then best, most = source, amount end
    end
    return best and ColorOf(best) or CHUNK_COLOR
end

local bars = {}
local function Bar(i)
    if bars[i] then return bars[i] end
    local b = CreateFrame("Button", nil, panel)
    b:SetWidth(BAR_W)
    b:SetHeight(BAR_H)
    b:RegisterForClicks("LeftButtonUp")
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    bg:SetVertexColor(0, 0, 0, 0.8)
    bg:SetAllPoints(b)
    local lag = CreateFrame("StatusBar", nil, b)
    lag:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
    lag:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
    lag:SetStatusBarTexture(BAR_TEX)
    lag:SetStatusBarColor(1, 0.9, 0.55)
    lag:SetMinMaxValues(0, 1)
    lag:EnableMouse(false)
    lag:SetFrameLevel(b:GetFrameLevel() + 1)
    local health = CreateFrame("StatusBar", nil, b)
    health:SetFrameLevel(b:GetFrameLevel() + 2)
    health:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
    health:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
    health:SetStatusBarTexture(BAR_TEX)
    health:SetStatusBarColor(0.7, 0.2, 0.1)
    health:SetMinMaxValues(0, 1)
    health:EnableMouse(false)
    local skull = health:CreateTexture(nil, "OVERLAY")
    skull:SetTexture(SKULL)
    skull:SetWidth(BAR_H - 2)
    skull:SetHeight(BAR_H - 2)
    skull:SetPoint("LEFT", health, "LEFT", 2, 0)
    skull:Hide()
    local name = health:CreateFontString(nil, "OVERLAY")
    Font(name, 10)
    name:SetJustifyH("LEFT")
    name:SetPoint("LEFT", health, "LEFT", 4, 0)
    name:SetPoint("RIGHT", health, "RIGHT", -34, 0)
    name:SetHeight(BAR_H)
    local count = health:CreateFontString(nil, "OVERLAY")
    Font(count, 11)
    count:SetJustifyH("RIGHT")
    count:SetPoint("RIGHT", health, "RIGHT", -4, 0)
    count:SetTextColor(1, 0.82, 0)
    -- Gold edge on the pile that holds your target.
    local edge = b:CreateTexture(nil, "OVERLAY")
    edge:SetTexture("Interface\\Buttons\\WHITE8X8")
    edge:SetVertexColor(1, 0.82, 0, 1)
    edge:SetPoint("TOPRIGHT", b, "TOPLEFT", -1, 0)
    edge:SetPoint("BOTTOMRIGHT", b, "BOTTOMLEFT", -1, 0)
    edge:SetWidth(3)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    hl:SetAllPoints(b)
    hl:SetBlendMode("ADD")
    b.health, b.name, b.count, b.edge, b.skull, b.lag = health, name, count, edge, skull, lag
    b:SetScript("OnClick", function()
        -- 1.12 has no unit token for a plate; target the nearest mob with this name.
        if this.mob then TargetByName(this.mob, true) end
    end)
    bars[i] = b
    return b
end

-- Stuck to your character (above or below), rather than where you drag it.
local function AbovePlayer() return SP.Get("pileBarsAnchor") ~= "free" end

-- Below your character always grows down, above it always up; where you drag it, your pick.
-- Growing up, the bottom edge is fixed and bar 1 (most health) is the bottom one; growing
-- down it's the inverse.
local function GrowsDown()
    local anchor = SP.Get("pileBarsAnchor")
    if anchor == "below" then return true end
    return anchor == "free" and SP.Get("pileBarsGrow") == "down"
end

-- pileBarsY is the fixed edge: the panel's bottom growing up, its top growing down.
local function Place()
    panel:ClearAllPoints()
    local anchor, down = SP.Get("pileBarsAnchor"), GrowsDown()
    local x, y = SP.Get("pileBarsX"), SP.Get("pileBarsY")
    local away = SP.Get("pileBarsHeight") / SP.Get("pileBarsScale")
    if anchor == "player" then
        panel:SetPoint("BOTTOM", UIParent, "CENTER", 0, away)
    elseif anchor == "below" then
        panel:SetPoint("TOP", UIParent, "CENTER", 0, -away)
    elseif x and y then
        panel:SetPoint(down and "TOPLEFT" or "BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
    else
        panel:SetPoint(down and "TOPRIGHT" or "BOTTOMRIGHT", UIParent, "RIGHT", -260, 60)
    end
end

-- Bars and the drag strip, laid out for the current direction.
local laidDown
local function Layout(down)
    if laidDown == down then return end
    laidDown = down
    header:ClearAllPoints()
    if down then
        header:SetPoint("BOTTOMLEFT", panel, "TOPLEFT", 0, 2)
        header:SetPoint("BOTTOMRIGHT", panel, "TOPRIGHT", 0, 2)
    else
        header:SetPoint("TOPLEFT", panel, "BOTTOMLEFT", 0, -2)
        header:SetPoint("TOPRIGHT", panel, "BOTTOMRIGHT", 0, -2)
    end
    for i = 1, table.getn(bars) do
        local b = bars[i]
        b:ClearAllPoints()
        if down then
            b:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -(i - 1) * (BAR_H + SPACING))
        else
            b:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, (i - 1) * (BAR_H + SPACING))
        end
    end
end

-- Drag by the panel or its strip while unlocked. The fixed edge (and the strip on it) is
-- what gets saved, and bars only ever grow away from it.
local dragging = false
local function StartDrag()
    if SP.Get("pileBarsLocked") or AbovePlayer() then return end
    dragging = true
    -- Clamped only mid-drag: clamped otherwise, a tall stack reaching the top of the
    -- screen would push the whole panel, bottom included, down.
    if panel.SetClampedToScreen then panel:SetClampedToScreen(true) end
    panel:StartMoving()
end
local function StopDrag()
    if not dragging then return end
    dragging = false
    panel:StopMovingOrSizing()
    if panel.SetClampedToScreen then panel:SetClampedToScreen(false) end
    -- Keep the client from saving its own top-left anchor for this frame and putting it
    -- back later, which pins the top instead of the bottom.
    if panel.SetUserPlaced then panel:SetUserPlaced(false) end
    SP.SetQuiet("pileBarsX", panel:GetLeft())
    SP.SetQuiet("pileBarsY", GrowsDown() and panel:GetTop() or panel:GetBottom())
    Place()
end
panel:SetScript("OnDragStart", StartDrag)
panel:SetScript("OnDragStop", StopDrag)
header:EnableMouse(true)
header:RegisterForDrag("LeftButton")
header:SetScript("OnDragStart", StartDrag)
header:SetScript("OnDragStop", StopDrag)

-- Order, bottom to top: bosses and guardians first, then most health first. Two piles only
-- swap once one has SWAP_MARGIN more health than the other, so piles that are close don't
-- keep trading places.
local SWAP_MARGIN = 0.15
local lastRank = {} -- pile id -> its place last refresh

local function Before(a, b)
    if (a.boss and 1 or 0) ~= (b.boss and 1 or 0) then return a.boss ~= nil end
    local ra, rb = lastRank[a.id], lastRank[b.id]
    if ra and rb then
        local big = math.max(a.hp, b.hp)
        if math.abs(a.hp - b.hp) <= big * SWAP_MARGIN then return ra < rb end
    end
    if a.hp ~= b.hp then return a.hp > b.hp end
    return (ra or 1000000) < (rb or 1000000)
end

local function ByLastRank(a, b)
    local ra, rb = lastRank[a.id] or 1000000, lastRank[b.id] or 1000000
    if ra ~= rb then return ra < rb end
    return a.hp > b.hp
end

-- Start from last refresh's order, then insertion sort: Before isn't a strict order, which
-- table.sort can choke on.
local function Order(list)
    table.sort(list, ByLastRank)
    for i = 2, table.getn(list) do
        local p = list[i]
        local j = i - 1
        while j >= 1 and Before(p, list[j]) do
            list[j + 1] = list[j]
            j = j - 1
        end
        list[j + 1] = p
    end
    for k in pairs(lastRank) do lastRank[k] = nil end
    for i = 1, table.getn(list) do lastRank[list[i].id] = i end
end

local function Refresh()
    local on = SP.Get("pileBars")
    if not on then
        panel:Hide()
        return
    end
    local unlocked = not SP.Get("pileBarsLocked") and not AbovePlayer()
    local down = GrowsDown()
    -- Re-pin the fixed edge every refresh, in case anything else re-anchored the panel.
    if not dragging then Place() end
    local list = {}
    for i = 1, table.getn(SP.pileList) do list[i] = SP.pileList[i] end
    Order(list)
    -- Only as many bars as fit between the fixed edge and the edge of the screen it grows
    -- toward. The fixed edge never moves; bars that don't fit (the least health) are left off.
    local fit = 1000
    local room
    if down then
        room = panel:GetTop() -- down to the bottom of the screen, at 0
    elseif panel:GetBottom() and UIParent:GetTop() then
        room = UIParent:GetTop() * UIParent:GetEffectiveScale() / panel:GetEffectiveScale() - panel:GetBottom()
    end
    if room then fit = math.max(1, math.floor((room - 20 + SPACING) / (BAR_H + SPACING))) end
    local shown = math.min(table.getn(list), SP.Get("pileBarsMax"), fit)
    local lags = {}
    for i = 1, shown do
        if not bars[i] then
            Bar(i)
            laidDown = nil
        end
    end
    Layout(down)
    for i = 1, shown do
        local b, p = Bar(i), list[i]
        -- The damage chunk follows its pile when bars reorder.
        local s = lagOf[p.id] or { v = p.health, last = p.health, hold = 0, color = CHUNK_COLOR }
        if p.health < s.last then
            s.hold = HOLD -- a new hit: hold the chunk a bit longer
            s.color = SP.Get("pileDamageColors") and TopDamagerColor(p.name) or CHUNK_COLOR
        end
        b.lag:SetStatusBarColor(s.color[1], s.color[2], s.color[3])
        if p.health >= s.v then s.v = p.health end -- healed, or a hurt member died: no chunk
        s.last = p.health
        lags[p.id] = s
        b.lagState, b.hp = s, p.health
        b.lag:SetValue(s.v)
        b.mob = p.name
        b.name:SetText(p.name)
        if p.boss then
            local c = SKULL_COLOR[p.boss] or SKULL_COLOR.boss
            b.skull:SetVertexColor(c[1], c[2], c[3])
            b.skull:Show()
            b.name:SetPoint("LEFT", b.health, "LEFT", BAR_H + 2, 0)
        else
            b.skull:Hide()
            b.name:SetPoint("LEFT", b.health, "LEFT", 4, 0)
        end
        b.count:SetText("x" .. p.count)
        b.health:SetValue(p.health)
        if p.target then b.edge:Show() else b.edge:Hide() end
        -- Unlocked, the bars let drags through to the panel instead of taking clicks.
        b:EnableMouse(not unlocked)
        b:Show()
    end
    for i = shown + 1, table.getn(bars) do
        bars[i]:Hide()
        bars[i].lagState = nil
    end
    lagOf = lags
    -- Keep the panel's size to its bars; unlocked and empty, it still shows one bar's room.
    local rows = math.max(shown, unlocked and 1 or 0)
    panel:SetHeight(math.max(1, rows * (BAR_H + SPACING) - SPACING))
    if unlocked then
        header:Show()
        panel:SetBackdropColor(0, 0.4, 1, 0.2)
        panel:EnableMouse(true)
    else
        header:Hide()
        panel:SetBackdropColor(0, 0, 0, 0)
        panel:EnableMouse(false)
    end
    if rows > 0 then panel:Show() else panel:Hide() end
end

local since = 0
local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function()
    local dt = arg1 or 0
    -- Drain the damage chunks every frame so they slide rather than step.
    for i = 1, table.getn(bars) do
        local b = bars[i]
        local s = b.lagState
        if s and s.v > b.hp then
            if s.hold > 0 then
                s.hold = s.hold - dt
            else
                s.v = math.max(b.hp, s.v - math.max((s.v - b.hp) * 5, 0.05) * dt)
                b.lag:SetValue(s.v)
            end
        end
    end
    since = since + dt
    if since < 0.1 then return end
    since = 0
    if SP.Ready() then Refresh() end
end)

-- Settings changed: re-place and redraw at once.
function SP.UpdatePileBars()
    if not SP.Ready() then return end
    panel:SetScale(SP.Get("pileBarsScale"))
    Place()
    Refresh()
end

-- Combat log parsing ---------------------------------------------------------------------
-- The game's own message formats ("%s's %s hits %s for %d.") turned into patterns. Spell
-- formats go first: "Bob's Fireball hits" would also match the melee "%s hits".
-- slots: which %s/%d is the source (s), target (t) or amount (n); x = skipped (spell,
-- school). you = the source is you.
local FORMATS = {
    { "SPELLLOGCRITSCHOOLOTHEROTHER", "sxtnx" }, { "SPELLLOGSCHOOLOTHEROTHER", "sxtnx" },
    { "SPELLLOGCRITOTHEROTHER", "sxtn" }, { "SPELLLOGOTHEROTHER", "sxtn" },
    { "SPELLLOGCRITSCHOOLSELFOTHER", "xtnx", true }, { "SPELLLOGSCHOOLSELFOTHER", "xtnx", true },
    { "SPELLLOGCRITSELFOTHER", "xtn", true }, { "SPELLLOGSELFOTHER", "xtn", true },
    { "PERIODICAURADAMAGEOTHEROTHER", "tnxsx" }, { "PERIODICAURADAMAGESELFOTHER", "tnxx", true },
    { "COMBATHITCRITSCHOOLOTHEROTHER", "stnx" }, { "COMBATHITSCHOOLOTHEROTHER", "stnx" },
    { "COMBATHITCRITOTHEROTHER", "stn" }, { "COMBATHITOTHEROTHER", "stn" },
    { "COMBATHITCRITSCHOOLSELFOTHER", "tnx", true }, { "COMBATHITSCHOOLSELFOTHER", "tnx", true },
    { "COMBATHITCRITSELFOTHER", "tn", true }, { "COMBATHITSELFOTHER", "tn", true },
}
local patterns
local function BuildPatterns()
    patterns = {}
    for i = 1, table.getn(FORMATS) do
        local fmt = getglobal(FORMATS[i][1])
        if type(fmt) == "string" then
            local p = string.gsub(fmt, "([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
            p = string.gsub(p, "%%s", "(.+)")
            p = string.gsub(p, "%%d", "(%%d+)")
            table.insert(patterns, { pattern = "^" .. p, slots = FORMATS[i][2], you = FORMATS[i][3] })
        end
    end
end

local function OnHit(message)
    if not patterns then BuildPatterns() end
    for i = 1, table.getn(patterns) do
        local p = patterns[i]
        local r = { string.find(message, p.pattern) }
        if r[1] then
            local source, target, amount
            for k = 1, string.len(p.slots) do
                local slot, value = string.sub(p.slots, k, k), r[k + 2]
                if slot == "s" then
                    source = value
                elseif slot == "t" then
                    target = value
                elseif slot == "n" then
                    amount = tonumber(value)
                end
            end
            if p.you then source = UnitName("player") end
            if source and target and amount then
                local now = GetTime()
                local rec = hitsOn[target]
                if not rec or now - rec.at > DAMAGE_WINDOW then
                    rec = { by = {} }
                    hitsOn[target] = rec
                end
                rec.at = now
                rec.by[source] = (rec.by[source] or 0) + amount
            end
            return
        end
    end
end

local DAMAGE_EVENTS = {
    "CHAT_MSG_COMBAT_SELF_HITS", "CHAT_MSG_SPELL_SELF_DAMAGE", "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE",
    "CHAT_MSG_COMBAT_PET_HITS", "CHAT_MSG_SPELL_PET_DAMAGE",
    "CHAT_MSG_COMBAT_PARTY_HITS", "CHAT_MSG_SPELL_PARTY_DAMAGE",
    "CHAT_MSG_COMBAT_FRIENDLYPLAYER_HITS", "CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE",
}
local hits = CreateFrame("Frame")
for i = 1, table.getn(DAMAGE_EVENTS) do hits:RegisterEvent(DAMAGE_EVENTS[i]) end

-- /asp combatlog: records which of those events the game fires, with one sample each, to
-- check whether your coop partner's hits come through.
local seen, recording = {}, false
hits:SetScript("OnEvent", function()
    if arg1 then OnHit(arg1) end
    if recording then
        local s = seen[event]
        if not s then
            s = { n = 0 }
            seen[event] = s
        end
        s.n = s.n + 1
        s.sample = arg1
    end
end)

function SP.ToggleCombatLog()
    recording = not recording
    if recording then
        for k in pairs(seen) do seen[k] = nil end
        SP.Print("recording combat log events. Fight for a bit (in coop, let your partner hit things), then /asp combatlog again.")
        return
    end
    SP.Print("combat log events seen:")
    local any = false
    for i = 1, table.getn(DAMAGE_EVENTS) do
        local s = seen[DAMAGE_EVENTS[i]]
        if s then
            any = true
            SP.Print(string.gsub(DAMAGE_EVENTS[i], "CHAT_MSG_", "") .. " x" .. s.n .. ": " .. tostring(s.sample))
        end
    end
    if not any then SP.Print("none.") end
end
