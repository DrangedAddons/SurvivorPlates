-- SurvivorPlates: size, stacking and target options for SurvivorsDragonUi's nameplates.
-- SurvivorsDragonUi draws each enemy plate as a skin frame (data.style.visual) centred
-- on the native plate's health bar. The game positions the native plates, and already
-- spreads them so their 32 px frames never overlap ("Spread"). This addon resizes the skin
-- and, in Stack mode, moves skins that overlap sideways into tidy columns.

SurvivorPlates = {}
local SP = SurvivorPlates
SP.version = GetAddOnMetadata and GetAddOnMetadata("SurvivorPlates", "Version") or "?"

SP.defaults = {
    -- Stacking
    stackMode = "spread", -- "spread" (the game's own layout) or "stack" (columns)
    stackGap = 2,
    stackOverlap = 30, -- % of the narrower plate's width two plates must share to join a column
    stackKeep = true, -- a plate that joins a column stays in it until its plate goes away
    stackLeave = 2, -- plate widths sideways (x6 plate rows up/down) before a plate leaves its column
    stackMax = 10, -- most plates in one column; the rest start a new one
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
    -- Minimap button (Reset to defaults leaves these alone)
    minimapButton = true,
    minimapAngle = 225, -- degrees around the minimap, 0 = right
}
local KEEP_ON_RESET = { minimapButton = true, minimapAngle = true }

local CHOICES = {
    stackMode = { "spread", "stack" },
    namePos = { "above", "inside", "hidden" },
    healthText = { "none", "percent", "current", "both" },
}
SP.choices = CHOICES

local db -- this character's settings
local plates = {} -- plate -> data (SurvivorsDragonUi's per-plate table)
-- Skin offsets from the game's position, in screen pixels: current and wanted.
local offX, offY, wantX, wantY = {}, {}, {}, {}
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
    -- A mode change snaps every plate to its new place instead of gliding there.
    if key == "stackMode" then
        for _, t in ipairs({ offX, offY, wantX, wantY }) do
            for k in pairs(t) do t[k] = nil end
        end
    end
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
    if SP.UpdateMinimapButton then SP.UpdateMinimapButton() end
    if SP.RefreshOptions then SP.RefreshOptions() end
end

-- Stacking ---------------------------------------------------------------------------

local function Anchor(plate, data, dx, dy)
    local style = data.style
    local eff = style.visual:GetEffectiveScale()
    style.visual:ClearAllPoints()
    style.visual:SetPoint("CENTER", data.bar, "CENTER", dx / eff, dy / eff)
    -- Move the click area with the skin, so clicking a stacked plate targets its mob.
    -- SurvivorsDragonUi's hidden-plate mode sets its own insets, so stay out of its way then.
    if db.moveClicks and not data.presentationMasked then
        local ps = plate:GetEffectiveScale()
        local ix, iy = dx / ps, dy / ps
        if data.spInsetX ~= ix or data.spInsetY ~= iy then
            plate:SetHitRectInsets(ix, -ix, -iy, iy)
            data.spInsetX, data.spInsetY = ix, iy
        end
    elseif (data.spInsetX or 0) ~= 0 or (data.spInsetY or 0) ~= 0 then
        if not data.presentationMasked then
            plate:SetHitRectInsets(0, 0, 0, 0)
            data.spInsetX, data.spInsetY = 0, 0
        end
    end
end

-- Stack mode. Columns are remembered between passes, so they don't reshuffle every time
-- the game nudges a plate:
--  * Joining is easy: a free plate joins a column if it overlaps it sideways by at least
--    `stackOverlap` % and sits within reach of the column's top plate.
--  * Leaving is very hard: a member stays for at least STICK_TIME after joining, and after
--    that until its mob is far away: more than `stackLeave` plate widths sideways from the
--    column, or more than ROWS_PER_WIDTH times that in the game's plate rows from the plate
--    below it.
--  * Members keep their order, so a column never reorders itself; new plates go on top.
local STICK_TIME, ROWS_PER_WIDTH = 3.0, 6
local live, byPlate, order, joinedAt, memberName = {}, {}, {}, {}, {}
local function ComputeStack()
    for _, t in ipairs({ wantX, wantY }) do
        for k in pairs(t) do t[k] = nil end
    end
    local stacking = db.stackMode == "stack" and (not db.combatOnly or UnitAffectingCombat("player"))
    if not stacking then
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
                -- The game spreads its plate frames a frame's height apart, so a plate one
                -- to three of those above the column's top is still part of the same pile.
                e.row = (plate:GetHeight() or 32) * plate:GetEffectiveScale()
                e.reach = 3 * e.row
                e.taken = false
                e.name = PlateName(data)
                byPlate[plate] = e
            end
        end
    end
    for i = n + 1, table.getn(live) do live[i] = nil end
    local now = GetTime()
    local share = db.stackOverlap / 100
    local cols = {}

    -- Last pass's columns first, in their old order, keeping the members that still belong.
    for _, list in pairs(order) do
        local col
        for i = 1, table.getn(list) do
            local e = byPlate[list[i]]
            -- The game reuses plate frames: a frame now showing another mob starts afresh.
            if e and e.name ~= memberName[e.plate] then e = nil end
            if e and not e.taken then
                if not col then
                    col = { list = { e }, x = e.x, w = e.w }
                    e.taken = true
                elseif table.getn(col.list) < db.stackMax then
                    local top = col.list[table.getn(col.list)]
                    local far = math.abs(e.x - col.x) > db.stackLeave * math.max(e.w, col.w)
                        or math.abs(e.y - top.y) > db.stackLeave * ROWS_PER_WIDTH * e.row
                    if db.stackKeep or now - (joinedAt[e.plate] or 0) < STICK_TIME or not far then
                        table.insert(col.list, e)
                        e.taken = true
                    end
                end
            end
        end
        if col then table.insert(cols, col) end
    end

    -- Then every free plate, bottom-up: join the closest column it overlaps enough, or start one.
    table.sort(live, function(a, b) return a.y < b.y end)
    for i = 1, n do
        local e = live[i]
        if not e.taken then
            local best, bestDx
            for j = 1, table.getn(cols) do
                local col = cols[j]
                local count = table.getn(col.list)
                local top = col.list[count]
                local dx = math.abs(e.x - col.x)
                if count < db.stackMax
                    and (e.w + col.w) * 0.5 - dx >= share * math.min(e.w, col.w)
                    and math.abs(e.y - top.y) <= e.reach
                    and (not bestDx or dx < bestDx) then
                    best, bestDx = col, dx
                end
            end
            if best then
                table.insert(best.list, e)
            else
                table.insert(cols, { list = { e }, x = e.x, w = e.w })
            end
            e.taken = true
            joinedAt[e.plate] = now
        end
    end

    -- Remember the columns, and pack each one upward from its bottom plate.
    for k in pairs(order) do order[k] = nil end
    local screenTop = UIParent:GetTop() * UIParent:GetEffectiveScale()
    for j = 1, table.getn(cols) do
        local col = cols[j]
        local plateList = {}
        local prev
        for i = 1, table.getn(col.list) do
            local e = col.list[i]
            plateList[i] = e.plate
            memberName[e.plate] = e.name
            if not prev then
                e.fx, e.fy = e.x, e.y
            else
                e.fx, e.fy = col.x, prev.fy + (prev.h + e.h) * 0.5 + db.stackGap
                if db.clampTop and e.fy + e.h * 0.5 > screenTop - 4 then e.fy = screenTop - 4 - e.h * 0.5 end
            end
            wantX[e.plate], wantY[e.plate] = e.fx - e.x, e.fy - e.y
            prev = e
        end
        order[col.list[1].plate] = plateList
    end
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
            -- A recycled plate starts where the game puts it, then glides to its place.
            offX[plate], offY[plate] = 0, 0
            data.spAnchored = false
        elseif data.style then
            local tx, ty = wantX[plate] or 0, wantY[plate] or 0
            local cx, cy = offX[plate] or 0, offY[plate] or 0
            local nx, ny = cx + (tx - cx) * rate, cy + (ty - cy) * rate
            if math.abs(tx - nx) < 0.5 then nx = tx end
            if math.abs(ty - ny) < 0.5 then ny = ty end
            -- Offsets are set in the skin's own units, so a scale change (targeting) re-anchors too.
            local eff = data.style.visual:GetEffectiveScale()
            if nx ~= cx or ny ~= cy or not data.spAnchored or data.spEff ~= eff then
                offX[plate], offY[plate] = nx, ny
                Anchor(plate, data, nx, ny)
                data.spAnchored, data.spEff = true, eff
            end
            if SP.debug then SP.ShowMarker(plate, data) end
        end
    end
end

-- /asp debug: a cyan dot where the game puts each plate's health bar. SurvivorPlates never
-- moves the dot, so a skin sitting on its dot is unmoved, and one above it was stacked.
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
    -- An error here would stop every plate after the failing one from moving, every frame.
    -- Report the first one in chat instead of failing silently.
    local ok, err = pcall(OnUpdate)
    if not ok and not SP.updateError then
        SP.updateError = err
        Print("|cffff5555error while placing plates:|r " .. tostring(err))
    end
end)

function SP.IsInstalled() return installed end

-- How many plates the last stacking pass saw, how many it moved, and the biggest move.
function SP.StackStats()
    local seen, moved, most = 0, 0, 0
    for plate, data in pairs(plates) do
        if plate:IsShown() and data.style and data.style.visual:IsShown() then
            seen = seen + 1
            local dx, dy = wantX[plate] or 0, wantY[plate] or 0
            local d = math.sqrt(dx * dx + dy * dy)
            if d > 0.5 then
                moved = moved + 1
                if d > most then most = d end
            end
        end
    end
    return seen, moved, math.floor(most + 0.5)
end
function SP.PlateCount()
    local shown, all = 0, 0
    for plate in pairs(plates) do
        all = all + 1
        if plate:IsShown() then shown = shown + 1 end
    end
    return shown, all
end
