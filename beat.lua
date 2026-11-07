-- compact KeyframeSequence reconstruction
local data = {{"Keyframe",0,{{"HumanoidRootPart",0,{0,0,0,1,0,0,0,1,0,0,0,1},"Linear","In",{{"Torso",0,{0,0,0,1,0,0,0,1,0,0,0,1},"Linear","In",{{"Right Arm",1,{-1.90734863e-06,-1.90734863e-06,0,0.838685334,-0.378326774,0.391759843,0.544616282,0.582606077,-0.603293657,4.47034836e-07,0.719332337,0.694666088},"CubicV2","InOut",{}}}}}}}},{"Keyframe",0.200000003,{{"HumanoidRootPart",0,{0,0,0,1,0,0,0,1,0,0,0,1},"Linear","In",{{"Torso",0,{0,0,0,1,0,0,0,1,0,0,0,1},"Linear","In",{{"Right Arm",1,{-3.81469727e-06,-1.43051147e-06,0,0.428025544,-0.814456284,0.391733378,0.78783673,0.123863518,-0.603300154,0.442840129,0.566849887,0.694675326},"CubicV2","InOut",{}}}}}}}},{"Keyframe",0.333333343,{{"HumanoidRootPart",0,{0,0,0,1,0,0,0,1,0,0,0,1},"Linear","In",{{"Torso",0,{0,0,0,1,0,0,0,1,0,0,0,1},"Linear","In",{{"Right Arm",1,{-1.90734863e-06,-1.90734863e-06,0,0.838685334,-0.378326774,0.391759843,0.544616282,0.582606077,-0.603293657,4.47034836e-07,0.719332337,0.694666088},"CubicV2","InOut",{}}}}}}}}}
local sequence = Instance.new("KeyframeSequence")
sequence.Name = "a"
sequence.Loop = true
sequence.Priority = Enum.AnimationPriority.Idle

local function makePose(d, parent)
	local pose = Instance.new("Pose")
	pose.Name = d[1]
	pose.Weight = d[2]

	pose.CFrame = CFrame.new(table.unpack(d[3]))

	pose.EasingStyle = Enum.PoseEasingStyle[d[4]]
	pose.EasingDirection = Enum.PoseEasingDirection[d[5]]

	pose.Parent = parent

	for _, childData in ipairs(d[6]) do
		makePose(childData, pose)
	end

	return pose
end

for _, d in ipairs(data) do
	local keyframe = Instance.new("Keyframe")
	keyframe.Name = d[1]
	keyframe.Time = d[2]
	keyframe.Parent = sequence

	for _, poseData in ipairs(d[3]) do
		makePose(poseData, keyframe)
	end
end

print("Recreated KeyframeSequence:", sequence.Name)

-- =========================================
-- playback (run this in a LocalScript)
-- =========================================

local Players = game:GetService("Players")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

local animationId
local currentTrack

-- playKeyframes(speed, looped)
-- both args optional. speed defaults to 1, looped defaults to the sequence's Loop.
-- returns the AnimationTrack so you can :Stop() it yourself.
local function playKeyframes(speed, looped)
	local player = Players.LocalPlayer
	local character = player and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	if not humanoid then
		warn("playKeyframes: no humanoid found on the local character")
		return nil
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	if not animationId then
		animationId = KeyframeSequenceProvider:RegisterKeyframeSequence(sequence)
	end

	if currentTrack then
		currentTrack:Stop()
	end

	local animation = Instance.new("Animation")
	animation.AnimationId = animationId

	currentTrack = animator:LoadAnimation(animation)
	currentTrack.Priority = sequence.Priority
	if looped == nil then
		currentTrack.Looped = sequence.Loop
	else
		currentTrack.Looped = looped
	end

	currentTrack:Play()
	currentTrack:AdjustSpeed(speed or 1)

	return currentTrack
end

-- stopKeyframes(fadeTime)
-- stops the animation (even if it's looping) and kills the loop.
-- nothing plays again until you call playKeyframes() again.
local function stopKeyframes(fadeTime)
	if currentTrack then
		currentTrack.Looped = false
		currentTrack:Stop(fadeTime or 0.1)
		currentTrack = nil
	end
end

-- example:
-- playKeyframes()
-- task.wait(5)
-- stopKeyframes()
wait(1)
playKeyframes(2, true)
