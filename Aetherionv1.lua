
repeat
    task.wait()
until game:IsLoaded();


local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Stats = game:GetService("Stats")


local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")


local Alive = Workspace:FindFirstChild("Alive")
local Aerodynamic = false
local Aerodynamic_Time = tick()
local Last_Input = UserInputService:GetLastInputType()
local Vector2_Mouse_Location = nil
local Grab_Parry = nil
local Parry_Key = nil
local Remotes = {}
local Parries = 0
local disableParryUntil = 0
local abilityLastUsed = 0
local Connections_Manager = {}
local Animation = {storage = {}, current = nil, track = nil}
local Parried = false
local Closest_Entity = nil
local spectate_Enabled = false
local manualSpamSpeed = 10
local pingBased = true
local TargetSelectionMethod = ""
setfpscap(60);
local Parry_Key = nil
local Remotes = {}
task.spawn(function()
    for _, Value in getgc() do
        if type(Value) == 'function' and islclosure(Value) then
            local Protos = debug.getprotos(Value)
            local Upvalues = debug.getupvalues(Value)
            local Constants = debug.getconstants(Value)
            if #Protos == 4 and #Upvalues == 24 and #Constants >= 102 then
                local c62 = Constants[62]
                local c64 = Constants[64]
                local c65 = Constants[65]
                Remotes[debug.getupvalue(Value, 16)] = c62
                Parry_Key = debug.getupvalue(Value, 17)
                Remotes[debug.getupvalue(Value, 18)] = c64
                Remotes[debug.getupvalue(Value, 19)] = c65
                break
            end
        end
    end
end)

local Key = Parry_Key;
local Auto_Parry = {};
Auto_Parry.Parry_Animation = function()
	local Parry_Animation = ReplicatedStorage.Shared.SwordAPI.Collection.Default:FindFirstChild("GrabParry");
	local Current_Sword = LocalPlayer.Character:GetAttribute("CurrentlyEquippedSword");
	if (not Current_Sword or not Parry_Animation) then
		return;
	end
	local Sword_Data = ReplicatedStorage.Shared.ReplicatedInstances.Swords.GetSword:Invoke(Current_Sword);
	if (not Sword_Data or not Sword_Data['AnimationType']) then
		return;
	end
	for _, object in pairs(ReplicatedStorage.Shared.SwordAPI.Collection:GetChildren()) do
		if (object.Name == Sword_Data['AnimationType']) then
			local sword_animation_type = (object:FindFirstChild("GrabParry") and "GrabParry") or "Grab";
			Parry_Animation = object[sword_animation_type];
		end
	end
	Grab_Parry = LocalPlayer.Character.Humanoid.Animator:LoadAnimation(Parry_Animation);
	Grab_Parry:Play();
end;
Auto_Parry.Play_Animation = function(animationName)
	local Animations = Animation.storage[animationName];
	if not Animations then
		return false;
	end
	local Animator = LocalPlayer.Character.Humanoid.Animator;
	if (Animation.track and Animation.track:IsA("AnimationTrack")) then
		Animation.track:Stop();
	end
	Animation.track = Animator:LoadAnimation(Animations);
	if (Animation.track and Animation.track:IsA("AnimationTrack")) then
		Animation.track:Play();
	end
	Animation.current = animationName;
end;
Auto_Parry.Get_Balls = function()
	local Balls = {};
	for _, instance in pairs(Workspace.Balls:GetChildren()) do
		if instance:GetAttribute("realBall") then
			instance.CanCollide = false;
			table.insert(Balls, instance);
		end
	end
	return Balls;
end;
Auto_Parry.Get_Ball = function()
	for _, instance in pairs(Workspace.Balls:GetChildren()) do
		if instance:GetAttribute("realBall") then
			instance.CanCollide = false;
			return instance;
		end
	end
end;

function Auto_Parry.Parry_Data()
	local Camera = workspace.CurrentCamera
	if not Camera then return {0, CFrame.new(), {}, {0, 0}} end

	local ViewportSize = Camera.ViewportSize
	local MouseLocation = (Last_Input == Enum.UserInputType.MouseButton1 or Last_Input == Enum.UserInputType.MouseButton2 or Last_Input == Enum.UserInputType.Keyboard)
		and UserInputService:GetMouseLocation()
		or Vector2.new(ViewportSize.X / 2, ViewportSize.Y / 2)

	local Used = {MouseLocation.X, MouseLocation.Y}

	if TargetSelectionMethod == "ClosestToPlayer" then
		Auto_Parry.Closest_Player()
		local targetPlayer = Closest_Entity
		if targetPlayer and targetPlayer.PrimaryPart then
			Used = targetPlayer.PrimaryPart.Position
		end
	end

	local Alive = workspace.Alive:GetChildren()
	local Events = table.create(#Alive)
	for _, v in ipairs(Alive) do
			Events[tostring(v)] = Camera:WorldToScreenPoint(v.PrimaryPart.Position)
	end

	local pos = Camera.CFrame.Position
	local look = Camera.CFrame.LookVector
	local up = Camera.CFrame.UpVector
	local right = Camera.CFrame.RightVector

	local directions = {
		Backwards = pos - look * 1000,
		Random = Vector3.new(math.random(-3000, 3000), math.random(-3000, 3000), math.random(-3000, 3000)),
		Straight = pos + look * 1000,
		Up = pos + up * 1000,
		Right = pos + right * 1000,
		Left = pos - right * 1000
	}

	local lookTarget = directions[Auto_Parry.Parry_Type] or (pos + look * 1000)
	local DirectionCF = CFrame.new(pos, lookTarget)

	return {0, DirectionCF, Events, Used}
end

--thanks to forum(0XCode4A.L)User(0xF00000)
local foundFake = false
for _, Args in pairs(Remotes) do
    if Args == "PARRY_HASH_FAKE_1" or Args == "_G" then
        foundFake = true
        break
    end
end
Auto_Parry.Parry = function()
    local Parry_Data = Auto_Parry.Parry_Data()
    for Remote, Args in pairs(Remotes) do
        local Hash
        if foundFake then
            Hash = nil
        else
            Hash = Args
        end
        Remote:FireServer(Hash, Key, Parry_Data[1], Parry_Data[2], Parry_Data[3], Parry_Data[4])
    end
    if Parries > 7 then
        return false
    end
    Parries += 1
    task.delay(0.5, function()
        if Parries > 0 then
            Parries -= 1
        end
    end)
end


local Lerp_Radians = 0;
local Last_Warping = tick();
Auto_Parry.Linear_Interpolation = function(a, b, time_volume)
	return a + ((b - a) * time_volume);
end;
local Previous_Velocity = {};
local Curving = tick();
Auto_Parry.Is_Curved = function()
    local Ball = Auto_Parry.Get_Ball();
    if not Ball then
        return false;
    end
    local Zoomies = Ball:FindFirstChild("zoomies");
    if not Zoomies then
        return false;
    end

    local Velocity = Zoomies.VectorVelocity;
    local Ball_Direction = Velocity.Unit;
    local Direction = (LocalPlayer.Character.PrimaryPart.Position - Ball.Position).Unit;
    local Dot = Direction:Dot(Ball_Direction);
    local Speed = Velocity.Magnitude;
    local Distance = (LocalPlayer.Character.PrimaryPart.Position - Ball.Position).Magnitude;

    if not pingBased then
        if Speed < 100 then return false end
        if Dot < 0.8 then return true end
        if Distance > 100 then return false end
        return false
    end

    local Ping = game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue();
    local Speed_Threshold = math.min(Speed / 100, 40);
    local Angle_Threshold = 40 * math.max(Dot, 0);
    local Direction_Difference = (Ball_Direction - Velocity).Unit;
    local Direction_Similarity = Direction:Dot(Direction_Difference);
    local Dot_Difference = Dot - Direction_Similarity;
    local Dot_Threshold = 0.5 - (Ping / 975);
    local Reach_Time = (Distance / Speed) - (Ping / 1000);
    local Enough_Speed = Speed > 100;
    local Ball_Distance_Threshold = ((math.max(Ping/10,15) - math.min(Distance / 1000, 15)) + Angle_Threshold + Speed_Threshold)*(1+Ping/925)

    table.insert(Previous_Velocity, Velocity);
    if (#Previous_Velocity > 4) then
        table.remove(Previous_Velocity, 1);
    end

    if (Enough_Speed and (Reach_Time > (Ping / 10))) then
        Ball_Distance_Threshold = math.max(Ball_Distance_Threshold - 15, 15);
    end

    if (Distance < Ball_Distance_Threshold) then
        return false;
    end

    if ((tick() - Curving) < (Reach_Time / 1.5)) then
        return true;
    end

    if (Dot_Difference < Dot_Threshold) then
        return true;
    end

    local Radians = math.rad(math.asin(Dot));
    Lerp_Radians = Auto_Parry.Linear_Interpolation(Lerp_Radians, Radians, 0.8);
    if (Lerp_Radians < 0.018) then
        Last_Warping = tick();
    end

    if ((tick() - Last_Warping) < (Reach_Time / 1.5)) then
        return true;
    end

    if (#Previous_Velocity == 4) then
        local Intended_Direction_Difference = (Ball_Direction - Previous_Velocity[1].Unit).Unit;
        local Intended_Dot = Direction:Dot(Intended_Direction_Difference);
        local Intended_Dot_Difference = Dot - Intended_Dot;
        local Intended_Direction_Difference2 = (Ball_Direction - Previous_Velocity[2].Unit).Unit;
        local Intended_Dot2 = Direction:Dot(Intended_Direction_Difference2);
        local Intended_Dot_Difference2 = Dot - Intended_Dot2;

        if ((Intended_Dot_Difference < Dot_Threshold) or (Intended_Dot_Difference2 < Dot_Threshold)) then
            return true;
        end
    end

    if ((tick() - Last_Warping) < (Reach_Time / 1.5)) then
        return true;
    end
	return Dot < Dot_Threshold;
end;
Auto_Parry.Closest_Player = function()
	local Max_Distance = math.huge;
	Closest_Entity = nil;
	for _, Entity in pairs(Workspace.Alive:GetChildren()) do
		if ((tostring(Entity) ~= tostring(LocalPlayer)) and Entity.PrimaryPart) then
			local Distance = LocalPlayer:DistanceFromCharacter(Entity.PrimaryPart.Position);
			if (Distance < Max_Distance) then
				Max_Distance = Distance;
				Closest_Entity = Entity;
			end
		end
	end
	return Closest_Entity;
end;
Auto_Parry.Get_Entity_Properties = function(self)
	Auto_Parry.Closest_Player();
	if not Closest_Entity then
		return false;
	end
	local Entity_Velocity = Closest_Entity.PrimaryPart.Velocity;
	local Entity_Direction = (LocalPlayer.Character.PrimaryPart.Position - Closest_Entity.PrimaryPart.Position).Unit;
	local Entity_Distance = (LocalPlayer.Character.PrimaryPart.Position - Closest_Entity.PrimaryPart.Position).Magnitude;
	return {Velocity=Entity_Velocity,Direction=Entity_Direction,Distance=Entity_Distance};
end;
Auto_Parry.Get_Ball_Properties = function(self)
	local ball = Auto_Parry.Get_Ball();
	if not ball then
		return false;
	end
	local character = LocalPlayer.Character;
	if (not character or not character.PrimaryPart) then
		return false;
	end
	local ballVelocity = ball.AssemblyLinearVelocity;
	local ballDirection = (character.PrimaryPart.Position - ball.Position).Unit;
	local ballDistance = (character.PrimaryPart.Position - ball.Position).Magnitude;
	local ballDot = ballDirection:Dot(ballVelocity.Unit);
	return {Velocity=ballVelocity,Direction=ballDirection,Distance=ballDistance,Dot=ballDot};
end;
Auto_Parry.Spam_Service = function(self)
	local ball = Auto_Parry.Get_Ball();
	if not ball then
		return false;
	end
	Auto_Parry.Closest_Player();
	local spamDelay = 0;
	local spamAccuracy = 100;
	if not self.Spam_Sensitivity then
		self.Spam_Sensitivity = 50;
	end
	if not self.Ping_Based_Spam then
		self.Ping_Based_Spam = false;
	end
	local velocity = ball.AssemblyLinearVelocity;
	local speed = velocity.Magnitude;
	local direction = (LocalPlayer.Character.PrimaryPart.Position - ball.Position).Unit;
	local dot = direction:Dot(velocity.Unit);
	local targetPosition = Closest_Entity.PrimaryPart.Position;
	local targetDistance = LocalPlayer:DistanceFromCharacter(targetPosition);
	local maximumSpamDistance = self.Ping + math.min(speed / 6.5, 95);
	maximumSpamDistance = maximumSpamDistance * self.Spam_Sensitivity;
	if self.Ping_Based_Spam then
		maximumSpamDistance = maximumSpamDistance + self.Ping;
	end
	if ((self.Entity_Properties.Distance > maximumSpamDistance) or (self.Ball_Properties.Distance > maximumSpamDistance) or (targetDistance > maximumSpamDistance)) then
		return spamAccuracy;
	end
	local maximumSpeed = 5 - math.min(speed / 5, 5);
	local maximumDot = math.clamp(dot, -1, 0) * maximumSpeed;
	spamAccuracy = maximumSpamDistance - maximumDot;
	task.wait(spamDelay);
	return spamAccuracy;
end;

local visualizerEnabled = false
local visualizer = Instance.new("Part")
visualizer.Shape = Enum.PartType.Ball
visualizer.Anchored = true
visualizer.CanCollide = false
visualizer.Material = Enum.Material.ForceField
visualizer.Transparency = 0.5
visualizer.Parent = Workspace
visualizer.Size = Vector3.zero
local function calculate_visualizer_radius(ball)
	    local velocity = Ball:FindFirstChild("zoomies").VectorVelocity
	return Spamming and 25 or math.clamp((velocity / 2.4) + 10, 15, 200)
end
local function toggle_visualizer(state)
	visualizerEnabled = state
	if not state then
	  visualizer.Size = Vector3.zero  -- Hide visualizer instantly
	end
end
RunService.RenderStepped:Connect(function()
	if not visualizerEnabled then return end
	local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	local primaryPart = char and char.PrimaryPart
	local ball = Auto_Parry.Get_Ball()
	if not (primaryPart and ball) then
	  visualizer.Size = Vector3.zero
	  return
	end
	local target = ball:GetAttribute("target")
	local isTargetingPlayer = (target == LocalPlayer.Name)
	local radius = calculate_visualizer_radius(ball)
	visualizer.Size = Vector3.new(radius, radius, radius)
	visualizer.CFrame = primaryPart.CFrame
	visualizer.Color = Spamming and Color3.fromRGB(255, 0, 0) or isTargetingPlayer and Color3.fromRGB(255, 0, 0) or Color3.fromRGB(255, 255, 255) -- Red = targeted, Green = safe
end)
local Sound_Effect = true
local sound_effect_type = "DC_15X"
local CustomId = "" -- Should be set to just the numeric ID, like "1234567890"

local sound_assets = {
    DC_15X = 'rbxassetid://936447863',
    Neverlose = 'rbxassetid://8679627751',
    Minecraft = 'rbxassetid://8766809464',
    MinecraftHit2 = 'rbxassetid://8458185621',
    TeamfortressBonk = 'rbxassetid://8255306220',
    TeamfortressBell = 'rbxassetid://2868331684',
    Custom = 'empty'
}

local function PlaySound()
    if not Sound_Effect then return end

    local sound_id
    if CustomId ~= "" and sound_effect_type == "Custom" then
        sound_id = "rbxassetid://" .. CustomId
    else
        sound_id = sound_assets[sound_effect_type]
    end

    if not sound_id then return end

    local sound = Instance.new("Sound")
    sound.SoundId = sound_id
    sound.Volume = 1
    sound.PlayOnRemove = true
    sound.Parent = workspace
    sound:Destroy() -- Triggers the sound due to PlayOnRemove = true
end

task.defer(function()
    game.ReplicatedStorage.Remotes.ParrySuccess.OnClientEvent:Connect(PlaySound)
end)
function ManualSpam()

    if MauaulSpam then
        MauaulSpam:Destroy()
        MauaulSpam = nil
        return
    end


    MauaulSpam = Instance.new("ScreenGui")
    MauaulSpam.Name = "MauaulSpam"
    MauaulSpam.Parent = game:GetService("CoreGui") or game.Players.LocalPlayer:WaitForChild("PlayerGui")
    MauaulSpam.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    MauaulSpam.ResetOnSpawn = false


    local Main = Instance.new("Frame")
    Main.Name = "Main"
    Main.Parent = MauaulSpam
    Main.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    Main.BorderColor3 = Color3.fromRGB(0, 0, 0)
    Main.BorderSizePixel = 0
    Main.Position = UDim2.new(0.41414836, 0, 0.404336721, 0)
    Main.Size = UDim2.new(0.227479532, 0, 0.191326529, 0)

    local UICorner = Instance.new("UICorner")
    UICorner.Parent = Main


    local IndercantorBlahblah = Instance.new("Frame")
    IndercantorBlahblah.Name = "IndercantorBlahblah"
    IndercantorBlahblah.Parent = Main
    IndercantorBlahblah.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    IndercantorBlahblah.BorderColor3 = Color3.fromRGB(0, 0, 0)
    IndercantorBlahblah.BorderSizePixel = 0
    IndercantorBlahblah.Position = UDim2.new(0.0280000009, 0, 0.0733333305, 0)
    IndercantorBlahblah.Size = UDim2.new(0.0719999969, 0, 0.119999997, 0)

    local UICorner_2 = Instance.new("UICorner")
    UICorner_2.CornerRadius = UDim.new(1, 0)
    UICorner_2.Parent = IndercantorBlahblah

    local UIAspectRatioConstraint = Instance.new("UIAspectRatioConstraint")
    UIAspectRatioConstraint.Parent = IndercantorBlahblah


    local PC = Instance.new("TextLabel")
    PC.Name = "PC"
    PC.Parent = Main
    PC.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    PC.BackgroundTransparency = 1
    PC.BorderColor3 = Color3.fromRGB(0, 0, 0)
    PC.BorderSizePixel = 0
    PC.Position = UDim2.new(0.547999978, 0, 0.826666653, 0)
    PC.Size = UDim2.new(0.451999992, 0, 0.173333332, 0)
    PC.Font = Enum.Font.Unknown
    PC.Text = "PC: E"
    PC.TextColor3 = Color3.fromRGB(57, 57, 57)
    PC.TextScaled = true
    PC.TextSize = 16
    PC.TextWrapped = true

    local UITextSizeConstraint = Instance.new("UITextSizeConstraint")
    UITextSizeConstraint.Parent = PC
    UITextSizeConstraint.MaxTextSize = 16

    local UIAspectRatioConstraint_2 = Instance.new("UIAspectRatioConstraint")
    UIAspectRatioConstraint_2.Parent = PC
    UIAspectRatioConstraint_2.AspectRatio = 4.346


    local IndercanotTextBlah = Instance.new("TextButton")
    IndercanotTextBlah.Name = "IndercanotTextBlah"
    IndercanotTextBlah.Parent = Main
    IndercanotTextBlah.Active = false
    IndercanotTextBlah.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    IndercanotTextBlah.BackgroundTransparency = 1
    IndercanotTextBlah.BorderColor3 = Color3.fromRGB(0, 0, 0)
    IndercanotTextBlah.BorderSizePixel = 0
    IndercanotTextBlah.Position = UDim2.new(0.164000005, 0, 0.326666653, 0)
    IndercanotTextBlah.Selectable = false
    IndercanotTextBlah.Size = UDim2.new(0.667999983, 0, 0.346666664, 0)
    IndercanotTextBlah.Font = Enum.Font.GothamBold
    IndercanotTextBlah.Text = "Manual Spam"
    IndercanotTextBlah.TextColor3 = Color3.fromRGB(255, 255, 255)
    IndercanotTextBlah.TextScaled = true
    IndercanotTextBlah.TextSize = 24
    IndercanotTextBlah.TextWrapped = true

    local UIGradient = Instance.new("UIGradient")
    UIGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
        ColorSequenceKeypoint.new(0.75, Color3.fromRGB(255, 0, 4)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0))
    })
    UIGradient.Parent = IndercanotTextBlah

    local UITextSizeConstraint_2 = Instance.new("UITextSizeConstraint")
    UITextSizeConstraint_2.Parent = IndercanotTextBlah
    UITextSizeConstraint_2.MaxTextSize = 52

    local UIAspectRatioConstraint_3 = Instance.new("UIAspectRatioConstraint")
    UIAspectRatioConstraint_3.Parent = IndercanotTextBlah
    UIAspectRatioConstraint_3.AspectRatio = 3.212

    local UIAspectRatioConstraint_4 = Instance.new("UIAspectRatioConstraint")
    UIAspectRatioConstraint_4.Parent = Main
    UIAspectRatioConstraint_4.AspectRatio = 1.667


    local spamConnection
    local toggleManualSpam = false
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")

    local function toggleSpam()
        toggleManualSpam = not toggleManualSpam

        if spamConnection then
            spamConnection:Disconnect()
            spamConnection = nil
        end

        if toggleManualSpam then
            spamConnection = RunService.PreSimulation:Connect(function()
                for _ = 1, manualSpamSpeed do
                    if not toggleManualSpam then
                        break
                    end
                    local success, err = pcall(function()
                        Auto_Parry.Parry()
                    end)
                    if not success then
                        warn("Error in Auto_Parry.Parry:", err)
                    end
                    task.wait()
                end
            end)
        end
    end


    local button = IndercanotTextBlah
    local UIGredient = button.UIGradient
    local NeedToChange = IndercantorBlahblah

local green_Color = {
    ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 128)),
    ColorSequenceKeypoint.new(0.75, Color3.fromRGB(128, 0, 128)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 128))
}

    local red_Color = {
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
        ColorSequenceKeypoint.new(0.75, Color3.fromRGB(255, 0, 0)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0))
    }

    local current_Color = red_Color
    local target_Color = green_Color
    local is_Green = false
    local transition = false
    local transition_Time = 1
    local start_Time

    local function startColorTransition()
        transition = true
        start_Time = tick()
    end

    RunService.Heartbeat:Connect(function()
        if transition then
            local elapsed = tick() - start_Time
            local alpha = math.clamp(elapsed / transition_Time, 0, 1)
            local new_Color = {}

            for i = 1, #current_Color do
                local start_Color = current_Color[i].Value
                local end_Color = target_Color[i].Value
                new_Color[i] = ColorSequenceKeypoint.new(current_Color[i].Time, start_Color:Lerp(end_Color, alpha))
            end

            UIGredient.Color = ColorSequence.new(new_Color)

            if alpha >= 1 then
                transition = false
                current_Color, target_Color = target_Color, current_Color
            end
        end
    end)

    local function toggleColor()
        if not transition then
            is_Green = not is_Green

            if is_Green then
                target_Color = green_Color
                NeedToChange.BackgroundColor3 = Color3.new(0, 1, 0)
                toggleSpam()
            else
                target_Color = red_Color
                NeedToChange.BackgroundColor3 = Color3.new(1, 0, 0)
                toggleSpam()
            end

            startColorTransition()
        end
    end

    button.MouseButton1Click:Connect(toggleColor)


    local keyConnection
    keyConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.E then
            toggleColor()
        end
    end)


    MauaulSpam.Destroying:Connect(function()
        if keyConnection then
            keyConnection:Disconnect()
        end
        if spamConnection then
            spamConnection:Disconnect()
        end
    end)


    local gui = Main
    local dragging
    local dragInput
    local dragStart
    local startPos

    local function update(input)
        local delta = input.Position - dragStart
        local newPosition = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )

        local TweenService = game:GetService("TweenService")
        local tweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local tween = TweenService:Create(gui, tweenInfo, {Position = newPosition})
        tween:Play()
    end

    gui.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or
           input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = gui.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    gui.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or
           input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input == dragInput then
            update(input)
        end
    end)
end

local ScreenGui = Instance.new("ScreenGui")
local ImageButton = Instance.new("ImageButton")
local UICorner = Instance.new("UICorner")


ScreenGui.Parent = game.CoreGui
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling


ImageButton.Parent = ScreenGui
ImageButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
ImageButton.BorderSizePixel = 0
ImageButton.Position = UDim2.new(0.120833337, 0, 0.0952890813, 0)
ImageButton.Size = UDim2.new(0, 50, 0, 50)
ImageButton.Image = "rbxassetid://1058228955972"
ImageButton.Draggable = true


UICorner.Parent = ImageButton


ImageButton.MouseButton1Click:Connect(function()
    game:GetService("VirtualInputManager"):SendKeyEvent(true, Enum.KeyCode.LeftControl, false, game)
end)

local Fluent = loadstring(game:HttpGet("https://raw.githubusercontent.com/himselfco/lib/main/lib"))();

local Window = Fluent:CreateWindow({
    Title = "Blade Ball Script",
    SubTitle = "pc:LeftCtrl",
    TabWidth = 160,
    Size = UDim2.fromOffset(500, 500),
    Acrylic = false,
    Theme = "Rose",
    MinimizeKey = Enum.KeyCode.LeftControl
})
local Options = Fluent.Options
local Tabs = {
    Main = Window:AddTab({Title = "Main", Icon = "swords"}),
    Visual = Window:AddTab({Title = "Visuals", Icon = "eye"}),
    Settings = Window:AddTab({Title = "Settings", Icon = "settings"}),
}
Window:SelectTab(1)


local Section = Tabs.Main:AddSection("Info")
Tabs.Main:AddButton({
    Title = "Copy Discord Link",
    Description = "Copy Into Your Clipboard",
    Callback = function()
        setclipboard('https://discord.gg/vrRKtV9euG')
        Fluent:Notify({
            Title = "Join our Discord",
            Content = "Discord Link Copied",
            SubContent = "",
            Duration = 10
    })
    end
})


local AutoParry = Tabs.Main:AddToggle("AutoParry", {Title="Auto Parry",Default=false});
AutoParry:OnChanged(function(v)
	if v then
		Connections_Manager["Auto Parry"] = RunService.PreSimulation:Connect(function()
			local One_Ball = Auto_Parry.Get_Ball();
			local Balls = Auto_Parry.Get_Balls();
			if (not Balls or (#Balls == 0)) then
				return;
			end
			for _, Ball in pairs(Balls) do
				if not Ball then
					return;
				end
				local Zoomies = Ball:FindFirstChild("zoomies");
				if not Zoomies then
					return;
				end
				Ball:GetAttributeChangedSignal("target"):Once(function()
					Parried = false;
				end);
				if Parried then
					return;
				end
				local Ball_Target = Ball:GetAttribute("target");
				local One_Target = One_Ball and One_Ball:GetAttribute("target");
				local Velocity = Zoomies.VectorVelocity;
				local character = LocalPlayer.Character;
				if (not character or not character.PrimaryPart) then
					return;
				end
				local Distance = (character.PrimaryPart.Position - Ball.Position).Magnitude;
				local Speed = Velocity.Magnitude;
				local Ping = game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue() / 10;
				local Parry_Accuracy = (Speed / 3.25) + Ping;
				local Curved = Auto_Parry.Is_Curved();
				if ((Ball_Target == tostring(LocalPlayer)) and Aerodynamic) then
					local Elapsed_Tornado = tick() - Aerodynamic_Time;
					if (Elapsed_Tornado > 0.6) then
						Aerodynamic_Time = tick();
						Aerodynamic = false;
					end
					return;
				end
				if ((One_Target == tostring(LocalPlayer)) and Curved) then
					return;
				end
				if ((Ball_Target == tostring(LocalPlayer)) and (Distance <= Parry_Accuracy)) then
					Auto_Parry.Parry();
					Parried = true;
				end
				local Last_Parrys = tick();
				while (tick() - Last_Parrys) < 1 do
					if not Parried then
						break;
					end
					task.wait();
				end
				Parried = false;
			end
		end);
	elseif Connections_Manager["Auto Parry"] then
		Connections_Manager["Auto Parry"]:Disconnect();
		Connections_Manager["Auto Parry"] = nil;
	end
end);
local AutoSpam = Tabs.Main:AddToggle("AutoSpam", {Title="Auto Spam",Default=false});
local autoSpamCoroutine = nil;
local targetPlayer = nil;
AutoSpam:OnChanged(function(v)
	if v then
		if autoSpamCoroutine then
			coroutine.resume(autoSpamCoroutine, "stop")
			autoSpamCoroutine = nil
		end

		autoSpamCoroutine = coroutine.create(function(signal)
			while AutoSpam.Value and (signal ~= "stop") do
				local ball = Auto_Parry.Get_Ball()
				if ball and ball:IsDescendantOf(workspace) then
					local zoomies = ball:FindFirstChild("zoomies")
					if zoomies then
						Auto_Parry.Closest_Player()
						targetPlayer = Closest_Entity

						if targetPlayer and targetPlayer.PrimaryPart and targetPlayer:IsDescendantOf(workspace) then
							local playerDistance = LocalPlayer:DistanceFromCharacter(ball.Position)
							local targetPosition = targetPlayer.PrimaryPart.Position
							local targetDistance = LocalPlayer:DistanceFromCharacter(targetPosition)

							if targetPlayer.Parent then
								if ball:IsDescendantOf(workspace) and (ball.Position.Magnitude >= 1) then
									local ballVelocity = ball.Velocity.Magnitude
									local ballSpeed = math.max(ballVelocity, 0)
									local ping = game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()
									local pingThreshold = math.clamp(ping / 10, 10, 16)
									local ballProperties = Auto_Parry:Get_Ball_Properties()
									local entityProperties = Auto_Parry:Get_Entity_Properties()

									local spamAccuracy = Auto_Parry.Spam_Service({
										Ball_Properties = ballProperties,
										Entity_Properties = entityProperties,
										Ping = pingThreshold,
										Spam_Sensitivity = Auto_Parry.Spam_Sensitivity,
										Ping_Based_Spam = Auto_Parry.Ping_Based_Spam
									})

									if (zoomies.Parent == ball) and ((playerDistance <= 30) or (targetDistance <= 30)) and (Parries > 1) then
										Auto_Parry.Parry()
									end
								else
									local waitTime = 0
									repeat
										task.wait(0.1)
										waitTime = waitTime + 0.1
										ball = Auto_Parry.Get_Ball()
									until (ball and ball:IsDescendantOf(workspace) and (ball.Position.Magnitude > 1)) or (waitTime >= 2.5)
								end
							end
						end
					end
				end
				task.wait(0.001)
			end
		end)

		coroutine.resume(autoSpamCoroutine)
	elseif autoSpamCoroutine then
		coroutine.resume(autoSpamCoroutine, "stop")
		autoSpamCoroutine = nil
	end
end);


ManualSpam()
local Toggle = Tabs.Main:AddToggle("MyToggle",
{
    Title = "Manual Spam",
    Description = "",
    Default = false,
    Callback = function()
        ManualSpam()
    end
})
local Toggle = Tabs.Main:AddToggle("MyToggle",
{
    Title = "Ping Based",
    Description = "Turn This If you Have Bad Ping",
    Default = false,
    Callback = function(state)
        pingBased = state
        Auto_Parry.Ping_Based_Spam = state
    end
})
local SpamSensitivitySlider = Tabs.Settings:AddSlider("SpamSensitivity", {
    Title = "Spam Sensitivity",
    Description = "",
    Default = 30,
    Min = 1,
    Max = 100,
    Rounding = 0,
    Callback = function(Value)
        Auto_Parry.Spam_Sensitivity = Value
    end
})
local nigra = Tabs.Settings:AddSlider("bru", {
    Title = "Spam Speed",
    Description = "10 is Best Option",
    Default = 1,
    Min = 10,
    Max = 20,
    Rounding = 1,
    Callback = function(Value)
manualSpamSpeed = Value
    end
})
Auto_Parry.Parry_Type = "Default"

local Dropdown = Tabs.Main:AddDropdown("Dropdown", {
    Title = "Curve Method",
    Description = "",
    Values = {"Random", "Backwards", "Straight", "Up", "Right", "Left"},
    Multi = false,
    Default = 3,
    Callback = function(selected)
        Auto_Parry.Parry_Type = selected
    end
})
local Section = Tabs.Visual:AddSection("Visual")

local Toggle = Tabs.Visual:AddToggle("MyToggle",
{
    Title = "Visualizer(Broken) ",
    Description = "",
    Default = false,
    Callback = function(state)
        visualizerEnabled = state
    end
})

local Toaggle = Tabs.Visual:AddToggle("MyaToggle",
{
    Title = "Hit Sound",
    Description = "",
    Default = false,
    Callback = function(state)
        Sound_Effect = state
    end
})
local AIaMethodDropdown = Tabs.Visual:AddDropdown("SoundType", {
    Title = "Sound Type",
    Description = "",
    Values = {'DC_15X','Neverlose','Minecraft','MinecraftHit2','TeamfortressBonk','TeamfortressBell'},
    Default = 1,
    Multi = false,
    Callback = function(Value)
        sound_effect_type = Value
    end
})

loadstring(game:HttpGet("https://dpaste.com/9G5CYNAAA.txt"))()




print("Loaded getgc Into Auto Parry remote was patch later")


-- Add to Visual Tab: Sword Name Textbox
local SwordNameBox = Tabs.Visual:AddInput("SwordNameBox", {
    Title = "Sword Changer",
    Default = "Inferno Scythe",
    Placeholder = "Enter your sword name...",
    Numeric = false,
    Finished = true,
    Callback = function(value)
        getgenv().swordName = value
    end
})

getgenv().swordName = "Inferno Scythe" -- initial value

-- Sword Visual & Effect Integration
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local swordInstances = require(ReplicatedStorage:WaitForChild("Shared", 9e9):WaitForChild("ReplicatedInstances", 9e9):WaitForChild("Swords", 9e9))

local swordsController
while task.wait() and not swordsController do
    for _, v in getconnections(ReplicatedStorage.Remotes.FireSwordInfo.OnClientEvent) do
        if v.Function and islclosure(v.Function) then
            local up = getupvalues(v.Function)
            if type(up[1]) == "table" then
                swordsController = up[1]
                break
            end
        end
    end
end

local function getSlashName(name)
    local swordData = swordInstances:GetSword(name)
    return (swordData and swordData.SlashName) or "SlashEffect"
end

local function setSword()
    local char = player.Character
    if not char then return end

    for _, obj in ipairs(char:GetChildren()) do
        if obj:IsA("Model") and obj.Name ~= getgenv().swordName then
            obj:Destroy()
        end
    end

    setupvalue(rawget(swordInstances, "EquipSwordTo"), 2, false)
    swordInstances:EquipSwordTo(char, getgenv().swordName)
    swordsController:SetSword(getgenv().swordName)
end

getgenv().slashName = getSlashName(getgenv().swordName)

local playParryFunc
for _, v in getconnections(ReplicatedStorage.Remotes.ParrySuccessAll.OnClientEvent) do
    if v.Function and getinfo(v.Function).name == "parrySuccessAll" then
        playParryFunc = v.Function
        v:Disable()
        break
    end
end

ReplicatedStorage.Remotes.ParrySuccessAll.OnClientEvent:Connect(function(...)
    setthreadidentity(2)
    local args = { ... }
    if tostring(args[4]) == player.Name then
        args[1] = getgenv().slashName
        args[3] = getgenv().swordName
    end
    return playParryFunc(unpack(args))
end)

task.spawn(function()
    local lastSword = ""
    while task.wait(1) do
        local current = getgenv().swordName
        if current ~= "" and current ~= lastSword then
            getgenv().slashName = getSlashName(current)
            setSword()
            lastSword = current
        else
            local char = player.Character or player.CharacterAdded:Wait()
            if not char:FindFirstChild(current) or player:GetAttribute("CurrentlyEquippedSword") ~= current then
                setSword()
            end
        end
    end
end)
