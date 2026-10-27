-- Pile bars: a panel that lists each collapsed pile as its own bar, like boss bars.
-- Each bar shows the mob's name, how many are in the pile and their average health.
-- Click a bar to target one of that mob. Shown only in Collapse piles mode. It sits where
-- you drag it, or above your character: the camera follows you, so that's a fixed height
-- above the middle of the screen (the game tells addons nothing better).
local SP = SurvivorPlates
local BAR_W, BAR_H, SPACING = 200, 16, 3
-- The same bar texture SurvivorsDragonUi gives its plates.
local BAR_TEX = "Interface\\AddOns\\SurvivorsDragonUi\\media\\tex\\nameplates\\kui_bar.blp"

local panel = CreateFrame("Frame", "SurvivorPlatesPileBars", UIParent)
panel:SetWidth(BAR_W)
panel:SetHeight(BAR_H)
panel:SetFrameStrata("MEDIUM")
if panel.SetClampedToScreen then panel:SetClampedToScreen(true) end
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

local bars = {}
local function Bar(i)
    if bars[i] then return bars[i] end
    local b = CreateFrame("Button", nil, panel)
    b:SetWidth(BAR_W)
    b:SetHeight(BAR_H)
    b:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -(i - 1) * (BAR_H + SPACING))
    b:RegisterForClicks("LeftButtonUp")
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    bg:SetVertexColor(0, 0, 0, 0.8)
    bg:SetAllPoints(b)
    local health = CreateFrame("StatusBar", nil, b)
    health:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
    health:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
    health:SetStatusBarTexture(BAR_TEX)
    health:SetStatusBarColor(0.7, 0.2, 0.1)
    health:SetMinMaxValues(0, 1)
    health:EnableMouse(false)
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
    b.health, b.name, b.count, b.edge = health, name, count, edge
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
        panel:SetPoint("RIGHT", UIParent, "RIGHT", -260, 120)
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

-- Bosses first, then the biggest piles.
local function ByCount(a, b)
    if (a.boss and 1 or 0) ~= (b.boss and 1 or 0) then return a.boss and true or false end
    if a.count ~= b.count then return a.count > b.count end
    return a.name < b.name
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
    table.sort(list, ByCount)
    local shown = math.min(table.getn(list), SP.Get("pileBarsMax"))
    for i = 1, shown do
        local b, p = Bar(i), list[i]
        b.mob = p.name
        b.name:SetText(p.name)
        b.count:SetText("x" .. p.count)
        b.health:SetValue(p.health)
        if p.target then b.edge:Show() else b.edge:Hide() end
        -- Unlocked, the bars let drags through to the panel instead of taking clicks.
        b:EnableMouse(not unlocked)
        b:Show()
    end
    for i = shown + 1, table.getn(bars) do bars[i]:Hide() end
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
    since = since + (arg1 or 0)
    if since < 0.2 then return end
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
