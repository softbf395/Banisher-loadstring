-- Service and Variable Definitions
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- Security check to ensure the script is running on the server
if not RunService:IsServer() then
    warn("ERROR: non-server detected, stopping.")
    return
end

warn("BANISHER NS LOADSTRING V0.1 prototype 1.") -- v0.1_p1
warn(" ")
warn("----------------------------------------------------------")
warn(" ")
warn("this is my first loadstring banisher")
warn(" ")
warn("----------------------------------------------------------")
warn(" ")
warn("UPDATE:")
warn(" ")
warn("----------------------------------------------------------")
warn(" ")
warn("= first version.")
warn(" ")
warn("----------------------------------------------------------")

-- Create RemoteEvents and BoolValue
local rm = ReplicatedStorage:FindFirstChild("B_rm") or Instance.new("RemoteEvent", ReplicatedStorage)
rm.Name = "B_rm"
local IMV = ReplicatedStorage:FindFirstChild("IsMobile") or Instance.new("BoolValue", ReplicatedStorage)
IMV.Name = "IsMobile"
local updateRm = ReplicatedStorage:FindFirstChild("B_update") or Instance.new("RemoteEvent", ReplicatedStorage)
updateRm.Name = "B_update"

-- Global State and Configuration for animations
local recordedAnimations = {}
local recordingQueue = {}
local recordingActive = false
local playbackActive = false
local currentPlaybackFrames = {}
local playbackFrameIndex = 1

-- Wait for the owner's character to load and then create the dummy for recording
local ownerCharacter = owner.Character or owner.CharacterAdded:Wait()
local dummyCharacter = ownerCharacter:Clone()
dummyCharacter.Name = "DummyCharacter"
dummyCharacter.Parent = workspace

-- Make the dummy invisible and non-collidable
for _, part in ipairs(dummyCharacter:GetChildren()) do
    if part:IsA("BasePart") then
        part.Transparency = 1
        part.CanCollide = false
    end
end

-- Server-side position and animation data (this is the single source of truth)
local crPosition = CFrame.new(0, 5, 0)
local currentKeyframe = {}
local updateRate = 0.2
local lastUpdate = tick()

-- Function to record the CFrame of a body part on the dummy
local function recordAnimation(animId, animName)
    local frames = {}
    local humanoid = dummyCharacter:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    local animation = Instance.new("Animation")
    animation.AnimationId = "rbxassetid://" .. animId
    local animTrack = humanoid:LoadAnimation(animation)
    animTrack:Play()

    warn("Started recording animation:", animName, "with ID:", animId)

    local recordingConnection = RunService.Heartbeat:Connect(function()
        if not recordingActive then
            animTrack:Stop()
            recordingConnection:Disconnect()
            warn("Stopped recording.")
            recordedAnimations[animName] = frames

            if #recordingQueue > 0 then
                local nextAnim = table.remove(recordingQueue, 1)
                recordAnimation(nextAnim.animId, nextAnim.animName)
            end
            return
        end

        local keyframe = {}
        for _, part in ipairs(dummyCharacter:GetChildren()) do
            if part:IsA("BasePart") then
                keyframe[part.Name] = part.CFrame
            end
        end
        table.insert(frames, keyframe)
    end)

    animTrack.Stopped:Connect(function()
        recordingActive = false
    end)
end

-- Main playback loop for broadcasting animation data
RunService.Heartbeat:Connect(function()
    if tick() - lastUpdate < updateRate then return end
    lastUpdate = tick()

    if playbackActive and playbackFrameIndex <= #currentPlaybackFrames then
        local keyframe = currentPlaybackFrames[playbackFrameIndex]
        updateRm:FireAllClients(keyframe)
        playbackFrameIndex += 1
    elseif playbackActive and playbackFrameIndex > #currentPlaybackFrames then
        playbackActive = false
        -- End of playback, broadcast a single CFrame for movement
        updateRm:FireAllClients({Torso = crPosition})
    end

    if not playbackActive then
      -- Always broadcast the current position for continuous movement
      updateRm:FireAllClients({Torso = crPosition})
    end
end)

-- The server's event listener for all incoming commands from the owner
rm.OnServerEvent:Connect(function(plr, action, params)
    if plr ~= owner then
        warn("Wrong Player!")
        return
    end

    if action == "IsMobile" then
        IMV.Value = params[1]
    elseif action == "record" then
        local animId = params[1]
        local animName = params[2] or tostring(animId)
        if not recordingActive then
            recordingActive = true
            recordAnimation(animId, animName)
        else
            table.insert(recordingQueue, {animId = animId, animName = animName})
            warn("Added animation to queue:", animName, "with ID:", animId)
        end
    elseif action == "stop" then
        recordingActive = false
        playbackActive = false
        warn("All recording and playback has been stopped.")
    elseif action == "play" then
        local animName = params[1]
        local frames = recordedAnimations[animName]
        if not frames or #frames == 0 then
            warn("No recorded animation named:", animName, "to play.")
            return
        end
        currentPlaybackFrames = frames
        playbackActive = true
        playbackFrameIndex = 1
    elseif action == "move" then
        local direction = params[1]
        crPosition = crPosition + direction
    end
end)

--- Client-side LocalScripts loaded via NLS ---
-- This script contains the function that creates the client-side visualizer
local visualizerCreatorSource = [[
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")

local guid = Instance.new("ScreenGui")
guid.Name = "<GUID>"
guid.ResetOnSpawn = false
guid.Parent = StarterGui

local visualizerCR = nil
local visualizerParts = {}

local function createVisualizer(owner)
    if visualizerCR then return visualizerCR end
    local ownerChar = owner.Character or owner.CharacterAdded:Wait()
    
    local model = Instance.new("Model")
    model.Name = "CR_Visualizer"
    model.Parent = Workspace

    local humanoid = Instance.new("Humanoid", model)
    humanoid.Name = "Humanoid"
    humanoid.Health = 0 -- Keep the visualizer's health at zero to avoid interference

    for _, part in ipairs(ownerChar:GetChildren()) do
        if part:IsA("BasePart") or part:IsA("Accessory") then
            local clonedPart = part:Clone()
            clonedPart.Parent = model
            clonedPart.Anchored = false
            clonedPart.CanCollide = false
            clonedPart.Locked = false
            clonedPart.Archivable = true
            
            -- Randomize reflectance once
            clonedPart.Reflectance = math.random() * 0.6
            
            visualizerParts[clonedPart.Name] = clonedPart
        end
    end
    visualizerCR = model
    return visualizerCR, visualizerParts
end

_G.createVisualizer = createVisualizer
_G.visualizerParts = visualizerParts
]]

-- This is the main client script that uses the visualizer creator
local clientScriptSource = [[
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local owner = Players:FindFirstChild("]]..owner.Name..[[")
local rm = ReplicatedStorage:WaitForChild("B_rm")
local updateRm = ReplicatedStorage:WaitForChild("B_update")

local isMobile = UIS.TouchEnabled

-- Call the NLS-created function to build the visualizer
local visualizerCR, visualizerParts = _G.createVisualizer(owner)

-- This function updates the visualizer's position based on server data
local function updateVisualizer(keyframe)
    if not keyframe then return end

    for partName, cframe in pairs(keyframe) do
        local part = visualizerParts[partName]
        if part then
            TweenService:Create(part, TweenInfo.new(0.2), {CFrame = cframe}):Play()
        end
    end
end
updateRm.OnClientEvent:Connect(updateVisualizer)


-- PC Controls Logic
if not isMobile then
    local movementVector = Vector3.new(0, 0, 0)
    local function updateMovementVector()
        movementVector = Vector3.new(0, 0, 0)
        if UIS:IsKeyDown(Enum.KeyCode.W) then movementVector += Vector3.new(0, 0, -1) end
        if UIS:IsKeyDown(Enum.KeyCode.S) then movementVector += Vector3.new(0, 0, 1) end
        if UIS:IsKeyDown(Enum.KeyCode.A) then movementVector += Vector3.new(-1, 0, 0) end
        if UIS:IsKeyDown(Enum.KeyCode.D) then movementVector += Vector3.new(1, 0, 0) end
    end
    UIS.InputBegan:Connect(function(input, gameProcessedEvent)
        if gameProcessedEvent then return end
        updateMovementVector()
        if input.KeyCode == Enum.KeyCode.Z then
            rm:FireServer("play", {"slash"})
        end
    end)
    UIS.InputEnded:Connect(function(input, gameProcessedEvent)
        if gameProcessedEvent then return end
        updateMovementVector()
    end)
    RunService.RenderStepped:Connect(function()
        if movementVector.Magnitude > 0 then
            rm:FireServer("move", {movementVector})
        end
    end)
else
    -- Mobile Controls Logic
    rm:FireServer("IsMobile", {true})
    
    local mobileController = require(Players.LocalPlayer.PlayerScripts:WaitForChild("PlayerModule")).GetControls()
    
    -- Create a button for the slash attack
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0, 100, 0, 50)
    button.Position = UDim2.new(1, -110, 1, -60)
    button.BackgroundColor3 = Color3.new(0.8, 0.2, 0.2)
    button.TextColor3 = Color3.new(1, 1, 1)
    button.Text = "Slash"
    button.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    
    button.MouseButton1Click:Connect(function()
        rm:FireServer("play", {"slash"})
    end)
    
    -- Listen to mobile controller movement
    RunService.RenderStepped:Connect(function()
        local moveVector = mobileController:GetMoveVector()
        if moveVector.Magnitude > 0 then
             rm:FireServer("move", {moveVector})
        end
    end)
end

-- Chat Commands
local function chatCommand(message)
	local args = message:split(" ")
	local command = args[1]:lower()

	if isMobile then
		if command == "/stop" then
			rm:FireServer("stop", {})
		end
	end
end
Players.LocalPlayer.Chatted:Connect(chatCommand)
]]

-- Load the client-side scripts
NLS(visualizerCreatorSource, owner.Backpack)
NLS(clientScriptSource, owner.Backpack)
