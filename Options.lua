-- SurvivorPlates options window: /asp. Every change applies at once (live preview).
local SP = SurvivorPlates

local LABELS = {
    spread = "Spread (game default)", collapse = "Collapse piles",
    above = "Above the bar", inside = "Inside the bar", hidden = "Hidden",
    none = "None", percent = "Percent", current = "Current", both = "Current / max",
    free = "Where you drag it", player = "Above your character", below = "Below your character",
    up = "Upward", down = "Downward",
}

local frame
local widgets = {}

local function Font(label, size)
    local T = DFRL and DFRL.tools
    if T and T.SetFont then
        T.SetFont(label, size, "OUTLINE")
    else
        label:SetFont("Fonts\\FRIZQT__.TTF", size, "OUTLINE")
    end
end

local function Text(parent, size, r, g, b)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    Font(fs, size)
    fs:SetTextColor(r or 1, g or 1, b or 1)
    return fs
end

local function Heading(parent, text, x, y)
    local fs = Text(parent, 14, 1, 0.82, 0)
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    fs:SetText(text)
end

-- A smaller grey label for a group of settings inside a column.
local function SubHeading(parent, text, x, y)
    local fs = Text(parent, 11, 0.6, 0.6, 0.6)
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    fs:SetText(text)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetTexture("Interface\\Buttons\\WHITE8X8")
    line:SetVertexColor(1, 1, 1, 0.15)
    line:SetHeight(1)
    line:SetPoint("LEFT", fs, "RIGHT", 6, 0)
    line:SetPoint("RIGHT", parent, "LEFT", x + 220, 0)
end

local function FormatValue(value, step, suffix)
    if step < 1 then return string.format("%.2f", value) .. (suffix or "") end
    return tostring(math.floor(value + 0.5)) .. (suffix or "")
end

local function Slider(parent, key, label, minV, maxV, step, x, y, suffix)
    local s = CreateFrame("Slider", nil, parent)
    s:SetOrientation("HORIZONTAL")
    s:SetWidth(220)
    s:SetHeight(16)
    s:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 16)
    s:SetBackdrop({
        bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
        edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 3, right = 3, top = 6, bottom = 6 },
    })
    s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    local title = Text(s, 11)
    title:SetPoint("BOTTOMLEFT", s, "TOPLEFT", 0, 1)
    title:SetText(label)
    local value = Text(s, 11, 1, 0.82, 0)
    value:SetPoint("BOTTOMRIGHT", s, "TOPRIGHT", 0, 1)
    s:SetScript("OnValueChanged", function()
        local v = this:GetValue()
        if step >= 1 then v = math.floor(v + 0.5) else v = math.floor(v / step + 0.5) * step end
        value:SetText(FormatValue(v, step, suffix))
        if not this.refreshing and SP.Get(key) ~= v then SP.Set(key, v) end
    end)
    -- The mouse wheel nudges it one step.
    s:EnableMouseWheel(true)
    s:SetScript("OnMouseWheel", function()
        this:SetValue(this:GetValue() + (arg1 > 0 and step or -step))
    end)
    s.Refresh = function()
        s.refreshing = true
        s:SetValue(SP.Get(key))
        value:SetText(FormatValue(SP.Get(key), step, suffix))
        s.refreshing = false
    end
    table.insert(widgets, s)
    return s
end

-- A slider with - and + buttons either side, for settings you line up by the pixel.
local function NudgeSlider(parent, key, label, minV, maxV, step, x, y, suffix)
    local s = Slider(parent, key, label, minV, maxV, step, x + 20, y, suffix)
    s:SetWidth(180)
    local function Nudge(text, delta, point, xOff)
        local b = CreateFrame("Button", nil, parent)
        b:SetWidth(18)
        b:SetHeight(18)
        b:SetPoint(point, s, point, xOff, 0)
        b:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        b:SetBackdropColor(0, 0, 0, 0.5)
        b:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
        local fs = Text(b, 12, 1, 0.82, 0)
        fs:SetPoint("CENTER", b, "CENTER", 0, 1)
        fs:SetText(text)
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        hl:SetAllPoints(b)
        hl:SetBlendMode("ADD")
        b:SetScript("OnClick", function()
            local v = math.max(minV, math.min(maxV, SP.Get(key) + delta))
            SP.Set(key, v)
        end)
    end
    Nudge("-", -step, "RIGHT", -182)
    Nudge("+", step, "LEFT", 182)
    return s
end

local function Check(parent, key, label, x, y)
    local c = CreateFrame("CheckButton", nil, parent)
    c:SetWidth(24)
    c:SetHeight(24)
    c:SetPoint("TOPLEFT", parent, "TOPLEFT", x - 4, y)
    c:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    c:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    c:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
    c:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    local fs = Text(c, 11)
    fs:SetPoint("LEFT", c, "RIGHT", 2, 0)
    fs:SetText(label)
    c:SetScript("OnClick", function() SP.Set(key, this:GetChecked() and true or false) end)
    c.Refresh = function() c:SetChecked(SP.Get(key) and 1 or nil) end
    table.insert(widgets, c)
    return c
end

-- A button that steps through a setting's choices: left click forward, right click back.
local function Cycle(parent, key, label, x, y)
    local title = Text(parent, 11)
    title:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    title:SetText(label)
    local b = CreateFrame("Button", nil, parent)
    b:SetWidth(220)
    b:SetHeight(22)
    b:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    b:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    b:SetBackdropColor(0, 0, 0, 0.5)
    b:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    hl:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
    hl:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
    hl:SetBlendMode("ADD")
    local fs = Text(b, 11, 1, 0.82, 0)
    fs:SetPoint("CENTER", b, "CENTER", 0, 0)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnClick", function()
        local list = SP.choices[key]
        local n = table.getn(list)
        local at = 1
        for i = 1, n do
            if list[i] == SP.Get(key) then at = i end
        end
        if arg1 == "RightButton" then at = at - 1 else at = at + 1 end
        if at < 1 then at = n elseif at > n then at = 1 end
        SP.Set(key, list[at])
    end)
    b.Refresh = function() fs:SetText("< " .. (LABELS[SP.Get(key)] or SP.Get(key)) .. " >") end
    table.insert(widgets, b)
    return b
end

local function PlainButton(parent, text, width)
    local T = DFRL and DFRL.tools
    if T and T.CreateButton then return T.CreateButton(parent, text, width, 26) end
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetWidth(width)
    b:SetHeight(24)
    b:SetText(text)
    return b
end

local function Build()
    frame = CreateFrame("Frame", "SurvivorPlatesOptions", UIParent)
    frame:SetWidth(540)
    frame:SetHeight(690)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("DIALOG")
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0, 0, 0, 0.9)
    frame:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function() this:StartMoving() end)
    frame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    frame:Hide()
    table.insert(UISpecialFrames, "SurvivorPlatesOptions") -- Escape closes it

    local title = Text(frame, 18, 1, 0.82, 0)
    title:SetPoint("TOP", frame, "TOP", 0, -14)
    title:SetText("SurvivorPlates")
    local version = Text(frame, 10, 0.6, 0.6, 0.6)
    version:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -12)
    version:SetText("v" .. SP.version)
    local status = Text(frame, 10, 0.6, 0.6, 0.6)
    status:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -12)
    frame.status = status

    local L, R = 20, 290
    -- Column divider.
    local divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetTexture("Interface\\Buttons\\WHITE8X8")
    divider:SetVertexColor(1, 1, 1, 0.12)
    divider:SetWidth(1)
    divider:SetPoint("TOP", frame, "TOPLEFT", 270, -44)
    divider:SetPoint("BOTTOM", frame, "BOTTOMLEFT", 270, 84)

    -- Left: the nameplates above the mobs. These apply in every mode.
    Heading(frame, "Nameplates", L, -44)
    Check(frame, "worldPlates", "Show nameplates above mobs", L, -66)
    Cycle(frame, "stackMode", "Piles of mobs", L, -94)
    SubHeading(frame, "Size", L, -146)
    Slider(frame, "width", "Width", 40, 250, 1, L, -162, " px")
    Slider(frame, "height", "Height", 4, 40, 1, L, -202, " px")
    Slider(frame, "scale", "Scale", 0.5, 2, 0.05, L, -242)
    Slider(frame, "fontSize", "Font size", 6, 20, 1, L, -282)
    Cycle(frame, "namePos", "Name", L, -318)
    Cycle(frame, "healthText", "Health text", L, -364)
    SubHeading(frame, "Target and bosses", L, -414)
    Slider(frame, "targetScale", "Target scale", 1, 2, 0.05, L, -430)
    Check(frame, "targetHighlight", "Gold border on the target", L, -470)
    Check(frame, "fadeOthers", "Fade plates that aren't the target", L, -494)
    Slider(frame, "otherAlpha", "Faded opacity", 0.1, 1, 0.05, L, -518)
    Slider(frame, "bossScale", "Boss and guardian scale", 1, 2.5, 0.05, L, -558)

    -- Right: the pile bars panel, and how piles form (shared with Collapse piles).
    Heading(frame, "Pile bars", R, -44)
    Check(frame, "pileBars", "Show pile bars", R, -66)
    SubHeading(frame, "How piles form", R, -98)
    Slider(frame, "stackOverlap", "Sideways overlap to join", 0, 100, 5, R, -114, "%")
    Check(frame, "combatOnly", "Only form piles in combat", R, -150)
    SubHeading(frame, "Placement", R, -184)
    Cycle(frame, "pileBarsAnchor", "Position", R, -200)
    Cycle(frame, "pileBarsGrow", "Grow (where you drag it)", R, -246)
    NudgeSlider(frame, "pileBarsHeight", "Vertical offset (above / below you)", -300, 500, 1, R, -292, " px")
    Check(frame, "pileBarsLocked", "Lock pile bars (untick to move)", R, -330)
    SubHeading(frame, "Look", R, -364)
    Slider(frame, "pileBarsMax", "Most pile bars", 1, 30, 1, R, -380)
    Slider(frame, "pileBarsScale", "Pile bars scale", 0.5, 2, 0.05, R, -420)
    Check(frame, "pileDamageColors", "Damage in the dealer's class colour", R, -458)

    Check(frame, "minimapButton", "Show minimap button", L, -606)

    local reset = PlainButton(frame, "Reset to defaults", 150)
    reset:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 16, 14)
    reset:SetScript("OnClick", function() SP.Reset() end)
    local close = PlainButton(frame, "Close", 100)
    close:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 14)
    close:SetScript("OnClick", function() frame:Hide() end)

    frame:SetScript("OnShow", function() SP.RefreshOptions() end)
    -- Keep the plate count in the corner current while the window is open.
    local sinceStatus = 0
    frame:SetScript("OnUpdate", function()
        sinceStatus = sinceStatus + (arg1 or 0)
        if sinceStatus < 0.5 then return end
        sinceStatus = 0
        if SP.IsInstalled() then
            frame.status:SetText(SP.StatusLine())
        end
    end)
end

-- "84 plates, 57 hidden in piles".
function SP.StatusLine()
    local seen, hidden = SP.PileStats()
    return seen .. " plates, " .. hidden .. " hidden in piles"
end

function SP.RefreshOptions()
    if not frame or not frame:IsShown() then return end
    for i = 1, table.getn(widgets) do widgets[i].Refresh() end
    if SP.IsInstalled() then
        frame.status:SetText(SP.StatusLine())
    else
        frame.status:SetText("|cffff5555not hooked|r")
    end
end

function SP.ToggleOptions()
    if not frame then Build() end
    if frame:IsShown() then frame:Hide() else frame:Show() end
end

SLASH_SURVIVORPLATES1 = "/asp"
SLASH_SURVIVORPLATES2 = "/survivorplates"
SlashCmdList["SURVIVORPLATES"] = function(msg)
    msg = string.lower(msg or "")
    if msg == "reset" then
        SP.Reset()
        SP.Print("settings reset to defaults.")
    elseif msg == "minimap" then
        SP.Set("minimapButton", not SP.Get("minimapButton"))
        SP.Print("minimap button " .. (SP.Get("minimapButton") and "shown." or "hidden. /asp minimap brings it back."))
    elseif msg == "debug" then
        SP.SetDebug(not SP.debug)
        SP.Print(SP.debug and "debug on: a cyan dot marks where the game puts each plate. /asp debug turns it off."
            or "debug off.")
    elseif msg == "combatlog" then
        SP.ToggleCombatLog()
    elseif msg == "status" then
        local shown, all = SP.PlateCount()
        local _, hidden = SP.PileStats()
        SP.Print("v" .. SP.version .. ", " .. (SP.IsInstalled() and "hooked into SurvivorsDragonUi" or "NOT hooked")
            .. ", " .. shown .. " of " .. all .. " known plates shown. Mode: " .. SP.Get("stackMode")
            .. ", " .. hidden .. " hidden in piles.")
        if SP.updateError then SP.Print("last error: " .. tostring(SP.updateError)) end
    else
        SP.ToggleOptions()
    end
end
