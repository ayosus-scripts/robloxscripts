--!strict
-- LocalScript
-- Place in StarterPlayerScripts.
-- Builds two torso-colored boobs (cylinder + rounded cap) on the chest,
-- each with an independent jiggle spring driven by body motion.
-- R6 and R15 compatible. No external dependencies.

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local settings = {
    size       = 5, -- boob diameter
    protrusion = 1, -- how far forward from torso surface
    jiggliness = 1,
}

local rigs: { any } = {}
local rootPart: BasePart? = nil

local function build(character: Model)
    if character:FindFirstChild("BoobAttachment") then return end

    local upperTorso =
        character:FindFirstChild("UpperTorso")
        or character:FindFirstChild("Torso")
    if not upperTorso or not upperTorso:IsA("BasePart") then return end

    local rp = character:FindFirstChild("HumanoidRootPart")
    if not rp or not rp:IsA("BasePart") then rp = upperTorso end

    local torsoColor    = upperTorso.Color
    local torsoMaterial = upperTorso.Material
    local torsoDepth    = upperTorso.Size.Z

    local model = Instance.new("Model")
    model.Name = "BoobAttachment"

    rigs = {}
    rootPart = rp

    local specs = {
        { offsetX = -0.42, side = -1, phase = 0.7 }, -- left
        { offsetX =  0.42, side =  1, phase = 2.1 }, -- right
    }

    local protrusion = settings.protrusion
    local frontZ     = -(torsoDepth / 2) + 0.05 -- pivot slightly inside torso surface

    for i, spec in ipairs(specs) do
        local pivot = Instance.new("Part")
        pivot.Name       = "Pivot" .. i
        pivot.Size       = Vector3.new(0.15, 0.15, 0.15)
        pivot.Transparency = 1
        pivot.CanCollide = false
        pivot.CanQuery   = false
        pivot.CanTouch   = false
        pivot.Massless   = true
        pivot.CFrame     = upperTorso.CFrame * CFrame.new(spec.offsetX, 0.15, frontZ)
        pivot.Parent     = model

        local pw = Instance.new("WeldConstraint")
        pw.Part0 = pivot
        pw.Part1 = upperTorso
        pw.Parent = pivot

        -- Cylinder body — Size.X is length (rotated to point forward),
        -- Size.Y / Size.Z are the circular diameter
        local body = Instance.new("Part")
        body.Name          = "Body" .. i
        body.Shape         = Enum.PartType.Cylinder
        body.Size          = Vector3.new(protrusion, settings.size, settings.size)
        body.Color         = torsoColor
        body.Material      = torsoMaterial
        body.CanCollide    = false
        body.CanQuery      = false
        body.CanTouch      = false
        body.Massless      = true
        body.TopSurface    = Enum.SurfaceType.Smooth
        body.BottomSurface = Enum.SurfaceType.Smooth
        body.Parent        = model

        -- +90 deg about Y so cylinder's X axis points along pivot's -Z (forward)
        local restC0 = CFrame.new(0, 0, -protrusion / 2) * CFrame.Angles(0, math.rad(90), 0)
        body.CFrame = pivot.CFrame * restC0

        local motor = Instance.new("Motor6D")
        motor.Name   = "JiggleMotor" .. i
        motor.Part0  = pivot
        motor.Part1  = body
        motor.C0     = restC0
        motor.C1     = CFrame.new()
        motor.Parent = pivot

        -- Rounded cap (ball) welded at the far front end of the cylinder
        local cap = Instance.new("Part")
        cap.Name       = "Cap" .. i
        cap.Shape      = Enum.PartType.Ball
        local capSize  = settings.size * 1.02
        cap.Size       = Vector3.new(capSize, capSize, capSize)
        cap.Color      = torsoColor
        cap.Material   = torsoMaterial
        cap.CanCollide = false
        cap.CanQuery   = false
        cap.CanTouch   = false
        cap.Massless   = true
        cap.CFrame     = body.CFrame * CFrame.new(protrusion / 2, 0, 0)
        cap.Parent     = model

        local cw = Instance.new("WeldConstraint")
        cw.Part0 = body
        cw.Part1 = cap
        cw.Parent = cap

        table.insert(rigs, {
            pivot   = pivot,
            body    = body,
            cap     = cap,
            motor   = motor,
            restC0  = restC0,
            theta   = Vector2.new(0, 0),
            omega   = Vector2.new(0, 0),
            side    = spec.side,
            phase   = spec.phase,
        })
    end

    model.Parent = character
end

RunService.Heartbeat:Connect(function(dt: number)
    if not rootPart or not rootPart.Parent then return end
    if #rigs == 0 then return end

    local rootCF   = rootPart.CFrame
    local localVel = rootCF:VectorToObjectSpace(rootPart.AssemblyLinearVelocity)
    local t        = os.clock()
    local j        = math.clamp(settings.jiggliness, 0, 1)
    local stiffness = 120 * (1 - j * 0.92) + 8
    local damp      = 12 * (1 - j * 0.85) + 1

    for _, rig in ipairs(rigs) do
        if not rig.body or not rig.body.Parent then continue end

        -- Body-velocity forcing
        local fx = localVel.Z * 1.2 + localVel.Y * 0.6 * rig.side
        local fy = -localVel.X * 1.6 * rig.side

        -- Idle breathing wobble (subtle)
        fx = fx + math.sin(t * 1.6 + rig.phase) * 1.8
        fy = fy + math.sin(t * 1.3 + rig.phase) * 1.0

        local ax = -stiffness * rig.theta.X + fx - damp * rig.omega.X
        local ay = -stiffness * rig.theta.Y + fy - damp * rig.omega.Y
        rig.omega = Vector2.new(rig.omega.X + ax * dt, rig.omega.Y + ay * dt)
        rig.theta = Vector2.new(
            math.clamp(rig.theta.X + rig.omega.X * dt, -0.7, 0.7),
            math.clamp(rig.theta.Y + rig.omega.Y * dt, -0.7, 0.7)
        )

        rig.motor.C0 = rig.restC0 * CFrame.Angles(rig.theta.X, rig.theta.Y, 0)
    end
end)

local function onCharacter(char: Model)
    char:WaitForChild("Humanoid", 10)
    task.wait(0.15)
    build(char)
end

if player.Character then
    onCharacter(player.Character)
end
player.CharacterAdded:Connect(onCharacter)
