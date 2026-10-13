print("TP Save cargado")

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local saves = {}
local selectedSaves = {}

-- ✅ SEPARACIÓN POR JUEGO
local placeId = game.PlaceId
local fileName = "TPSave_" .. tostring(placeId) .. ".json"

-- ============================================
-- 🔄 AUTO-REJOIN: URL hardcodeada
-- ============================================
local URL_CACHE_FILE = "TPSave_CachedURL.txt"
local SCRIPT_URL_OVERRIDE = "https://pastebin.com/raw/ruqnZWhG"

local function detectarUrlScript()
    if SCRIPT_URL_OVERRIDE and SCRIPT_URL_OVERRIDE ~= "" then
        return SCRIPT_URL_OVERRIDE
    end
    local ok, info = pcall(function() return debug.getinfo(1, "s") end)
    if ok and info and info.source then
        local src = info.source
        if src:sub(1,1) == "=" then src = src:sub(2) end
        if src:sub(1,1) == "@" then src = src:sub(2) end
        if src:match("^https?://") then return src end
    end
    return nil
end

local function leerUrlCacheada()
    if not readfile or not isfile then return nil end
    local ok, data = pcall(function()
        if isfile(URL_CACHE_FILE) then return readfile(URL_CACHE_FILE) end
        return nil
    end)
    if ok and data and data ~= "" and data:match("^https?://") then return data end
    return nil
end

local function guardarUrlCacheada(url)
    if not writefile then return end
    pcall(function() writefile(URL_CACHE_FILE, url) end)
end

local scriptUrl = detectarUrlScript() or leerUrlCacheada()

if scriptUrl then
    guardarUrlCacheada(scriptUrl)
    print("[TP Save] 🔄 URL configurada: " .. scriptUrl)
end

local function queueAutoExec()
    if not scriptUrl then return false end
    local queueFunc = queue_on_teleport or queueonteleport
    if not queueFunc then
        warn("[TP Save] ⚠️ Este executor no soporta queue_on_teleport")
        return false
    end
    local loader = 'loadstring(game:HttpGet("' .. scriptUrl .. '"))()'
    local ok = pcall(function() queueFunc(loader) end)
    if ok then
        print("[TP Save] ✅ Script en cola para el próximo servidor")
    end
    return ok
end

local function canUseFiles()
    return type(writefile) == "function"
       and type(readfile) == "function"
       and type(isfile) == "function"
end

local function saveToDisk()
    if not canUseFiles() then return end
    local ok, err = pcall(function()
        writefile(fileName, HttpService:JSONEncode(saves))
    end)
    if ok then
        print("✅ Guardado en: " .. fileName .. " (" .. #saves .. " saves)")
    else
        warn("❌ Error al guardar: " .. tostring(err))
    end
end

-- ============================================
-- 🧠 SISTEMA DE PRE-CARGA REAL CON RequestStreamAroundAsync ✅
-- ============================================
local zonasCargadas = {} -- { [idSave] = { expiracion = os.time() + 240 } }
local TIEMPO_PRE_CARGA = 240 -- 4 minutos

-- ✅ Esta función SÍ mantiene la zona cargada en memoria
local function precargarZona(cframeTarget, idSave)
    -- Si ya está cargada y no ha expirado, renovamos el tiempo y salimos
    if zonasCargadas[idSave] and os.time() < zonasCargadas[idSave].expiracion then
        zonasCargadas[idSave].expiracion = os.time() + TIEMPO_PRE_CARGA
        print("[TP Save] 🔄 Renovando precarga: " .. tostring(idSave))
        return
    end

    -- Marcar como cargada con tiempo de expiración
    zonasCargadas[idSave] = { expiracion = os.time() + TIEMPO_PRE_CARGA }

    -- ✅ Usar la API nativa de Roblox para cargar la zona
    task.spawn(function()
        local ok, err = pcall(function()
            if player.RequestStreamAroundAsync then
                -- Esto le dice al servidor que envíe los assets de esa zona
                player:RequestStreamAroundAsync(cframeTarget.Position)
                print("[TP Save] 📦 Precargando zona: " .. tostring(idSave))
            else
                warn("[TP Save] ⚠️ RequestStreamAroundAsync no disponible en este juego")
            end
        end)
        if not ok then
            warn("[TP Save] ❌ Error al precargar: " .. tostring(err))
        end
    end)
end

-- Limpiador de zonas expiradas (se ejecuta cada 30 segundos)
task.spawn(function()
    while task.wait(30) do
        local ahora = os.time()
        for id, data in pairs(zonasCargadas) do
            if ahora >= data.expiracion then
                zonasCargadas[id] = nil
                print("[TP Save] 🧹 Zona liberada por inactividad (4 min sin uso): " .. tostring(id))
            end
        end
    end
end)

-- ============================================
-- ✅ SCREEN GUI
-- ============================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DeltaTPSave"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 999
screenGui.IgnoreGuiInset = true
if syn and syn.protect_gui then
    syn.protect_gui(screenGui)
    screenGui.Parent = game:GetService("CoreGui")
elseif gethui then
    screenGui.Parent = gethui()
else
    screenGui.Parent = player:WaitForChild("PlayerGui")
end

-- 📦 MARCO PRINCIPAL
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 120, 0, 240)
mainFrame.Position = UDim2.new(0.5, -60, 0.35, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
mainFrame.Active = true
mainFrame.Parent = screenGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 10)
local frameStroke = Instance.new("UIStroke", mainFrame)
frameStroke.Thickness = 1.5
frameStroke.Color = Color3.fromRGB(0, 0, 0)

-- TÍTULO
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -52, 0, 22)
title.Position = UDim2.new(0, 26, 0, 0)
title.BackgroundTransparency = 1
title.Text = "TP Save"
title.TextColor3 = Color3.fromRGB(0, 0, 0)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = mainFrame

-- ❌ CERRAR
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 20, 0, 20)
closeBtn.Position = UDim2.new(0, 1, 0, 1)
closeBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.TextScaled = true
closeBtn.Font = Enum.Font.GothamBold
closeBtn.Parent = mainFrame
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 5)

-- ➖ MINIMIZAR
local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Size = UDim2.new(0, 20, 0, 20)
minimizeBtn.Position = UDim2.new(1, -22, 0, 1)
minimizeBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
minimizeBtn.Text = "-"
minimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
minimizeBtn.TextScaled = true
minimizeBtn.Font = Enum.Font.GothamBold
minimizeBtn.Parent = mainFrame
Instance.new("UICorner", minimizeBtn).CornerRadius = UDim.new(0, 5)

-- 💾 GUARDAR POSICIÓN
local saveBtn = Instance.new("TextButton")
saveBtn.Size = UDim2.new(1, -12, 0, 26)
saveBtn.Position = UDim2.new(0, 6, 0, 26)
saveBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
saveBtn.Text = "Guardar Posición"
saveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
saveBtn.TextScaled = true
saveBtn.Font = Enum.Font.GothamBold
saveBtn.Parent = mainFrame
Instance.new("UICorner", saveBtn).CornerRadius = UDim.new(0, 7)

-- 🔄 REJOIN
local rejoinBtn = Instance.new("TextButton")
rejoinBtn.Size = UDim2.new(0, 51, 0, 26)
rejoinBtn.Position = UDim2.new(0, 6, 0, 56)
rejoinBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
rejoinBtn.Text = "Rejoin"
rejoinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
rejoinBtn.TextScaled = true
rejoinBtn.Font = Enum.Font.GothamBold
rejoinBtn.Parent = mainFrame
Instance.new("UICorner", rejoinBtn).CornerRadius = UDim.new(0, 7)

-- ✅ AUTO
local autoBtn = Instance.new("TextButton")
autoBtn.Size = UDim2.new(0, 51, 0, 26)
autoBtn.Position = UDim2.new(0, 63, 0, 56)
autoBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
autoBtn.Text = "Auto"
autoBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
autoBtn.TextScaled = true
autoBtn.Font = Enum.Font.GothamBold
autoBtn.Parent = mainFrame
Instance.new("UICorner", autoBtn).CornerRadius = UDim.new(0, 7)

-- 📜 LISTA
local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -12, 0, 148)
scroll.Position = UDim2.new(0, 6, 0, 86)
scroll.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
scroll.ScrollBarThickness = 3
scroll.ScrollBarImageColor3 = Color3.fromRGB(0, 0, 0)
scroll.Parent = mainFrame
Instance.new("UICorner", scroll).CornerRadius = UDim.new(0, 7)
local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 3)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = scroll

-- POPUP NOMBRE
local namePromptFrame = Instance.new("Frame")
namePromptFrame.Size = UDim2.new(0, 150, 0, 120)
namePromptFrame.Position = UDim2.new(0.5, -75, 0.42, 0)
namePromptFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
namePromptFrame.Visible = false
namePromptFrame.ZIndex = 100
namePromptFrame.Parent = screenGui
Instance.new("UICorner", namePromptFrame).CornerRadius = UDim.new(0, 10)
local promptStroke = Instance.new("UIStroke", namePromptFrame)
promptStroke.Thickness = 2
promptStroke.Color = Color3.fromRGB(0, 0, 0)

local promptTitle = Instance.new("TextLabel")
promptTitle.Size = UDim2.new(1, 0, 0, 26)
promptTitle.BackgroundTransparency = 1
promptTitle.Text = "Nombre del Save"
promptTitle.TextColor3 = Color3.fromRGB(0, 0, 0)
promptTitle.Font = Enum.Font.GothamBold
promptTitle.TextSize = 12
promptTitle.ZIndex = 101
promptTitle.Parent = namePromptFrame

local nameInput = Instance.new("TextBox")
nameInput.Size = UDim2.new(1, -14, 0, 28)
nameInput.Position = UDim2.new(0, 7, 0, 28)
nameInput.BackgroundColor3 = Color3.fromRGB(230, 230, 230)
nameInput.Text = ""
nameInput.PlaceholderText = "Escribe un nombre..."
nameInput.TextColor3 = Color3.fromRGB(0, 0, 0)
nameInput.PlaceholderColor3 = Color3.fromRGB(100, 100, 100)
nameInput.Font = Enum.Font.Gotham
nameInput.TextSize = 11
nameInput.ClearTextOnFocus = false
nameInput.ZIndex = 101
nameInput.Parent = namePromptFrame
Instance.new("UICorner", nameInput).CornerRadius = UDim.new(0, 7)

local confirmSaveBtn = Instance.new("TextButton")
confirmSaveBtn.Size = UDim2.new(0, 62, 0, 26)
confirmSaveBtn.Position = UDim2.new(0, 7, 0, 84)
confirmSaveBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
confirmSaveBtn.Text = "Guardar"
confirmSaveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
confirmSaveBtn.Font = Enum.Font.GothamBold
confirmSaveBtn.TextSize = 11
confirmSaveBtn.ZIndex = 101
confirmSaveBtn.Parent = namePromptFrame
Instance.new("UICorner", confirmSaveBtn).CornerRadius = UDim.new(0, 7)

local cancelSaveBtn = Instance.new("TextButton")
cancelSaveBtn.Size = UDim2.new(0, 62, 0, 26)
cancelSaveBtn.Position = UDim2.new(1, -69, 0, 84)
cancelSaveBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
cancelSaveBtn.Text = "Cancelar"
cancelSaveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
cancelSaveBtn.Font = Enum.Font.GothamBold
cancelSaveBtn.TextSize = 11
cancelSaveBtn.ZIndex = 101
cancelSaveBtn.Parent = namePromptFrame
Instance.new("UICorner", cancelSaveBtn).CornerRadius = UDim.new(0, 7)

-- ⚫ MINI BOLA
local miniBall = Instance.new("TextButton")
miniBall.Size = UDim2.new(0, 40, 0, 40)
miniBall.Position = UDim2.new(0.08, 0, 0.78, 0)
miniBall.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
miniBall.Visible = false
miniBall.Text = "SAVE"
miniBall.TextColor3 = Color3.fromRGB(255, 255, 255)
miniBall.TextScaled = true
miniBall.Font = Enum.Font.GothamBold
miniBall.ZIndex = 100
miniBall.Parent = screenGui
Instance.new("UICorner", miniBall).CornerRadius = UDim.new(1, 0)
local ballStroke = Instance.new("UIStroke", miniBall)
ballStroke.Thickness = 1.5
ballStroke.Color = Color3.fromRGB(255, 255, 255)

-- ARRASTRE
local function makeDraggable(guiObject)
    local dragging, dragInput, dragStart, startPos
    guiObject.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = guiObject.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    guiObject.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input == dragInput then
            local delta = input.Position - dragStart
            guiObject.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

makeDraggable(mainFrame)
makeDraggable(miniBall)
makeDraggable(namePromptFrame)

-- ============================================
-- ✅ SISTEMA DE SELECCIÓN
-- ============================================
local function estaSeleccionado(saveData)
    for _, s in ipairs(selectedSaves) do
        if s == saveData then return true end
    end
    return false
end

local function toggleSeleccion(saveData)
    if estaSeleccionado(saveData) then
        for i, s in ipairs(selectedSaves) do
            if s == saveData then
                table.remove(selectedSaves, i)
                break
            end
        end
        return false
    else
        table.insert(selectedSaves, saveData)
        return true
    end
end

-- ============================================
-- ✅ SISTEMA AUTO
-- ============================================
local autoActivo = false
local autoIndex = 1
local INTERVALO_AUTO = 1.0

local function teleportarASave(saveData)
    local char = player.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    -- ✅ Antes de teletransportar, renovamos la precarga de la zona
    local targetCFrame = CFrame.new(unpack(saveData.CFrameComponents))
    precargarZona(targetCFrame, saveData.Name or "Save")

    local ok, err = pcall(function()
        hrp.CFrame = targetCFrame
    end)
    if not ok then
        warn("❌ CFrame inválido: " .. tostring(err))
        return false
    end
    return true
end

local function iniciarAuto()
    if #selectedSaves == 0 then
        StarterGui:SetCore("SendNotification", {
            Title = "TP Save",
            Text = "Selecciona ubicaciones primero",
            Duration = 2
        })
        return false
    end

    autoActivo = true
    autoIndex = 1

    autoBtn.Text = "ON " .. #selectedSaves
    autoBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)

    task.spawn(function()
        while autoActivo do
            if #selectedSaves == 0 then
                autoActivo = false
                break
            end

            if autoIndex > #selectedSaves then
                autoIndex = 1
            end

            local saveData = selectedSaves[autoIndex]
            if saveData then
                teleportarASave(saveData)
            end

            autoIndex = autoIndex + 1
            task.wait(INTERVALO_AUTO)
        end

        autoBtn.Text = "Auto"
        autoBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    end)

    return true
end

local function detenerAuto()
    autoActivo = false
    autoIndex = 1

    autoBtn.Text = "Auto"
    autoBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
end

-- ============================================
-- LISTA CON CHECKBOX
-- ============================================
local reloadList
local function createLoadButton(saveData)
    local btnFrame = Instance.new("Frame")
    btnFrame.Size = UDim2.new(1, 0, 0, 24)
    btnFrame.BackgroundTransparency = 1
    btnFrame.Parent = scroll

    local deleteBtn = Instance.new("TextButton")
    deleteBtn.Size = UDim2.new(0, 16, 1, 0)
    deleteBtn.Position = UDim2.new(0, 2, 0, 0)
    deleteBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    deleteBtn.Text = "X"
    deleteBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    deleteBtn.TextScaled = true
    deleteBtn.Font = Enum.Font.GothamBold
    deleteBtn.Parent = btnFrame
    Instance.new("UICorner", deleteBtn).CornerRadius = UDim.new(0, 5)

    local selectBtn = Instance.new("TextButton")
    selectBtn.Size = UDim2.new(0, 16, 1, 0)
    selectBtn.Position = UDim2.new(0, 20, 0, 0)
    selectBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    selectBtn.Text = ""
    selectBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
    selectBtn.Font = Enum.Font.GothamBold
    selectBtn.TextScaled = true
    selectBtn.Parent = btnFrame
    Instance.new("UICorner", selectBtn).CornerRadius = UDim.new(0, 4)

    local loadBtn = Instance.new("TextButton")
    loadBtn.Size = UDim2.new(1, -40, 1, 0)
    loadBtn.Position = UDim2.new(0, 38, 0, 0)
    loadBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    loadBtn.Text = saveData.Name or "Save"
    loadBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    loadBtn.TextScaled = true
    loadBtn.Font = Enum.Font.GothamSemibold
    loadBtn.Parent = btnFrame
    Instance.new("UICorner", loadBtn).CornerRadius = UDim.new(0, 5)

    if estaSeleccionado(saveData) then
        selectBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        selectBtn.Text = "✓"
        selectBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    end

    selectBtn.MouseButton1Click:Connect(function()
        local ahoraSeleccionado = toggleSeleccion(saveData)
        if ahoraSeleccionado then
            selectBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
            selectBtn.Text = "✓"
            selectBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        else
            selectBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            selectBtn.Text = ""
            selectBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
        end
        if autoActivo then
            autoBtn.Text = "ON " .. #selectedSaves
        end
    end)

    loadBtn.MouseButton1Click:Connect(function()
        teleportarASave(saveData)
    end)

    deleteBtn.MouseButton1Click:Connect(function()
        for i, s in ipairs(saves) do
            if s == saveData then
                table.remove(saves, i)
                break
            end
        end
        for i, s in ipairs(selectedSaves) do
            if s == saveData then
                table.remove(selectedSaves, i)
                break
            end
        end
        saveToDisk()
        reloadList()
    end)
end

reloadList = function()
    scroll:ClearAllChildren()
    local newLayout = Instance.new("UIListLayout")
    newLayout.Padding = UDim.new(0, 3)
    newLayout.SortOrder = Enum.SortOrder.LayoutOrder
    newLayout.Parent = scroll
    for _, saveData in ipairs(saves) do
        createLoadButton(saveData)
    end
    scroll.CanvasSize = UDim2.new(0, 0, 0, newLayout.AbsoluteContentSize.Y + 8)
end

-- ✅ CARGA DE DISCO
local function loadFromDisk()
    saves = {}

    if not canUseFiles() then
        print("ℹ️ Este executor no soporta archivos.")
        reloadList()
        return
    end

    if not isfile(fileName) then
        print("ℹ️ Sin guardados previos para este juego.")
        reloadList()
        return
    end

    local ok, res = pcall(function()
        return HttpService:JSONDecode(readfile(fileName))
    end)

    if ok and type(res) == "table" then
        for _, saveData in ipairs(res) do
            if type(saveData) == "table"
               and type(saveData.CFrameComponents) == "table"
               and #saveData.CFrameComponents >= 3
               and (saveData.PlaceId == nil or saveData.PlaceId == placeId)
            then
                table.insert(saves, saveData)
            end
        end
    else
        warn("❌ Error al leer el archivo de saves: " .. tostring(res))
    end

    reloadList()
end

-- ============================================
-- EVENTOS
-- ============================================
minimizeBtn.MouseButton1Click:Connect(function()
    mainFrame.Visible = false
    miniBall.Visible = true
end)

miniBall.MouseButton1Click:Connect(function()
    mainFrame.Visible = true
    miniBall.Visible = false
end)

closeBtn.MouseButton1Click:Connect(function()
    autoActivo = false
    screenGui:Destroy()
end)

saveBtn.MouseButton1Click:Connect(function()
    nameInput.Text = ""
    namePromptFrame.Visible = true
    nameInput:CaptureFocus()
end)

autoBtn.MouseButton1Click:Connect(function()
    if autoActivo then
        detenerAuto()
    else
        iniciarAuto()
    end
end)

-- ============================================
-- 🔄 REJOIN
-- ============================================
rejoinBtn.MouseButton1Click:Connect(function()
    if _G.TPSave_Rejoining then return end
    _G.TPSave_Rejoining = true

    if autoActivo then detenerAuto() end

    local encolado = queueAutoExec()
    if encolado then
        StarterGui:SetCore("SendNotification", {
            Title = "TP Save",
            Text = "Auto-ejecución activada. Buscando servidor vacío...",
            Duration = 2
        })
    else
        StarterGui:SetCore("SendNotification", {
            Title = "TP Save",
            Text = "Buscando servidor vacío...",
            Duration = 2
        })
    end

    task.spawn(function()
        local ok, err = pcall(function()
            local todosLosServidores = {}
            local cursor = ""
            
            for i = 1, 3 do
                local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
                if cursor ~= "" then
                    url = url .. "&cursor=" .. cursor
                end
                
                local response = game:HttpGet(url)
                local data = HttpService:JSONDecode(response)
                
                if data and data.data then
                    for _, servidor in ipairs(data.data) do
                        if servidor.playing < 30 and servidor.id ~= game.JobId then
                            table.insert(todosLosServidores, servidor)
                        end
                    end
                end
                
                if data and data.nextPageCursor then
                    cursor = data.nextPageCursor
                else
                    break
                end
                
                task.wait(0.2)
            end

            if #todosLosServidores == 0 then
                _G.TPSave_Rejoining = false
                return
            end

            table.sort(todosLosServidores, function(a, b)
                return a.playing < b.playing
            end)

            local limite = math.min(10, #todosLosServidores)
            local elegido = todosLosServidores[math.random(1, limite)]

            TeleportService:TeleportToPlaceInstance(game.PlaceId, elegido.id, player)
        end)

        if not ok then
            warn("[TP Save] Error al buscar servidor: " .. tostring(err))
            _G.TPSave_Rejoining = false
        end
    end)

    task.delay(8, function() _G.TPSave_Rejoining = false end)
end)

confirmSaveBtn.MouseButton1Click:Connect(function()
    local char = player.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        local n = nameInput.Text
        if n:match("^%s*$") then n = "Save " .. (#saves + 1) end

        local cframeTarget = char.HumanoidRootPart.CFrame
        table.insert(saves, {
            Name = n,
            PlaceId = placeId,
            CFrameComponents = { cframeTarget:GetComponents() }
        })
        saveToDisk()
        reloadList()
        namePromptFrame.Visible = false

        -- ✅ Precargamos la zona al guardar
        precargarZona(cframeTarget, n)

        StarterGui:SetCore("SendNotification", {
            Title = "TP Save",
            Text = n .. " guardado y precargado",
            Duration = 2
        })
    end
end)

cancelSaveBtn.MouseButton1Click:Connect(function()
    namePromptFrame.Visible = false
end)

nameInput.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        confirmSaveBtn:Activate()
    end
end)

-- INICIO
loadFromDisk()
print("TP Save listo — PlaceId: " .. placeId .. " | Archivo: " .. fileName)
if scriptUrl then
    print("[TP Save] 🔄 Auto-Rejoin LISTO: " .. scriptUrl)
else
    print("[TP Save] ⚠️ Sin URL — Rejoin funcionará sin auto-ejecución")
end
