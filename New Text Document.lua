-- Services
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- Player and Character References
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

-- Configuration
local TARGET_POSITION = Vector3.new(-659.9823, -31.057972, -283.255127)
local BASE_TELEPORT_DURATION = 5 -- Base duration in seconds
local TELEPORT_SPEED_FACTOR = 0.005 -- Adjusts how duration scales with distance
local TELEPORT_KEY = Enum.KeyCode.N -- Key to trigger teleport

-- Highlight Colors
local ACTIVE_COLOR = Color3.fromRGB(0, 255, 0) -- Green for active VAULTs
local INACTIVE_COLOR = Color3.fromRGB(255, 0, 0) -- Red for inactive VAULTs
local CASH_COLOR = Color3.fromRGB(255, 215, 0) -- Gold for Cash

-- Folders and Models
local cashiersFolder = Workspace:WaitForChild("Cashiers")
local ignoredFolder = Workspace:WaitForChild("Ignored")
local dropsFolder = ignoredFolder:WaitForChild("Drops")
local moneyDropTemplate = dropsFolder:WaitForChild("MoneyDrop")
local mapFolder = Workspace:WaitForChild("MAP"):WaitForChild("Map")
local mapVault = mapFolder:WaitForChild("Vault")

-- Remote Events
local mainEvent = ReplicatedStorage:WaitForChild("MainEvent")

-- Tables to Manage Highlights
local vaultHighlights = {}
local cashHighlights = {}

-- Tables to Manage Weapons
local weapons = {
    ["[RPG]"] = nil,
    ["[Double-Barrel SG]"] = nil
}

-- Variables for Shooting
local isShooting = false
local shootConnection = nil

-- Function to Enable Noclip
local function enableNoclip()
    RunService.Stepped:Connect(function()
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end)
end

-- Function to Calculate Teleport Duration Based on Distance
local function calculateTeleportDuration(distance)
    return BASE_TELEPORT_DURATION + (distance * TELEPORT_SPEED_FACTOR)
end

-- Function to Perform Tweened Teleport
local function tweenTeleport(targetPosition)
    local currentPosition = humanoidRootPart.Position
    local distance = (targetPosition - currentPosition).Magnitude
    local duration = calculateTeleportDuration(distance)

    local tweenInfo = TweenInfo.new(
        duration,
        Enum.EasingStyle.Quad,
        Enum.EasingDirection.Out,
        0,
        false,
        0
    )

    local goal = {}
    goal.CFrame = CFrame.new(targetPosition)

    local tween = TweenService:Create(humanoidRootPart, tweenInfo, goal)
    tween:Play()
end

-- Function to Create a Highlight Instance
local function createHighlight(adornee, color)
    local highlight = Instance.new("Highlight")
    highlight.Adornee = adornee
    highlight.FillColor = color
    highlight.FillTransparency = 0.5
    highlight.OutlineColor = Color3.new(1, 1, 1)
    highlight.OutlineTransparency = 0
    highlight.Parent = adornee
    return highlight
end

-- Function to Handle VAULT Highlighting
local function handleVault(vaultModel)
    local humanoid = vaultModel:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    -- Initial Highlight
    if humanoid.Health > 0 then
        vaultHighlights[vaultModel] = createHighlight(vaultModel, ACTIVE_COLOR)
    else
        vaultHighlights[vaultModel] = createHighlight(vaultModel, INACTIVE_COLOR)
    end

    -- Connect to HealthChanged Event
    humanoid.HealthChanged:Connect(function()
        if humanoid.Health > 0 then
            if vaultHighlights[vaultModel] then
                vaultHighlights[vaultModel].FillColor = ACTIVE_COLOR
            else
                vaultHighlights[vaultModel] = createHighlight(vaultModel, ACTIVE_COLOR)
            end
        else
            if vaultHighlights[vaultModel] then
                vaultHighlights[vaultModel].FillColor = INACTIVE_COLOR
            else
                vaultHighlights[vaultModel] = createHighlight(vaultModel, INACTIVE_COLOR)
            end
            -- Optionally, remove from active list or perform other actions
        end
    end)

    -- Handle VAULT Removal
    vaultModel.AncestryChanged:Connect(function(_, parent)
        if not parent then
            if vaultHighlights[vaultModel] then
                vaultHighlights[vaultModel]:Destroy()
                vaultHighlights[vaultModel] = nil
            end
        end
    end)
end

-- Initialize Existing VAULTs
for _, vault in ipairs(cashiersFolder:GetChildren()) do
    if vault:IsA("Model") and vault.Name == "VAULT" then
        handleVault(vault)
    end
end

-- Listen for New VAULTs Being Added
cashiersFolder.ChildAdded:Connect(function(child)
    if child:IsA("Model") and child.Name == "VAULT" then
        handleVault(child)
    end
end)

-- Function to Handle MoneyDrop When VAULT is Destroyed
local function handleVaultDestruction(vaultModel)
    local moneyDrop = moneyDropTemplate:Clone()
    moneyDrop.Position = vaultModel.Position -- Adjust as needed
    moneyDrop.Parent = Workspace
    -- Optionally, add physics or other properties
end

-- Connect to VAULTs' Humanoid Died Event
for _, vault in ipairs(cashiersFolder:GetChildren()) do
    if vault:IsA("Model") and vault.Name == "VAULT" then
        local humanoid = vault:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.Died:Connect(function()
                handleVaultDestruction(vault)
            end)
        end
    end
end

-- Listen for New VAULTs and Connect Died Event
cashiersFolder.ChildAdded:Connect(function(child)
    if child:IsA("Model") and child.Name == "VAULT" then
        local humanoid = child:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.Died:Connect(function()
                handleVaultDestruction(child)
            end)
        end
    end
end)

-- Function to Highlight Nearby Cash
local function highlightNearbyCash()
    while true do
        for _, cash in ipairs(Workspace:GetDescendants()) do
            if cash.Name == "Cash" and cash:IsA("BasePart") then
                local distance = (cash.Position - humanoidRootPart.Position).Magnitude
                if distance <= 150 then
                    if not cashHighlights[cash] then
                        cashHighlights[cash] = createHighlight(cash, CASH_COLOR)
                    end
                else
                    if cashHighlights[cash] then
                        cashHighlights[cash]:Destroy()
                        cashHighlights[cash] = nil
                    end
                end
            end
        end
        wait(1) -- Adjust the frequency as needed
    end
end

-- Start Highlighting Nearby Cash
spawn(highlightNearbyCash)

-- Function to Monitor and Handle Weapon Ammo
local function monitorWeapons()
    -- Initialize Weapons
    for weaponName, _ in pairs(weapons) do
        local tool = character:FindFirstChild(weaponName) or player.Backpack:FindFirstChild(weaponName)
        if tool then
            weapons[weaponName] = tool
        end
    end

    -- Monitor Ammo for Each Weapon
    for weaponName, tool in pairs(weapons) do
        if tool then
            local ammo = tool:FindFirstChild("Ammo")
            if ammo and ammo:IsA("IntValue") then
                ammo.Changed:Connect(function()
                    if ammo.Value <= 0 then
                        -- Reload Sequence
                        if weaponName ~= "[RPG]" then
                            -- Equip RPG First
                            local rpg = weapons["[RPG]"]
                            if rpg then
                                rpg.Parent = character
                                wait(0.5) -- Wait for equipping
                                -- Simulate 'R' Key Press for Reload
                                UserInputService.InputBegan:Fire({KeyCode = Enum.KeyCode.R, UserInputType = Enum.UserInputType.Keyboard}, false)
                                wait(0.5)
                            end
                        end

                        -- Equip Double-Barrel SG
                        local dbsg = weapons["[Double-Barrel SG]"]
                        if dbsg then
                            dbsg.Parent = character
                            wait(0.5)
                            -- Simulate 'R' Key Press for Reload
                            UserInputService.InputBegan:Fire({KeyCode = Enum.KeyCode.R, UserInputType = Enum.UserInputType.Keyboard}, false)
                            wait(0.5)
                        end
                    end
                end)
            end
        end
    end
end

-- Start Monitoring Weapons
monitorWeapons()

-- Function to Handle Shooting with Double-Barrel SG
local function handleShooting()
    local dbsg = weapons["[Double-Barrel SG]"]
    if not dbsg then return end

    local ammo = dbsg:FindFirstChild("Ammo")
    if not ammo then return end

    while true do
        if ammo.Value > 0 and isShooting then
            dbsg:Activate()
            wait(0.5) -- Adjust firing rate as needed
        elseif ammo.Value <= 0 and isShooting then
            isShooting = false
            -- Reload Sequence
            -- Equip RPG First
            local rpg = weapons["[RPG]"]
            if rpg then
                rpg.Parent = character
                wait(0.5)
                -- Simulate 'R' Key Press for Reload
                UserInputService.InputBegan:Fire({KeyCode = Enum.KeyCode.R, UserInputType = Enum.UserInputType.Keyboard}, false)
                wait(0.5)
            end

            -- Equip Double-Barrel SG
            if dbsg then
                dbsg.Parent = character
                wait(0.5)
                -- Simulate 'R' Key Press for Reload
                UserInputService.InputBegan:Fire({KeyCode = Enum.KeyCode.R, UserInputType = Enum.UserInputType.Keyboard}, false)
                wait(0.5)
            end
        end
        wait(0.1)
    end
end

-- Start Handling Shooting
spawn(handleShooting)

-- Function to Spoof RemoteEvent
local function spoofRemoteEvent(action, position)
    local args = {
        [1] = action,
        [2] = position
    }
    mainEvent:FireServer(unpack(args))
end

-- Function to Handle MAP Vault RemoteEvent Spoofing
local function handleMapVault()
    -- Check if Vault is Opened
    if #mapVault:GetChildren() == 0 then
        -- Vault is opened
        -- Pick a VAULT from Cashiers with Health >1
        for vaultModel, highlight in pairs(vaultHighlights) do
            local humanoid = vaultModel:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health > 1 then
                local door = vaultModel:FindFirstChild("Door")
                if door and door:IsA("BasePart") then
                    -- Spoof RemoteEvent with Door Position
                    spoofRemoteEvent("UpdateMousePosI2", door.Position)

                    -- Equip Double-Barrel SG
                    local dbsg = weapons["[Double-Barrel SG]"]
                    if dbsg then
                        dbsg.Parent = character
                        wait(0.5)
                    end

                    -- Start Shooting
                    isShooting = true
                end
                break -- Only handle one VAULT at a time
            end
        end
    else
        -- Vault is not opened
        -- Use default position
        spoofRemoteEvent("UpdateMousePosI2", Vector3.new(-629.738037109375, -23.192718505859375, -285.164306640625))
    end
end

-- Function to Handle Tool Equipping and 'R' Key Press
local function equipToolAndReload(tool)
    if tool then
        tool.Parent = character
        wait(0.5) -- Wait for equipping
        -- Simulate 'R' Key Press for Reload
        UserInputService.InputBegan:Fire({KeyCode = Enum.KeyCode.R, UserInputType = Enum.UserInputType.Keyboard}, false)
    end
end

-- Connect to Teleport Key Press
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == TELEPORT_KEY then
        -- Perform Teleport
        tweenTeleport(TARGET_POSITION)

        -- Wait for Teleport to Complete
        wait(BASE_TELEPORT_DURATION + ( (humanoidRootPart.Position - TARGET_POSITION).Magnitude * TELEPORT_SPEED_FACTOR ) + 1)

        -- Handle MAP Vault Spoofing
        handleMapVault()
    end
end)

-- Enable Noclip Immediately
enableNoclip()

-- Optional: Automatically Handle Reloading and Shooting in Background
spawn(function()
    while true do
        -- Handle DB SG Shooting
        local dbsg = weapons["[Double-Barrel SG]"]
        if dbsg then
            local ammo = dbsg:FindFirstChild("Ammo")
            if ammo and ammo.Value > 0 and isShooting then
                dbsg:Activate()
                wait(0.5) -- Adjust firing rate as needed
            elseif ammo and ammo.Value <= 0 and isShooting then
                isShooting = false
                -- Reload Sequence
                -- Equip RPG First
                local rpg = weapons["[RPG]"]
                if rpg then
                    equipToolAndReload(rpg)
                end

                -- Equip Double-Barrel SG
                if dbsg then
                    equipToolAndReload(dbsg)
                end
            end
        end
        wait(0.1)
    end
end)