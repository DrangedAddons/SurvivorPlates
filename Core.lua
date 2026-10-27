-- SurvivorPlates: size, stacking and target options for SurvivorsDragonUi's nameplates.
-- SurvivorsDragonUi draws each enemy plate as a skin frame (data.style.visual) centred
-- on the native plate's health bar. The game keeps positioning the native plates; this
-- addon only resizes the skin and offsets it upward so overlapping plates stack.

SurvivorPlates = {}
local SP = SurvivorPlates
SP.version = GetAddOnMetadata and GetAddOnMetadata("SurvivorPlates", "Version") or "?"

SP.defaults = {
    -- Stacking
    stackMode = "stack", -- "stack" or "overlap"
    stackGap = 2,
    stackOverlap = 10, -- % of the narrower plate's width two plates must share to collide
    stackMax = 10, -- highest a plate may be pushed, in plate rows
    stackSpeed = 12, -- 0 = jump straight to place
    clampTop = true,
    combatOnly = false,
    moveClicks = true, -- move the plate's click area along with its stacked skin
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
}

local CHOICES = {
    stackMode = { "stack", "overlap" },
    namePos = { "above", "inside", "hidden" },
    healthText = { "none", "percent", "current", "both" },
}
SP.choices = CHOICES

local db -- this character's settings
local plates = {} -- plate -> data (SurvivorsDragonUi's per-plate table)
local offsets = {} -- plate -> current stack offset in screen pixels
local targets = {} -- plate -> wanted stack offset in screen pixels
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

function SP.Set(key, value)
    db[key] = value
    SP.RestyleAll()
end

function SP.Reset()
    for k, v in pairs(SP.defaults) do db[k] = v end
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

-- Bosses, final bosses and guardians, by name, from the game's unit list.
local bigNames = {}
local function RefreshBigNames()
    for k in pairs(bigNames) do bigNames[k] = nil end
    if type(AZS_UNITS) ~= "table" then return end
    for i = 1, table.getn(AZS_UNITS) do
        local u = AZS_UNITS[i]
        if u.kind == "boss" or u.kind == "final" or u.kind == "guardian" then bigNames[u.name] = true end
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
end

function SP.RestyleAll()
    for plate, data in pairs(plates) do
        if data.style and data.style.sp then data.style.sp.layoutDone = false end
        data.spAnchored = false -- re-apply the anchor and click area too
    end
    if SP.RefreshOptions then SP.RefreshOptions() end
end

-- Stacking ---------------------------------------------------------------------------

local function Anchor(plate, data, offset)
    local style = data.style
    local eff = style.visual:GetEffectiveScale()
    style.visual:ClearAllPoints()
    style.visual:SetPoint("CENTER", data.bar, "CENTER", 0, offset / eff)
    -- Move the click area up with the skin, so clicking a stacked plate targets its mob.
    -- SurvivorsDragonUi's hidden-plate mode sets its own insets, so stay out of its way then.
    if db.moveClicks and not data.presentationMasked then
        local d = offset / plate:GetEffectiveScale()
        if data.spInset ~= d then
            plate:SetHitRectInsets(0, 0, -d, d)
            data.spInset = d
        end
    elseif data.spInset and data.spInset ~= 0 and not data.presentationMasked then
        plate:SetHitRectInsets(0, 0, 0, 0)
        data.spInset = 0
    end
end

local live, placed = {}, {}
local function ComputeStack()
    for k in pairs(targets) do targets[k] = nil end
    local stacking = db.stackMode == "stack" and (not db.combatOnly or UnitAffectingCombat("player"))
    if not stacking then return end
    local n = 0
    for plate, data in pairs(plates) do
        local style = data.style
        if plate:IsShown() and style and style.visual:IsShown() and not data.presentationMasked then
            local x, y = data.bar:GetCenter()
            if x and y then
                local bs = data.bar:GetEffectiveScale()
                local eff = style.visual:GetEffectiveScale()
                local h = db.height * eff
                if db.namePos == "above" then h = h + (db.fontSize + 1) * eff end
                n = n + 1
                local e = live[n] or {}
                live[n] = e
                e.plate, e.x, e.y, e.w, e.h = plate, x * bs, y * bs, db.width * eff, h
            end
        end
    end
    for i = n + 1, table.getn(live) do live[i] = nil end
    -- Lowest on screen first: those are usually nearest, and they keep their place.
    table.sort(live, function(a, b) return a.y < b.y end)
    local screenTop = UIParent:GetTop() * UIParent:GetEffectiveScale()
    local share = db.stackOverlap / 100
    local m = 0
    for i = 1, n do
        local e = live[i]
        local y = e.y
        local limit = e.y + db.stackMax * (e.h + db.stackGap)
        -- `placed` is kept sorted by final y, so one upward pass finds every collision.
        for j = 1, m do
            local p = placed[j]
            -- Collide when they share at least `share` of the narrower plate's width.
            local reach = (e.w + p.w) * 0.5 - share * math.min(e.w, p.w)
            if math.abs(e.x - p.x) < reach and y < p.top + db.stackGap and y + e.h + db.stackGap > p.fy then
                y = p.top + db.stackGap
            end
        end
        if y > limit then y = limit end
        if db.clampTop and y + e.h > screenTop - 4 then y = math.max(e.y, screenTop - 4 - e.h) end
        e.fy, e.top = y, y + e.h
        -- Insert into placed, keeping it sorted by final y.
        local k = m + 1
        while k > 1 and placed[k - 1].fy > y do
            placed[k] = placed[k - 1]
            k = k - 1
        end
        placed[k] = e
        m = m + 1
        targets[e.plate] = y - e.y
    end
    for i = m + 1, table.getn(placed) do placed[i] = nil end
end

local sinceStack = 0
local function OnUpdate()
    if not installed then return end
    local dt = arg1 or 0
    sinceStack = sinceStack + dt
    if sinceStack >= 0.05 then
        sinceStack = 0
        ComputeStack()
    end
    local rate = db.stackSpeed > 0 and math.min(1, dt * db.stackSpeed) or 1
    for plate, data in pairs(plates) do
        if not plate:IsShown() then
            -- A recycled plate starts unstacked, then glides to its place.
            offsets[plate] = 0
            data.spAnchored = false
        elseif data.style then
            local want = targets[plate] or 0
            local cur = offsets[plate] or 0
            local nextOffset = cur + (want - cur) * rate
            if math.abs(want - nextOffset) < 0.5 then nextOffset = want end
            -- The offset is set in the skin's own units, so a scale change (targeting) re-anchors too.
            local eff = data.style.visual:GetEffectiveScale()
            if nextOffset ~= cur or not data.spAnchored or data.spEff ~= eff then
                offsets[plate] = nextOffset
                Anchor(plate, data, nextOffset)
                data.spAnchored, data.spEff = true, eff
            end
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
    OnUpdate()
end)

function SP.IsInstalled() return installed end
function SP.PlateCount()
    local shown, all = 0, 0
    for plate in pairs(plates) do
        all = all + 1
        if plate:IsShown() then shown = shown + 1 end
    end
    return shown, all
end
