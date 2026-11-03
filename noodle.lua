--!strict
-- LocalScript
-- Place in StarterPlayerScripts.
-- Dong with draggable adjuster GUI: length, jiggliness, pee toggle, RGB.
-- Pee emits unanchored ball parts with physics; Debris cleans after 3s.

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Debris           = game:GetService("Debris")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local settings = {
    length        = 1.7,
    jiggliness    = 0.5,
    shaftDiameter = 0.75,
    peeEnabled    = false,
    peeColor      = Color3.fromRGB(255, 255, 0), -- yellow
}

local currentModel, currentPivot, currentShaft, currentTip, currentMotor, currentTipWeld
local restC0 = CFrame.new()
local theta, omega = Vector2.new(0, 0), Vector2.new(0, 0)
local rootPart  = nil
local peeAccum  = 0
local PEE_RATE  = 70

local function jiggleParams()
    local j = math.clamp(settings.jiggliness, 0, 1)
    return 120 * (1 - j * 0.92) + 8, 12 * (1 - j * 0.85) + 1
end

local function build(character: Model)
    if character:FindFirstChild("DongAttachment") then return end
    local lowerTorso = character:FindFirstChild("LowerTorso") or character:FindFirstChild("Torso")
    if not lowerTorso or not lowerTorso:IsA("BasePart") then return end
    local rp = character:FindFirstChild("HumanoidRootPart")
    if not rp or not rp:IsA("BasePart") then rp = lowerTorso end
    rootPart = rp

    local torsoColor    = lowerTorso.Color
    local torsoMaterial = lowerTorso.Material

    local model = Instance.new("Model"); model.Name = "DongAttachment"

    local pivot = Instance.new("Part")
    pivot.Name = "Pivot"; pivot.Size = Vector3.new(0.2, 0.2, 0.2)
    pivot.Transparency = 1; pivot.CanCollide = false
    pivot.CanQuery = false; pivot.CanTouch = false; pivot.Massless = true
    pivot.CFrame = lowerTorso.CFrame * CFrame.new(0, -0.2, -0.5)
    pivot.Parent = model

    local pw = Instance.new("WeldConstraint")
    pw.Part0 = pivot; pw.Part1 = lowerTorso; pw.Parent = pivot

    local shaft = Instance.new("Part")
    shaft.Name = "Shaft"; shaft.Shape = Enum.PartType.Cylinder
    shaft.Size = Vector3.new(settings.length, settings.shaftDiameter, settings.shaftDiameter)
    shaft.Color = torsoColor; shaft.Material = torsoMaterial
    shaft.CanCollide = false; shaft.CanQuery = false
    shaft.CanTouch = false; shaft.Massless = true
    shaft.TopSurface = Enum.SurfaceType.Smooth
    shaft.BottomSurface = Enum.SurfaceType.Smooth
    shaft.Parent = model

    restC0 = CFrame.new(0, 0, -settings.length / 2) * CFrame.Angles(0, math.rad(90), 0)
    shaft.CFrame = pivot.CFrame * restC0

    local motor = Instance.new("Motor6D")
    motor.Name = "JiggleMotor"; motor.Part0 = pivot; motor.Part1 = shaft
    motor.C0 = restC0; motor.C1 = CFrame.new(); motor.Parent = pivot

    local tip = Instance.new("Part")
    tip.Name = "Tip"; tip.Shape = Enum.PartType.Ball
    local tipSz = settings.shaftDiameter * 1.05
    tip.Size = Vector3.new(tipSz, tipSz, tipSz)
    tip.Color = Color3.fromRGB(255, 120, 155)
    tip.Material = Enum.Material.SmoothPlastic
    tip.CanCollide = false; tip.CanQuery = false
    tip.CanTouch = false; tip.Massless = true
    tip.CFrame = shaft.CFrame * CFrame.new(settings.length / 2, 0, 0)
    tip.Parent = model

    local tipWeld = Instance.new("Weld")
    tipWeld.Name = "TipWeld"; tipWeld.Part0 = shaft; tipWeld.Part1 = tip
    tipWeld.C0 = CFrame.new(settings.length / 2, 0, 0)
    tipWeld.C1 = CFrame.new(); tipWeld.Parent = tip

    local ballSpecs = {
        { Vector3.new(-0.20, -0.42, -0.05), 0.72 },
        { Vector3.new( 0.20, -0.42, -0.05), 0.72 },
    }
    for i, spec in ipairs(ballSpecs) do
        local ball = Instance.new("Part")
        ball.Name = "Ball" .. i; ball.Shape = Enum.PartType.Ball
        ball.Size = Vector3.new(spec[2], spec[2], spec[2])
        ball.Color = torsoColor; ball.Material = SmoothPlastic
        ball.CanCollide = false; ball.CanQuery = false
        ball.CanTouch = false; ball.Massless = true
        ball.CFrame = pivot.CFrame * CFrame.new(spec[1])
        ball.Parent = model
        local bw = Instance.new("WeldConstraint")
        bw.Part0 = pivot; bw.Part1 = ball; bw.Parent = ball
    end

    model.Parent = character
    currentModel, currentPivot, currentShaft, currentTip, currentMotor, currentTipWeld =
        model, pivot, shaft, tip, motor, tipWeld
    theta, omega = Vector2.new(0, 0), Vector2.new(0, 0)
end

-- Jiggle loop
RunService.Heartbeat:Connect(function(dt: number)
    if not currentModel or not currentModel.Parent then return end
    if not currentMotor or not rootPart or not rootPart.Parent then return end

    local rootCF    = rootPart.CFrame
    local localVel  = rootCF:VectorToObjectSpace(rootPart.AssemblyLinearVelocity)
    local stiffness, damp = jiggleParams()
    local t = os.clock()

    local fx =  localVel.Z * 1.4 + math.sin(t * 1.7) * 0.35
    local fy = -localVel.X * 1.8 + math.sin(t * 1.3) * 0.25

    local ax = -stiffness * theta.X + fx - damp * omega.X
    local ay = -stiffness * theta.Y + fy - damp * omega.Y
    omega = Vector2.new(omega.X + ax * dt, omega.Y + ay * dt)
    theta = Vector2.new(
        math.clamp(theta.X + omega.X * dt, -0.65, 0.65),
        math.clamp(theta.Y + omega.Y * dt, -0.65, 0.65)
    )

    currentMotor.C0 = restC0 * CFrame.Angles(theta.X, theta.Y, 0)
end)

-- Pee loop
RunService.Heartbeat:Connect(function(dt: number)
    if not settings.peeEnabled then peeAccum = 0; return end
    if not currentTip or not currentTip.Parent then return end
    if not currentPivot or not currentPivot.Parent then return end

    peeAccum = peeAccum + dt * PEE_RATE
    while peeAccum >= 1 do
        peeAccum = peeAccum - 1

        local tipPos = currentTip.CFrame.Position
        local dir    = tipPos - currentPivot.CFrame.Position
        if dir.Magnitude >= 0.01 then
            dir = dir.Unit

            local p = Instance.new("Part")
            p.Shape = Enum.PartType.Ball
            local size = 0.10 + math.random() * 0.06
            p.Size = Vector3.new(size, size, size)
            p.Color = settings.peeColor
            p.Material = Enum.Material.SmoothPlastic
            p.Anchored = false
            p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
            p.CFrame = CFrame.new(tipPos + dir * 0.15)
            p.Velocity = dir * (28 + math.random() * 8) + Vector3.new(
                (math.random() - 0.5) * 4,
                (math.random() - 0.5) * 3 + 1,
                (math.random() - 0.5) * 4
            )
            p.Parent = workspace
            Debris:AddItem(p, 3)
        end
    end
end)

-- Character bootstrap
local function onCharacter(char: Model)
    char:WaitForChild("Humanoid", 10)
    task.wait(0.15)
    build(char)
end

if player.Character then
    onCharacter(player.Character)
end
player.CharacterAdded:Connect(onCharacter)

-- ---- GUI ----
local existing = playerGui:FindFirstChild("DongGUI")
if existing then existing:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "DongGUI"; gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 260, 0, 380)
frame.Position = UDim2.new(0, 20, 0, 20)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
frame.BorderSizePixel = 0; frame.Active = true; frame.Parent = gui

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 28)
header.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
header.BorderSizePixel = 0; header.Active = true; header.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -30, 1, 0); title.BackgroundTransparency = 1
title.Text = "  Dong Adjuster"; title.TextColor3 = Color3.new(1, 1, 1)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = Enum.Font.Code; title.TextSize = 14; title.Active = false
title.Parent = header

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 28, 1, 0)
closeBtn.Position = UDim2.new(1, -28, 0, 0)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
closeBtn.BorderSizePixel = 0; closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.Font = Enum.Font.Code; closeBtn.TextSize = 14
closeBtn.Parent = header
closeBtn.MouseButton1Click:Connect(function() gui.Enabled = false end)

local body = Instance.new("Frame")
body.Size = UDim2.new(1, -16, 1, -36)
body.Position = UDim2.new(0, 8, 0, 32)
body.BackgroundTransparency = 1; body.Parent = frame

local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 6)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = body

local function makeSlider(label: string, minV, maxV, initV, order, format, onChange)
    format = format or "%.2f"
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 32)
    row.BackgroundTransparency = 1; row.LayoutOrder = order; row.Parent = body

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 14); lbl.BackgroundTransparency = 1
    lbl.Text = string.format("%s: " .. format, label, initV)
    lbl.TextColor3 = Color3.new(1, 1, 1)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Font = Enum.Font.Code; lbl.TextSize = 12; lbl.Parent = row

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, 0, 0, 6)
    track.Position = UDim2.new(0, 0, 0, 20)
    track.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
    track.BorderSizePixel = 0; track.Parent = row

    local initRel = (initV - minV) / (maxV - minV)
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(initRel, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(100, 170, 255)
    fill.BorderSizePixel = 0; fill.Parent = track

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 10, 0, 10)
    knob.Position = UDim2.new(initRel, -5, 0.5, -5)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.BorderSizePixel = 0; knob.ZIndex = 2; knob.Parent = track

    local dragging = false
    local function setFromX(x: number)
        local ap, asz = track.AbsolutePosition, track.AbsoluteSize
        local rel = math.clamp((x - ap.X) / asz.X, 0, 1)
        local value = minV + (maxV - minV) * rel
        fill.Size = UDim2.new(rel, 0, 1, 0)
        knob.Position = UDim2.new(rel, -5, 0.5, -5)
        lbl.Text = string.format("%s: " .. format, label, value)
        if onChange then onChange(value) end
    end

    track.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            setFromX(inp.Position.X)
        end
    end)
    knob.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true
        end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if not dragging then return end
        if inp.UserInputType == Enum.UserInputType.MouseMovement
        or inp.UserInputType == Enum.UserInputType.Touch then
            setFromX(inp.Position.X)
        end
    end)
end

makeSlider("Length", 0.4, 4.0, settings.length, 1, "%.2f", function(v)
    settings.length = v
    if not currentShaft then return end
    currentShaft.Size = Vector3.new(v, settings.shaftDiameter, settings.shaftDiameter)
    restC0 = CFrame.new(0, 0, -v / 2) * CFrame.Angles(0, math.rad(90), 0)
    if currentMotor then
        currentMotor.C0 = restC0 * CFrame.Angles(theta.X, theta.Y, 0)
    end
    if currentTipWeld then
        currentTipWeld.C0 = CFrame.new(v / 2, 0, 0)
    end
end)

makeSlider("Jiggliness", 0, 1, settings.jiggliness, 2, "%.2f", function(v)
    settings.jiggliness = v
end)

-- Pee toggle
local peeRow = Instance.new("Frame")
peeRow.Size = UDim2.new(1, 0, 0, 26); peeRow.BackgroundTransparency = 1
peeRow.LayoutOrder = 3; peeRow.Parent = body

local peeLabel = Instance.new("TextLabel")
peeLabel.Size = UDim2.new(0, 70, 1, 0); peeLabel.BackgroundTransparency = 1
peeLabel.Text = "Pee:"; peeLabel.TextColor3 = Color3.new(1, 1, 1)
peeLabel.TextXAlignment = Enum.TextXAlignment.Left
peeLabel.Font = Enum.Font.Code; peeLabel.TextSize = 12; peeLabel.Parent = peeRow

local peeBtn = Instance.new("TextButton")
peeBtn.Size = UDim2.new(0, 60, 1, 0); peeBtn.Position = UDim2.new(0, 80, 0, 0)
peeBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
peeBtn.BorderSizePixel = 0; peeBtn.Text = "OFF"
peeBtn.TextColor3 = Color3.new(1, 1, 1)
peeBtn.Font = Enum.Font.Code; peeBtn.TextSize = 12; peeBtn.Parent = peeRow

peeBtn.MouseButton1Click:Connect(function()
    settings.peeEnabled = not settings.peeEnabled
    if settings.peeEnabled then
        peeBtn.BackgroundColor3 = Color3.fromRGB(80, 180, 80); peeBtn.Text = "ON"
    else
        peeBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80); peeBtn.Text = "OFF"
    end
end)

-- Preview row (declared before sliders so updatePreview can reference it)
local previewRow = Instance.new("Frame")
previewRow.Size = UDim2.new(1, 0, 0, 22)
previewRow.BackgroundTransparency = 1
previewRow.LayoutOrder = 100; previewRow.Parent = body

local previewLabel = Instance.new("TextLabel")
previewLabel.Size = UDim2.new(0, 90, 1, 0); previewLabel.BackgroundTransparency = 1
previewLabel.Text = "Pee color:"; previewLabel.TextColor3 = Color3.new(1, 1, 1)
previewLabel.TextXAlignment = Enum.TextXAlignment.Left
previewLabel.Font = Enum.Font.Code; previewLabel.TextSize = 12
previewLabel.Parent = previewRow

local previewBox = Instance.new("Frame")
previewBox.Size = UDim2.new(0, 60, 1, 0); previewBox.Position = UDim2.new(0, 100, 0, 0)
previewBox.BackgroundColor3 = settings.peeColor
previewBox.BorderSizePixel = 0; previewBox.Parent = previewRow

local function updatePreview()
    previewBox.BackgroundColor3 = settings.peeColor
end

makeSlider("Pee R", 0, 255, settings.peeColor.R * 255, 4, "%.0f", function(v)
    settings.peeColor = Color3.new(v / 255, settings.peeColor.G, settings.peeColor.B)
    updatePreview()
end)
makeSlider("Pee G", 0, 255, settings.peeColor.G * 255, 5, "%.0f", function(v)
    settings.peeColor = Color3.new(settings.peeColor.R, v / 255, settings.peeColor.B)
    updatePreview()
end)
makeSlider("Pee B", 0, 255, settings.peeColor.B * 255, 6, "%.0f", function(v)
    settings.peeColor = Color3.new(settings.peeColor.R, settings.peeColor.G, v / 255)
    updatePreview()
end)

-- Frame dragging via header
local dragFrame = false
local dragStart: Vector3? = nil
local startPos: UDim2? = nil
header.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
    or inp.UserInputType == Enum.UserInputType.Touch then
        dragFrame = true
        dragStart = inp.Position
        startPos = frame.Position
    end
end)
UserInputService.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
    or inp.UserInputType == Enum.UserInputType.Touch then
        dragFrame = false
    end
end)
UserInputService.InputChanged:Connect(function(inp)
    if not dragFrame or not dragStart or not startPos then return end
    if inp.UserInputType == Enum.UserInputType.MouseMovement
    or inp.UserInputType == Enum.UserInputType.Touch then
        local delta = inp.Position - dragStart
        frame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)
