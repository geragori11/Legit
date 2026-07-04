return function(Window)
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local LocalPlayer = Players.LocalPlayer
    local Camera = workspace.CurrentCamera
    local Debris = game:GetService("Debris")
    
    local LegitTab = Window:CreateTab("LEGIT", 4483362458)
    
    -- --- НАСТРОЙКИ ФУНКЦИЙ ---
    local SmartESPEnabled = false
    local SmartESPRadius = 40

    local WeaponAlertEnabled = false

    local CoinESPEnabled = false
    local CoinESPRadius = 20

    local ProximityEnabled = false

    local TrailsEnabled = false
    local LastTrailSpawn = 0

    local GunTrackerEnabled = false

    -- Настройки новой функции Тепловой Карты Нычек
    local HidingSpotsEnabled = false
    local HidingSpotsRadius = 12
    local LastSpotCheck = 0
    
    -- ТАБЛИЦА С ТВОИМИ НЫЧКАМИ
    local HidingSpots = {
        -- 1. Лобби (Добавлено через Vector3 координат, так как это надежнее всего)
        Vector3.new(-16.29867172241211, 519.5198974609375, 66.64859008789062),
        
        -- 2. Карта House2 (Добавлено через координаты)
        Vector3.new(-3.17547607421875, 258.2041015625, 8960.1005859375),
        
        -- Пример добавления через динамический путь (если карта загружена):
        -- workspace:FindFirstChild("House2") and workspace.House2.Base:FindFirstChild("Part")
    }

    -- --- ТАБЛИЦЫ ХРАНЕНИЯ ОБЪЕКТОВ ---
    local ActiveHighlights = {}
    local ActiveCoinHighlights = {}
    local ActiveSpotHighlights = {} -- Хранилище эффектов для нычек
    local ActiveGunHighlight = nil

    -- ==========================================
    -- СОЗДАНИЕ ЛЕГИТНОГО UI ДЛЯ ИНДИКАТОРОВ
    -- ==========================================
    local LegitGui = Instance.new("ScreenGui")
    LegitGui.Name = "MM2_Legit_Assist"
    LegitGui.ResetOnSpawn = false
    pcall(function() LegitGui.Parent = game:GetService("CoreGui") end)
    if not LegitGui.Parent then LegitGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

    -- Индикатор датчика приближения
    local ProximityLabel = Instance.new("TextLabel")
    ProximityLabel.Size = UDim2.new(0, 200, 0, 30)
    ProximityLabel.Position = UDim2.new(0.5, -100, 0, 50)
    ProximityLabel.BackgroundTransparency = 1
    ProximityLabel.Font = Enum.Font.GothamBold
    ProximityLabel.TextSize = 16
    ProximityLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    ProximityLabel.Text = ""
    ProximityLabel.Visible = false
    ProximityLabel.Parent = LegitGui

    -- Текстовое предупреждение о ноже
    local AlertLabel = Instance.new("TextLabel")
    AlertLabel.Size = UDim2.new(0, 300, 0, 40)
    AlertLabel.Position = UDim2.new(0.5, -150, 0.1, 0)
    AlertLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    AlertLabel.BackgroundTransparency = 0.3
    AlertLabel.Font = Enum.Font.GothamBold
    AlertLabel.TextSize = 18
    AlertLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
    AlertLabel.Text = "⚠️ УБИЙЦА ДОСТАЛ НОЖ! ⚠️"
    AlertLabel.Visible = false
    AlertLabel.Parent = LegitGui
    
    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 8)
    UICorner.Parent = AlertLabel

    -- ==========================================
    -- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
    -- ==========================================
    local function IsVisible(TargetPlayer)
        local Character = LocalPlayer.Character
        local TargetCharacter = TargetPlayer.Character
        if not Character or not TargetCharacter then return false end
        
        local Origin = Character:FindFirstChild("HumanoidRootPart") or Character:FindFirstChild("Head")
        local Destination = TargetCharacter:FindFirstChild("HumanoidRootPart") or TargetCharacter:FindFirstChild("Head")
        if not Origin or not Destination then return false end
        
        local RayParams = RaycastParams.new()
        RayParams.FilterType = Enum.RaycastFilterType.Exclude
        RayParams.FilterDescendantsInstances = {Character, TargetCharacter, Camera}
        RayParams.IgnoreWater = true
        
        local RayResult = workspace:Raycast(Origin.Position, Destination.Position - Origin.Position, RayParams)
        return RayResult == nil
    end

    local function GetDistance(Part)
        if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return 999999 end
        return (LocalPlayer.Character.HumanoidRootPart.Position - Part.Position).Magnitude
    end

    -- Очистка ESP при выключении
    local function ClearAllESP()
        for player, highlight in pairs(ActiveHighlights) do
            if highlight then highlight:Destroy() end
        end
        table.clear(ActiveHighlights)
    end

    local function ClearCoinESP()
        for coin, highlight in pairs(ActiveCoinHighlights) do
            if highlight then highlight:Destroy() end
        end
        table.clear(ActiveCoinHighlights)
    end

    -- Очистка подсветки нычек
    local function ClearHidingSpotsESP()
        for id, data in pairs(ActiveSpotHighlights) do
            if data.Highlight then data.Highlight:Destroy() end
            if data.Part then data.Part:Destroy() end
        end
        table.clear(ActiveSpotHighlights)
    end

    -- ==========================================
    -- СЕКЦИЯ: SMART VISUALS (УМНЫЙ ESP)
    -- ==========================================
    LegitTab:CreateSection("Subtle Visuals")

    LegitTab:CreateToggle({
        Name = "Умный ESP (Smart ESP)",
        CurrentValue = false,
        Flag = "SmartESPToggle",
        Callback = function(Value)
            SmartESPEnabled = Value
            if not Value then ClearAllESP() end
        end
    })

    LegitTab:CreateSlider({
        Name = "Радиус видимости ESP",
        Range = {10, 150},
        Increment = 5,
        Suffix = " studs",
        CurrentValue = 40,
        Flag = "SmartESPRadiusSlider",
        Callback = function(Value)
            SmartESPRadius = Value
        end
    })

    -- ==========================================
    -- СЕКЦИЯ: RADAR & DETECTORS (ДАТЧИКИ И АЛЕРТЫ)
    -- ==========================================
    LegitTab:CreateSection("Detectors & Alerts")

    LegitTab:CreateToggle({
        Name = "Индикатор оружия (Weapon Draw Alert)",
        CurrentValue = false,
        Flag = "WeaponAlertToggle",
        Callback = function(Value)
            WeaponAlertEnabled = Value
            if not Value then AlertLabel.Visible = false end
        end
    })

    LegitTab:CreateToggle({
        Name = "Датчик приближения (Proximity Warning)",
        CurrentValue = false,
        Flag = "ProximityToggle",
        Callback = function(Value)
            ProximityEnabled = Value
            if not Value then ProximityLabel.Visible = false end
        end
    })

    -- ==========================================
    -- СЕКЦИЯ: WORLD TRACKERS (СБОР И ОБЪЕКТЫ)
    -- ==========================================
    LegitTab:CreateSection("World Trackers")

    LegitTab:CreateToggle({
        Name = "Ограниченный ESP монет (Radius Coins)",
        CurrentValue = false,
        Flag = "CoinESPToggle",
        Callback = function(Value)
            CoinESPEnabled = Value
            if not Value then ClearCoinESP() end
        end
    })

    LegitTab:CreateSlider({
        Name = "Радиус поиска монет",
        Range = {10, 50},
        Increment = 5,
        Suffix = " studs",
        CurrentValue = 20,
        Flag = "CoinRadiusSlider",
        Callback = function(Value)
            CoinESPRadius = Value
        end
    })

    LegitTab:CreateToggle({
        Name = "Подсветка нычек (Hiding Spots)",
        CurrentValue = false,
        Flag = "HidingSpotsToggle",
        Callback = function(Value)
            HidingSpotsEnabled = Value
            if not Value then ClearHidingSpotsESP() end
        end
    })

    LegitTab:CreateToggle({
        Name = "Следы шагов Убийцы (Footstep Trails)",
        CurrentValue = false,
        Flag = "TrailsToggle",
        Callback = function(Value)
            TrailsEnabled = Value
        end
    })

    LegitTab:CreateToggle({
        Name = "Трекер пушки Шерифа (Gun Tracker)",
        CurrentValue = false,
        Flag = "GunTrackerToggle",
        Callback = function(Value)
            GunTrackerEnabled = Value
            if not Value and ActiveGunHighlight then 
                ActiveGunHighlight:Destroy() 
                ActiveGunHighlight = nil
            end
        end
    })

    -- ==========================================
    -- ЕДИНЫЙ ЦИКЛ ОБРАБОТКИ (RENDERSTEPPED)
    -- ==========================================
    RunService.RenderStepped:Connect(function()
        local TargetMurderer = nil
        local TargetSheriff = nil
        local enemyPositions = {}

        -- 1. Сбор ролей на сервере и координат противников
        for _, Player in ipairs(Players:GetPlayers()) do
            if Player ~= LocalPlayer and Player.Character then
                local hasKnife = Player.Character:FindFirstChild("Knife") or (Player:FindFirstChild("Backpack") and Player.Backpack:FindFirstChild("Knife"))
                local hasGun = Player.Character:FindFirstChild("Gun") or (Player:FindFirstChild("Backpack") and Player.Backpack:FindFirstChild("Gun"))
                
                if hasKnife then TargetMurderer = Player end
                if hasGun then TargetSheriff = Player end

                local root = Player.Character:FindFirstChild("HumanoidRootPart")
                local humanoid = Player.Character:FindFirstChildOfClass("Humanoid")
                
                if root and humanoid and humanoid.Health > 0 then
                    table.insert(enemyPositions, root.Position)

                    -- [ЛОГИКА SMART ESP]
                    if SmartESPEnabled then
                        local distance = GetDistance(root)
                        local visible = IsVisible(Player)

                        if distance <= SmartESPRadius or visible then
                            if not ActiveHighlights[Player] then
                                local highlight = Instance.new("Highlight")
                                highlight.Name = "LegitESP"
                                highlight.FillTransparency = 0.5
                                highlight.OutlineTransparency = 0.2
                                highlight.Parent = Player.Character
                                ActiveHighlights[Player] = highlight
                            end
                            
                            if hasKnife then
                                ActiveHighlights[Player].FillColor = Color3.fromRGB(255, 50, 50)
                            elseif hasGun then
                                ActiveHighlights[Player].FillColor = Color3.fromRGB(50, 150, 255)
                            else
                                ActiveHighlights[Player].FillColor = Color3.fromRGB(255, 255, 255)
                            end
                        else
                            if ActiveHighlights[Player] then
                                ActiveHighlights[Player]:Destroy()
                                ActiveHighlights[Player] = nil
                            end
                        end
                    else
                        if ActiveHighlights[Player] then
                            ActiveHighlights[Player]:Destroy()
                            ActiveHighlights[Player] = nil
                        end
                    end
                else
                    if ActiveHighlights[Player] then
                        ActiveHighlights[Player]:Destroy()
                        ActiveHighlights[Player] = nil
                    end
                end
            end
        end

        -- 2. Логика индикатора ножа (Weapon Draw Alert)
        if WeaponAlertEnabled and TargetMurderer and TargetMurderer.Character then
            local knifeEquipped = TargetMurderer.Character:FindFirstChild("Knife")
            AlertLabel.Visible = not not knifeEquipped
        else
            AlertLabel.Visible = false
        end

        -- 3. Логика датчика приближения (Proximity Warning)
        if ProximityEnabled and TargetMurderer and TargetMurderer.Character and TargetMurderer.Character:FindFirstChild("HumanoidRootPart") then
            local dist = math.round(GetDistance(TargetMurderer.Character.HumanoidRootPart))
            ProximityLabel.Visible = true
            ProximityLabel.Text = "Дистанция до Убийцы: " .. tostring(dist) .. " studs"

            if dist > 60 then
                ProximityLabel.TextColor3 = Color3.fromRGB(50, 255, 50)
            elseif dist > 25 and dist <= 60 then
                ProximityLabel.TextColor3 = Color3.fromRGB(255, 255, 50)
            else
                ProximityLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
            end
        else
            ProximityLabel.Visible = false
        end

        -- 4. Логика следов шагов (Footstep Trails)
        if TrailsEnabled and TargetMurderer and TargetMurderer.Character and TargetMurderer.Character:FindFirstChild("HumanoidRootPart") then
            if tick() - LastTrailSpawn > 0.25 then
                LastTrailSpawn = tick()
                local rootPos = TargetMurderer.Character.HumanoidRootPart.Position
                
                local TrailPart = Instance.new("Part")
                TrailPart.Size = Vector3.new(1, 0.1, 1)
                TrailPart.Position = rootPos - Vector3.new(0, 2.8, 0)
                TrailPart.Anchored = true
                TrailPart.CanCollide = false
                TrailPart.Material = Enum.Material.Neon
                TrailPart.Color = Color3.fromRGB(255, 75, 75)
                TrailPart.Transparency = 0.4
                TrailPart.Parent = workspace
                
                task.spawn(function()
                    for i = 4, 10 do
                        task.wait(0.2)
                        if TrailPart and TrailPart.Parent then
                            TrailPart.Transparency = i / 10
                        end
                    end
                    if TrailPart then TrailPart:Destroy() end
                end)
            end
        end

        -- 5. Логика ограниченного ESP на монеты (Radius Coin ESP)
        if CoinESPEnabled then
            local container = workspace:FindFirstChild("Normal") and workspace.Normal:FindFirstChild("CoinContainer")
            local coins = container and container:GetChildren() or {}
            
            if #coins == 0 then
                for _, obj in ipairs(workspace:GetChildren()) do
                    if obj.Name == "CoinContainer" or obj.Name == "Coin" then
                        if obj:IsA("BasePart") then table.insert(coins, obj)
                        else for _, c in ipairs(obj:GetChildren()) do table.insert(coins, c) end end
                    end
                end
            end

            for _, coin in ipairs(coins) do
                if coin:IsA("BasePart") or coin:FindFirstChildOfClass("TouchTransmitter") then
                    local basePart = coin:IsA("BasePart") and coin or coin.Parent:FindFirstChildOfClass("BasePart")
                    if basePart then
                        local dist = GetDistance(basePart)
                        if dist <= CoinESPRadius then
                            if not ActiveCoinHighlights[coin] then
                                local box = Instance.new("BoxHandleAdornment")
                                box.Name = "LegitCoinESP"
                                box.Size = basePart.Size + Vector3.new(0.2, 0.2, 0.2)
                                box.AlwaysOnTop = true
                                box.ZIndex = 5
                                box.Color3 = Color3.fromRGB(255, 215, 0)
                                box.Transparency = 0.6
                                box.Adornee = basePart
                                box.Parent = basePart
                                ActiveCoinHighlights[coin] = box
                            end
                        else
                            if ActiveCoinHighlights[coin] then
                                ActiveCoinHighlights[coin]:Destroy()
                                ActiveCoinHighlights[coin] = nil
                            end
                        end
                    end
                end
            end
        end

        -- 6. Трекер упавшего пистолета (Dead Sheriff Gun Tracker)
        if GunTrackerEnabled then
            local droppedGun = workspace:FindFirstChild("GunDrop")
            if droppedGun and droppedGun:IsA("BasePart") then
                if not ActiveGunHighlight then
                    ActiveGunHighlight = Instance.new("BoxHandleAdornment")
                    ActiveGunHighlight.Name = "LegitGunTracker"
                    ActiveGunHighlight.Size = droppedGun.Size + Vector3.new(0.5, 0.5, 0.5)
                    ActiveGunHighlight.AlwaysOnTop = true
                    ActiveGunHighlight.ZIndex = 6
                    ActiveGunHighlight.Color3 = Color3.fromRGB(0, 255, 255)
                    ActiveGunHighlight.Transparency = 0.4
                    ActiveGunHighlight.Adornee = droppedGun
                    ActiveGunHighlight.Parent = droppedGun
                end
            else
                if ActiveGunHighlight then
                    ActiveGunHighlight:Destroy()
                    ActiveGunHighlight = nil
                end
            end
        end

        -- 7. Логика подсветки нычек (Hiding Spots)
        if HidingSpotsEnabled then
            if tick() - LastSpotCheck > 0.3 then
                LastSpotCheck = tick()

                for id, spot in ipairs(HidingSpots) do
                    if not spot then continue end -- Пропускаем, если объект не существует
                    
                    -- Защищенное получение координат объекта
                    local spotPosition = nil
                    if typeof(spot) == "Vector3" then
                        spotPosition = spot
                    elseif typeof(spot) == "Instance" and spot:IsA("BasePart") then
                        spotPosition = spot.Position
                    end
                    
                    if not spotPosition then continue end
                    
                    local data = ActiveSpotHighlights[id]
                    if not data then
                        data = {}
                        local highlight = Instance.new("Highlight")
                        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                        highlight.OutlineOpacity = 0.8
                        
                        if typeof(spot) == "Instance" then
                            highlight.Adornee = spot
                            highlight.Parent = spot
                        else
                            local visualPart = Instance.new("Part")
                            visualPart.Size = Vector3.new(6, 6, 6)
                            visualPart.Position = spot
                            visualPart.Anchored = true
                            visualPart.CanCollide = false
                            visualPart.Transparency = 1
                            visualPart.Parent = workspace
                            
                            highlight.Adornee = visualPart
                            highlight.Parent = visualPart
                            data.Part = visualPart
                        end
                        data.Highlight = highlight
                        ActiveSpotHighlights[id] = data
                    end
                    
                    local playersInside = 0
                    for _, enemyPos in ipairs(enemyPositions) do
                        if (spotPosition - enemyPos).Magnitude <= HidingSpotsRadius then
                            playersInside = playersInside + 1
                        end
                    end
                    
                    local hl = data.Highlight
                    if playersInside == 0 then
                        hl.FillColor = Color3.fromRGB(0, 255, 120)
                        hl.OutlineColor = Color3.fromRGB(0, 255, 120)
                        hl.FillOpacity = 0.15
                    elseif playersInside == 1 then
                        hl.FillColor = Color3.fromRGB(255, 200, 0)
                        hl.OutlineColor = Color3.fromRGB(255, 200, 0)
                        hl.FillOpacity = 0.4
                    else
                        hl.FillColor = Color3.fromRGB(255, 0, 50)
                        hl.OutlineColor = Color3.fromRGB(255, 0, 50)
                        hl.FillOpacity = 0.6
                    end
                end
            end
        else
            -- Если функция отключена, очищаем созданные Vector3-парты
            if next(ActiveSpotHighlights) ~= nil then
                ClearHidingSpotsESP()
            end
        end

    end)
end
