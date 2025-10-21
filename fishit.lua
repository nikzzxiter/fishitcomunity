-- NIKZZ FISH IT - FINAL INTEGRATED VERSION
-- DEVELOPER BY NIKZZ
-- Complete Integration: Auto Quest + Fishing + Telegram Hook + Database

print("Loading NIKZZ FISH IT - FINAL INTEGRATED VERSION...")

if not game:IsLoaded() then
    game.Loaded:Wait()
end

-- Services
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
local Humanoid = Character:WaitForChild("Humanoid")

-- Rayfield Setup
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
    Name = "NIKZZ FISH IT - FINAL INTEGRATED VERSION",
    LoadingTitle = "NIKZZ FISH IT - FINAL VERSION",
    LoadingSubtitle = "DEVELOPER BY NIKZZ",
    ConfigurationSaving = { Enabled = false },
})

-- ================= DATABASE SYSTEM (FROM FIX AUTO QUEST) =================

-- Load Database
local function LoadDatabase()
    local paths = {"/storage/emulated/0/Delta/Workspace/FULL_ITEM_DATA.json", "FULL_ITEM_DATA.json"}
    for _, p in ipairs(paths) do
        local ok, content = pcall(function() return readfile(p) end)
        if ok and content then
            local decodeOk, data = pcall(function() return HttpService:JSONDecode(content) end)
            if decodeOk and data then
                print("[DB] Loaded JSON from path:", p)
                return data
            else
                print("[DB] JSON parse failed for path:", p)
            end
        end
    end
    print("[DB] FULL_ITEM_DATA.json not found in paths.")
    return nil
end

local database = LoadDatabase()

-- Tier -> Rarity mapping
local tierToRarity = {
    [1] = "COMMON",
    [2] = "UNCOMMON",
    [3] = "RARE",
    [4] = "EPIC",
    [5] = "LEGENDARY",
    [6] = "MYTHIC",
    [7] = "SECRET"
}

-- Normalize and build ItemDatabase
local ItemDatabase = {}

if database and database.Data then
    for cat, list in pairs(database.Data) do
        if type(list) == "table" then
            for key, item in pairs(list) do
                if type(item) == "table" then
                    local tierNum = tonumber(item.Tier) or 0
                    item.Rarity = (item.Rarity and string.upper(tostring(item.Rarity))) or (tierToRarity[tierNum] or "UNKNOWN")
                    if item.Id then
                        local idn = tonumber(item.Id)
                        if idn then item.Id = idn end
                    end
                end
            end
        end
    end

    for cat, list in pairs(database.Data) do
        if type(list) == "table" then
            for _, item in pairs(list) do
                if item and item.Id then
                    local id = tonumber(item.Id) or item.Id
                    local tierNum = tonumber(item.Tier) or 0
                    ItemDatabase[id] = {
                        Name = item.Name or tostring(id),
                        Type = item.Type or cat,
                        Tier = tierNum,
                        SellPrice = item.SellPrice or 0,
                        Weight = item.Weight or "-",
                        Rarity = (item.Rarity and string.upper(tostring(item.Rarity))) or (tierToRarity[tierNum] or "UNKNOWN"),
                        Raw = item
                    }
                end
            end
        end
    end

    print("[Database] Loaded item database, total items (approx):", (database.Metadata and database.Metadata.TotalItems) or "unknown")
else
    print("[Database] FULL_ITEM_DATA.json not found or invalid. Item DB empty.")
end

local function GetItemInfo(itemId)
    local info = ItemDatabase[itemId]
    if not info then
        return { Name = "Unknown Item", Type = "Unknown", Tier = 0, SellPrice = 0, Weight = "-", Rarity = "UNKNOWN" }
    end
    info.Rarity = string.upper(tostring(info.Rarity or "UNKNOWN"))
    return info
end

-- ================= TELEGRAM SYSTEM (FROM FIX AUTO QUEST) =================

local TELEGRAM_BOT_TOKEN = "8397717015:AAGpYPg2X_rBDumP30MSSXWtDnR_Bi5e_30"

local TelegramConfig = {
    Enabled = false,
    BotToken = TELEGRAM_BOT_TOKEN,
    ChatID = "",
    SelectedRarities = {},
    MaxSelection = 3,
    UseFancyFont = true,
    QuestNotifications = true
}

local function safeJSONEncode(tbl)
    local ok, res = pcall(function() return HttpService:JSONEncode(tbl) end)
    if ok then return res end
    return "{}"
end

local function pickHTTPRequest(requestTable)
    local ok, result
    if type(http_request) == "function" then
        ok, result = pcall(function() return http_request(requestTable) end)
        return ok, result
    elseif type(syn) == "table" and type(syn.request) == "function" then
        ok, result = pcall(function() return syn.request(requestTable) end)
        return ok, result
    elseif type(request) == "function" then
        ok, result = pcall(function() return request(requestTable) end)
        return ok, result
    elseif type(http) == "table" and type(http.request) == "function" then
        ok, result = pcall(function() return http.request(requestTable) end)
        return ok, result
    else
        return false, "No supported http request function found"
    end
end

local function CountSelected()
    local c = 0
    for k,v in pairs(TelegramConfig.SelectedRarities) do if v then c = c + 1 end end
    return c
end

local function FancyHeader()
    if TelegramConfig.UseFancyFont then
        return "NIKZZ SCRIPT FISH IT"
    else
        return "NIKZZ SCRIPT FISH IT V1"
    end
end

local function GetPlayerStats()
    local caught, rarest = "Unknown", "Unknown"
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    if ls then
        pcall(function()
            local c = ls:FindFirstChild("Caught") or ls:FindFirstChild("caught")
            if c and c.Value then caught = tostring(c.Value) end
            local r = ls:FindFirstChild("Rarest Fish") or ls:FindFirstChild("RarestFish") or ls:FindFirstChild("Rarest")
            if r and r.Value then rarest = tostring(r.Value) end
        end)
    end
    return caught, rarest
end

local function BuildTelegramMessage(fishInfo, fishId, fishRarity, weight)
    local playerName = LocalPlayer.Name or "Unknown"
    local displayName = LocalPlayer.DisplayName or playerName
    local userId = tostring(LocalPlayer.UserId or "Unknown")
    local caught, rarest = GetPlayerStats()
    local serverTime = os.date("%H:%M:%S")
    local serverDate = os.date("%Y-%m-%d")
    local fishName = (fishInfo and fishInfo.Name) and fishInfo.Name or "Unknown"
    local fishTier = tostring((fishInfo and fishInfo.Tier) or "?")
    local sellPrice = tostring((fishInfo and fishInfo.SellPrice) or "?")
    local weightDisplay = "?"
    if weight then
        if type(weight) == "number" then weightDisplay = string.format("%.2fkg", weight) else weightDisplay = tostring(weight) .. "kg" end
    elseif fishInfo and fishInfo.Weight then weightDisplay = tostring(fishInfo.Weight) end

    local fishRarityStr = string.upper(tostring(fishRarity or (fishInfo and fishInfo.Rarity) or "UNKNOWN"))

    local message = "```\n"
    message = message .. "=============================\n"
    message = message .. "  " .. FancyHeader() .. "\n"
    message = message .. "  DEVELOPER: NIKZZ\n"
    message = message .. "=============================\n"
    message = message .. "\n"
    message = message .. "  PLAYER INFORMATION\n"
    message = message .. "     NAME: " .. playerName .. "\n"
    if displayName ~= playerName then message = message .. "     DISPLAY: " .. displayName .. "\n" end
    message = message .. "     ID: " .. userId .. "\n"
    message = message .. "     CAUGHT: " .. tostring(caught) .. "\n"
    message = message .. "     RAREST FISH: " .. tostring(rarest) .. "\n"
    message = message .. "\n"
    message = message .. "  FISH DETAILS\n"
    message = message .. "     NAME: " .. fishName .. "\n"
    message = message .. "     ID: " .. tostring(fishId or "?") .. "\n"
    message = message .. "     TIER: " .. fishTier .. "\n"
    message = message .. "     RARITY: " .. fishRarityStr .. "\n"
    message = message .. "     WEIGHT: " .. weightDisplay .. "\n"
    message = message .. "     PRICE: " .. sellPrice .. " COINS\n"
    message = message .. "\n"
    message = message .. "  SYSTEM STATS\n"
    message = message .. "     TIME: " .. serverTime .. "\n"
    message = message .. "     DATE: " .. serverDate .. "\n"
    message = message .. "\n"
    message = message .. "  DEVELOPER SOCIALS\n"
    message = message .. "     TIKTOK: @nikzzxit\n"
    message = message .. "     INSTAGRAM: @n1kzx.z\n"
    message = message .. "     ROBLOX: @Nikzz7z\n"
    message = message .. "\n"
    message = message .. "  STATUS: ACTIVE\n"
    message = message .. "=============================\n"
    message = message .. "```"
    return message
end

local function BuildQuestTelegramMessage(questName, taskName, progress, statusType)
    local playerName = LocalPlayer.Name or "Unknown"
    local displayName = LocalPlayer.DisplayName or playerName
    local userId = tostring(LocalPlayer.UserId or "Unknown")
    local caught, rarest = GetPlayerStats()
    local serverTime = os.date("%H:%M:%S")
    local serverDate = os.date("%Y-%m-%d")
    
    local statusText = "UNKNOWN"
    
    if statusType == "START" then
        statusText = "QUEST STARTED"
    elseif statusType == "TASK_SELECTED" then
        statusText = "TASK SELECTED"
    elseif statusType == "TASK_COMPLETED" then
        statusText = "TASK COMPLETED"
    elseif statusType == "QUEST_COMPLETED" then
        statusText = "QUEST COMPLETED"
    elseif statusType == "TELEPORT" then
        statusText = "TELEPORTED"
    elseif statusType == "FARMING" then
        statusText = "FARMING STARTED"
    elseif statusType == "PROGRESS_UPDATE" then
        statusText = "PROGRESS UPDATE"
    end

    local message = "```\n"
    message = message .. "=============================\n"
    message = message .. "  " .. FancyHeader() .. "\n"
    message = message .. "  DEVELOPER: NIKZZ\n"
    message = message .. "=============================\n"
    message = message .. "\n"
    message = message .. "  PLAYER INFORMATION\n"
    message = message .. "     NAME: " .. playerName .. "\n"
    if displayName ~= playerName then message = message .. "     DISPLAY: " .. displayName .. "\n" end
    message = message .. "     ID: " .. userId .. "\n"
    message = message .. "     CAUGHT: " .. tostring(caught) .. "\n"
    message = message .. "     RAREST FISH: " .. tostring(rarest) .. "\n"
    message = message .. "\n"
    message = message .. "  QUEST INFORMATION\n"
    message = message .. "     QUEST: " .. questName .. "\n"
    if taskName then
        message = message .. "     TASK: " .. taskName .. "\n"
    end
    if progress then
        message = message .. "     PROGRESS: " .. string.format("%.1f%%", progress) .. "\n"
    end
    message = message .. "\n"
    message = message .. "  SYSTEM STATS\n"
    message = message .. "     TIME: " .. serverTime .. "\n"
    message = message .. "     DATE: " .. serverDate .. "\n"
    message = message .. "\n"
    message = message .. "  DEVELOPER SOCIALS\n"
    message = message .. "     TIKTOK: @nikzzxit\n"
    message = message .. "     INSTAGRAM: @n1kzx.z\n"
    message = message .. "     ROBLOX: @Nikzz7z\n"
    message = message .. "\n"
    message = message .. "  STATUS: " .. statusText .. "\n"
    message = message .. "=============================\n"
    message = message .. "```"
    return message
end

local function SendTelegram(message)
    if not TelegramConfig.BotToken or TelegramConfig.BotToken == "" then
        print("[Telegram] Bot token empty!")
        return false, "no token"
    end
    if not TelegramConfig.ChatID or TelegramConfig.ChatID == "" then
        print("[Telegram] Chat ID empty!")
        return false, "no chat id"
    end

    local url = ("https://api.telegram.org/bot%s/sendMessage"):format(TelegramConfig.BotToken)
    local payload = {
        chat_id = TelegramConfig.ChatID,
        text = message,
        parse_mode = "Markdown"
    }

    local body = safeJSONEncode(payload)
    local req = {
        Url = url,
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = body
    }

    local ok, res = pickHTTPRequest(req)
    if not ok then
        print("[Telegram] HTTP request failed:", res)
        return false, res
    end

    local success = false
    if type(res) == "table" then
        if res.Body then
            success = true
        elseif res.body then
            success = true
        elseif res.StatusCode and tonumber(res.StatusCode) and tonumber(res.StatusCode) >= 200 and tonumber(res.StatusCode) < 300 then
            success = true
        end
    elseif type(res) == "string" then
        success = true
    end

    if success then
        print("[Telegram] Message sent to Telegram.")
        return true, res
    else
        print("[Telegram] Unknown response:", res)
        return false, res
    end
end

local function ShouldSendByRarity(rarity)
    if not TelegramConfig.Enabled then return false end
    if CountSelected() == 0 then return false end
    local key = string.upper(tostring(rarity or "UNKNOWN"))
    return TelegramConfig.SelectedRarities[key] == true
end

local function SendQuestNotification(questName, taskName, progress, statusType)
    if not TelegramConfig.Enabled or not TelegramConfig.QuestNotifications then return end
    if not TelegramConfig.ChatID or TelegramConfig.ChatID == "" then return end
    
    local message = BuildQuestTelegramMessage(questName, taskName, progress, statusType)
    spawn(function() 
        local success = SendTelegram(message)
        if success then
            print("[Quest Telegram] " .. statusType .. " notification sent for " .. questName)
        end
    end)
end

-- ================= QUEST SYSTEM (FROM FIX AUTO QUEST) =================

local TaskMapping = {
    ["Catch a SECRET Crystal Crab"] = "CRYSTAL CRAB",
    ["Catch 100 Epic Fish"] = "CRYSTAL CRAB",
    ["Catch 10,000 Fish"] = "CRYSTAL CRAB",
    ["Catch 300 Rare/Epic fish"] = "RARE/EPIC FISH",
    ["Earn 1M Coins"] = "FARMING COIN",
    ["Catch 1 SECRET fish at Sisyphus"] = "SECRET SYPUSH",
    ["Catch 3 Mythic fishes at Sisyphus"] = "SECRET SYPUSH",
    ["Create 3 Transcended Stones"] = "CREATE STONE",
    ["Catch 1 SECRET fish at Sacred Temple"] = "SECRET TEMPLE",
    ["Catch 1 SECRET fish at Ancient Jungle"] = "SECRET JUNGLE"
}

local function getQuestTracker(questName)
    local menu = workspace:FindFirstChild("!!! MENU RINGS")
    if not menu then return nil end
    for _, inst in ipairs(menu:GetChildren()) do
        if inst.Name:find("Tracker") and inst.Name:lower():find(questName:lower()) then
            return inst
        end
    end
    return nil
end

local function getQuestProgress(questName)
    local tracker = getQuestTracker(questName)
    if not tracker then return 0 end
    local label = tracker:FindFirstChild("Board") and tracker.Board:FindFirstChild("Gui") 
        and tracker.Board.Gui:FindFirstChild("Content") 
        and tracker.Board.Gui.Content:FindFirstChild("Progress") 
        and tracker.Board.Gui.Content.Progress:FindFirstChild("ProgressLabel")
    if label and label:IsA("TextLabel") then
        local percent = string.match(label.Text, "([%d%.]+)%%")
        return tonumber(percent) or 0
    end
    return 0
end

local function getAllTasks(questName)
    local tracker = getQuestTracker(questName)
    if not tracker then return {} end
    local content = tracker:FindFirstChild("Board") and tracker.Board:FindFirstChild("Gui") and tracker.Board.Gui:FindFirstChild("Content")
    if not content then return {} end
    local tasks = {}
    for _, obj in ipairs(content:GetChildren()) do
        if obj:IsA("TextLabel") and obj.Name:match("Label") and not obj.Name:find("Progress") then
            local txt = obj.Text
            local percent = string.match(txt, "([%d%.]+)%%") or "0"
            local done = txt:find("100%%") or txt:find("DONE") or txt:find("COMPLETED")
            table.insert(tasks, {name = txt, percent = tonumber(percent), completed = done ~= nil})
        end
    end
    return tasks
end

local function getActiveTasks(questName)
    local all = getAllTasks(questName)
    local active = {}
    for _, t in ipairs(all) do
        if not t.completed then
            table.insert(active, t)
        end
    end
    return active
end

local teleportPositions = {
    ["CRYSTAL CRAB"] = CFrame.new(40.0956, 1.7772, 2757.2583),
    ["RARE/EPIC FISH"] = CFrame.new(-3596.9094, -281.1832, -1645.1220),
    ["SECRET SYPUSH"] = CFrame.new(-3658.5747, -138.4813, -951.7969),
    ["SECRET TEMPLE"] = CFrame.new(1451.4100, -22.1250, -635.6500),
    ["SECRET JUNGLE"] = CFrame.new(1479.6647, 11.1430, -297.9549),
    ["FARMING COIN"] = CFrame.new(-553.3464, 17.1376, 114.2622)
}

local function teleportTo(locName)
    local char = LocalPlayer.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local cf = teleportPositions[locName]
    if cf then
        hrp.CFrame = cf
        return true
    end
    return false
end

local State = {
    Active = false,
    CurrentQuest = nil,
    SelectedTask = nil,
    CurrentLocation = nil,
    Teleported = false,
    Fishing = false,
    LastProgress = 0,
    LastTaskIndex = nil
}

local function findLocationByTaskName(taskName)
    for key, loc in pairs(TaskMapping) do
        if string.find(taskName, key, 1, true) then
            return loc
        end
    end
    return nil
end

-- ================= CONFIGURATION =================

local Config = {
    AutoFishingV1 = false,
    AutoFishingV2 = false,
    AutoFishingStable = false,
    FishingDelay = 0.3,
    PerfectCatch = false,
    AntiAFK = false,
    AutoJump = false,
    AutoJumpDelay = 3,
    AutoSell = false,
    SavedPosition = nil,
    CheckpointPosition = HumanoidRootPart.CFrame,
    WalkSpeed = 16,
    JumpPower = 50,
    WalkOnWater = false,
    InfiniteZoom = false,
    NoClip = false,
    XRay = false,
    ESPEnabled = false,
    ESPDistance = 20,
    LockedPosition = false,
    LockCFrame = nil,
    AutoBuyWeather = false,
    SelectedWeathers = {},
    AutoRejoin = false,
    Brightness = 2,
    TimeOfDay = 14,
}

-- Auto Rejoin Data Storage
local RejoinData = {
    Position = nil,
    ActiveFeatures = {},
    Settings = {}
}

-- ================= REMOTES =================

local net = ReplicatedStorage:WaitForChild("Packages")
    :WaitForChild("_Index")
    :WaitForChild("sleitnick_net@0.2.0")
    :WaitForChild("net")

local function GetRemote(name)
    return net:FindFirstChild(name)
end

local EquipTool = GetRemote("RE/EquipToolFromHotbar")
local ChargeRod = GetRemote("RF/ChargeFishingRod")
local StartMini = GetRemote("RF/RequestFishingMinigameStarted")
local FinishFish = GetRemote("RE/FishingCompleted")
local EquipOxy = GetRemote("RF/EquipOxygenTank")
local UnequipOxy = GetRemote("RF/UnequipOxygenTank")
local Radar = GetRemote("RF/UpdateFishingRadar")
local SellRemote = GetRemote("RF/SellAllItems")
local PurchaseWeather = GetRemote("RF/PurchaseWeatherEvent")
local UpdateAutoFishing = GetRemote("RF/UpdateAutoFishingState")
local FishCaught = GetRemote("RE/FishCaught")

-- ================= FISH CATCH LISTENER =================

if FishCaught then
    FishCaught.OnClientEvent:Connect(function(data)
        if not data then return end

        local fishName = "Unknown"
        local fishTier = 1
        local fishId = nil
        local fishChance = 0
        local fishPrice = 0
        local fishWeight = nil
        
        if type(data) == "string" then
            fishName = data
        elseif type(data) == "table" then
            fishName = data.Name or "Unknown"
            fishTier = data.Tier or 1
            fishId = data.Id
            fishChance = data.Chance or 0
            fishPrice = data.SellPrice or 0
            fishWeight = data.Weight
        end

        local fishInfo = GetItemInfo(fishId or 0)
        
        if not fishInfo or fishInfo.Name == "Unknown Item" then
            fishInfo = {
                Name = fishName,
                Tier = fishTier,
                Id = fishId or "?",
                Chance = fishChance,
                SellPrice = fishPrice,
                Weight = fishWeight
            }
        end
        
        if not fishInfo.Tier or fishInfo.Tier == 0 then
            fishInfo.Tier = fishTier
        end
        
        local tier = fishInfo.Tier
        local rarity = tierToRarity[tier] or "UNKNOWN"
        local sellPrice = fishInfo.SellPrice or 0
        local id = fishInfo.Id or "?"
        
        print(string.format("[CAUGHT] %s | Tier: %s | Rarity: %s | Price: %s coins | ID: %s",
            fishName, tostring(tier), rarity, tostring(sellPrice), tostring(id)))
        
        Rayfield:Notify({
            Title = "Fish Caught!",
            Content = string.format("%s | Tier %s | %s", fishName, tier, rarity),
            Duration = 3
        })
        
        if ShouldSendByRarity(rarity) then
            local message = BuildTelegramMessage(fishInfo, fishId, rarity, fishWeight)
            spawn(function() SendTelegram(message) end)
        end
    end)
    
    print("[Fish Catch] Listener initialized")
else
    warn("[Fish Catch] Remote not found! Notifications may not work.")
end

-- ================= AUTO FISHING FUNCTIONS =================

-- Auto Fishing V1 (Ultra Speed + Anti-Stuck)
local FishingActive = false
local IsCasting = false
local MaxRetries = 5
local CurrentRetries = 0
local LastFishTime = tick()
local StuckCheckInterval = 15

local function ResetFishingState(full)
    FishingActive = false
    IsCasting = false
    CurrentRetries = 0
    LastFishTime = tick()
    if full then
        pcall(function()
            if Character then
                for _, v in pairs(Character:GetChildren()) do
                    if v:IsA("Tool") or v:IsA("Model") then
                        v:Destroy()
                    end
                end
            end
        end)
    end
end

local function SafeRespawn()
    task.spawn(function()
        local currentPos = HumanoidRootPart and HumanoidRootPart.CFrame or CFrame.new()
        warn("[Anti-Stuck] Respawning player to fix stuck...")

        Character:BreakJoints()
        local newChar = LocalPlayer.CharacterAdded:Wait()

        task.wait(2)
        Character = newChar
        HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
        Humanoid = Character:WaitForChild("Humanoid")

        task.wait(0.5)
        HumanoidRootPart.CFrame = currentPos

        ResetFishingState(true)

        warn("[Anti-Stuck] Cooldown 3 detik sebelum melanjutkan memancing...")
        task.wait(3)

        if Config.AutoFishingV1 then
            warn("[AutoFishingV1] Restarting fishing after cooldown...")
            AutoFishingV1()
        end
    end)
end

local function CheckStuckState()
    task.spawn(function()
        while Config.AutoFishingV1 do
            task.wait(StuckCheckInterval)
            local timeSinceLastFish = tick() - LastFishTime
            if timeSinceLastFish > StuckCheckInterval and FishingActive then
                warn("[Anti-Stuck] Detected stuck! Respawning...")
                SafeRespawn()
                return
            end
        end
    end)
end

function AutoFishingV1()
    task.spawn(function()
        print("[AutoFishingV1] Started - Ultra Speed + Anti-Stuck")
        CheckStuckState()

        while Config.AutoFishingV1 do
            if IsCasting then
                task.wait(0.05)
                continue
            end

            IsCasting = true
            FishingActive = true
            local cycleSuccess = false

            local success, err = pcall(function()
                if not LocalPlayer.Character or not HumanoidRootPart then
                    repeat task.wait(0.25) until LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    Character = LocalPlayer.Character
                    HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
                end

                local equipSuccess = pcall(function()
                    EquipTool:FireServer(1)
                end)
                if not equipSuccess then
                    CurrentRetries += 1
                    if CurrentRetries >= MaxRetries then
                        SafeRespawn()
                        return
                    end
                    task.wait(0.25)
                    return
                end
                task.wait(0.12)

                local chargeSuccess = false
                for attempt = 1, 3 do
                    local ok, result = pcall(function()
                        return ChargeRod:InvokeServer(tick())
                    end)
                    if ok and result then
                        chargeSuccess = true
                        break
                    end
                    task.wait(0.08)
                end
                if not chargeSuccess then
                    warn("[AutoFishingV1] Charge failed")
                    CurrentRetries += 1
                    IsCasting = false
                    if CurrentRetries >= MaxRetries then
                        SafeRespawn()
                        return
                    end
                    task.wait(0.2)
                    return
                end
                task.wait(0.1)

                local startSuccess = false
                for attempt = 1, 3 do
                    local ok, result = pcall(function()
                        return StartMini:InvokeServer(-1.233184814453125, 0.9945034885633273)
                    end)
                    if ok then
                        startSuccess = true
                        break
                    end
                    task.wait(0.08)
                end
                if not startSuccess then
                    warn("[AutoFishingV1] Start minigame failed")
                    CurrentRetries += 1
                    IsCasting = false
                    if CurrentRetries >= MaxRetries then
                        SafeRespawn()
                        return
                    end
                    task.wait(0.2)
                    return
                end

                local actualDelay = math.max(Config.FishingDelay or 0.1, 0.1)
                task.wait(actualDelay * 0.8)

                local finishSuccess = pcall(function()
                    FinishFish:FireServer()
                end)

                if finishSuccess then
                    cycleSuccess = true
                    LastFishTime = tick()
                    CurrentRetries = 0
                end
                task.wait(0.1)
            end)

            IsCasting = false

            if not success then
                warn("[AutoFishingV1] Cycle Error: " .. tostring(err))
                CurrentRetries += 1
                if CurrentRetries >= MaxRetries then
                    SafeRespawn()
                end
                task.wait(0.4)
            elseif cycleSuccess then
                task.wait(0.08)
            else
                task.wait(0.2)
            end
        end

        ResetFishingState()
        print("[AutoFishingV1] Stopped")
    end)
end

-- Auto Fishing V2
local function AutoFishingV2()
    task.spawn(function()
        print("[AutoFishingV2] Started - Using Game Auto Fishing")
        
        pcall(function()
            UpdateAutoFishing:InvokeServer(true)
        end)
        
        local mt = getrawmetatable(game)
        if mt then
            setreadonly(mt, false)
            local old = mt.__namecall
            mt.__namecall = newcclosure(function(self, ...)
                local method = getnamecallmethod()
                if method == "InvokeServer" and self == StartMini then
                    if Config.AutoFishingV2 then
                        return old(self, -1.233184814453125, 0.9945034885633273)
                    end
                end
                return old(self, ...)
            end)
            setreadonly(mt, true)
        end
        
        while Config.AutoFishingV2 do
            task.wait(1)
        end
        
        pcall(function()
            UpdateAutoFishing:InvokeServer(false)
        end)
        
        print("[AutoFishingV2] Stopped")
    end)
end

-- Auto Fishing Stable (FROM FIX AUTO QUEST)
local function AutoFishingStable()
    task.spawn(function()
        print("[AutoFishingStable] Started - Stable Version")
        
        while Config.AutoFishingStable do
            local success, err = pcall(function()
                if not LocalPlayer.Character or not HumanoidRootPart or LocalPlayer.Character:FindFirstChild("Humanoid") and LocalPlayer.Character.Humanoid.Health <= 0 then
                    repeat task.wait(1) until LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character.Humanoid.Health > 0
                    Character = LocalPlayer.Character
                    HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
                    Humanoid = Character:WaitForChild("Humanoid")
                end

                if EquipTool then
                    EquipTool:FireServer(1)
                    task.wait(0.3)
                end

                if ChargeRod then
                    local chargeSuccess = false
                    for attempt = 1, 3 do
                        local ok, result = pcall(function()
                            return ChargeRod:InvokeServer(tick())
                        end)
                        if ok and result then 
                            chargeSuccess = true 
                            break 
                        end
                        task.wait(0.1)
                    end
                    if not chargeSuccess then
                        error("Failed to charge rod")
                    end
                end
                task.wait(0.2)

                if StartMini then
                    local startSuccess = false
                    for attempt = 1, 3 do
                        local ok, result = pcall(function()
                            return StartMini:InvokeServer(-1.233184814453125, 0.9945034885633273)
                        end)
                        if ok then 
                            startSuccess = true 
                            break 
                        end
                        task.wait(0.1)
                    end
                    if not startSuccess then
                        error("Failed to start minigame")
                    end
                end

                local waitTime = 2 - (Config.FishingDelay * 0.5)
                if waitTime < 0.5 then waitTime = 0.5 end
                task.wait(waitTime)

                if FinishFish then
                    local finishSuccess = pcall(function()
                        FinishFish:FireServer()
                    end)
                    if not finishSuccess then
                        error("Failed to finish fishing")
                    end
                end

                print("[AutoFishingStable] Successfully caught fish!")
                task.wait(0.5)
            end)

            if not success then
                warn("[AutoFishingStable] Error in cycle: " .. tostring(err))
                task.wait(1)
            end
            
            if not Config.AutoFishingStable then break end
        end
        
        print("[AutoFishingStable] Stopped")
    end)
end

-- Perfect Catch
local PerfectCatchConn = nil
local function TogglePerfectCatch(enabled)
    Config.PerfectCatch = enabled
    
    if enabled then
        if PerfectCatchConn then PerfectCatchConn:Disconnect() end

        local mt = getrawmetatable(game)
        if not mt then return end
        setreadonly(mt, false)
        local old = mt.__namecall
        mt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if method == "InvokeServer" and self == StartMini then
                if Config.PerfectCatch and not Config.AutoFishingV1 and not Config.AutoFishingV2 and not Config.AutoFishingStable then
                    return old(self, -1.233184814453125, 0.9945034885633273)
                end
            end
            return old(self, ...)
        end)
        setreadonly(mt, true)
    else
        if PerfectCatchConn then
            PerfectCatchConn:Disconnect()
            PerfectCatchConn = nil
        end
    end
end

-- Auto Buy Weather
local WeatherList = {"Wind", "Cloudy", "Snow", "Storm", "Radiant", "Shark Hunt"}
local function AutoBuyWeather()
    task.spawn(function()
        while Config.AutoBuyWeather do
            for _, weather in pairs(Config.SelectedWeathers) do
                if weather and weather ~= "None" then
                    pcall(function()
                        local weatherName = weather
                        PurchaseWeather:InvokeServer(weatherName)
                        print("[AUTO BUY WEATHER] Purchased: " .. weatherName)
                    end)
                    task.wait(0.5)
                end
            end
            task.wait(5)
        end
    end)
end

-- Anti AFK
local function AntiAFK()
    task.spawn(function()
        while Config.AntiAFK do
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
            task.wait(30)
        end
    end)
end

-- Auto Jump
local function AutoJump()
    task.spawn(function()
        print("[AUTO JUMP] Started with delay: " .. Config.AutoJumpDelay .. "s")
        while Config.AutoJump do
            pcall(function()
                if Humanoid and Humanoid.FloorMaterial ~= Enum.Material.Air then
                    Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                end
            end)
            task.wait(Config.AutoJumpDelay)
        end
        print("[AUTO JUMP] Stopped")
    end)
end

-- Auto Sell
local function AutoSell()
    task.spawn(function()
        while Config.AutoSell do
            pcall(function()
                SellRemote:InvokeServer()
            end)
            task.wait(10)
        end
    end)
end

-- Walk on Water
local WalkOnWaterConnection = nil
local function WalkOnWater()
    if WalkOnWaterConnection then
        WalkOnWaterConnection:Disconnect()
        WalkOnWaterConnection = nil
    end
    
    if not Config.WalkOnWater then return end
    
    task.spawn(function()
        print("[WALK ON WATER] Activated")
        
        WalkOnWaterConnection = RunService.Heartbeat:Connect(function()
            if not Config.WalkOnWater then
                if WalkOnWaterConnection then
                    WalkOnWaterConnection:Disconnect()
                    WalkOnWaterConnection = nil
                end
                return
            end
            
            pcall(function()
                if HumanoidRootPart and Humanoid then
                    local rayOrigin = HumanoidRootPart.Position
                    local rayDirection = Vector3.new(0, -20, 0)
                    
                    local raycastParams = RaycastParams.new()
                    raycastParams.FilterDescendantsInstances = {Character}
                    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
                    
                    local raycastResult = Workspace:Raycast(rayOrigin, rayDirection, raycastParams)
                    
                    if raycastResult and raycastResult.Instance then
                        local hitPart = raycastResult.Instance
                        
                        if hitPart.Name:lower():find("water") or hitPart.Material == Enum.Material.Water then
                            local waterSurfaceY = raycastResult.Position.Y
                            local playerY = HumanoidRootPart.Position.Y
                            
                            if playerY < waterSurfaceY + 3 then
                                local newPosition = Vector3.new(
                                    HumanoidRootPart.Position.X,
                                    waterSurfaceY + 3.5,
                                    HumanoidRootPart.Position.Z
                                )
                                HumanoidRootPart.CFrame = CFrame.new(newPosition)
                            end
                        end
                    end
                    
                    local region = Region3.new(
                        HumanoidRootPart.Position - Vector3.new(2, 10, 2),
                        HumanoidRootPart.Position + Vector3.new(2, 2, 2)
                    )
                    region = region:ExpandToGrid(4)
                    
                    local terrain = Workspace:FindFirstChildOfClass("Terrain")
                    if terrain then
                        local materials, sizes = terrain:ReadVoxels(region, 4)
                        local size = materials.Size
                        
                        for x = 1, size.X do
                            for y = 1, size.Y do
                                for z = 1, size.Z do
                                    if materials[x][y][z] == Enum.Material.Water then
                                        local waterY = HumanoidRootPart.Position.Y
                                        if waterY < HumanoidRootPart.Position.Y + 3 then
                                            HumanoidRootPart.CFrame = CFrame.new(
                                                HumanoidRootPart.Position.X,
                                                waterY + 3.5,
                                                HumanoidRootPart.Position.Z
                                            )
                                        end
                                        return
                                    end
                                end
                            end
                        end
                    end
                end
            end)
        end)
    end)
end

-- Infinite Zoom
local function InfiniteZoom()
    task.spawn(function()
        while Config.InfiniteZoom do
            pcall(function()
                if LocalPlayer:FindFirstChild("CameraMaxZoomDistance") then
                    LocalPlayer.CameraMaxZoomDistance = math.huge
                end
            end)
            task.wait(1)
        end
    end)
end

-- No Clip
local function NoClip()
    task.spawn(function()
        while Config.NoClip do
            pcall(function()
                if Character then
                    for _, part in pairs(Character:GetChildren()) do
                        if part:IsA("BasePart") then
                            part.CanCollide = false
                        end
                    end
                end
            end)
            task.wait(0.1)
        end
    end)
end

-- X-Ray
local function XRay()
    task.spawn(function()
        while Config.XRay do
            pcall(function()
                for _, part in pairs(Workspace:GetDescendants()) do
                    if part:IsA("BasePart") and part.Transparency < 0.5 then
                        part.LocalTransparencyModifier = 0.5
                    end
                end
            end)
            task.wait(1)
        end
    end)
end

-- ESP
local function ESP()
    task.spawn(function()
        while Config.ESPEnabled do
            pcall(function()
                for _, player in pairs(Players:GetPlayers()) do
                    if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                        local distance = (HumanoidRootPart.Position - player.Character.HumanoidRootPart.Position).Magnitude
                        if distance <= Config.ESPDistance then
                            -- ESP logic here
                        end
                    end
                end
            end)
            task.wait(1)
        end
    end)
end

-- Lock Position
local function LockPosition()
    task.spawn(function()
        while Config.LockedPosition do
            if HumanoidRootPart then
                HumanoidRootPart.CFrame = Config.LockCFrame
            end
            task.wait()
        end
    end)
end

-- Saved Islands Data
local IslandsData = {
    {Name = "Fisherman Island", Position = Vector3.new(92, 9, 2768)},
    {Name = "Arrow Lever", Position = Vector3.new(898, 8, -363)},
    {Name = "Sisyphus Statue", Position = Vector3.new(-3740, -136, -1013)},
    {Name = "Ancient Jungle", Position = Vector3.new(1481, 11, -302)},
    {Name = "Weather Machine", Position = Vector3.new(-1519, 2, 1908)},
    {Name = "Coral Refs", Position = Vector3.new(-3105, 6, 2218)},
    {Name = "Tropical Island", Position = Vector3.new(-2110, 53, 3649)},
    {Name = "Kohana", Position = Vector3.new(-662, 3, 714)},
    {Name = "Esoteric Island", Position = Vector3.new(2035, 27, 1386)},
    {Name = "Diamond Lever", Position = Vector3.new(1818, 8, -285)},
    {Name = "Underground Cellar", Position = Vector3.new(2098, -92, -703)},
    {Name = "Volcano", Position = Vector3.new(-631, 54, 194)},
    {Name = "Enchant Room", Position = Vector3.new(3255, -1302, 1371)},
    {Name = "Lost Isle", Position = Vector3.new(-3717, 5, -1079)},
    {Name = "Sacred Temple", Position = Vector3.new(1475, -22, -630)},
    {Name = "Creater Island", Position = Vector3.new(981, 41, 5080)},
    {Name = "Double Enchant Room", Position = Vector3.new(1480, 127, -590)},
    {Name = "Treassure Room", Position = Vector3.new(-3599, -276, -1642)},
    {Name = "Crescent Lever", Position = Vector3.new(1419, 31, 78)},
    {Name = "Hourglass Diamond Lever", Position = Vector3.new(1484, 8, -862)},
    {Name = "Snow Island", Position = Vector3.new(1627, 4, 3288)}
}

-- Teleport System
local function TeleportToPosition(pos)
    if HumanoidRootPart then
        HumanoidRootPart.CFrame = CFrame.new(pos)
        return true
    end
    return false
end

-- Event Scanner
local function ScanActiveEvents()
    local events = {}
    local validEvents = {
        "megalodon", "whale", "kraken", "hunt", "Ghost Worm", "Mount Hallow",
        "admin", "Hallow Bay", "worm", "blackhole", "HalloweenFastTravel"
    }

    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") or obj:IsA("Folder") then
            local name = obj.Name:lower()

            for _, keyword in ipairs(validEvents) do
                if name:find(keyword) and not name:find("boat") and not name:find("sharki") then
                    local exists = false
                    for _, e in ipairs(events) do
                        if e.Name == obj.Name then
                            exists = true
                            break
                        end
                    end

                    if not exists then
                        local pos = Vector3.new(0, 0, 0)

                        if obj:IsA("Model") then
                            pcall(function()
                                pos = obj:GetModelCFrame().Position
                            end)
                        elseif obj:IsA("BasePart") then
                            pos = obj.Position
                        elseif obj:IsA("Folder") and #obj:GetChildren() > 0 then
                            local child = obj:GetChildren()[1]
                            if child:IsA("Model") then
                                pcall(function()
                                    pos = child:GetModelCFrame().Position
                                end)
                            elseif child:IsA("BasePart") then
                                pos = child.Position
                            end
                        end

                        table.insert(events, {
                            Name = obj.Name,
                            Object = obj,
                            Position = pos
                        })
                    end

                    break
                end
            end
        end
    end

    print("[EVENT SCANNER] Found " .. tostring(#events) .. " events.")
    return events
end

-- Graphics Functions
local LightingConnection = nil

local function ApplyPermanentLighting()
    if LightingConnection then LightingConnection:Disconnect() end
    
    LightingConnection = RunService.Heartbeat:Connect(function()
        Lighting.Brightness = Config.Brightness
        Lighting.ClockTime = Config.TimeOfDay
    end)
end

local function RemoveFog()
    Lighting.FogEnd = 100000
    Lighting.FogStart = 0
    for _, effect in pairs(Lighting:GetChildren()) do
        if effect:IsA("Atmosphere") then
            effect.Density = 0
        end
    end
    
    RunService.Heartbeat:Connect(function()
        Lighting.FogEnd = 100000
        Lighting.FogStart = 0
    end)
end

local PerformanceModeActive = false

local function PerformanceMode()
    if PerformanceModeActive then return end
    
    PerformanceModeActive = true
    print("[PERFORMANCE MODE] Activating ultra performance...")
    
    Lighting.GlobalShadows = false
    Lighting.FogEnd = 100000
    Lighting.FogStart = 0
    Lighting.Brightness = 1
    Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
    
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
            obj.Enabled = false
        end
        
        if obj:IsA("Terrain") then
            obj.WaterReflectance = 0
            obj.WaterTransparency = 0.9
            obj.WaterWaveSize = 0
            obj.WaterWaveSpeed = 0
        end
        
        if obj:IsA("Part") or obj:IsA("MeshPart") then
            if obj.Material == Enum.Material.Water then
                obj.Transparency = 0.9
                obj.Reflectance = 0
            end
            
            obj.Material = Enum.Material.SmoothPlastic
            obj.Reflectance = 0
            obj.CastShadow = false
        end
        
        if obj:IsA("Atmosphere") or obj:IsA("PostEffect") then
            obj:Destroy()
        end
    end
    
    settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
    
    RunService.Heartbeat:Connect(function()
        if PerformanceModeActive then
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 100000
            settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        end
    end)
    
    Workspace.DescendantAdded:Connect(function(obj)
        if PerformanceModeActive then
            if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
                obj.Enabled = false
            end
            
            if obj:IsA("Part") or obj:IsA("MeshPart") then
                obj.Material = Enum.Material.SmoothPlastic
                obj.Reflectance = 0
                obj.CastShadow = false
            end
        end
    end)
    
    Rayfield:Notify({
        Title = "Performance Mode",
        Content = "Ultra performance activated! 50x smoother experience",
        Duration = 3
    })
end

local function Enable8Bit()
    task.spawn(function()
        print("[8-Bit Mode] Enabling super smooth rendering...")
        
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") then
                obj.Material = Enum.Material.SmoothPlastic
                obj.Reflectance = 0
                obj.CastShadow = false
                obj.TopSurface = Enum.SurfaceType.Smooth
                obj.BottomSurface = Enum.SurfaceType.Smooth
            end
            if obj:IsA("MeshPart") then
                obj.Material = Enum.Material.SmoothPlastic
                obj.Reflectance = 0
                obj.TextureID = ""
                obj.CastShadow = false
                obj.RenderFidelity = Enum.RenderFidelity.Performance
            end
            if obj:IsA("Decal") or obj:IsA("Texture") then
                obj.Transparency = 1
            end
            if obj:IsA("SpecialMesh") then
                obj.TextureId = ""
            end
        end
        
        for _, effect in pairs(Lighting:GetChildren()) do
            if effect:IsA("PostEffect") or effect:IsA("Atmosphere") then
                effect.Enabled = false
            end
        end
        
        Lighting.Brightness = 3
        Lighting.Ambient = Color3.fromRGB(255, 255, 255)
        Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 100000
        
        Workspace.DescendantAdded:Connect(function(obj)
            if obj:IsA("BasePart") then
                obj.Material = Enum.Material.SmoothPlastic
                obj.Reflectance = 0
                obj.CastShadow = false
                obj.TopSurface = Enum.SurfaceType.Smooth
                obj.BottomSurface = Enum.SurfaceType.Smooth
            end
            if obj:IsA("MeshPart") then
                obj.Material = Enum.Material.SmoothPlastic
                obj.Reflectance = 0
                obj.TextureID = ""
                obj.RenderFidelity = Enum.RenderFidelity.Performance
            end
            if obj:IsA("Decal") or obj:IsA("Texture") then
                obj.Transparency = 1
            end
        end)
        
        Rayfield:Notify({
            Title = "8-Bit Mode",
            Content = "Super smooth rendering enabled!",
            Duration = 2
        })
    end)
end

local function RemoveParticles()
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
            obj.Enabled = false
            obj:Destroy()
        end
    end
    
    Workspace.DescendantAdded:Connect(function(obj)
        if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
            obj.Enabled = false
            obj:Destroy()
        end
    end)
end

local function RemoveSeaweed()
    for _, obj in pairs(Workspace:GetDescendants()) do
        local name = obj.Name:lower()
        if name:find("seaweed") or name:find("kelp") or name:find("coral") or name:find("plant") or name:find("weed") then
            pcall(function()
                if obj:IsA("Model") or obj:IsA("Part") or obj:IsA("MeshPart") then
                    obj:Destroy()
                end
            end)
        end
    end
    
    Workspace.DescendantAdded:Connect(function(obj)
        local name = obj.Name:lower()
        if name:find("seaweed") or name:find("kelp") or name:find("coral") or name:find("plant") or name:find("weed") then
            pcall(function()
                if obj:IsA("Model") or obj:IsA("Part") or obj:IsA("MeshPart") then
                    task.wait(0.1)
                    obj:Destroy()
                end
            end)
        end
    end)
end

local function OptimizeWater()
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("Terrain") then
            obj.WaterReflectance = 0
            obj.WaterTransparency = 1
            obj.WaterWaveSize = 0
            obj.WaterWaveSpeed = 0
        end
        
        if obj:IsA("Part") or obj:IsA("MeshPart") then
            if obj.Material == Enum.Material.Water then
                obj.Reflectance = 0
                obj.Transparency = 0.8
            end
        end
    end
    
    RunService.Heartbeat:Connect(function()
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("Terrain") then
                obj.WaterReflectance = 0
                obj.WaterTransparency = 1
                obj.WaterWaveSize = 0
                obj.WaterWaveSpeed = 0
            end
        end
    end)
end

-- Auto Rejoin System
local RejoinSaveFile = "NikzzRejoinData_" .. LocalPlayer.UserId .. ".json"

local function SaveRejoinData()
    RejoinData.Position = HumanoidRootPart.CFrame
    RejoinData.ActiveFeatures = {
        AutoFishingV1 = Config.AutoFishingV1,
        AutoFishingV2 = Config.AutoFishingV2,
        AutoFishingStable = Config.AutoFishingStable,
        PerfectCatch = Config.PerfectCatch,
        AntiAFK = Config.AntiAFK,
        AutoJump = Config.AutoJump,
        AutoSell = Config.AutoSell,
        WalkOnWater = Config.WalkOnWater,
        NoClip = Config.NoClip,
        XRay = Config.XRay,
        AutoBuyWeather = Config.AutoBuyWeather
    }
    RejoinData.Settings = {
        WalkSpeed = Config.WalkSpeed,
        JumpPower = Config.JumpPower,
        FishingDelay = Config.FishingDelay,
        AutoJumpDelay = Config.AutoJumpDelay,
        Brightness = Config.Brightness,
        TimeOfDay = Config.TimeOfDay
    }
    
    writefile(RejoinSaveFile, HttpService:JSONEncode(RejoinData))
    print("[AUTO REJOIN] Data saved for reconnection")
end

local function LoadRejoinData()
    if isfile(RejoinSaveFile) then
        local success, data = pcall(function()
            return HttpService:JSONDecode(readfile(RejoinSaveFile))
        end)
        
        if success and data then
            RejoinData = data
            
            if RejoinData.Position and HumanoidRootPart then
                HumanoidRootPart.CFrame = RejoinData.Position
                print("[AUTO REJOIN] Position restored")
            end
            
            if RejoinData.Settings then
                for key, value in pairs(RejoinData.Settings) do
                    if Config[key] ~= nil then
                        Config[key] = value
                    end
                end
            end
            
            if RejoinData.ActiveFeatures then
                for key, value in pairs(RejoinData.ActiveFeatures) do
                    if Config[key] ~= nil then
                        Config[key] = value
                    end
                end
            end
            
            if Humanoid then
                Humanoid.WalkSpeed = Config.WalkSpeed
                Humanoid.JumpPower = Config.JumpPower
            end
            
            Lighting.Brightness = Config.Brightness
            Lighting.ClockTime = Config.TimeOfDay
            
            print("[AUTO REJOIN] All settings and features restored")
            return true
        end
    end
    return false
end

local function SetupAutoRejoin()
    if Config.AutoRejoin then
        print("[AUTO REJOIN] System enabled")
        
        task.spawn(function()
            while Config.AutoRejoin do
                SaveRejoinData()
                task.wait(10)
            end
        end)
        
        task.spawn(function()
            local success = pcall(function()
                game:GetService("CoreGui").RobloxPromptGui.promptOverlay.ChildAdded:Connect(function(child)
                    if Config.AutoRejoin then
                        if child.Name == 'ErrorPrompt' then
                            task.wait(1)
                            SaveRejoinData()
                            task.wait(1)
                            TeleportService:Teleport(game.PlaceId, LocalPlayer)
                        end
                    end
                end)
            end)
            
            if not success then
                warn("[AUTO REJOIN] Method 1 failed to setup")
            end
        end)
        
        task.spawn(function()
            game:GetService("GuiService").ErrorMessageChanged:Connect(function()
                if Config.AutoRejoin then
                    task.wait(1)
                    SaveRejoinData()
                    task.wait(1)
                    TeleportService:Teleport(game.PlaceId, LocalPlayer)
                end
            end)
        end)
        
        LocalPlayer.OnTeleport:Connect(function(State)
            if Config.AutoRejoin and State == Enum.TeleportState.Failed then
                task.wait(1)
                SaveRejoinData()
                task.wait(1)
                TeleportService:Teleport(game.PlaceId, LocalPlayer)
            end
        end)
        
        Rayfield:Notify({
            Title = "Auto Rejoin",
            Content = "Protection active! Will rejoin on disconnect",
            Duration = 3
        })
    end
end

-- ================= QUEST LOOP (FROM FIX AUTO QUEST) =================

task.spawn(function()
    while task.wait(1) do
        if not State.Active then continue end

        local questProgress = getQuestProgress(State.CurrentQuest)
        local activeTasks = getActiveTasks(State.CurrentQuest)
        local allTasks = getAllTasks(State.CurrentQuest)
        
        local allTasksCompleted = true
        for _, task in ipairs(allTasks) do
            if not task.completed and task.percent < 100 then
                allTasksCompleted = false
                break
            end
        end
        
        if allTasksCompleted and questProgress >= 100 then
            local completionMessage = "```\n"
            completionMessage = completionMessage .. "=============================\n"
            completionMessage = completionMessage .. "  " .. FancyHeader() .. " - MISSION ACCOMPLISHED!\n"
            completionMessage = completionMessage .. "  DEVELOPER: NIKZZ\n"
            completionMessage = completionMessage .. "=============================\n"
            completionMessage = completionMessage .. "\n"
            completionMessage = completionMessage .. "  PLAYER INFORMATION\n"
            completionMessage = completionMessage .. "     NAME: " .. (LocalPlayer.Name or "Unknown") .. "\n"
            completionMessage = completionMessage .. "     QUEST: " .. State.CurrentQuest .. "\n"
            completionMessage = completionMessage .. "\n"
            completionMessage = completionMessage .. "  TASK COMPLETION STATUS\n"
            for _, task in ipairs(allTasks) do
                completionMessage = completionMessage .. "     [DONE] " .. task.name .. "\n"
            end
            completionMessage = completionMessage .. "\n"
            completionMessage = completionMessage .. "  FINAL PROGRESS\n"
            completionMessage = completionMessage .. "     TOTAL: 100% COMPLETE!\n"
            completionMessage = completionMessage .. "\n"
            completionMessage = completionMessage .. "  SYSTEM STATUS\n"
            completionMessage = completionMessage .. "     TIME: " .. os.date("%H:%M:%S") .. "\n"
            completionMessage = completionMessage .. "     DATE: " .. os.date("%Y-%m-%d") .. "\n"
            completionMessage = completionMessage .. "\n"
            completionMessage = completionMessage .. "  MISSION ACCOMPLISHED!\n"
            completionMessage = completionMessage .. "     All tasks completed successfully!\n"
            completionMessage = completionMessage .. "=============================\n"
            completionMessage = completionMessage .. "```"
            
            if TelegramConfig.Enabled and TelegramConfig.QuestNotifications then
                spawn(function() 
                    SendTelegram(completionMessage)
                    print("[QUEST COMPLETE] All tasks finished for " .. State.CurrentQuest)
                end)
            end
            
            Config.AutoFishingStable = false
            State.Active = false
            continue
        end
        
        if math.floor(questProgress / 10) > math.floor(State.LastProgress / 10) then
            SendQuestNotification(State.CurrentQuest, State.SelectedTask, questProgress, "PROGRESS_UPDATE")
        end
        State.LastProgress = questProgress

        if questProgress >= 100 then
            SendQuestNotification(State.CurrentQuest, nil, 100, "QUEST_COMPLETED")
            Config.AutoFishingStable = false
            State.Active = false
            continue
        end

        if #activeTasks == 0 then
            SendQuestNotification(State.CurrentQuest, nil, 100, "QUEST_COMPLETED")
            Config.AutoFishingStable = false
            State.Active = false
            continue
        end

        local currentTask = nil
        local currentTaskIndex = nil
        
        for i, t in ipairs(activeTasks) do
            if State.SelectedTask and t.name == State.SelectedTask then
                currentTask = t
                currentTaskIndex = i
                break
            end
        end

        if not currentTask then
            if State.LastTaskIndex and State.LastTaskIndex <= #activeTasks then
                currentTaskIndex = State.LastTaskIndex
                currentTask = activeTasks[currentTaskIndex]
            else
                currentTaskIndex = 1
                currentTask = activeTasks[1]
            end
            
            if currentTask then
                State.SelectedTask = currentTask.name
                State.LastTaskIndex = currentTaskIndex
                
                local nextTaskMessage = "```\n"
                nextTaskMessage = nextTaskMessage .. "=============================\n"
                nextTaskMessage = nextTaskMessage .. "  " .. FancyHeader() .. " - NEXT TASK STARTED\n"
                nextTaskMessage = nextTaskMessage .. "  DEVELOPER: NIKZZ\n"
                nextTaskMessage = nextTaskMessage .. "=============================\n"
                nextTaskMessage = nextTaskMessage .. "\n"
                nextTaskMessage = nextTaskMessage .. "  TASK INFORMATION\n"
                nextTaskMessage = nextTaskMessage .. "     QUEST: " .. State.CurrentQuest .. "\n"
                nextTaskMessage = nextTaskMessage .. "     TASK: " .. currentTask.name .. "\n"
                nextTaskMessage = nextTaskMessage .. "     PROGRESS: " .. string.format("%.1f%%", currentTask.percent or 0) .. "\n"
                nextTaskMessage = nextTaskMessage .. "\n"
                nextTaskMessage = nextTaskMessage .. "  REMAINING TASKS\n"
                for i, task in ipairs(activeTasks) do
                    local indicator = (i == currentTaskIndex) and "[ACTIVE]" or "[PENDING]"
                    nextTaskMessage = nextTaskMessage .. "     " .. indicator .. " " .. task.name .. " - " .. string.format("%.1f%%", task.percent) .. "\n"
                end
                nextTaskMessage = nextTaskMessage .. "\n"
                nextTaskMessage = nextTaskMessage .. "  STATUS: STARTING NEXT TASK\n"
                nextTaskMessage = nextTaskMessage .. "=============================\n"
                nextTaskMessage = nextTaskMessage .. "```"
                
                if TelegramConfig.Enabled and TelegramConfig.QuestNotifications then
                    spawn(function() SendTelegram(nextTaskMessage) end)
                end
            end
        end

        if not currentTask then
            State.SelectedTask = nil
            State.LastTaskIndex = nil
            State.CurrentLocation = nil
            State.Teleported = false
            State.Fishing = false
            Config.AutoFishingStable = false
            continue
        end

        if currentTask.percent >= 100 and not State.Fishing then
            SendQuestNotification(State.CurrentQuest, currentTask.name, 100, "TASK_COMPLETED")
            
            local remainingTasks = getActiveTasks(State.CurrentQuest)
            local nextTaskName = "QUEST COMPLETED"
            if #remainingTasks > 1 then
                local nextIndex = (currentTaskIndex < #activeTasks) and currentTaskIndex + 1 or 1
                if activeTasks[nextIndex] then
                    nextTaskName = activeTasks[nextIndex].name
                end
            end
            
            local taskCompleteMessage = "```\n"
            taskCompleteMessage = taskCompleteMessage .. "=============================\n"
            taskCompleteMessage = taskCompleteMessage .. "  " .. FancyHeader() .. " - TASK COMPLETED\n"
            taskCompleteMessage = taskCompleteMessage .. "  DEVELOPER: NIKZZ\n"
            taskCompleteMessage = taskCompleteMessage .. "=============================\n"
            taskCompleteMessage = taskCompleteMessage .. "\n"
            taskCompleteMessage = taskCompleteMessage .. "  COMPLETED TASK\n"
            taskCompleteMessage = taskCompleteMessage .. "     " .. currentTask.name .. "\n"
            taskCompleteMessage = taskCompleteMessage .. "     STATUS: 100% FINISHED\n"
            taskCompleteMessage = taskCompleteMessage .. "\n"
            taskCompleteMessage = taskCompleteMessage .. "  NEXT TARGET\n"
            taskCompleteMessage = taskCompleteMessage .. "     " .. nextTaskName .. "\n"
            taskCompleteMessage = taskCompleteMessage .. "\n"
            taskCompleteMessage = taskCompleteMessage .. "  OVERALL PROGRESS\n"
            taskCompleteMessage = taskCompleteMessage .. "     QUEST: " .. string.format("%.1f%%", questProgress) .. "\n"
            taskCompleteMessage = taskCompleteMessage .. "     REMAINING: " .. (#remainingTasks - 1) .. " tasks\n"
            taskCompleteMessage = taskCompleteMessage .. "\n"
            taskCompleteMessage = taskCompleteMessage .. "  STATUS: MOVING TO NEXT TASK\n"
            taskCompleteMessage = taskCompleteMessage .. "=============================\n"
            taskCompleteMessage = taskCompleteMessage .. "```"
            
            if TelegramConfig.Enabled and TelegramConfig.QuestNotifications then
                spawn(function() SendTelegram(taskCompleteMessage) end)
            end
            
            if currentTaskIndex < #activeTasks then
                State.LastTaskIndex = currentTaskIndex + 1
            else
                State.LastTaskIndex = 1
            end
            State.SelectedTask = nil
            State.CurrentLocation = nil
            State.Teleported = false
            State.Fishing = false
            continue
        end

        if not State.CurrentLocation then
            State.CurrentLocation = findLocationByTaskName(currentTask.name)
            if not State.CurrentLocation then
                State.SelectedTask = nil
                continue
            end
        end

        if not State.Teleported then
            if teleportTo(State.CurrentLocation) then
                SendQuestNotification(State.CurrentQuest, currentTask.name, questProgress, "TELEPORT")
                State.Teleported = true
                task.wait(2)
            end
            continue
        end

        if not State.Fishing then
            Config.AutoFishingStable = true
            AutoFishingStable()
            State.Fishing = true
            SendQuestNotification(State.CurrentQuest, currentTask.name, questProgress, "FARMING")
        end
    end
end)

-- ================= UI CREATION =================

local function CreateUI()
    local Islands = {}
    local Players_List = {}
    local Events = {}
    
    -- TAB 1: FISHING
    local Tab1 = Window:CreateTab("Fishing", 4483362458)
    
    Tab1:CreateSection("Auto Features")
    
    Tab1:CreateToggle({
        Name = "Auto Fishing V1 (Ultra Fast)",
        CurrentValue = Config.AutoFishingV1,
        Callback = function(Value)
            Config.AutoFishingV1 = Value
            if Value then
                Config.AutoFishingV2 = false
                Config.AutoFishingStable = false
                AutoFishingV1()
                Rayfield:Notify({Title = "Auto Fishing V1", Content = "Started with Anti-Stuck!", Duration = 3})
            end
        end
    })
    
    Tab1:CreateToggle({
        Name = "Auto Fishing V2 (Game Auto)",
        CurrentValue = Config.AutoFishingV2,
        Callback = function(Value)
            Config.AutoFishingV2 = Value
            if Value then
                Config.AutoFishingV1 = false
                Config.AutoFishingStable = false
                AutoFishingV2()
                Rayfield:Notify({Title = "Auto Fishing V2", Content = "Using game auto with perfect catch!", Duration = 3})
            end
        end
    })
    
    Tab1:CreateToggle({
        Name = "Auto Fishing Stable",
        CurrentValue = Config.AutoFishingStable,
        Callback = function(Value)
            Config.AutoFishingStable = Value
            if Value then
                Config.AutoFishingV1 = false
                Config.AutoFishingV2 = false
                AutoFishingStable()
                Rayfield:Notify({Title = "Auto Fishing Stable", Content = "Stable version started!", Duration = 3})
            end
        end
    })
    
    Tab1:CreateSlider({
        Name = "Fishing Delay",
        Range = {0.1, 5},
        Increment = 0.1,
        CurrentValue = Config.FishingDelay,
        Callback = function(Value)
            Config.FishingDelay = Value
        end
    })
    
    Tab1:CreateToggle({
        Name = "Perfect Catch",
        CurrentValue = Config.PerfectCatch,
        Callback = function(Value)
            TogglePerfectCatch(Value)
            Rayfield:Notify({
                Title = "Perfect Catch",
                Content = Value and "Enabled!" or "Disabled!",
                Duration = 2
            })
        end
    })
    
    Tab1:CreateToggle({
        Name = "Anti AFK",
        CurrentValue = Config.AntiAFK,
        Callback = function(Value)
            Config.AntiAFK = Value
            if Value then AntiAFK() end
        end
    })
    
    Tab1:CreateToggle({
        Name = "Auto Sell Fish",
        CurrentValue = Config.AutoSell,
        Callback = function(Value)
            Config.AutoSell = Value
            if Value then AutoSell() end
        end
    })
    
    Tab1:CreateSection("Extra Fishing")
    
    Tab1:CreateToggle({
        Name = "Auto Jump",
        CurrentValue = Config.AutoJump,
        Callback = function(Value)
            Config.AutoJump = Value
            if Value then 
                AutoJump()
                Rayfield:Notify({
                    Title = "Auto Jump",
                    Content = "Started with " .. Config.AutoJumpDelay .. "s delay",
                    Duration = 2
                })
            end
        end
    })
    
    Tab1:CreateSlider({
        Name = "Jump Delay",
        Range = {1, 10},
        Increment = 0.5,
        CurrentValue = Config.AutoJumpDelay,
        Callback = function(Value)
            Config.AutoJumpDelay = Value
            if Config.AutoJump then
                Config.AutoJump = false
                task.wait(0.5)
                Config.AutoJump = true
                AutoJump()
                Rayfield:Notify({
                    Title = "Jump Delay Updated",
                    Content = "New delay: " .. Value .. "s",
                    Duration = 2
                })
            end
        end
    })
    
    Tab1:CreateToggle({
        Name = "Walk on Water",
        CurrentValue = Config.WalkOnWater,
        Callback = function(Value)
            Config.WalkOnWater = Value
            if Value then
                WalkOnWater()
                Rayfield:Notify({
                    Title = "Walk on Water",
                    Content = "Enabled - You can now walk on water!",
                    Duration = 2
                })
            else
                Rayfield:Notify({
                    Title = "Walk on Water",
                    Content = "Disabled",
                    Duration = 2
                })
            end
        end
    })
    
    Tab1:CreateToggle({
        Name = "Enable Radar",
        CurrentValue = false,
        Callback = function(Value)
            pcall(function() Radar:InvokeServer(Value) end)
            Rayfield:Notify({
                Title = "Fishing Radar",
                Content = Value and "Enabled!" or "Disabled!",
                Duration = 2
            })
        end
    })
    
    Tab1:CreateToggle({
        Name = "Enable Diving Gear",
        CurrentValue = false,
        Callback = function(Value)
            pcall(function()
                if Value then
                    EquipTool:FireServer(2)
                    EquipOxy:InvokeServer(105)
                else
                    UnequipOxy:InvokeServer()
                end
            end)
            Rayfield:Notify({
                Title = "Diving Gear",
                Content = Value and "Activated!" or "Deactivated!",
                Duration = 2
            })
        end
    })
    
    -- TAB 2: WEATHER
    local Tab2 = Window:CreateTab("Weather", 4483362458)
    
    Tab2:CreateSection("Auto Buy Weather")
    
    local Weather1Drop = Tab2:CreateDropdown({
        Name = "Weather Slot 1",
        Options = {"None", "Wind", "Cloudy", "Snow", "Storm", "Radiant", "Shark Hunt"},
        CurrentOption = {"None"},
        Callback = function(Option)
            if Option[1] ~= "None" then
                Config.SelectedWeathers[1] = Option[1]
            else
                Config.SelectedWeathers[1] = nil
            end
        end
    })
    
    local Weather2Drop = Tab2:CreateDropdown({
        Name = "Weather Slot 2",
        Options = {"None", "Wind", "Cloudy", "Snow", "Storm", "Radiant", "Shark Hunt"},
        CurrentOption = {"None"},
        Callback = function(Option)
            if Option[1] ~= "None" then
                Config.SelectedWeathers[2] = Option[1]
            else
                Config.SelectedWeathers[2] = nil
            end
        end
    })
    
    local Weather3Drop = Tab2:CreateDropdown({
        Name = "Weather Slot 3",
        Options = {"None", "Wind", "Cloudy", "Snow", "Storm", "Radiant", "Shark Hunt"},
        CurrentOption = {"None"},
        Callback = function(Option)
            if Option[1] ~= "None" then
                Config.SelectedWeathers[3] = Option[1]
            else
                Config.SelectedWeathers[3] = nil
            end
        end
    })
    
    Tab2:CreateButton({
        Name = "Buy Selected Weathers Now",
        Callback = function()
            for _, weather in ipairs(Config.SelectedWeathers) do
                if weather then
                    pcall(function()
                        PurchaseWeather:InvokeServer(weather)
                        Rayfield:Notify({
                            Title = "Weather Purchased",
                            Content = "Bought: " .. weather,
                            Duration = 2
                        })
                    end)
                    task.wait(0.5)
                end
            end
        end
    })
    
    Tab2:CreateToggle({
        Name = "Auto Buy Weather (Continuous)",
        CurrentValue = Config.AutoBuyWeather,
        Callback = function(Value)
            Config.AutoBuyWeather = Value
            if Value then
                AutoBuyWeather()
                Rayfield:Notify({
                    Title = "Auto Buy Weather",
                    Content = "Will keep buying selected weathers!",
                    Duration = 3
                })
            end
        end
    })
    
    -- TAB 3: AUTO QUEST
    local Tab3 = Window:CreateTab("Auto Quest", 4483362458)
    
    local StatusLabel = Tab3:CreateLabel("STATUS: Idle")

    task.spawn(function()
        while task.wait(2) do
            local text = "STATUS\n\n"
            if State.Active then
                text = text .. "Quest: " .. State.CurrentQuest .. "\n"
                text = text .. "Progress: " .. string.format("%.1f", getQuestProgress(State.CurrentQuest)) .. "%\n"
                if State.SelectedTask then text = text .. "\nTask: " .. State.SelectedTask .. "\n" end
                text = text .. (State.Fishing and "\nFARMING..." or "\nPreparing...")
            else
                text = text .. "Idle\n\n"
            end
            text = text .. "\nAuto Fishing Stable: " .. (Config.AutoFishingStable and "ON" or "OFF")
            StatusLabel:Set(text)
        end
    end)
    
    local Selected = {}
    local Quests = {
        {Name = "Aura", Display = "Aura Boat"},
        {Name = "Deep Sea", Display = "Ghostfinn Rod"},
        {Name = "Element", Display = "Element Rod"}
    }

    for _, quest in ipairs(Quests) do
        Tab3:CreateSection("Tasks - " .. quest.Display)

        local function build_dropdown_options()
            local opts = {"Auto"}
            for _, t in ipairs(getActiveTasks(quest.Name)) do
                table.insert(opts, t.name)
            end
            return opts
        end

        local dropdown = Tab3:CreateDropdown({
            Name = quest.Display,
            Options = build_dropdown_options(),
            CurrentOption = "Auto",
            Callback = function(opt)
                if type(opt) == "table" then opt = opt[1] end
                Selected[quest.Name] = opt
            end
        })

        task.spawn(function()
            while task.wait(10) do
                if dropdown and dropdown.Refresh then
                    dropdown:Refresh(build_dropdown_options(), true)
                end
            end
        end)

        Tab3:CreateToggle({
            Name = "Auto " .. quest.Display,
            CurrentValue = false,
            Callback = function(val)
                if val then
                    if quest.Name == "Element" and getQuestProgress("Deep Sea") < 100 then
                        Rayfield:Notify({Title = "Need Ghostfinn 100% first!", Duration = 3})
                        return
                    end
                    local sel = Selected[quest.Name] or "Auto"
                    if type(sel) == "table" then sel = sel[1] end
                    if sel == "Auto" then sel = nil end
                    State.Active = true
                    State.CurrentQuest = quest.Name
                    State.SelectedTask = sel
                    State.CurrentLocation = nil
                    State.Teleported = false
                    State.Fishing = false
                    State.LastProgress = getQuestProgress(quest.Name)
                    State.LastTaskIndex = nil
                    
                    SendQuestNotification(quest.Display, sel or "Auto", State.LastProgress, "START")
                else
                    State.Active = false
                    Config.AutoFishingStable = false
                end
            end
        })

        Tab3:CreateButton({
            Name = "Check Progress " .. quest.Display,
            Callback = function()
                local all = getAllTasks(quest.Name)
                if #all == 0 then
                    Rayfield:Notify({Title = "No Tasks Found", Duration = 2})
                    return
                end
                local progress = getQuestProgress(quest.Name)
                local msg = quest.Display .. " Progress:\n"
                for _, t in ipairs(all) do
                    msg = msg .. string.format("- %s\n", t.name)
                end
                msg = msg .. string.format("\nTOTAL PROGRESS: %.1f%%", progress)
                Rayfield:Notify({Title = quest.Display, Content = msg, Duration = 6})
            end
        })
    end
    
    -- TAB 4: HOOK SYSTEM
    local Tab4 = Window:CreateTab("Hook System", 4483362458)
    
    Tab4:CreateSection("Telegram Hook Configuration")
    
    Tab4:CreateToggle({
        Name = "Enable Telegram Hook",
        CurrentValue = TelegramConfig.Enabled,
        Callback = function(Value)
            TelegramConfig.Enabled = Value
        end
    })
    
    Tab4:CreateToggle({
        Name = "Enable Quest Notifications",
        CurrentValue = TelegramConfig.QuestNotifications,
        Callback = function(Value)
            TelegramConfig.QuestNotifications = Value
        end
    })
    
    Tab4:CreateInput({
        Name = "Telegram Chat ID",
        PlaceholderText = "Enter Chat ID",
        RemoveTextAfterFocusLost = false,
        Callback = function(Text)
            TelegramConfig.ChatID = Text
        end,
    })
    
    Tab4:CreateParagraph({ Title = "Token Info", Content = "Bot token is pre-configured in script. Just enter your Chat ID above." })
    
    Tab4:CreateSection("Select Rarities (max 3)")
    local rarities = {"MYTHIC", "LEGENDARY", "SECRET", "EPIC", "RARE", "UNCOMMON", "COMMON"}
    for _, r in ipairs(rarities) do TelegramConfig.SelectedRarities[r] = TelegramConfig.SelectedRarities[r] or false end

    for _, r in ipairs(rarities) do
        Tab4:CreateToggle({ Name = r, CurrentValue = TelegramConfig.SelectedRarities[r], Callback = function(val)
            if val then
                if CountSelected() + 1 > TelegramConfig.MaxSelection then
                    print("[UI] Maximum "..TelegramConfig.MaxSelection.." rarity selected!")
                    TelegramConfig.SelectedRarities[r] = false
                    return
                else
                    TelegramConfig.SelectedRarities[r] = true
                end
            else
                TelegramConfig.SelectedRarities[r] = false
            end
        end })
    end
    
    Tab4:CreateSection("Test & Utilities")
    
    Tab4:CreateButton({ Name = "Test Random SECRET", Callback = function()
        if TelegramConfig.ChatID == "" then
            print("[UI] Chat ID empty!")
            return
        end

        local secretItems = {}
        for id, info in pairs(ItemDatabase) do
            local tier = tonumber(info.Tier) or 0
            local rarity = string.upper(tostring(info.Rarity or ""))
            if tier == 7 or rarity == "SECRET" then
                table.insert(secretItems, {Id = id, Info = info})
            end
        end

        if #secretItems == 0 then
            print("[TEST] No SECRET items in database.")
            return
        end

        local chosen = secretItems[math.random(1, #secretItems)]
        local info, rarity = chosen.Info, "SECRET"
        local weight = tonumber(info.Weight) or math.random(2, 6) + math.random()

        print(string.format("[TEST] SECRET -> %s (Tier %s)", info.Name, tostring(info.Tier)))
        local msg = BuildTelegramMessage(info, chosen.Id, rarity, weight)
        local ok = SendTelegram(msg)

        print(ok and "[TEST] SECRET sent" or "[TEST] SECRET failed")
    end })
    
    Tab4:CreateButton({ Name = "Test Random LEGENDARY", Callback = function()
        if TelegramConfig.ChatID == "" then
            print("[UI] Chat ID empty!")
            return
        end

        local legendaryItems = {}
        for id, info in pairs(ItemDatabase) do
            local tier = tonumber(info.Tier) or 0
            local rarity = string.upper(tostring(info.Rarity or ""))
            if tier == 5 or rarity == "LEGENDARY" then
                table.insert(legendaryItems, {Id = id, Info = info})
            end
        end

        if #legendaryItems == 0 then
            print("[TEST] No LEGENDARY items in database.")
            return
        end

        local chosen = legendaryItems[math.random(1, #legendaryItems)]
        local info, rarity = chosen.Info, "LEGENDARY"
        local weight = tonumber(info.Weight) or math.random(1, 5) + math.random()

        print(string.format("[TEST] LEGENDARY -> %s (Tier %s)", info.Name, tostring(info.Tier)))
        local msg = BuildTelegramMessage(info, chosen.Id, rarity, weight)
        local ok = SendTelegram(msg)

        print(ok and "[TEST] LEGENDARY sent" or "[TEST] LEGENDARY failed")
    end })
    
    Tab4:CreateButton({ Name = "Test Random MYTHIC", Callback = function()
        if TelegramConfig.ChatID == "" then
            print("[UI] Chat ID empty!")
            return
        end

        local mythicItems = {}
        for id, info in pairs(ItemDatabase) do
            local tier = tonumber(info.Tier) or 0
            local rarity = string.upper(tostring(info.Rarity or ""))
            if tier == 6 or rarity == "MYTHIC" or rarity == "MYTICH" then
                table.insert(mythicItems, {Id = id, Info = info})
            end
        end

        if #mythicItems == 0 then
            print("[TEST] No MYTHIC items in database.")
            return
        end

        local chosen = mythicItems[math.random(1, #mythicItems)]
        local info, rarity = chosen.Info, "MYTHIC"
        local weight = tonumber(info.Weight) or math.random(2, 5) + math.random()

        print(string.format("[TEST] MYTHIC -> %s (Tier %s)", info.Name, tostring(info.Tier)))
        local msg = BuildTelegramMessage(info, chosen.Id, rarity, weight)
        local ok = SendTelegram(msg)

        print(ok and "[TEST] MYTHIC sent" or "[TEST] MYTHIC failed")
    end })
    
    -- TAB 5: UTILITY (MERGED)
    local Tab5 = Window:CreateTab("Utility", 4483362458)
    
    Tab5:CreateSection("Speed Settings")
    
    Tab5:CreateSlider({
        Name = "Walk Speed",
        Range = {16, 500},
        Increment = 1,
        CurrentValue = Config.WalkSpeed,
        Callback = function(Value)
            Config.WalkSpeed = Value
            if Humanoid then
                Humanoid.WalkSpeed = Value
            end
        end
    })
    
    Tab5:CreateSlider({
        Name = "Jump Power",
        Range = {50, 500},
        Increment = 5,
        CurrentValue = Config.JumpPower,
        Callback = function(Value)
            Config.JumpPower = Value
            if Humanoid then
                Humanoid.JumpPower = Value
            end
        end
    })
    
    Tab5:CreateInput({
        Name = "Custom Speed",
        PlaceholderText = "Enter any speed value",
        RemoveTextAfterFocusLost = false,
        Callback = function(Text)
            local speed = tonumber(Text)
            if speed and speed >= 1 then
                if Humanoid then
                    Humanoid.WalkSpeed = speed
                    Config.WalkSpeed = speed
                    Rayfield:Notify({Title = "Speed Set", Content = "Speed: " .. speed, Duration = 2})
                end
            end
        end
    })
    
    Tab5:CreateButton({
        Name = "Reset Speed to Normal",
        Callback = function()
            if Humanoid then
                Humanoid.WalkSpeed = 16
                Humanoid.JumpPower = 50
                Config.WalkSpeed = 16
                Config.JumpPower = 50
                Rayfield:Notify({Title = "Speed Reset", Content = "Back to normal", Duration = 2})
            end
        end
    })
    
    Tab5:CreateSection("Extra Utility")
    
    Tab5:CreateToggle({
        Name = "NoClip",
        CurrentValue = Config.NoClip,
        Callback = function(Value)
            Config.NoClip = Value
            if Value then
                NoClip()
            end
            Rayfield:Notify({
                Title = "NoClip",
                Content = Value and "Enabled" or "Disabled",
                Duration = 2
            })
        end
    })
    
    Tab5:CreateToggle({
        Name = "XRay (Transparent Walls)",
        CurrentValue = Config.XRay,
        Callback = function(Value)
            Config.XRay = Value
            if Value then
                XRay()
            end
            Rayfield:Notify({
                Title = "XRay Mode",
                Content = Value and "Enabled" or "Disabled",
                Duration = 2
            })
        end
    })
    
    Tab5:CreateToggle({
        Name = "Enable ESP",
        CurrentValue = Config.ESPEnabled,
        Callback = function(Value)
            Config.ESPEnabled = Value
            if Value then
                ESP()
            end
            Rayfield:Notify({
                Title = "ESP",
                Content = Value and "Enabled" or "Disabled",
                Duration = 2
            })
        end
    })
    
    Tab5:CreateSlider({
        Name = "ESP Distance",
        Range = {10, 50},
        Increment = 1,
        CurrentValue = Config.ESPDistance,
        Callback = function(Value)
            Config.ESPDistance = Value
        end
    })
    
    Tab5:CreateButton({
        Name = "Highlight All Players",
        Callback = function()
            for _, player in pairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character then
                    local highlight = Instance.new("Highlight", player.Character)
                    highlight.FillColor = Color3.fromRGB(255, 0, 0)
                    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
                    highlight.FillTransparency = 0.5
                end
            end
            Rayfield:Notify({Title = "ESP Enabled", Content = "All players highlighted", Duration = 2})
        end
    })
    
    Tab5:CreateButton({
        Name = "Remove All Highlights",
        Callback = function()
            for _, player in pairs(Players:GetPlayers()) do
                if player.Character then
                    for _, obj in pairs(player.Character:GetChildren()) do
                        if obj:IsA("Highlight") then
                            obj:Destroy()
                        end
                    end
                end
            end
            Rayfield:Notify({Title = "ESP Disabled", Content = "Highlights removed", Duration = 2})
        end
    })
    
    Tab5:CreateButton({
        Name = "Infinite Jump",
        Callback = function()
            UserInputService.JumpRequest:Connect(function()
                if Humanoid then
                    Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                end
            end)
            Rayfield:Notify({Title = "Infinite Jump", Content = "Enabled", Duration = 2})
        end
    })
    
    Tab5:CreateSection("Lighting & Graphics")
    
    Tab5:CreateButton({
        Name = "Fullbright",
        Callback = function()
            Config.Brightness = 3
            Config.TimeOfDay = 14
            Lighting.Brightness = 3
            Lighting.ClockTime = 14
            Lighting.FogEnd = 100000
            Lighting.GlobalShadows = false
            Lighting.OutdoorAmbient = Color3.fromRGB(200, 200, 200)
            ApplyPermanentLighting()
            Rayfield:Notify({Title = "Fullbright", Content = "Maximum brightness", Duration = 2})
        end
    })
    
    Tab5:CreateButton({
        Name = "Remove Fog",
        Callback = function()
            RemoveFog()
            Rayfield:Notify({Title = "Fog Removed", Content = "Fog disabled permanently", Duration = 2})
        end
    })
    
    Tab5:CreateButton({
        Name = "8-Bit Mode",
        Callback = function()
            Enable8Bit()
            Rayfield:Notify({Title = "8-Bit Mode", Content = "Ultra smooth graphics enabled", Duration = 2})
        end
    })
    
    Tab5:CreateSlider({
        Name = "Brightness",
        Range = {0, 10},
        Increment = 0.5,
        CurrentValue = Config.Brightness,
        Callback = function(Value)
            Config.Brightness = Value
            Lighting.Brightness = Value
            ApplyPermanentLighting()
        end
    })
    
    Tab5:CreateSlider({
        Name = "Time of Day",
        Range = {0, 24},
        Increment = 0.5,
        CurrentValue = Config.TimeOfDay,
        Callback = function(Value)
            Config.TimeOfDay = Value
            Lighting.ClockTime = Value
            ApplyPermanentLighting()
        end
    })
    
    Tab5:CreateButton({
        Name = "Remove Particles",
        Callback = function()
            RemoveParticles()
            Rayfield:Notify({Title = "Particles Removed", Content = "All effects disabled", Duration = 2})
        end
    })
    
    Tab5:CreateButton({
        Name = "Remove Seaweed",
        Callback = function()
            RemoveSeaweed()
            Rayfield:Notify({Title = "Seaweed Removed", Content = "Water cleared", Duration = 2})
        end
    })
    
    Tab5:CreateButton({
        Name = "Optimize Water",
        Callback = function()
            OptimizeWater()
            Rayfield:Notify({Title = "Water Optimized", Content = "Water effects minimized", Duration = 2})
        end
    })
    
    Tab5:CreateButton({
        Name = "Performance Mode All In One",
        Callback = function()
            PerformanceMode()
            Rayfield:Notify({Title = "Performance Mode", Content = "Max FPS optimization applied!", Duration = 3})
        end
    })
    
    Tab5:CreateButton({
        Name = "Reset Graphics",
        Callback = function()
            if LightingConnection then LightingConnection:Disconnect() end
            Config.Brightness = 2
            Config.TimeOfDay = 14
            Lighting.Brightness = 2
            Lighting.FogEnd = 10000
            Lighting.GlobalShadows = true
            Lighting.ClockTime = 14
            settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
            Rayfield:Notify({Title = "Graphics Reset", Content = "Back to normal", Duration = 2})
        end
    })
    
    Tab5:CreateSection("Camera")
    
    Tab5:CreateButton({
        Name = "Infinite Zoom",
        Callback = function()
            Config.InfiniteZoom = true
            InfiniteZoom()
            Rayfield:Notify({Title = "Infinite Zoom", Content = "Zoom limits removed", Duration = 2})
        end
    })
    
    Tab5:CreateButton({
        Name = "Remove Camera Shake",
        Callback = function()
            local cam = Workspace.CurrentCamera
            if cam then
                cam.FieldOfView = 70
            end
            Rayfield:Notify({Title = "Camera Fixed", Content = "Shake removed", Duration = 2})
        end
    })
    
    Tab5:CreateSection("Event Scanner")
    
    local EventDrop = Tab5:CreateDropdown({
        Name = "Select Event",
        Options = {"Load events first"},
        CurrentOption = {"Load events first"},
        Callback = function(Option) end
    })
    
    Tab5:CreateButton({
        Name = "Load Events",
        Callback = function()
            Events = ScanActiveEvents()
            local options = {}
            
            for i, event in ipairs(Events) do
                table.insert(options, string.format("%d. %s", i, event.Name))
            end
            
            if #options == 0 then
                options = {"No events active"}
            end
            
            EventDrop:Refresh(options)
            Rayfield:Notify({
                Title = "Events Loaded",
                Content = string.format("Found %d events", #Events),
                Duration = 2
            })
        end
    })
    
    Tab5:CreateButton({
        Name = "Teleport to Event",
        Callback = function()
            local selected = EventDrop.CurrentOption[1]
            local index = tonumber(selected:match("^(%d+)%."))
            
            if index and Events[index] then
                TeleportToPosition(Events[index].Position)
                Rayfield:Notify({Title = "Teleported", Content = "Teleported to event", Duration = 2})
            end
        end
    })
    
    Tab5:CreateSection("Auto Rejoin")
    
    Tab5:CreateToggle({
        Name = "Auto Rejoin on Disconnect",
        CurrentValue = Config.AutoRejoin,
        Callback = function(Value)
            Config.AutoRejoin = Value
            if Value then
                SetupAutoRejoin()
                Rayfield:Notify({
                    Title = "Auto Rejoin",
                    Content = "Will auto rejoin if disconnected!",
                    Duration = 3
                })
            end
        end
    })
    
    -- TAB 6: TELEPORT
    local Tab6 = Window:CreateTab("Teleport", 4483362458)
    
    Tab6:CreateSection("Islands")
    
    local IslandOptions = {}
    for i, island in ipairs(IslandsData) do
        table.insert(IslandOptions, string.format("%d. %s", i, island.Name))
    end
    
    local IslandDrop = Tab6:CreateDropdown({
        Name = "Select Island",
        Options = IslandOptions,
        CurrentOption = {IslandOptions[1]},
        Callback = function(Option) end
    })
    
    Tab6:CreateButton({
        Name = "Teleport to Island",
        Callback = function()
            local selected = IslandDrop.CurrentOption[1]
            local index = tonumber(selected:match("^(%d+)%."))
            
            if index and IslandsData[index] then
                TeleportToPosition(IslandsData[index].Position)
                Rayfield:Notify({
                    Title = "Teleported",
                    Content = "Teleported to " .. IslandsData[index].Name,
                    Duration = 2
                })
            end
        end
    })
    
    Tab6:CreateToggle({
        Name = "Lock Position",
        CurrentValue = Config.LockedPosition,
        Callback = function(Value)
            Config.LockedPosition = Value
            if Value then
                Config.LockCFrame = HumanoidRootPart.CFrame
                LockPosition()
            end
            Rayfield:Notify({
                Title = "Lock Position",
                Content = Value and "Position Locked!" or "Position Unlocked!",
                Duration = 2
            })
        end
    })
    
    Tab6:CreateSection("Players")
    
    local PlayerDrop = Tab6:CreateDropdown({
        Name = "Select Player",
        Options = {"Load players first"},
        CurrentOption = {"Load players first"},
        Callback = function(Option) end
    })
    
    Tab6:CreateButton({
        Name = "Load Players",
        Callback = function()
            Players_List = {}
            for _, player in pairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character then
                    table.insert(Players_List, player.Name)
                end
            end
            
            if #Players_List == 0 then
                Players_List = {"No players online"}
            end
            
            PlayerDrop:Refresh(Players_List)
            Rayfield:Notify({
                Title = "Players Loaded",
                Content = string.format("Found %d players", #Players_List),
                Duration = 2
            })
        end
    })
    
    Tab6:CreateButton({
        Name = "Teleport to Player",
        Callback = function()
            local selected = PlayerDrop.CurrentOption[1]
            local player = Players:FindFirstChild(selected)
            
            if player and player.Character then
                local hrp = player.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    HumanoidRootPart.CFrame = hrp.CFrame * CFrame.new(0, 3, 0)
                    Rayfield:Notify({Title = "Teleported", Content = "Teleported to " .. selected, Duration = 2})
                end
            end
        end
    })
    
    Tab6:CreateSection("Position Manager")
    
    Tab6:CreateButton({
        Name = "Save Current Position",
        Callback = function()
            Config.SavedPosition = HumanoidRootPart.CFrame
            Rayfield:Notify({Title = "Saved", Content = "Position saved", Duration = 2})
        end
    })
    
    Tab6:CreateButton({
        Name = "Teleport to Saved Position",
        Callback = function()
            if Config.SavedPosition then
                HumanoidRootPart.CFrame = Config.SavedPosition
                Rayfield:Notify({Title = "Teleported", Content = "Loaded saved position", Duration = 2})
            else
                Rayfield:Notify({Title = "Error", Content = "No saved position", Duration = 2})
            end
        end
    })
    
    Tab6:CreateButton({
        Name = "Teleport to Checkpoint",
        Callback = function()
            if Config.CheckpointPosition then
                HumanoidRootPart.CFrame = Config.CheckpointPosition
                Rayfield:Notify({Title = "Teleported", Content = "Back to checkpoint", Duration = 2})
            end
        end
    })
    
    -- TAB 7: MISC
    local Tab7 = Window:CreateTab("Misc", 4483362458)
    
    Tab7:CreateSection("Character")
    
    Tab7:CreateButton({
        Name = "Reset Character",
        Callback = function()
            Character:BreakJoints()
            Rayfield:Notify({Title = "Resetting", Content = "Character respawning", Duration = 2})
        end
    })
    
    Tab7:CreateButton({
        Name = "Remove Accessories",
        Callback = function()
            for _, obj in pairs(Character:GetChildren()) do
                if obj:IsA("Accessory") then
                    obj:Destroy()
                end
            end
            Rayfield:Notify({Title = "Accessories Removed", Content = "Character cleaned", Duration = 2})
        end
    })
    
    Tab7:CreateButton({
        Name = "Rainbow Character",
        Callback = function()
            spawn(function()
                for i = 1, 100 do
                    if Character then
                        for _, part in pairs(Character:GetDescendants()) do
                            if part:IsA("BasePart") then
                                part.Color = Color3.fromHSV(i / 100, 1, 1)
                            end
                        end
                    end
                    task.wait(0.1)
                end
            end)
            Rayfield:Notify({Title = "Rainbow Mode", Content = "Character colorized", Duration = 2})
        end
    })
    
    Tab7:CreateSection("Audio")
    
    Tab7:CreateButton({
        Name = "Mute All Sounds",
        Callback = function()
            for _, sound in pairs(Workspace:GetDescendants()) do
                if sound:IsA("Sound") then
                    sound.Volume = 0
                end
            end
            Rayfield:Notify({Title = "Sounds Muted", Content = "All audio disabled", Duration = 2})
        end
    })
    
    Tab7:CreateButton({
        Name = "Restore Sounds",
        Callback = function()
            for _, sound in pairs(Workspace:GetDescendants()) do
                if sound:IsA("Sound") then
                    sound.Volume = 0.5
                end
            end
            Rayfield:Notify({Title = "Sounds Restored", Content = "Audio enabled", Duration = 2})
        end
    })
    
    Tab7:CreateSection("Inventory")
    
    Tab7:CreateButton({
        Name = "Show Inventory",
        Callback = function()
            print("=== INVENTORY ===")
            local backpack = LocalPlayer:FindFirstChild("Backpack")
            local count = 0
            if backpack then
                for i, item in ipairs(backpack:GetChildren()) do
                    if item:IsA("Tool") then
                        count = count + 1
                        print(string.format("[%d] %s", count, item.Name))
                    end
                end
            end
            print("=== TOTAL: " .. count .. " ===")
            Rayfield:Notify({Title = "Inventory", Content = "Found " .. count .. " items (check console F9)", Duration = 3})
        end
    })
    
    Tab7:CreateButton({
        Name = "Drop All Items",
        Callback = function()
            for _, item in pairs(LocalPlayer.Backpack:GetChildren()) do
                if item:IsA("Tool") then
                    item.Parent = Character
                    task.wait(0.1)
                    item.Parent = Workspace
                end
            end
            Rayfield:Notify({Title = "Items Dropped", Content = "All items dropped", Duration = 2})
        end
    })
    
    Tab7:CreateSection("Server")
    
    Tab7:CreateButton({
        Name = "Show Server Stats",
        Callback = function()
            local stats = string.format(
                "=== SERVER STATS ===\n" ..
                "Players: %d/%d\n" ..
                "Ping: %d ms\n" ..
                "FPS: %d\n" ..
                "Job ID: %s\n" ..
                "=== END ===",
                #Players:GetPlayers(),
                Players.MaxPlayers,
                LocalPlayer:GetNetworkPing() * 1000,
                workspace:GetRealPhysicsFPS(),
                game.JobId
            )
            print(stats)
            Rayfield:Notify({Title = "Server Stats", Content = "Check console (F9)", Duration = 3})
        end
    })
    
    Tab7:CreateButton({
        Name = "Copy Job ID",
        Callback = function()
            setclipboard(game.JobId)
            Rayfield:Notify({Title = "Copied", Content = "Job ID copied to clipboard", Duration = 2})
        end
    })
    
    Tab7:CreateButton({
        Name = "Rejoin Server (Same)",
        Callback = function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
        end
    })
    
    Tab7:CreateButton({
        Name = "Rejoin Server (Random)",
        Callback = function()
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end
    })
    
    -- TAB 8: INFO
    local Tab8 = Window:CreateTab("Info", 4483362458)
    
    Tab8:CreateSection("Script Information")
    
    Tab8:CreateParagraph({
        Title = "NIKZZ FISH IT - FINAL INTEGRATED VERSION",
        Content = "Complete Integration: Auto Quest + Fishing + Telegram Hook + Database\nDeveloper: Nikzz\nStatus: FULLY OPERATIONAL\nVersion: FINAL INTEGRATED"
    })
    
    Tab8:CreateSection("Features Overview")
    
    Tab8:CreateParagraph({
        Title = "Fishing System",
        Content = "Auto Fishing V1 (Ultra Fast)\nAuto Fishing V2 (Game Auto)\nAuto Fishing Stable (Quest Compatible)\nPerfect Catch Mode\nAuto Sell Fish\nRadar & Diving Gear\nAdjustable Fishing Delay\nAnti-Stuck Protection"
    })
    
    Tab8:CreateParagraph({
        Title = "Quest System",
        Content = "Auto Quest for Aura, Deep Sea, Element\nAuto Task Selection\nAuto Teleport to Quest Locations\nProgress Tracking\nTelegram Quest Notifications\nMultiple Quest Support"
    })
    
    Tab8:CreateParagraph({
        Title = "Hook System",
        Content = "Telegram Fish Notifications\nRarity Filter (Max 3)\nQuest Progress Notifications\nDatabase Integration\nTest Functions for All Rarities"
    })
    
    Tab8:CreateParagraph({
        Title = "Teleport System",
        Content = "21 Island Locations\nPlayer Teleport\nEvent Detection & Scanner\nPosition Lock Feature\nCheckpoint System\nSaved Position Manager"
    })
    
    Tab8:CreateParagraph({
        Title = "Utility Features",
        Content = "Custom Speed (Unlimited)\nWalk on Water\nNoClip & XRay\nInfinite Jump\nAuto Jump with Delay\nESP System\nEvent Scanner\nAuto Rejoin\nPerformance Mode"
    })
    
    Tab8:CreateParagraph({
        Title = "Weather System",
        Content = "Buy up to 3 weathers at once\nAuto buy mode (continuous)\nAll weather types supported\nWind, Cloudy, Snow, Storm, Radiant, Shark Hunt"
    })
    
    Tab8:CreateSection("Usage Guide")
    
    Tab8:CreateParagraph({
        Title = "Quick Start Guide",
        Content = "1. Enable Auto Fishing (V1/V2/Stable)\n2. Configure Telegram Hook (optional)\n3. Select Quest and Enable Auto Quest\n4. Adjust Speed in Utility Tab\n5. Use Perfect Catch for Manual Fishing"
    })
    
    Tab8:CreateParagraph({
        Title = "Important Notes",
        Content = "Auto Fishing V1: Ultra fast with anti-stuck\nAuto Fishing V2: Uses game auto\nAuto Fishing Stable: Best for quests\nAll features auto-load on start\nDatabase loaded from FULL_ITEM_DATA.json\nTelegram notifications require Chat ID"
    })
    
    Tab8:CreateSection("Script Control")
    
    Tab8:CreateButton({
        Name = "Show Statistics",
        Callback = function()
            local stats = string.format(
                "=== NIKZZ STATISTICS ===\n" ..
                "Version: FINAL INTEGRATED\n" ..
                "Islands Available: %d\n" ..
                "Players Online: %d\n" ..
                "Auto Fishing V1: %s\n" ..
                "Auto Fishing V2: %s\n" ..
                "Auto Fishing Stable: %s\n" ..
                "Auto Jump: %s\n" ..
                "Auto Buy Weather: %s\n" ..
                "Auto Rejoin: %s\n" ..
                "Walk on Water: %s\n" ..
                "Walk Speed: %d\n" ..
                "Telegram Hook: %s\n" ..
                "Quest Active: %s\n" ..
                "=== END ===",
                #IslandsData,
                #Players:GetPlayers() - 1,
                Config.AutoFishingV1 and "ON" or "OFF",
                Config.AutoFishingV2 and "ON" or "OFF",
                Config.AutoFishingStable and "ON" or "OFF",
                Config.AutoJump and "ON" or "OFF",
                Config.AutoBuyWeather and "ON" or "OFF",
                Config.AutoRejoin and "ON" or "OFF",
                Config.WalkOnWater and "ON" or "OFF",
                Config.WalkSpeed,
                TelegramConfig.Enabled and "ON" or "OFF",
                State.Active and State.CurrentQuest or "NONE"
            )
            print(stats)
            Rayfield:Notify({Title = "Statistics", Content = "Check console (F9)", Duration = 3})
        end
    })
    
    Tab8:CreateButton({
        Name = "Close Script",
        Callback = function()
            Rayfield:Notify({Title = "Closing Script", Content = "Shutting down...", Duration = 2})
            
            Config.AutoFishingV1 = false
            Config.AutoFishingV2 = false
            Config.AutoFishingStable = false
            Config.AntiAFK = false
            Config.AutoJump = false
            Config.AutoSell = false
            Config.AutoBuyWeather = false
            Config.AutoRejoin = false
            Config.WalkOnWater = false
            State.Active = false
            
            if LightingConnection then LightingConnection:Disconnect() end
            if WalkOnWaterConnection then WalkOnWaterConnection:Disconnect() end
            
            task.wait(2)
            Rayfield:Destroy()
            
            print("=======================================")
            print("  NIKZZ FISH IT - FINAL VERSION CLOSED")
            print("  All Features Stopped")
            print("  Thank you for using!")
            print("=======================================")
        end
    })
    
    task.wait(1)
    Rayfield:Notify({
        Title = "NIKZZ FISH IT - FINAL INTEGRATED VERSION",
        Content = "All systems ready - Complete integration!",
        Duration = 5
    })
    
    print("=======================================")
    print("  NIKZZ FISH IT - FINAL INTEGRATED")
    print("  Status: ALL FEATURES WORKING")
    print("  Developer: Nikzz")
    print("  Version: FINAL INTEGRATED")
    print("=======================================")
    print("  INTEGRATED SYSTEMS:")
    print("  + Auto Quest System")
    print("  + Auto Fishing (3 Modes)")
    print("  + Telegram Hook")
    print("  + Database System")
    print("  + Quest Hook")
    print("  + All Utilities")
    print("=======================================")
    
    return Window
end

-- Character Respawn Handler
LocalPlayer.CharacterAdded:Connect(function(char)
    Character = char
    HumanoidRootPart = char:WaitForChild("HumanoidRootPart")
    Humanoid = char:WaitForChild("Humanoid")
    
    task.wait(2)
    
    if Humanoid then
        Humanoid.WalkSpeed = Config.WalkSpeed
        Humanoid.JumpPower = Config.JumpPower
    end
    
    if Config.AutoFishingV1 then
        task.wait(2)
        AutoFishingV1()
    end
    
    if Config.AutoFishingV2 then
        task.wait(2)
        AutoFishingV2()
    end
    
    if Config.AutoFishingStable then
        task.wait(2)
        AutoFishingStable()
    end
    
    if Config.AntiAFK then
        task.wait(1)
        AntiAFK()
    end
    
    if Config.AutoJump then
        task.wait(1)
        AutoJump()
    end
    
    if Config.AutoSell then
        task.wait(1)
        AutoSell()
    end
    
    if Config.AutoBuyWeather then
        task.wait(1)
        AutoBuyWeather()
    end
    
    if Config.WalkOnWater then
        task.wait(1)
        WalkOnWater()
    end
    
    if Config.NoClip then
        task.wait(1)
        NoClip()
    end
    
    if Config.XRay then
        task.wait(1)
        XRay()
    end
    
    if Config.ESPEnabled then
        task.wait(1)
        ESP()
    end
    
    if Config.PerfectCatch then
        task.wait(1)
        TogglePerfectCatch(true)
    end
    
    if Config.LockedPosition then
        task.wait(1)
        Config.LockCFrame = HumanoidRootPart.CFrame
        LockPosition()
    end
    
    if Config.InfiniteZoom then
        task.wait(1)
        InfiniteZoom()
    end
end)

-- Main Execution
print("Initializing NIKZZ FISH IT - FINAL INTEGRATED VERSION...")

task.wait(1)
Config.CheckpointPosition = HumanoidRootPart.CFrame
print("Checkpoint position saved")

if Config.AutoRejoin then
    LoadRejoinData()
end

task.spawn(function()
    task.wait(3)
    
    if Config.AutoFishingV1 then
        print("[AUTO START] Starting Auto Fishing V1...")
        AutoFishingV1()
    end
    
    if Config.AutoFishingV2 then
        print("[AUTO START] Starting Auto Fishing V2...")
        AutoFishingV2()
    end
    
    if Config.AutoFishingStable then
        print("[AUTO START] Starting Auto Fishing Stable...")
        AutoFishingStable()
    end
    
    if Config.AntiAFK then
        print("[AUTO START] Starting Anti AFK...")
        AntiAFK()
    end
    
    if Config.AutoJump then
        print("[AUTO START] Starting Auto Jump...")
        AutoJump()
    end
    
    if Config.AutoSell then
        print("[AUTO START] Starting Auto Sell...")
        AutoSell()
    end
    
    if Config.AutoBuyWeather then
        print("[AUTO START] Starting Auto Buy Weather...")
        AutoBuyWeather()
    end
    
    if Config.WalkOnWater then
        print("[AUTO START] Starting Walk on Water...")
        WalkOnWater()
    end
    
    if Config.NoClip then
        print("[AUTO START] Starting NoClip...")
        NoClip()
    end
    
    if Config.XRay then
        print("[AUTO START] Starting XRay...")
        XRay()
    end
    
    if Config.ESPEnabled then
        print("[AUTO START] Starting ESP...")
        ESP()
    end
    
    if Config.PerfectCatch then
        print("[AUTO START] Enabling Perfect Catch...")
        TogglePerfectCatch(true)
    end
    
    if Config.InfiniteZoom then
        print("[AUTO START] Enabling Infinite Zoom...")
        InfiniteZoom()
    end
    
    if Config.AutoRejoin then
        print("[AUTO START] Setting up Auto Rejoin...")
        SetupAutoRejoin()
    end
    
    if Humanoid then
        Humanoid.WalkSpeed = Config.WalkSpeed
        Humanoid.JumpPower = Config.JumpPower
    end
    
    Lighting.Brightness = Config.Brightness
    Lighting.ClockTime = Config.TimeOfDay
    
    print("[AUTO START] All enabled features started!")
end)

local success, err = pcall(function()
    CreateUI()
end)

if not success then
    warn("ERROR: " .. tostring(err))
else
    print("NIKZZ FISH IT - FINAL INTEGRATED VERSION LOADED SUCCESSFULLY")
    print("Complete Integration - All Systems Operational")
    print("Developer by Nikzz")
    print("Ready to use!")
    print("")
    print("INTEGRATED FEATURES:")
    print("+ Auto Quest System (Aura, Deep Sea, Element)")
    print("+ Auto Fishing V1 (Ultra Fast with Anti-Stuck)")
    print("+ Auto Fishing V2 (Game Auto with Perfect Catch)")
    print("+ Auto Fishing Stable (Quest Compatible)")
    print("+ Telegram Hook (Fish + Quest Notifications)")
    print("+ Database System (FULL_ITEM_DATA.json)")
    print("+ All Utility Features (Merged Tab)")
    print("+ Teleport System (21 Islands)")
    print("+ Weather Control")
    print("+ Auto Rejoin System")
    print("")
    print("MERGED TABS:")
    print("1. Fishing - All fishing features + extras")
    print("2. Weather - Weather control system")
    print("3. Auto Quest - Quest automation system")
    print("4. Hook System - Telegram notifications")
    print("5. Utility - All utilities merged (speed, graphics, events, etc)")
    print("6. Teleport - Islands, players, positions")
    print("7. Misc - Character, audio, inventory, server")
    print("8. Info - Documentation and controls")
    print("")
    print("All features ready and auto-loaded!")
    print("Enjoy the complete integrated experience!")
end

-- Expose global functions
_G.SetTelegramChatID = function(id)
    TelegramConfig.ChatID = tostring(id or "")
end

_G.NIKZZ_TelegramConfig = TelegramConfig
_G.NIKZZ_ItemDatabase = ItemDatabase
_G.NIKZZ_Config = Config
_G.NIKZZ_State = State

print("=======================================")
print("  SCRIPT FULLY LOADED AND READY")
print("  All systems operational")
print("  Have fun fishing!")
print("=======================================")
