-- Pile bars: a panel that lists each collapsed pile as its own bar, like boss bars.
-- Each bar shows the mob's name, how many are in the pile and their average health.
-- Click a bar to target one of that mob. Shown only in Collapse piles mode. It sits where
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

-- Shown only while unlocked: a title strip to grab, and a backdrop marking the area.
local header = CreateFrame("Frame", nil, panel)
header:SetPoint("BOTTOMLEFT", panel, "TOPLEFT", 0, 2)
header:SetPoint("BOTTOMRIGHT", panel, "TOPRIGHT", 0, 2)
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

local bars = {}
local function Bar(i)
    if bars[i] then return bars[i] end
    local b = CreateFrame("Button", nil, panel)
    b:SetWidth(BAR_W)
    b:SetHeight(BAR_H)
    -- Bar 1 is the bottom one; the rest stack upward.
    b:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, (i - 1) * (BAR_H + SPACING))
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

local function AbovePlayer() return SP.Get("pileBarsAnchor") == "player" end

local function Place()
    panel:ClearAllPoints()
    local x, y = SP.Get("pileBarsX"), SP.Get("pileBarsY")
    if AbovePlayer() then
        -- Grows upward from just above your character's head.
        panel:SetPoint("BOTTOM", UIParent, "CENTER", 0, SP.Get("pileBarsHeight") / SP.Get("pileBarsScale"))
    elseif x and y then
        panel:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
    else
        panel:SetPoint("BOTTOMRIGHT", UIParent, "RIGHT", -260, 60)
    end
end

-- Drag by the panel or its title strip while unlocked.
local function StartDrag()
    if not SP.Get("pileBarsLocked") then panel:StartMoving() end
end
local function StopDrag()
    panel:StopMovingOrSizing()
    SP.SetQuiet("pileBarsX", panel:GetLeft())
    SP.SetQuiet("pileBarsY", panel:GetBottom())
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
    local on = SP.Get("pileBars") and SP.Get("stackMode") == "collapse"
    if not on then
        panel:Hide()
        return
    end
    local unlocked = not SP.Get("pileBarsLocked") and not AbovePlayer()
    local list = {}
    for i = 1, table.getn(SP.pileList) do list[i] = SP.pileList[i] end
    Order(list)
    -- Only as many bars as fit between the panel's bottom and the top of the screen. The
    -- bottom never moves; bars that don't fit (the least health) are left off.
    local fit = 1000
    local bottom = panel:GetBottom()
    if bottom and UIParent:GetTop() then
        local top = UIParent:GetTop() * UIParent:GetEffectiveScale() / panel:GetEffectiveScale()
        fit = math.max(1, math.floor((top - bottom - 20 + SPACING) / (BAR_H + SPACING)))
    end
    local shown = math.min(table.getn(list), SP.Get("pileBarsMax"), fit)
    local lags = {}
    for i = 1, shown do
        local b, p = Bar(i), list[i]
        -- The damage chunk follows its pile when bars reorder.
        local s = lagOf[p.id] or { v = p.health, last = p.health, hold = 0 }
        if p.health < s.last then s.hold = HOLD end -- a new hit: hold the chunk a bit longer
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
    -- Clamped only while you drag it; locked, being pushed back on screen would move the bottom.
    if panel.SetClampedToScreen then panel:SetClampedToScreen(unlocked) end
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
