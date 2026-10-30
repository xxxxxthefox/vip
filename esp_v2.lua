-- esp_v2.lua
-- ESP موسّع: دائرة تحت اللاعب، اسم الفريق (كشف تلقائي)، اسم الأداة، رادار،
-- أسهم خارج الشاشة، Chams، قائمة لاعبين، تنبيه قرب، حفظ/تحميل إعدادات.

if not (Drawing and Drawing.new) then
    error("[ESP] هذا الـ executor لا يدعم Drawing API")
end

--// Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

local floor, max, min, clamp = math.floor, math.max, math.min, math.clamp
local sin, cos, pi = math.sin, math.cos, math.pi
local Vec2, Vec3 = Vector2.new, Vector3.new

--// Settings (flat table عشان تتوافق مع أي GUI)
local S = {
    -- عام
    Enabled = false,
    Teamcheck = false,        -- يخفي زملاء الفريق
    WallCheck = false,
    MaxDistance = 2000,
    MinDistance = 0,
    MaxPlayers = 0,           -- 0 = بدون حد، غير كذا يعرض أقرب N لاعب
    UpdateRate = 0,           -- 0 = كل فريم، غير كذا مرات بالثانية
    UseDisplayName = false,
    DistanceSuffix = "m",     -- الوحدة (الرقم بالـ studs)
    TextSize = 13,
    ScaleText = false,        -- الخط يصغر مع المسافة
    DistanceFade = false,     -- الشفافية تزيد مع المسافة

    -- ألوان
    UseTeamColors = false,    -- يلون كل شي بلون فريق اللاعب
    ColorByRelation = false,  -- حليف/عدو
    AllyColor = Color3.fromRGB(0, 170, 255),
    EnemyColor = Color3.fromRGB(255, 60, 60),
    RainbowMode = false,
    RainbowSpeed = 0.5,
    HighlightFriends = false,
    FriendColor = Color3.fromRGB(0, 255, 120),
    HighlightClosest = false, -- أقرب عدو بلون مختلف
    ClosestColor = Color3.fromRGB(255, 255, 0),

    BoxColor = Color3.new(1, 1, 1),
    BoxOutlineColor = Color3.new(0, 0, 0),
    NameColor = Color3.new(1, 1, 1),
    ToolColor = Color3.fromRGB(255, 215, 0),
    DistanceColor = Color3.new(1, 1, 1),
    SpeedColor = Color3.fromRGB(170, 170, 255),
    TeamTextColor = Color3.fromRGB(200, 200, 200),
    HealthOutlineColor = Color3.new(0, 0, 0),
    HealthHighColor = Color3.new(0, 1, 0),
    HealthLowColor = Color3.new(1, 0, 0),
    TracerColor = Color3.new(1, 1, 1),
    SkeletonsColor = Color3.new(1, 1, 1),
    HeadDotColor = Color3.fromRGB(255, 80, 80),
    LookLineColor = Color3.fromRGB(255, 150, 0),
    FootCircleColor = Color3.fromRGB(255, 255, 255),
    ArrowColor = Color3.fromRGB(255, 80, 80),

    -- أساسيات
    ShowBox = false,
    BoxType = "2D",           -- "2D" / "Corner Box Esp"
    BoxFill = false,
    BoxFillTransparency = 0.15,
    ShowName = false,
    ShowHealth = false,
    ShowHealthText = false,
    ShowDistance = false,
    ShowSkeletons = false,
    ShowTracer = false,
    TracerThickness = 2,
    TracerPosition = "Bottom", -- Top / Middle / Bottom

    -- ميزات جديدة
    ShowTool = true,          -- اسم الأداة الممسوكة (فوق المسافة)
    ShowEmptyTool = false,
    EmptyToolText = "Empty",

    ShowTeam = true,          -- اسم الفريق (كشف تلقائي)
    ShowNoTeam = false,       -- يكتب "No Team" لو ما لقى فريق
    NoTeamText = "No Team",
    TeamTextUseTeamColor = true,

    ShowFootCircle = true,    -- دائرة تحت اللاعب
    FootCircleRadius = 3,
    FootCircleSegments = 24,
    FootCircleThickness = 1.5,
    FootCirclePulse = false,
    FootCircleSpin = false,
    FootCircleDashed = false,

    ShowHeadDot = false,
    HeadDotFilled = true,
    ShowLookLine = false,
    LookLineLength = 12,
    ShowSpeed = false,

    ShowArrows = false,       -- أسهم للاعبين خارج الشاشة
    ArrowRadius = 200,
    ArrowSize = 16,

    ShowChams = false,        -- Highlight (حد أقصى 31 بالمشهد)
    ChamsUseColor = true,
    ChamsFillColor = Color3.fromRGB(255, 0, 0),
    ChamsOutlineColor = Color3.new(1, 1, 1),
    ChamsFillTransparency = 0.5,
    ChamsOutlineTransparency = 0,

    ShowRadar = false,
    RadarSize = 140,
    RadarRange = 150,
    RadarOffset = Vec2(20, 20), -- من الزاوية اليمنى العليا
    RadarClamp = true,        -- اللي بعيد يظهر على الحافة
    RadarBgTransparency = 0.45,
    RadarBorderColor = Color3.new(1, 1, 1),

    ShowPlayerList = false,   -- قائمة أقرب اللاعبين
    ListMax = 8,
    ListPosition = Vec2(20, 200),

    ProximityAlert = false,   -- تنبيه لو عدو قريب
    AlertDistance = 40,
}

--// Constants
local BONES_R15 = {
    {"Head", "UpperTorso"},
    {"UpperTorso", "RightUpperArm"},
    {"RightUpperArm", "RightLowerArm"},
    {"RightLowerArm", "RightHand"},
    {"UpperTorso", "LeftUpperArm"},
    {"LeftUpperArm", "LeftLowerArm"},
    {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "LowerTorso"},
    {"LowerTorso", "LeftUpperLeg"},
    {"LeftUpperLeg", "LeftLowerLeg"},
    {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"},
    {"RightUpperLeg", "RightLowerLeg"},
    {"RightLowerLeg", "RightFoot"},
}

local BONES_R6 = {
    {"Head", "Torso"},
    {"Torso", "Right Arm"},
    {"Torso", "Left Arm"},
    {"Torso", "Right Leg"},
    {"Torso", "Left Leg"},
}

-- كشف تلقائي لأنظمة الفرق والأدوات المخصصة
local TEAM_ATTRIBUTES = {"Team", "TeamName", "team", "teamName", "Squad", "Faction", "Side"}
local TEAM_VALUE_NAMES = {"Team", "TeamName", "Squad", "Faction", "Side"}
local TOOL_ATTRIBUTES = {"EquippedTool", "Equipped", "CurrentWeapon", "Weapon", "CurrentTool", "Tool"}
local TOOL_VALUE_NAMES = {"EquippedTool", "Equipped", "CurrentWeapon", "Weapon", "CurrentTool"}

local SINGLES = {
    "tracer", "boxFill", "boxOutline", "box", "name", "team", "tool", "distance", "speed",
    "healthOutline", "health", "healthText", "headDot", "lookLine", "arrow", "radarDot",
}

--// State
local cache = {}
local connections = {}
local teamCache = setmetatable({}, {__mode = "k"})
local closestPlayer = nil
local hiddenAll = false
local lastUpdate = 0

local frame = {
    camPos = Vector3.zero,
    yaw = CFrame.new(),
    vp = Vector2.zero,
    rainbow = Color3.new(1, 1, 1),
    allowed = nil,
    radarCenter = Vector2.zero,
}

--// Drawing helpers
local function create(class, properties)
    local drawing = Drawing.new(class)
    for property, value in pairs(properties) do
        drawing[property] = value
    end
    return drawing
end

local function safeRemove(drawing)
    if drawing then
        pcall(function()
            drawing:Remove()
        end)
    end
end

--// Value helpers
local function valueToString(v)
    if v == nil then
        return nil
    end
    if typeof(v) == "Instance" then
        return v.Name
    end
    local s = tostring(v)
    if s == "" then
        return nil
    end
    return s
end

--// كشف الفريق تلقائياً: Team service ثم Attributes ثم Values
local function detectTeam(player)
    if player.Team and not player.Neutral then
        return player.Team.Name, player.Team.TeamColor.Color
    end

    local character = player.Character
    for _, key in ipairs(TEAM_ATTRIBUTES) do
        local v = player:GetAttribute(key)
        if v == nil and character then
            v = character:GetAttribute(key)
        end
        local s = valueToString(v)
        if s then
            return s, nil
        end
    end

    local stats = player:FindFirstChild("leaderstats")
    for _, key in ipairs(TEAM_VALUE_NAMES) do
        local obj = player:FindFirstChild(key) or (stats and stats:FindFirstChild(key))
        if obj and obj:IsA("ValueBase") then
            local s = valueToString(obj.Value)
            if s then
                return s, nil
            end
        end
    end

    return nil, nil
end

-- كاش ثانية وحدة عشان ما نفحص كل فريم
local function getTeam(player)
    local entry = teamCache[player]
    local now = os.clock()
    if not entry or now - entry.t > 1 then
        local name, color = detectTeam(player)
        entry = {t = now, name = name, color = color}
        teamCache[player] = entry
    end
    return entry.name, entry.color
end

local function isTeammate(player)
    local mine = getTeam(localPlayer)
    local theirs = getTeam(player)
    if mine and theirs then
        return mine == theirs
    end
    return false
end

--// كشف الأداة الممسوكة تلقائياً
local function getHeldToolName(player, character)
    local tool = character:FindFirstChildOfClass("Tool")
    if tool then
        return tool.Name
    end

    for _, key in ipairs(TOOL_ATTRIBUTES) do
        local v = character:GetAttribute(key)
        if v == nil then
            v = player:GetAttribute(key)
        end
        local s = valueToString(v)
        if s then
            return s
        end
    end

    for _, key in ipairs(TOOL_VALUE_NAMES) do
        local obj = character:FindFirstChild(key) or player:FindFirstChild(key)
        if obj and obj:IsA("ValueBase") then
            local s = valueToString(obj.Value)
            if s then
                return s
            end
        end
    end

    return nil
end

--// Colors
local function getOverrideColor(player, esp)
    if S.RainbowMode then
        return frame.rainbow
    end
    if S.HighlightClosest and player == closestPlayer then
        return S.ClosestColor
    end
    if S.HighlightFriends and esp.isFriend then
        return S.FriendColor
    end
    if S.UseTeamColors then
        local _, teamColor = getTeam(player)
        if teamColor then
            return teamColor
        end
    end
    if S.ColorByRelation then
        return esp.teammate and S.AllyColor or S.EnemyColor
    end
    return nil
end

--// Wall check
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local function isBehindWall(character, rootPart)
    local origin = frame.camPos
    rayParams.FilterDescendantsInstances = {localPlayer.Character, character}

    local result = workspace:Raycast(origin, rootPart.Position - origin, rayParams)
    if not result then
        return false
    end

    local hit = result.Instance
    if hit.Transparency >= 0.95 then
        return false
    end

    local model = hit:FindFirstAncestorOfClass("Model")
    if model and model:FindFirstChildOfClass("Humanoid") then
        return false
    end

    return true
end

--// Radar (رسومات ثابتة، وحدة لكل السكربت)
local radar = {
    bg = create("Circle", {Filled = true, Color = Color3.new(0, 0, 0), NumSides = 48, Transparency = 0.45, Visible = false}),
    border = create("Circle", {Filled = false, Thickness = 1.5, NumSides = 48, Transparency = 1, Visible = false}),
    h = create("Line", {Thickness = 1, Transparency = 0.4, Visible = false}),
    v = create("Line", {Thickness = 1, Transparency = 0.4, Visible = false}),
    me = create("Triangle", {Filled = true, Color = Color3.new(1, 1, 1), Transparency = 1, Visible = false}),
}

local function hideRadarBase()
    for _, d in pairs(radar) do
        d.Visible = false
    end
end

local function updateRadarBase()
    if not S.ShowRadar then
        return hideRadarBase()
    end

    local r = S.RadarSize / 2
    local c = Vec2(frame.vp.X - r - S.RadarOffset.X, r + S.RadarOffset.Y)
    frame.radarCenter = c

    radar.bg.Position = c
    radar.bg.Radius = r
    radar.bg.Transparency = S.RadarBgTransparency
    radar.bg.Visible = true

    radar.border.Position = c
    radar.border.Radius = r
    radar.border.Color = S.RadarBorderColor
    radar.border.Visible = true

    radar.h.From = c - Vec2(r, 0)
    radar.h.To = c + Vec2(r, 0)
    radar.h.Color = S.RadarBorderColor
    radar.h.Visible = true

    radar.v.From = c - Vec2(0, r)
    radar.v.To = c + Vec2(0, r)
    radar.v.Color = S.RadarBorderColor
    radar.v.Visible = true

    radar.me.PointA = c + Vec2(0, -6)
    radar.me.PointB = c + Vec2(-4, 4)
    radar.me.PointC = c + Vec2(4, 4)
    radar.me.Visible = true
end

--// HUD: قائمة اللاعبين + تنبيه القرب
local listTexts = {}
local alertText = create("Text", {
    Color = Color3.fromRGB(255, 60, 60),
    Outline = true,
    Center = true,
    Size = 18,
    Visible = false,
})

local function hideHud()
    alertText.Visible = false
    for _, t in ipairs(listTexts) do
        t.Visible = false
    end
end

--// Highlight (Chams)
local highlightParent
do
    local ok, ui = pcall(function()
        return gethui and gethui() or nil
    end)
    if ok and ui then
        highlightParent = ui
    else
        local okCore = pcall(function()
            return CoreGui.Name
        end)
        highlightParent = okCore and CoreGui or localPlayer:FindFirstChildOfClass("PlayerGui")
    end
end

local function updateChams(esp, character, color)
    local hl = esp.highlight
    if not hl or not hl.Parent then
        local ok, created = pcall(function()
            local h = Instance.new("Highlight")
            h.Parent = highlightParent
            return h
        end)
        if not ok then
            return
        end
        hl = created
        esp.highlight = hl
    end

    hl.Adornee = character
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.FillColor = S.ChamsUseColor and color or S.ChamsFillColor
    hl.OutlineColor = S.ChamsUseColor and color or S.ChamsOutlineColor
    hl.FillTransparency = S.ChamsFillTransparency
    hl.OutlineTransparency = S.ChamsOutlineTransparency
    hl.Enabled = true
end

--// Create / hide / remove
local function createEsp(player)
    if cache[player] then
        return
    end

    local esp = {
        player = player,
        cornerLines = {},
        footLines = {},
        skeleton = {},
        skeletonChar = nil,
        highlight = nil,
        isFriend = false,
        teammate = false,
        dist = math.huge,
    }

    esp.boxFill = create("Square", {Filled = true, Color = S.BoxColor, Visible = false})
    esp.boxOutline = create("Square", {Color = S.BoxOutlineColor, Thickness = 3, Filled = false, Visible = false})
    esp.box = create("Square", {Color = S.BoxColor, Thickness = 1, Filled = false, Visible = false})
    esp.tracer = create("Line", {Thickness = S.TracerThickness, Color = S.TracerColor, Transparency = 1, Visible = false})
    esp.healthOutline = create("Line", {Thickness = 3, Color = S.HealthOutlineColor, Visible = false})
    esp.health = create("Line", {Thickness = 1, Visible = false})
    esp.lookLine = create("Line", {Thickness = 1, Color = S.LookLineColor, Visible = false})
    esp.headDot = create("Circle", {Thickness = 1, NumSides = 16, Radius = 3, Filled = true, Visible = false})
    esp.arrow = create("Triangle", {Filled = true, Color = S.ArrowColor, Visible = false})
    esp.radarDot = create("Circle", {Radius = 3, NumSides = 12, Filled = true, Visible = false})

    local function text(size)
        return create("Text", {Outline = true, Center = true, Size = size, Color = Color3.new(1, 1, 1), Visible = false})
    end
    esp.name = text(13)
    esp.team = text(12)
    esp.tool = text(12)
    esp.distance = text(12)
    esp.speed = text(12)
    esp.healthText = text(11)

    cache[player] = esp

    -- IsFriendsWith يسوي طلب شبكة، نسويه بخيط منفصل
    task.spawn(function()
        local ok, result = pcall(function()
            return localPlayer:IsFriendsWith(player.UserId)
        end)
        if ok and cache[player] then
            cache[player].isFriend = result
        end
    end)
end

local function hideDrawn(esp)
    for _, key in ipairs(SINGLES) do
        if key ~= "arrow" and key ~= "radarDot" then
            esp[key].Visible = false
        end
    end
    for _, line in ipairs(esp.cornerLines) do
        line.Visible = false
    end
    for _, line in ipairs(esp.footLines) do
        line.Visible = false
    end
    for _, data in ipairs(esp.skeleton) do
        data[1].Visible = false
    end
end

local function hideAll(esp)
    hideDrawn(esp)
    esp.arrow.Visible = false
    esp.radarDot.Visible = false
    if esp.highlight then
        esp.highlight.Enabled = false
    end
end

local function clearSkeleton(esp)
    for _, data in ipairs(esp.skeleton) do
        safeRemove(data[1])
    end
    esp.skeleton = {}
    esp.skeletonChar = nil
end

local function removeEsp(player)
    local esp = cache[player]
    if not esp then
        return
    end

    for _, key in ipairs(SINGLES) do
        safeRemove(esp[key])
    end
    for _, line in ipairs(esp.cornerLines) do
        safeRemove(line)
    end
    for _, line in ipairs(esp.footLines) do
        safeRemove(line)
    end
    clearSkeleton(esp)
    if esp.highlight then
        pcall(function()
            esp.highlight:Destroy()
        end)
    end

    cache[player] = nil
    teamCache[player] = nil
end

--// Corner box
local function ensureCornerLines(esp)
    if #esp.cornerLines > 0 then
        return
    end
    -- 1-8 outline أسود، 9-16 الخطوط الملونة فوقها
    for i = 1, 16 do
        esp.cornerLines[i] = create("Line", {
            Thickness = i <= 8 and 3 or 1,
            Color = i <= 8 and S.BoxOutlineColor or S.BoxColor,
            Transparency = 1,
            Visible = false,
        })
    end
end

local function drawCornerBox(esp, x, y, w, h, color, alpha)
    ensureCornerLines(esp)
    local lw, lh = w / 4, h / 5
    local segments = {
        {Vec2(x, y), Vec2(x + lw, y)},
        {Vec2(x, y), Vec2(x, y + lh)},
        {Vec2(x + w - lw, y), Vec2(x + w, y)},
        {Vec2(x + w, y), Vec2(x + w, y + lh)},
        {Vec2(x, y + h - lh), Vec2(x, y + h)},
        {Vec2(x, y + h), Vec2(x + lw, y + h)},
        {Vec2(x + w - lw, y + h), Vec2(x + w, y + h)},
        {Vec2(x + w, y + h - lh), Vec2(x + w, y + h)},
    }

    for i, seg in ipairs(segments) do
        local outline = esp.cornerLines[i]
        outline.From, outline.To = seg[1], seg[2]
        outline.Color = S.BoxOutlineColor
        outline.Transparency = alpha
        outline.Visible = true

        local colored = esp.cornerLines[i + 8]
        colored.From, colored.To = seg[1], seg[2]
        colored.Color = color
        colored.Transparency = alpha
        colored.Visible = true
    end
end

local function hideCorner(esp)
    for _, line in ipairs(esp.cornerLines) do
        line.Visible = false
    end
end

--// Foot circle (دائرة على الأرض تحت اللاعب، بمنظور حقيقي)
local function ensureFootLines(esp, n)
    local lines = esp.footLines
    while #lines < n do
        lines[#lines + 1] = create("Line", {Thickness = 1, Transparency = 1, Visible = false})
    end
    while #lines > n do
        safeRemove(table.remove(lines))
    end
end

local function drawFootCircle(esp, rootPart, humanoid, color, alpha)
    local n = clamp(floor(S.FootCircleSegments), 8, 64)
    ensureFootLines(esp, n)

    local feetOffset
    if humanoid.RigType == Enum.HumanoidRigType.R6 then
        feetOffset = 3
    else
        feetOffset = rootPart.Size.Y / 2 + humanoid.HipHeight
    end

    local center = rootPart.Position
    local groundY = center.Y - feetOffset

    local radius = S.FootCircleRadius
    if S.FootCirclePulse then
        radius = radius * (1 + 0.12 * sin(os.clock() * 3))
    end
    local spin = S.FootCircleSpin and os.clock() * 1.5 or 0

    local lines = esp.footLines
    local prev, prevOk
    for i = 0, n do
        local angle = spin + (i / n) * pi * 2
        local world = Vec3(center.X + cos(angle) * radius, groundY, center.Z + sin(angle) * radius)
        local p = camera:WorldToViewportPoint(world)
        local ok = p.Z > 0
        local point = Vec2(p.X, p.Y)

        if i > 0 then
            local line = lines[i]
            if prevOk and ok and (not S.FootCircleDashed or i % 2 == 0) then
                line.From = prev
                line.To = point
                line.Color = color
                line.Thickness = S.FootCircleThickness
                line.Transparency = alpha
                line.Visible = true
            else
                line.Visible = false
            end
        end

        prev, prevOk = point, ok
    end
end

local function hideFoot(esp)
    for _, line in ipairs(esp.footLines) do
        line.Visible = false
    end
end

--// Skeleton
local function buildSkeleton(esp, character)
    clearSkeleton(esp)

    local bones = character:FindFirstChild("UpperTorso") and BONES_R15 or BONES_R6
    for _, pair in ipairs(bones) do
        if character:FindFirstChild(pair[1]) and character:FindFirstChild(pair[2]) then
            local line = create("Line", {Thickness = 1, Color = S.SkeletonsColor, Transparency = 1, Visible = false})
            esp.skeleton[#esp.skeleton + 1] = {line, pair[1], pair[2]}
        end
    end
    esp.skeletonChar = character
end

local function drawSkeleton(esp, character, color, alpha)
    if esp.skeletonChar ~= character then
        buildSkeleton(esp, character)
    end

    for _, data in ipairs(esp.skeleton) do
        local line = data[1]
        local partA = character:FindFirstChild(data[2])
        local partB = character:FindFirstChild(data[3])

        if partA and partB then
            local a = camera:WorldToViewportPoint(partA.Position)
            local b = camera:WorldToViewportPoint(partB.Position)
            if a.Z > 0 and b.Z > 0 then
                line.From = Vec2(a.X, a.Y)
                line.To = Vec2(b.X, b.Y)
                line.Color = color
                line.Transparency = alpha
                line.Visible = true
            else
                line.Visible = false
            end
        else
            line.Visible = false
        end
    end
end

--// Off-screen arrow
local function drawArrow(esp, rootPart, color)
    local obj = frame.yaw:PointToObjectSpace(rootPart.Position)
    local dir = Vec2(obj.X, obj.Z)
    if dir.Magnitude < 0.001 then
        esp.arrow.Visible = false
        return
    end
    dir = dir.Unit

    local center = frame.vp / 2
    local radius = min(S.ArrowRadius, min(frame.vp.X, frame.vp.Y) / 2 - 30)
    local size = S.ArrowSize
    local perp = Vec2(-dir.Y, dir.X)
    local tip = center + dir * radius
    local baseCenter = center + dir * (radius - size)

    esp.arrow.PointA = tip
    esp.arrow.PointB = baseCenter + perp * (size * 0.5)
    esp.arrow.PointC = baseCenter - perp * (size * 0.5)
    esp.arrow.Color = color
    esp.arrow.Visible = true
end

--// Radar dot
local function drawRadarDot(esp, rootPart, color)
    local dot = esp.radarDot
    local radius = S.RadarSize / 2
    local obj = frame.yaw:PointToObjectSpace(rootPart.Position)
    local rel = Vec2(obj.X, obj.Z) / S.RadarRange * radius

    if rel.Magnitude > radius - 3 then
        if not S.RadarClamp then
            dot.Visible = false
            return
        end
        rel = rel.Unit * (radius - 3)
    end

    dot.Position = frame.radarCenter + rel
    dot.Color = color
    dot.Visible = true
end

--// تحديث لاعب واحد (يرجع info للـ HUD أو nil)
local function updatePlayer(esp)
    local player = esp.player
    local character = player.Character
    if not character then
        return hideAll(esp)
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    local head = character:FindFirstChild("Head")
    if not (humanoid and rootPart and head) or humanoid.Health <= 0 then
        return hideAll(esp)
    end

    local dist = esp.dist
    if dist > S.MaxDistance or dist < S.MinDistance then
        return hideAll(esp)
    end
    if frame.allowed and not frame.allowed[esp] then
        return hideAll(esp)
    end
    if S.Teamcheck and esp.teammate then
        return hideAll(esp)
    end
    if S.WallCheck and isBehindWall(character, rootPart) then
        return hideAll(esp)
    end

    local override = getOverrideColor(player, esp)
    local teamName, teamColor = getTeam(player)

    local toolName
    if S.ShowTool or S.ShowPlayerList then
        toolName = getHeldToolName(player, character)
    end

    local info
    if S.ShowPlayerList or S.ProximityAlert then
        info = {
            name = S.UseDisplayName and player.DisplayName or player.Name,
            dist = dist,
            color = override or S.NameColor,
            team = teamName,
            tool = toolName,
            teammate = esp.teammate,
        }
    end

    -- Chams + Radar ما يعتمدون على إن اللاعب بالشاشة
    if S.ShowChams then
        updateChams(esp, character, override or S.ChamsFillColor)
    elseif esp.highlight then
        esp.highlight.Enabled = false
    end

    if S.ShowRadar then
        drawRadarDot(esp, rootPart, override or (esp.teammate and S.AllyColor or S.EnemyColor))
    else
        esp.radarDot.Visible = false
    end

    local rootPos, onScreen = camera:WorldToViewportPoint(rootPart.Position)
    if not onScreen or rootPos.Z <= 0 then
        hideDrawn(esp)
        if S.ShowArrows then
            drawArrow(esp, rootPart, override or S.ArrowColor)
        else
            esp.arrow.Visible = false
        end
        return info
    end
    esp.arrow.Visible = false

    -- شفافية + حجم نص حسب المسافة
    local alpha = 1
    if S.DistanceFade then
        alpha = clamp(1 - dist / S.MaxDistance, 0.3, 1)
    end
    local textSize = S.TextSize
    if S.ScaleText then
        textSize = clamp(floor(S.TextSize * clamp(120 / max(dist, 1), 0.7, 1.3) + 0.5), 8, 20)
    end

    -- حجم الصندوق
    local topPos = camera:WorldToViewportPoint(rootPart.Position + Vec3(0, 2.8, 0))
    local bottomPos = camera:WorldToViewportPoint(rootPart.Position - Vec3(0, 3.2, 0))
    local height = math.abs(bottomPos.Y - topPos.Y)
    local width = height * 0.55

    local boxSize = Vec2(floor(width), floor(height))
    local boxPos = Vec2(floor(rootPos.X - width / 2), floor(topPos.Y))
    local centerX = boxPos.X + boxSize.X / 2

    -- Box
    if S.ShowBox then
        local boxColor = override or S.BoxColor
        if S.BoxType == "Corner Box Esp" then
            drawCornerBox(esp, boxPos.X, boxPos.Y, boxSize.X, boxSize.Y, boxColor, alpha)
            esp.box.Visible = false
            esp.boxOutline.Visible = false
        else
            esp.boxOutline.Size = boxSize
            esp.boxOutline.Position = boxPos
            esp.boxOutline.Color = S.BoxOutlineColor
            esp.boxOutline.Transparency = alpha
            esp.boxOutline.Visible = true

            esp.box.Size = boxSize
            esp.box.Position = boxPos
            esp.box.Color = boxColor
            esp.box.Transparency = alpha
            esp.box.Visible = true
            hideCorner(esp)
        end

        if S.BoxFill then
            esp.boxFill.Size = boxSize
            esp.boxFill.Position = boxPos
            esp.boxFill.Color = boxColor
            esp.boxFill.Transparency = S.BoxFillTransparency * alpha
            esp.boxFill.Visible = true
        else
            esp.boxFill.Visible = false
        end
    else
        esp.box.Visible = false
        esp.boxOutline.Visible = false
        esp.boxFill.Visible = false
        hideCorner(esp)
    end

    -- فوق الصندوق: الاسم، وفوقه اسم الفريق
    local topY = boxPos.Y - (textSize + 3)
    if S.ShowName then
        esp.name.Text = S.UseDisplayName and player.DisplayName or player.Name
        esp.name.Size = textSize
        esp.name.Position = Vec2(centerX, topY)
        esp.name.Color = override or S.NameColor
        esp.name.Transparency = alpha
        esp.name.Visible = true
        topY = topY - (textSize + 1)
    else
        esp.name.Visible = false
    end

    if S.ShowTeam then
        local label = teamName
        if not label and S.ShowNoTeam then
            label = S.NoTeamText
        end

        if label then
            esp.team.Text = "[" .. label .. "]"
            esp.team.Size = max(textSize - 1, 8)
            esp.team.Position = Vec2(centerX, topY)
            esp.team.Color = override or ((S.TeamTextUseTeamColor and teamColor) or S.TeamTextColor)
            esp.team.Transparency = alpha
            esp.team.Visible = true
        else
            esp.team.Visible = false
        end
    else
        esp.team.Visible = false
    end

    -- Health bar + text
    if S.ShowHealth or S.ShowHealthText then
        local percent = clamp(humanoid.Health / max(humanoid.MaxHealth, 1), 0, 1)
        local healthColor = S.HealthLowColor:Lerp(S.HealthHighColor, percent)
        local x = boxPos.X - 5
        local bottomY = boxPos.Y + boxSize.Y

        if S.ShowHealth then
            esp.healthOutline.From = Vec2(x, bottomY + 1)
            esp.healthOutline.To = Vec2(x, boxPos.Y - 1)
            esp.healthOutline.Color = S.HealthOutlineColor
            esp.healthOutline.Visible = true

            esp.health.From = Vec2(x, bottomY)
            esp.health.To = Vec2(x, bottomY - boxSize.Y * percent)
            esp.health.Color = healthColor
            esp.health.Visible = true
        else
            esp.healthOutline.Visible = false
            esp.health.Visible = false
        end

        if S.ShowHealthText then
            esp.healthText.Text = tostring(floor(humanoid.Health))
            esp.healthText.Position = Vec2(x - 12, bottomY - boxSize.Y * percent - 6)
            esp.healthText.Color = healthColor
            esp.healthText.Visible = true
        else
            esp.healthText.Visible = false
        end
    else
        esp.healthOutline.Visible = false
        esp.health.Visible = false
        esp.healthText.Visible = false
    end

    -- تحت الصندوق: الأداة (فوق) ثم المسافة ثم السرعة
    local textY = boxPos.Y + boxSize.Y + 3
    local step = textSize + 1

    if S.ShowTool then
        local label = toolName
        if not label and S.ShowEmptyTool then
            label = S.EmptyToolText
        end

        if label then
            esp.tool.Text = label
            esp.tool.Size = textSize
            esp.tool.Position = Vec2(centerX, textY)
            esp.tool.Color = override or S.ToolColor
            esp.tool.Transparency = alpha
            esp.tool.Visible = true
            textY = textY + step
        else
            esp.tool.Visible = false
        end
    else
        esp.tool.Visible = false
    end

    if S.ShowDistance then
        esp.distance.Text = string.format("[%d%s]", floor(dist + 0.5), S.DistanceSuffix)
        esp.distance.Size = textSize
        esp.distance.Position = Vec2(centerX, textY)
        esp.distance.Color = override or S.DistanceColor
        esp.distance.Transparency = alpha
        esp.distance.Visible = true
        textY = textY + step
    else
        esp.distance.Visible = false
    end

    if S.ShowSpeed then
        local speed = rootPart.AssemblyLinearVelocity.Magnitude
        esp.speed.Text = string.format("%d sps", floor(speed + 0.5))
        esp.speed.Size = max(textSize - 1, 8)
        esp.speed.Position = Vec2(centerX, textY)
        esp.speed.Color = override or S.SpeedColor
        esp.speed.Transparency = alpha
        esp.speed.Visible = true
    else
        esp.speed.Visible = false
    end

    -- دائرة الأرض
    if S.ShowFootCircle then
        drawFootCircle(esp, rootPart, humanoid, override or S.FootCircleColor, alpha)
    else
        hideFoot(esp)
    end

    -- نقطة الرأس
    if S.ShowHeadDot then
        local headPos = camera:WorldToViewportPoint(head.Position)
        if headPos.Z > 0 then
            esp.headDot.Position = Vec2(headPos.X, headPos.Y)
            esp.headDot.Radius = clamp(height * 0.05, 2, 12)
            esp.headDot.Filled = S.HeadDotFilled
            esp.headDot.Color = override or S.HeadDotColor
            esp.headDot.Transparency = alpha
            esp.headDot.Visible = true
        else
            esp.headDot.Visible = false
        end
    else
        esp.headDot.Visible = false
    end

    -- خط اتجاه النظر
    if S.ShowLookLine then
        local from = camera:WorldToViewportPoint(head.Position)
        local to = camera:WorldToViewportPoint(head.Position + head.CFrame.LookVector * S.LookLineLength)
        if from.Z > 0 and to.Z > 0 then
            esp.lookLine.From = Vec2(from.X, from.Y)
            esp.lookLine.To = Vec2(to.X, to.Y)
            esp.lookLine.Color = override or S.LookLineColor
            esp.lookLine.Transparency = alpha
            esp.lookLine.Visible = true
        else
            esp.lookLine.Visible = false
        end
    else
        esp.lookLine.Visible = false
    end

    -- Skeleton
    if S.ShowSkeletons then
        drawSkeleton(esp, character, override or S.SkeletonsColor, alpha)
    else
        for _, data in ipairs(esp.skeleton) do
            data[1].Visible = false
        end
    end

    -- Tracer
    if S.ShowTracer then
        local viewport = frame.vp
        local originY
        if S.TracerPosition == "Top" then
            originY = 0
        elseif S.TracerPosition == "Middle" then
            originY = viewport.Y / 2
        else
            originY = viewport.Y
        end

        esp.tracer.From = Vec2(viewport.X / 2, originY)
        esp.tracer.To = Vec2(rootPos.X, rootPos.Y)
        esp.tracer.Color = override or S.TracerColor
        esp.tracer.Thickness = S.TracerThickness
        esp.tracer.Transparency = alpha
        esp.tracer.Visible = true
    else
        esp.tracer.Visible = false
    end

    return info
end

--// HUD
local function updateHud(entries)
    -- قائمة اللاعبين
    if S.ShowPlayerList and #entries > 0 then
        table.sort(entries, function(a, b)
            return a.dist < b.dist
        end)

        local count = min(#entries, S.ListMax)
        for i = 1, count do
            local t = listTexts[i]
            if not t then
                t = create("Text", {Outline = true, Center = false, Size = 13, Color = Color3.new(1, 1, 1), Visible = false})
                listTexts[i] = t
            end

            local e = entries[i]
            local parts = {e.name}
            if e.team then
                parts[#parts + 1] = "[" .. e.team .. "]"
            end
            if e.tool then
                parts[#parts + 1] = "{" .. e.tool .. "}"
            end
            parts[#parts + 1] = string.format("%d%s", floor(e.dist + 0.5), S.DistanceSuffix)

            t.Text = table.concat(parts, " ")
            t.Position = S.ListPosition + Vec2(0, (i - 1) * 15)
            t.Color = e.color
            t.Visible = true
        end
        for i = count + 1, #listTexts do
            listTexts[i].Visible = false
        end
    else
        for _, t in ipairs(listTexts) do
            t.Visible = false
        end
    end

    -- تنبيه القرب
    if S.ProximityAlert then
        local nearest
        for _, e in ipairs(entries) do
            if not e.teammate and e.dist <= S.AlertDistance and (not nearest or e.dist < nearest.dist) then
                nearest = e
            end
        end

        if nearest then
            alertText.Text = string.format("[!] %s  %d%s", nearest.name, floor(nearest.dist + 0.5), S.DistanceSuffix)
            alertText.Position = Vec2(frame.vp.X / 2, 60)
            alertText.Visible = true
        else
            alertText.Visible = false
        end
    else
        alertText.Visible = false
    end
end

--// Main loop
local function hideEverything()
    for _, esp in pairs(cache) do
        hideAll(esp)
    end
    hideRadarBase()
    hideHud()
end

local function updateEsp()
    camera = workspace.CurrentCamera
    if not camera then
        return
    end

    if not S.Enabled then
        if not hiddenAll then
            hideEverything()
            hiddenAll = true
        end
        return
    end
    hiddenAll = false

    local now = os.clock()
    if S.UpdateRate > 0 and now - lastUpdate < 1 / S.UpdateRate then
        return
    end
    lastUpdate = now

    -- بيانات الفريم
    local camCF = camera.CFrame
    frame.camPos = camCF.Position
    frame.vp = camera.ViewportSize
    frame.rainbow = Color3.fromHSV((now * S.RainbowSpeed) % 1, 1, 1)

    local look = camCF.LookVector
    local flat = Vec3(look.X, 0, look.Z)
    if flat.Magnitude > 0.01 then
        frame.yaw = CFrame.new(frame.camPos, frame.camPos + flat)
    end

    -- مرحلة أولى: المسافات + أقرب عدو + حد اللاعبين
    local candidates = {}
    local nearestDist = math.huge
    closestPlayer = nil

    for player, esp in pairs(cache) do
        local character = player.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if root then
            esp.dist = (root.Position - frame.camPos).Magnitude
            esp.teammate = isTeammate(player)
            candidates[#candidates + 1] = esp

            if not esp.teammate and esp.dist < nearestDist then
                nearestDist = esp.dist
                closestPlayer = player
            end
        else
            esp.dist = math.huge
        end
    end

    frame.allowed = nil
    if S.MaxPlayers > 0 and #candidates > S.MaxPlayers then
        table.sort(candidates, function(a, b)
            return a.dist < b.dist
        end)
        frame.allowed = {}
        for i = 1, S.MaxPlayers do
            frame.allowed[candidates[i]] = true
        end
    end

    updateRadarBase()

    -- مرحلة ثانية: الرسم
    local entries = {}
    for _, esp in pairs(cache) do
        local ok, info = pcall(updatePlayer, esp)
        if ok then
            if info then
                entries[#entries + 1] = info
            end
        else
            hideAll(esp)
        end
    end

    updateHud(entries)
end

--// Init
for _, player in ipairs(Players:GetPlayers()) do
    if player ~= localPlayer then
        createEsp(player)
    end
end

connections[#connections + 1] = Players.PlayerAdded:Connect(function(player)
    if player ~= localPlayer then
        createEsp(player)
    end
end)
connections[#connections + 1] = Players.PlayerRemoving:Connect(removeEsp)
connections[#connections + 1] = RunService.RenderStepped:Connect(updateEsp)

--// API
function S.ToggleAll(state)
    for key, value in pairs(S) do
        if type(value) == "boolean" and key:sub(1, 4) == "Show" then
            S[key] = state
        end
    end
end

function S.GetTeamOf(player)
    return getTeam(player)
end

local CONFIG_FOLDER = "ESP_Configs"

function S.Save(name)
    if not (writefile and makefolder and isfolder) then
        return false, "executor لا يدعم writefile"
    end

    local data = {}
    for key, value in pairs(S) do
        local t = typeof(value)
        if t == "boolean" or t == "number" or t == "string" then
            data[key] = value
        elseif t == "Color3" then
            data[key] = {__t = "c3", r = value.R, g = value.G, b = value.B}
        elseif t == "Vector2" then
            data[key] = {__t = "v2", x = value.X, y = value.Y}
        end
    end

    local ok, err = pcall(function()
        if not isfolder(CONFIG_FOLDER) then
            makefolder(CONFIG_FOLDER)
        end
        writefile(CONFIG_FOLDER .. "/" .. (name or "default") .. ".json", HttpService:JSONEncode(data))
    end)
    return ok, err
end

function S.Load(name)
    if not (readfile and isfile) then
        return false, "executor لا يدعم readfile"
    end

    local path = CONFIG_FOLDER .. "/" .. (name or "default") .. ".json"
    if not isfile(path) then
        return false, "الملف غير موجود"
    end

    local ok, err = pcall(function()
        local data = HttpService:JSONDecode(readfile(path))
        for key, value in pairs(data) do
            local current = S[key]
            if current ~= nil and type(current) ~= "function" then
                if type(value) == "table" then
                    if value.__t == "c3" and typeof(current) == "Color3" then
                        S[key] = Color3.new(value.r, value.g, value.b)
                    elseif value.__t == "v2" and typeof(current) == "Vector2" then
                        S[key] = Vec2(value.x, value.y)
                    end
                elseif typeof(value) == typeof(current) then
                    S[key] = value
                end
            end
        end
    end)
    return ok, err
end

function S.Unload()
    for _, connection in ipairs(connections) do
        connection:Disconnect()
    end
    connections = {}

    for player in pairs(cache) do
        removeEsp(player)
    end

    for _, d in pairs(radar) do
        safeRemove(d)
    end
    for _, t in ipairs(listTexts) do
        safeRemove(t)
    end
    listTexts = {}
    safeRemove(alertText)
end

return S
