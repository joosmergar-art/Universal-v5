-- KRYOHUB ADVANCED HITBOX SYSTEM v3.0
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- Optimización: Variables cache
local Vector3_new = Vector3.new
local Color3_fromRGB = Color3.fromRGB
local CFrame_new = CFrame.new

-- Configuración avanzada
local Settings = {
    Hitbox = false,
    HitboxSize = 12,
    HitboxTransparency = 0.6,
    HitboxColor = Color3_fromRGB(0, 255, 150),
    TeamCheck = false, -- No golpear aliados
    HitboxShape = "Ball", -- Ball, Cylinder, Box
    AutoResize = true, -- Ajuste dinámico según distancia
    ShowHitMarkers = true, -- Marcadores de impacto
    DistanceScale = 1.5, -- Multiplicador por distancia
}

-- Cache de jugadores y conexiones
local HitboxCache = {}
local ActiveHitboxes = {}
local CleanupQueue = {}

-- Funciones de utilidad mejoradas
local function CreateHitbox(targetModel)
    if not targetModel then return end
    
    local head = targetModel:FindFirstChild("Head")
    if not head then return end
    
    -- Limpiar hitbox anterior si existe
    if HitboxCache[targetModel] then
        HitboxCache[targetModel]:Destroy()
    end
    
    local fakeBox = Instance.new("Part")
    fakeBox.Name = "RealHitbox"
    fakeBox.Shape = Settings.HitboxShape == "Box" and Enum.PartType.Box or 
                    Settings.HitboxShape == "Cylinder" and Enum.PartType.Cylinder or 
                    Enum.PartType.Ball
    fakeBox.Massless = true
    fakeBox.Anchored = false
    fakeBox.CanCollide = false
    fakeBox.Material = Enum.Material.ForceField
    fakeBox.Parent = head
    
    -- Efecto visual de la hitbox
    local highlight = Instance.new("Highlight")
    highlight.Name = "HitboxHighlight"
    highlight.FillTransparency = Settings.HitboxTransparency
    highlight.OutlineTransparency = 0.5
    highlight.FillColor = Settings.HitboxColor
    highlight.OutlineColor = Color3_fromRGB(255, 255, 255)
    highlight.Parent = fakeBox
    
    -- Partículas de impacto
    local hitParticles = Instance.new("ParticleEmitter")
    hitParticles.Name = "HitParticles"
    hitParticles.Enabled = false
    hitParticles.Rate = 100
    hitParticles.Lifetime = NumberRange.new(0.1, 0.3)
    hitParticles.Size = NumberSequence.new(0.5, 0)
    hitParticles.Color = ColorSequence.new(Settings.HitboxColor)
    hitParticles.Parent = fakeBox
    
    local weld = Instance.new("Weld")
    weld.Part0 = head
    weld.Part1 = fakeBox
    weld.C0 = CFrame_new(0, 0, 0)
    weld.Parent = fakeBox
    
    HitboxCache[targetModel] = fakeBox
    ActiveHitboxes[fakeBox] = targetModel
    
    -- Efecto de creación
    spawn(function()
        local origSize = fakeBox.Size
        fakeBox.Size = Vector3_new(1, 1, 1)
        for i = 0, 1, 0.05 do
            fakeBox.Size = origSize:Lerp(Vector3_new(Settings.HitboxSize, Settings.HitboxSize, Settings.HitboxSize), i)
            task.wait(0.01)
        end
    end)
    
    return fakeBox
end

-- Sistema de hitmarkers
local function CreateHitMarker(position)
    if not Settings.ShowHitMarkers then return end
    
    local marker = Instance.new("Part")
    marker.Size = Vector3_new(0.5, 0.5, 0.5)
    marker.Shape = Enum.PartType.Ball
    marker.Position = position
    marker.Anchored = true
    marker.CanCollide = false
    marker.Material = Enum.Material.Neon
    marker.Color = Color3_fromRGB(255, 100, 100)
    marker.Parent = Workspace
    
    spawn(function()
        for i = 0, 1, 0.1 do
            marker.Transparency = i
            marker.Size = Vector3_new(0.5 * (1 - i), 0.5 * (1 - i), 0.5 * (1 - i))
            task.wait(0.02)
        end
        marker:Destroy()
    end)
end

-- Sistema de detección de impactos mejorado
local function OnHitboxTouched(hitbox, hit)
    if not Settings.Hitbox then return end
    if hit.Name == "RealHitbox" then return end -- Evitar auto-impacto
    
    local targetModel = ActiveHitboxes[hitbox]
    if not targetModel then return end
    
    -- Team check
    if Settings.TeamCheck and targetModel:FindFirstChild("Humanoid") then
        local targetPlayer = Players:GetPlayerFromCharacter(targetModel)
        if targetPlayer and targetPlayer.Team == LocalPlayer.Team then
            return
        end
    end
    
    -- Efecto de impacto
    local hitParticles = hitbox:FindFirstChild("HitParticles")
    if hitParticles then
        hitParticles.Enabled = true
        task.delay(0.1, function()
            hitParticles.Enabled = false
        end)
    end
    
    -- Hitmarker
    CreateHitMarker(hitbox.Position)
    
    -- Efecto de daño visual
    local humanoid = targetModel:FindFirstChild("Humanoid")
    if humanoid then
        local healthBefore = humanoid.Health
        task.delay(0.1, function()
            if humanoid.Health < healthBefore then
                CreateHitMarker(hitbox.Position)
            end
        end)
    end
end

-- Sistema de autoescalado por distancia
local function UpdateHitboxSize(hitbox, targetModel)
    if not Settings.AutoResize then return end
    
    local localHead = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Head")
    local targetHead = targetModel:FindFirstChild("Head")
    
    if localHead and targetHead then
        local distance = (localHead.Position - targetHead.Position).Magnitude
        local scale = math.clamp(distance / 100 * Settings.DistanceScale, 1, 2.5)
        local baseSize = Vector3_new(Settings.HitboxSize, Settings.HitboxSize, Settings.HitboxSize)
        
        hitbox.Size = baseSize * scale
    end
end

-- Bucle principal optimizado
local function UpdateHitboxes()
    if not Settings.Hitbox then return end
    
    local currentTime = tick()
    local hitboxesToRemove = {}
    
    -- Actualizar hitboxes existentes
    for hitbox, targetModel in pairs(ActiveHitboxes) do
        if not targetModel.Parent or not targetModel:FindFirstChild("Humanoid") then
            table.insert(hitboxesToRemove, hitbox)
        else
            UpdateHitboxSize(hitbox, targetModel)
        end
    end
    
    -- Limpiar hitboxes inválidas
    for _, hitbox in pairs(hitboxesToRemove) do
        hitbox:Destroy()
        ActiveHitboxes[hitbox] = nil
        local model = CleanupQueue[hitbox]
        if model then
            HitboxCache[model] = nil
        end
    end
    
    -- Buscar nuevos targets
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj ~= LocalPlayer.Character then
            local humanoid = obj:FindFirstChild("Humanoid")
            local head = obj:FindFirstChild("Head")
            
            if humanoid and head and humanoid.Health > 0 then
                if not HitboxCache[obj] then
                    local hitbox = CreateHitbox(obj)
                    if hitbox then
                        hitbox.Touched:Connect(function(hit)
                            OnHitboxTouched(hitbox, hit)
                        end)
                    end
                end
            end
        end
    end
end

-- Loader mejorado
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "KryoHubLoader"
screenGui.ResetOnSpawn = false
screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- Frame principal con efectos
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 450, 0, 200)
mainFrame.Position = UDim2.new(0.5, -225, 0.5, -100)
mainFrame.BackgroundColor3 = Color3_fromRGB(15, 15, 20)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Parent = screenGui

-- Efecto de gradiente animado
local gradientFrame = Instance.new("Frame")
gradientFrame.Size = UDim2.new(1, 0, 0, 4)
gradientFrame.BackgroundColor3 = Color3_fromRGB(0, 255, 150)
gradientFrame.BorderSizePixel = 0
gradientFrame.Parent = mainFrame

spawn(function()
    while gradientFrame do
        for i = 0, 1, 0.01 do
            gradientFrame.BackgroundColor3 = Color3_fromRGB(
                0,
                150 + math.sin(i * math.pi * 2) * 105,
                150 + math.cos(i * math.pi * 2) * 105
            )
            task.wait(0.02)
        end
    end
end)

-- Esquinas redondeadas
local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 12)
uiCorner.Parent = mainFrame

-- Borde con gradiente
local uiStroke = Instance.new("UIStroke")
uiStroke.Color = Color3_fromRGB(0, 255, 150)
uiStroke.Thickness = 2
uiStroke.Transparency = 0.5
uiStroke.Parent = mainFrame

-- Título con efectos
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 60)
title.Position = UDim2.new(0, 0, 0, 10)
title.BackgroundTransparency = 1
title.Text = "KRYOHUB v3.0"
title.TextColor3 = Color3_fromRGB(255, 255, 255)
title.TextScaled = true
title.Font = Enum.Font.GothamBlack
title.Parent = mainFrame

-- Gradiente del título animado
local titleGradient = Instance.new("UIGradient")
titleGradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3_fromRGB(0, 255, 150)),
    ColorSequenceKeypoint.new(0.5, Color3_fromRGB(0, 200, 255)),
    ColorSequenceKeypoint.new(1, Color3_fromRGB(150, 0, 255))
}
titleGradient.Parent = title

-- Status con iconos
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -40, 0, 40)
statusLabel.Position = UDim2.new(0, 20, 0, 80)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "⚡ Preparando sistema avanzado..."
statusLabel.TextColor3 = Color3_fromRGB(255, 200, 100)
statusLabel.TextScaled = true
statusLabel.Font = Enum.Font.GothamSemibold
statusLabel.Parent = mainFrame

-- Barra de progreso
local progressBar = Instance.new("Frame")
progressBar.Size = UDim2.new(0.9, 0, 0, 6)
progressBar.Position = UDim2.new(0.05, 0, 0, 140)
progressBar.BackgroundColor3 = Color3_fromRGB(40, 40, 50)
progressBar.BorderSizePixel = 0
progressBar.Parent = mainFrame

local progressFill = Instance.new("Frame")
progressFill.Size = UDim2.new(0, 0, 1, 0)
progressFill.BackgroundColor3 = Color3_fromRGB(0, 255, 150)
progressFill.BorderSizePixel = 0
progressFill.Parent = progressBar

local progressCorner = Instance.new("UICorner")
progressCorner.CornerRadius = UDim.new(1, 0)
progressCorner.Parent = progressFill

-- Sistema de arrastre mejorado
local dragging, dragStart, startPos
title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position
        mainFrame.BackgroundTransparency = 0.2
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(
            startPos.X.Scale, 
            startPos.X.Offset + delta.X, 
            startPos.Y.Scale, 
            startPos.Y.Offset + delta.Y
        )
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
        mainFrame.BackgroundTransparency = 0
    end
end)

-- Inicialización
task.spawn(function()
    -- Animación de carga
    for i = 1, 10 do
        progressFill.Size = UDim2.new(i * 0.1, 0, 1, 0)
        statusLabel.Text = "⚡ " .. {
            "Cargando módulos...",
            "Optimizando hitboxes...",
            "Configurando físicas...",
            "Sincronizando partículas...",
            "Calibrando colisiones...",
            "Activando efectos visuales...",
            "Inicializando red...",
            "Preparando interfaz...",
            "Verificando seguridad...",
            "✅ Sistema listo!"
        }[i]
        task.wait(0.15)
    end
    
    task.wait(0.5)
    screenGui:Destroy()
    
    -- Cargar UI principal
    local success, Rayfield = pcall(function()
        return loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
    end)
    
    if not success then
        warn("Error cargando Rayfield:", Rayfield)
        return
    end
    
    local Window = Rayfield:CreateWindow({
        Name = "KryoHub - Real Hitbox v3",
        LoadingTitle = "Inyectando Multiplicador...",
        LoadingSubtitle = "Sistema Avanzado de Hitbox",
        ConfigurationSaving = { Enabled = true },
        ConfigurationFolder = "KryoHub_Configs",
        KeySystem = false
    })
    
    local TabCombat = Window:CreateTab("⚔️ Combate", 4483362458)
    local TabVisuals = Window:CreateTab("👁️ Visuales", 4483362458)
    local TabSettings = Window:CreateTab("⚙️ Config", 4483362458)
    
    -- Toggle principal
    TabCombat:CreateToggle({
        Name = "Activar Hitbox Realista",
        CurrentValue = false,
        Flag = "HitboxToggle",
        Callback = function(Value)
            Settings.Hitbox = Value
            if not Value then
                for hitbox, _ in pairs(ActiveHitboxes) do
                    hitbox:Destroy()
                end
                table.clear(HitboxCache)
                table.clear(ActiveHitboxes)
            end
        end,
    })
    
    -- Selector de forma
    TabCombat:CreateDropdown({
        Name = "Forma de Hitbox",
        Options = {"Ball", "Cylinder", "Box"},
        CurrentOption = "Ball",
        Flag = "HitboxShape",
        Callback = function(Option)
            Settings.HitboxShape = Option
            -- Recrear todas las hitboxes con nueva forma
            for hitbox, model in pairs(ActiveHitboxes) do
                hitbox:Destroy()
                CreateHitbox(model)
            end
        end,
    })
    
    -- Slider de tamaño
    TabCombat:CreateSlider({
        Name = "Tamaño de Hitbox",
        Range = {4, 30},
        Increment = 1,
        Suffix = "Studs",
        CurrentValue = 12,
        Flag = "SizeSlider",
        Callback = function(Value)
            Settings.HitboxSize = Value
        end,
    })
    
    -- Toggle de team check
    TabCombat:CreateToggle({
        Name = "No Golpear Aliados",
        CurrentValue = false,
        Flag = "TeamCheck",
        Callback = function(Value)
            Settings.TeamCheck = Value
        end,
    })
    
    -- Visuales
    TabVisuals:CreateSlider({
        Name = "Transparencia",
        Range = {0, 100},
        Increment = 5,
        Suffix = "%",
        CurrentValue = 60,
        Flag = "Transparency",
        Callback = function(Value)
            Settings.HitboxTransparency = Value / 100
        end,
    })
    
    TabVisuals:CreateColorPicker({
        Name = "Color de Hitbox",
        Color = Color3_fromRGB(0, 255, 150),
        Flag = "HitboxColor",
        Callback = function(Color)
            Settings.HitboxColor = Color
        end,
    })
    
    TabVisuals:CreateToggle({
        Name = "Mostrar Marcadores",
        CurrentValue = true,
        Flag = "HitMarkers",
        Callback = function(Value)
            Settings.ShowHitMarkers = Value
        end,
    })
    
    -- Config avanzada
    TabSettings:CreateToggle({
        Name = "Auto-Escalar por Distancia",
        CurrentValue = true,
        Flag = "AutoResize",
        Callback = function(Value)
            Settings.AutoResize = Value
        end,
    })
    
    TabSettings:CreateSlider({
        Name = "Multiplicador de Escala",
        Range = {1, 3},
        Increment = 0.1,
        Suffix = "x",
        CurrentValue = 1.5,
        Flag = "DistanceScale",
        Callback = function(Value)
            Settings.DistanceScale = Value
        end,
    })
    
    -- Conectar el bucle principal
    RunService.Heartbeat:Connect(UpdateHitboxes)
    
    -- Limpieza al salir
    LocalPlayer.CharacterRemoving:Connect(function()
        for hitbox, _ in pairs(ActiveHitboxes) do
            hitbox:Destroy()
        end
        table.clear(HitboxCache)
        table.clear(ActiveHitboxes)
    end)
end)