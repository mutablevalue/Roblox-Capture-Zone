--[[ VARIABLES ]]--
-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Teams = require(ReplicatedStorage.Teams)
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local point2 = "POINT DATA"
local captureSoundId = "CAPTURESOUND"
local captureSound = Instance.new("Sound", workspace)
captureSound.SoundId = captureSoundId

-- Constants
local Parent = script.Parent
local Progress = Parent.Progress
local Marker = Parent.Marker

local CaptureZone = "CAPTURE ZONE"
local CaptureZoneSize = CaptureZone.Size
local CaptureZoneDiameter = CaptureZoneSize.X
local CaptureZoneRadius = CaptureZoneDiameter / 2
local remotes = ReplicatedStorage.Depot

local Thread = -- INPUT THREAD LOCATION

-- Variables
local captureLoop = nil
local currentPoints = 0

local playerRoots = {}
local rootParts = {}

local timeSinceLast = 0

local togglePoints = 0
local toggleTeam = nil
local currentOwner = nil

local heartBeatConn = nil

local Depot = "RAID SERVICE" -- ADD YOUR RAID SERVICE HERE

local function updateBeamColors(teamColor)
	for __, Beam in pairs(BEAMS:GetChildren()) do -- Insert the beam data of your surrounding zone
		Beam.Color = ColorSequence.new{
			ColorSequenceKeypoint.new(0, teamColor),
			ColorSequenceKeypoint.new(1, teamColor)
		}
	end
end

function AddTogglePoint(team)
	if currentOwner == team or team == nil then
		if currentOwner then
			CAPTUREUI.ImageLabel.BackgroundColor3 = currentOwner.TeamColor.Color -- SET CAPTUREUI TO BE YOUR CAPTUREUI
		end
		return
	end

	-- The new toggling team is the enemy team
	if team ~= toggleTeam then
		toggleTeam = team
		togglePoints = 0
	end
	-- Increment the points
	togglePoints = togglePoints + 1

	-- Update toggle progress
	local increment = togglePoints / 3
	local tweenInfo = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local goal = {BackgroundColor3 = team.TeamColor.Color}
	local tween = TweenService:Create(Marker.CaptureUI.ImageLabel, tweenInfo, goal)

	if togglePoints >= 2 then
		currentOwner = team -- INSERT ALL YOUR UI MANIPUALTION DATA HERE
		tween:Play()
		point2:SetColor(team.TeamColor.Color) -- FOR INSTANCE SETTING THE COLOR OF BEAMS
		["RAID DATA"].UpdateDomUi:FireAllClients(togglePoints, team.TeamColor.Color, "point3") -- FOR INSTANCE UI UPDATE
		captureSound:Play()
		updateBeamColors(team.TeamColor.Color)
	end
end

-- Capture loop control
function StartCaptureLoop()
	-- Start the capture loop
	captureLoop = Thread.new()
	captureLoop:Start(CaptureLoopCallback)
	-- Set the owner to nil initially
	currentOwner = nil

	-- Update the marker GUI looks
	Marker.CaptureUI.ImageLabel.BackgroundColor3 = Color3.new(0,0,0) -- Default to white or any default color
	Marker.CaptureUI.ImageLabel.Size = UDim2.new(1, 0, 1, 0)
	Marker.CaptureUI.ImageLabel.Position = UDim2.new(0, 0, 0, 0)

	-- Setup heartbeat connection
	heartBeatConn = RunService.Heartbeat:Connect(OnHeartBeatUpdate)
end

function StopCaptureLoop()
	-- Stop the capture loop
	if captureLoop then
		captureLoop:Stop()
		captureLoop = nil
	end

	-- Update the marker GUI looks
	Marker.CaptureUI.ImageLabel.Size = UDim2.new(1, 0, 1, 0)
	Marker.CaptureUI.ImageLabel.Position = UDim2.new(0, 0, 0, 0)

	-- Break the heartbeat connection
	if heartBeatConn then
		heartBeatConn:Disconnect()
		heartBeatConn = nil
	end
end

function CaptureLoopCallback()
	local size = CaptureZoneSize
	local region = Region3.new(CaptureZone.Position - (size / 2), CaptureZone.Position + (size / 2))

	local friendlyCount = 0
	local invaderCount = 0

	local rootsInRegion = workspace:FindPartsInRegion3WithWhiteList(region, rootParts)
	local humanoidRootPartsInRegion = {}


	-- Filter to ensure only HumanoidRootParts are considered
	for _, part in pairs(rootsInRegion) do
		if part.Name == "HumanoidRootPart" then
			table.insert(humanoidRootPartsInRegion, part)
		end
	end


	for _, root in pairs(humanoidRootPartsInRegion) do
		local plr = Players:GetPlayerFromCharacter(root.Parent)
		-- Debug prints

		if not plr then continue end

		local rootPosition = Vector3.new(root.Position.X, CaptureZone.Position.Y, root.Position.Z)
		local isInRegion = (CaptureZone.Position - rootPosition).magnitude <= CaptureZoneRadius
		if isInRegion then
			if plr.Team == Teams.Horizon then
				friendlyCount = friendlyCount + 1
			else
				invaderCount = invaderCount + 1
			end
		end
	end


	if friendlyCount > invaderCount then
		AddTogglePoint(Teams.Horizon)
	elseif friendlyCount < invaderCount then
		AddTogglePoint(Teams.Hostiles)
	else
		AddTogglePoint(nil)
	end

	return 1
end


-- Player cache functions
function ReloadCharactersList()
	local plrRoots = {}
	local roots = {}
	for _,plr in ipairs(Players:GetPlayers()) do
		if not plr.Character then continue end
		local humanoid = plr.Character:FindFirstChild("Humanoid")
		local humanoidRootPart = plr.Character:FindFirstChild("HumanoidRootPart")
		if not humanoidRootPart or humanoid.Health <= 0 then continue end
		plrRoots[humanoidRootPart] = plr
		table.insert(roots, humanoidRootPart)
	end


	playerRoots = plrRoots
	rootParts = roots
end

--[[ EVENTS ]]--
function OnPlayerAdded(player)
	player.CharacterAdded:Connect(function()		
		local humanoid = player.Character:WaitForChild("Humanoid")
		humanoid.Died:Connect(function()
			ReloadCharactersList()
		end)
		ReloadCharactersList()
	end)

	player.CharacterRemoving:Connect(function()
		ReloadCharactersList()
	end)
end

function OnPlayerRemoving(player)
	ReloadCharactersList()
end

function OnPlayerRespawn(player)
	ReloadCharactersList()
end

function OnRaidStart()
	RAID_DATA:Setup()
	RAID_DATA.Official = true
	task.wait(25)
	Marker.CaptureUI.Enabled = true
	for __, Beam in pairs(script.Parent.P2Beam.RayColor:GetChildren()) do
		Beam.Enabled = true
	end
	point2:Show() -- FOR INSTANCE ACTIVATING BEAM COLORS
	StartCaptureLoop()
end

local POINTS_INTERVAL = 2
local pointAccumulationTimer = 0
local raidEnded = false
function OnHeartBeatUpdate(step)
	timeSinceLast += step
	local secondsElapsed = math.floor(timeSinceLast)
	timeSinceLast -= secondsElapsed

	
	if not raidEnded then
		if RAID_DATA.DefenderPoints >= RAID_DATA.PointsToWin and RAID_DATA.DefenderPoints >= RAID_DATA.RaiderPoints then
			raidEnded = true
			StopCaptureLoop()
			print("done")
			Marker.CaptureUI.Enabled = false
			for __, Beam in pairs(script.Parent.P2Beam.RayColor:GetChildren()) do
				Beam.Enabled = false
			end
		elseif RAID_DATA.RaiderPoints >= RAID_DATA.PointsToWin and RAID_DATA.RaiderPoints >= RAID_DATA.DefenderPoints then
			raidEnded = true
			StopCaptureLoop()
			print("done")
			Marker.CaptureUI.Enabled = false
			for __, Beam in pairs(script.Parent.P2Beam.RayColor:GetChildren()) do
				Beam.Enabled = false
			end
		end
	end
	
	if secondsElapsed == 0 then return end

	pointAccumulationTimer = pointAccumulationTimer + secondsElapsed
	
	if not raidEnded then
	if pointAccumulationTimer >= POINTS_INTERVAL then
		pointAccumulationTimer = pointAccumulationTimer - POINTS_INTERVAL

			if currentOwner == Teams.Horizon and Depot.Official then
				RAID_DATA.DefenderPoints = RAID_DATA.DefenderPoints + 1
				RAID_REMOTE.DefenderPointsUpdated:FireAllClients(RAID_DATA.DefenderPoints)
				RAID_REMOTERaiderPointsUpdated:FireAllClients(RAID_DATA.RaiderPoints)
			elseif currentOwner == Teams.Hostiles and Depot.Official then
				RAID_DATA.RaiderPoints = RAID_DATA.RaiderPoints + 1
				RAID_REMOTE.DefenderPointsUpdated:FireAllClients(RAID_DATA.DefenderPoints)
				RAID_REMOTE.RaiderPointsUpdated:FireAllClients(RAID_DATA.RaiderPoints)
		end
		end
	end

end
--[[ INITIALIZATION ]]--
Players.PlayerAdded:Connect(OnPlayerAdded)
Players.PlayerRemoving:Connect(OnPlayerRemoving)

for __, player in next, game.Players:GetPlayers() do
	OnPlayerAdded(player)
end

"".DominationEvent.Event:Connect(OnRaidStart) -- ADD YOUR EVENT HERE

"".EndDomination.Event:Connect(function()
	raidEnded = true
	Marker.CaptureUI.Enabled = false
	for __, Beam in pairs(script.Parent.P2Beam.RayColor:GetChildren()) do
		Beam.Enabled = false
	end
end)

-- Start the initial setup

if currentOwner then
	Marker.CaptureUI.ImageLabel.BackgroundColor3 = currentOwner.TeamColor.Color
else
	Marker.CaptureUI.ImageLabel.BackgroundColor3 = Color3.new(0,0,0) -- Default to white or any default color
end
