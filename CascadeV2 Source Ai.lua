--[[
    CascadeV2 - Enhanced UI Library
    Version: 2.1.0
    
    Improvements:
    ✓ Memory management with proper cleanup & connection pooling
    ✓ Additional controls (TextInput, Keybind, ColorPicker, Label)
    ✓ Bug fixes and performance optimizations
    ✓ Better animations and hover effects
    ✓ Dropdown closes on outside click
    ✓ Window bounds checking (can't drag off-screen)
    ✓ Error handling for callbacks
    ✓ Window minimize/maximize
    ✓ Slider decimal support with increment
    ✓ Theme customization
    ✓ Shadow effects
    ✓ Notification types (Info, Success, Warning, Error)
]]

--// Services
local Players = game:GetService('Players')
local UserInputService = game:GetService('UserInputService')
local TweenService = game:GetService('TweenService')
local RunService = game:GetService('RunService')

local LocalPlayer = Players.LocalPlayer

--// Constants
local CORNER_RADIUS = 6
local ANIMATION_SPEED = 0.18
local DEFAULT_EASING = Enum.EasingStyle.Quint

--// Main Module
local CascadeV2 = {}
CascadeV2.__index = CascadeV2

--// Theme Configuration
CascadeV2.Theme = {
    Background = Color3.fromRGB(16, 17, 20),
    Panel = Color3.fromRGB(24, 25, 30),
    PanelAlt = Color3.fromRGB(20, 21, 25),
    Accent = Color3.fromRGB(0, 140, 255),
    AccentDark = Color3.fromRGB(0, 100, 200),
    AccentLight = Color3.fromRGB(50, 170, 255),
    Text = Color3.fromRGB(235, 235, 245),
    SubText = Color3.fromRGB(170, 175, 190),
    Outline = Color3.fromRGB(70, 75, 95),
    ToggleOn = Color3.fromRGB(0, 175, 110),
    ToggleOff = Color3.fromRGB(55, 56, 65),
    SliderTrack = Color3.fromRGB(40, 42, 50),
    SliderFill = Color3.fromRGB(0, 140, 255),
    Notification = Color3.fromRGB(26, 27, 33),
    Error = Color3.fromRGB(255, 75, 75),
    Warning = Color3.fromRGB(255, 180, 50),
    Success = Color3.fromRGB(0, 175, 110),
}

--// Internal State
CascadeV2._gui = nil
CascadeV2._notifHolder = nil
CascadeV2.Windows = {}

--// Class Definitions
local Window = {}
Window.__index = Window

local Tab = {}
Tab.__index = Tab

local Section = {}
Section.__index = Section

--[[ ================== UTILITY CLASSES ================== ]]

-- Connection Manager for proper cleanup
local ConnectionManager = {}
ConnectionManager.__index = ConnectionManager

function ConnectionManager.new()
    return setmetatable({ _connections = {} }, ConnectionManager)
end

function ConnectionManager:Add(connection)
    if connection then
        table.insert(self._connections, connection)
    end
    return connection
end

function ConnectionManager:Disconnect()
    for _, conn in ipairs(self._connections) do
        if typeof(conn) == "RBXScriptConnection" and conn.Connected then
            conn:Disconnect()
        end
    end
    table.clear(self._connections)
end

--[[ ================== UTILITY FUNCTIONS ================== ]]

-- Safe callback execution with error handling
local function safeCallback(callback, ...)
    if not callback then return end
    local success, err = pcall(callback, ...)
    if not success then
        warn("[CascadeV2] Callback error:", err)
    end
end

-- Create tween helper
local function createTween(instance, properties, duration, easingStyle, easingDirection)
    return TweenService:Create(
        instance,
        TweenInfo.new(
            duration or ANIMATION_SPEED,
            easingStyle or DEFAULT_EASING,
            easingDirection or Enum.EasingDirection.Out
        ),
        properties
    )
end

-- Apply corner radius
local function applyCorner(instance, radius)
    local corner = Instance.new('UICorner')
    corner.CornerRadius = UDim.new(0, radius or CORNER_RADIUS)
    corner.Parent = instance
    return corner
end

-- Apply stroke
local function applyStroke(instance, color, thickness)
    local stroke = Instance.new('UIStroke')
    stroke.Color = color or CascadeV2.Theme.Outline
    stroke.Thickness = thickness or 1
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.LineJoinMode = Enum.LineJoinMode.Round
    stroke.Parent = instance
    return stroke
end

-- Create shadow effect
local function applyShadow(instance, transparency)
    local shadow = Instance.new('ImageLabel')
    shadow.Name = 'Shadow'
    shadow.BackgroundTransparency = 1
    shadow.Position = UDim2.new(0, -15, 0, -15)
    shadow.Size = UDim2.new(1, 30, 1, 30)
    shadow.ZIndex = -1
    shadow.Image = 'rbxassetid://6014261993'
    shadow.ImageColor3 = Color3.new(0, 0, 0)
    shadow.ImageTransparency = transparency or 0.5
    shadow.ScaleType = Enum.ScaleType.Slice
    shadow.SliceCenter = Rect.new(49, 49, 450, 450)
    shadow.Parent = instance
    return shadow
end

-- Ensure GUI exists
local function ensureGui()
    if CascadeV2._gui and CascadeV2._gui.Parent then
        return CascadeV2._gui
    end

    local gui = Instance.new('ScreenGui')
    gui.Name = 'CascadeV2_' .. tostring(math.random(100000, 999999))
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    gui.DisplayOrder = 999

    -- Try CoreGui first, fall back to PlayerGui
    local success = pcall(function()
        gui.Parent = game:GetService('CoreGui')
    end)

    if not success then
        pcall(function()
            gui.Parent = LocalPlayer:WaitForChild('PlayerGui', 5)
        end)
    end

    if not gui.Parent then
        warn("[CascadeV2] Failed to parent GUI")
        return nil
    end

    CascadeV2._gui = gui

    -- Create notification holder
    local notifHolder = Instance.new('Frame')
    notifHolder.Name = 'Notifications'
    notifHolder.BackgroundTransparency = 1
    notifHolder.AnchorPoint = Vector2.new(1, 1)
    notifHolder.Position = UDim2.new(1, -20, 1, -20)
    notifHolder.Size = UDim2.new(0, 300, 0.8, 0)
    notifHolder.Parent = gui

    local list = Instance.new('UIListLayout')
    list.FillDirection = Enum.FillDirection.Vertical
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.HorizontalAlignment = Enum.HorizontalAlignment.Right
    list.VerticalAlignment = Enum.VerticalAlignment.Bottom
    list.Padding = UDim.new(0, 8)
    list.Parent = notifHolder

    CascadeV2._notifHolder = notifHolder

    return gui
end

-- Make frame draggable with bounds checking
local function makeDraggable(frame, dragArea, connections, boundToScreen)
    dragArea = dragArea or frame
    boundToScreen = boundToScreen ~= false

    local dragging = false
    local dragStart, startPos

    connections:Add(dragArea.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or
           input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
        end
    end))

    connections:Add(dragArea.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or
           input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))

    connections:Add(UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and
           input.UserInputType ~= Enum.UserInputType.Touch then return end

        local delta = input.Position - dragStart
        local newX = startPos.X.Offset + delta.X
        local newY = startPos.Y.Offset + delta.Y

        if boundToScreen then
            local camera = workspace.CurrentCamera
            if camera then
                local screenSize = camera.ViewportSize
                local frameSize = frame.AbsoluteSize
                newX = math.clamp(newX, -frameSize.X / 2 + 50, screenSize.X - frameSize.X / 2 - 50)
                newY = math.clamp(newY, 0, screenSize.Y - 50)
            end
        end

        frame.Position = UDim2.new(startPos.X.Scale, newX, startPos.Y.Scale, newY)
    end))
end

--[[ ================== WINDOW ================== ]]

function CascadeV2:CreateWindow(options)
    options = options or {}
    local gui = ensureGui()
    if not gui then return nil end

    local window = setmetatable({}, Window)
    window.Title = options.Name or 'CascadeV2'
    window.Size = options.Size or UDim2.new(0, 550, 0, 360)
    window.Keybind = options.Keybind or Enum.KeyCode.RightControl
    window.Tabs = {}
    window.CurrentTab = nil
    window._connections = ConnectionManager.new()
    window._minimized = false
    window._visible = true

    -- Main window frame
    local root = Instance.new('Frame')
    root.Name = 'Window'
    root.BackgroundColor3 = CascadeV2.Theme.Panel
    root.BorderSizePixel = 0
    root.Size = window.Size
    root.Position = UDim2.new(0.5, -window.Size.X.Offset / 2, 0.5, -window.Size.Y.Offset / 2)
    root.ClipsDescendants = true
    root.Parent = gui
    applyCorner(root, 8)
    applyStroke(root)
    applyShadow(root, 0.6)

    window.Root = root

    -- Top bar
    local topBar = Instance.new('Frame')
    topBar.Name = 'TopBar'
    topBar.BackgroundColor3 = CascadeV2.Theme.PanelAlt
    topBar.BorderSizePixel = 0
    topBar.Size = UDim2.new(1, 0, 0, 38)
    topBar.Parent = root

    -- Top bar corner fix (only round top corners)
    local topCorner = applyCorner(topBar, 8)
    
    local topBarFix = Instance.new('Frame')
    topBarFix.BackgroundColor3 = CascadeV2.Theme.PanelAlt
    topBarFix.BorderSizePixel = 0
    topBarFix.Position = UDim2.new(0, 0, 1, -10)
    topBarFix.Size = UDim2.new(1, 0, 0, 10)
    topBarFix.Parent = topBar

    -- Title
    local title = Instance.new('TextLabel')
    title.Name = 'Title'
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(1, -100, 1, 0)
    title.Position = UDim2.new(0, 14, 0, 0)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 15
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextColor3 = CascadeV2.Theme.Text
    title.Text = window.Title
    title.Parent = topBar

    -- Window controls container
    local controls = Instance.new('Frame')
    controls.BackgroundTransparency = 1
    controls.Size = UDim2.new(0, 75, 1, 0)
    controls.Position = UDim2.new(1, -75, 0, 0)
    controls.Parent = topBar

    local controlLayout = Instance.new('UIListLayout')
    controlLayout.FillDirection = Enum.FillDirection.Horizontal
    controlLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    controlLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    controlLayout.Padding = UDim.new(0, 6)
    controlLayout.Parent = controls

    -- Helper for control buttons
    local function createControlButton(text, hoverColor)
        local btn = Instance.new('TextButton')
        btn.BackgroundColor3 = CascadeV2.Theme.Panel
        btn.Size = UDim2.new(0, 28, 0, 28)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 16
        btn.Text = text
        btn.TextColor3 = CascadeV2.Theme.SubText
        btn.AutoButtonColor = false
        btn.Parent = controls
        applyCorner(btn, 6)

        window._connections:Add(btn.MouseEnter:Connect(function()
            createTween(btn, {BackgroundColor3 = hoverColor or CascadeV2.Theme.PanelAlt}):Play()
        end))
        window._connections:Add(btn.MouseLeave:Connect(function()
            createTween(btn, {BackgroundColor3 = CascadeV2.Theme.Panel}):Play()
        end))

        return btn
    end

    local minimize = createControlButton('−')
    local close = createControlButton('×', CascadeV2.Theme.Error)

    -- Content area
    local content = Instance.new('Frame')
    content.Name = 'Content'
    content.BackgroundColor3 = CascadeV2.Theme.Background
    content.BorderSizePixel = 0
    content.Position = UDim2.new(0, 0, 0, 38)
    content.Size = UDim2.new(1, 0, 1, -38)
    content.ClipsDescendants = true
    content.Parent = root

    window.Content = content

    -- Sidebar
    local sidebar = Instance.new('ScrollingFrame')
    sidebar.Name = 'Sidebar'
    sidebar.BackgroundColor3 = CascadeV2.Theme.PanelAlt
    sidebar.BorderSizePixel = 0
    sidebar.Position = UDim2.new(0, 0, 0, 0)
    sidebar.Size = UDim2.new(0, 135, 1, 0)
    sidebar.ScrollBarThickness = 2
    sidebar.ScrollBarImageColor3 = CascadeV2.Theme.Outline
    sidebar.CanvasSize = UDim2.new(0, 0, 0, 0)
    sidebar.AutomaticCanvasSize = Enum.AutomaticSize.Y
    sidebar.Parent = content

    local sidebarPadding = Instance.new('UIPadding')
    sidebarPadding.PaddingTop = UDim.new(0, 8)
    sidebarPadding.PaddingBottom = UDim.new(0, 8)
    sidebarPadding.PaddingLeft = UDim.new(0, 8)
    sidebarPadding.PaddingRight = UDim.new(0, 8)
    sidebarPadding.Parent = sidebar

    local sideList = Instance.new('UIListLayout')
    sideList.FillDirection = Enum.FillDirection.Vertical
    sideList.SortOrder = Enum.SortOrder.LayoutOrder
    sideList.Padding = UDim.new(0, 4)
    sideList.Parent = sidebar

    -- Pages container
    local pages = Instance.new('Frame')
    pages.Name = 'Pages'
    pages.BackgroundTransparency = 1
    pages.Position = UDim2.new(0, 135, 0, 0)
    pages.Size = UDim2.new(1, -135, 1, 0)
    pages.Parent = content

    window.Sidebar = sidebar
    window.Pages = pages

    -- Event handlers
    window._connections:Add(close.MouseButton1Click:Connect(function()
        window:Hide()
    end))

    window._connections:Add(minimize.MouseButton1Click:Connect(function()
        window:ToggleMinimize()
    end))

    -- Dragging
    makeDraggable(root, topBar, window._connections, true)

    -- Keybind toggle
    window._connections:Add(UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == window.Keybind then
            window:Toggle()
        end
    end))

    table.insert(CascadeV2.Windows, window)
    return window
end

function Window:Show()
    self._visible = true
    self.Root.Visible = true
    self.Root.BackgroundTransparency = 1
    createTween(self.Root, {BackgroundTransparency = 0}, 0.25):Play()
end

function Window:Hide()
    self._visible = false
    local tween = createTween(self.Root, {BackgroundTransparency = 1}, 0.2)
    tween:Play()
    tween.Completed:Once(function()
        if not self._visible then
            self.Root.Visible = false
            self.Root.BackgroundTransparency = 0
        end
    end)
end

function Window:Toggle()
    if self.Root.Visible and self._visible then
        self:Hide()
    else
        self:Show()
    end
end

function Window:ToggleMinimize()
    self._minimized = not self._minimized
    local targetSize = self._minimized 
        and UDim2.new(self.Size.X.Scale, self.Size.X.Offset, 0, 38) 
        or self.Size
    createTween(self.Root, {Size = targetSize}, 0.25):Play()
    self.Content.Visible = not self._minimized
end

function Window:SetTitle(newTitle)
    self.Title = newTitle
    local titleLabel = self.Root:FindFirstChild('TopBar') and self.Root.TopBar:FindFirstChild('Title')
    if titleLabel then
        titleLabel.Text = newTitle
    end
end

function Window:Destroy()
    self._connections:Disconnect()
    for _, tab in ipairs(self.Tabs) do
        if tab._connections then
            tab._connections:Disconnect()
        end
    end
    self.Root:Destroy()

    for i, win in ipairs(CascadeV2.Windows) do
        if win == self then
            table.remove(CascadeV2.Windows, i)
            break
        end
    end
end

function Window:_setActiveTab(tab)
    self.CurrentTab = tab
    for _, t in ipairs(self.Tabs) do
        local isActive = (t == tab)
        t.Page.Visible = isActive

        createTween(t.Button, {
            BackgroundColor3 = isActive and CascadeV2.Theme.Accent or CascadeV2.Theme.Panel,
            TextColor3 = isActive and Color3.new(1, 1, 1) or CascadeV2.Theme.Text
        }, 0.15):Play()
    end
end

function Window:CreateTab(name)
    local tab = setmetatable({}, Tab)
    tab.Window = self
    tab.Name = name or 'Tab'
    tab.Sections = {}
    tab._connections = ConnectionManager.new()

    local btn = Instance.new('TextButton')
    btn.Name = 'TabButton'
    btn.Size = UDim2.new(1, 0, 0, 34)
    btn.BackgroundColor3 = CascadeV2.Theme.Panel
    btn.BorderSizePixel = 0
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 13
    btn.TextColor3 = CascadeV2.Theme.Text
    btn.Text = tab.Name
    btn.AutoButtonColor = false
    btn.Parent = self.Sidebar
    applyCorner(btn, 6)

    -- Hover effect
    tab._connections:Add(btn.MouseEnter:Connect(function()
        if self.CurrentTab ~= tab then
            createTween(btn, {BackgroundColor3 = CascadeV2.Theme.PanelAlt}):Play()
        end
    end))

    tab._connections:Add(btn.MouseLeave:Connect(function()
        if self.CurrentTab ~= tab then
            createTween(btn, {BackgroundColor3 = CascadeV2.Theme.Panel}):Play()
        end
    end))

    local page = Instance.new('ScrollingFrame')
    page.Name = 'Page'
    page.BackgroundTransparency = 1
    page.Position = UDim2.new(0, 10, 0, 10)
    page.Size = UDim2.new(1, -20, 1, -20)
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = CascadeV2.Theme.Outline
    page.Visible = false
    page.Parent = self.Pages

    local layout = Instance.new('UIListLayout')
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 10)
    layout.Parent = page

    tab.Button = btn
    tab.Page = page

    tab._connections:Add(btn.MouseButton1Click:Connect(function()
        self:_setActiveTab(tab)
    end))

    table.insert(self.Tabs, tab)
    if not self.CurrentTab then
        self:_setActiveTab(tab)
    end

    return tab
end

--[[ ================== TAB ================== ]]

function Tab:CreateSection(name)
    local section = setmetatable({}, Section)
    section.Tab = self
    section.Name = name
    section.Controls = {}
    section._connections = ConnectionManager.new()

    local frame = Instance.new('Frame')
    frame.Name = 'Section'
    frame.BackgroundColor3 = CascadeV2.Theme.Panel
    frame.BorderSizePixel = 0
    frame.Size = UDim2.new(1, 0, 0, 0)
    frame.AutomaticSize = Enum.AutomaticSize.Y
    frame.Parent = self.Page
    applyCorner(frame, 8)

    local padding = Instance.new('UIPadding')
    padding.PaddingTop = UDim.new(0, 12)
    padding.PaddingBottom = UDim.new(0, 12)
    padding.PaddingLeft = UDim.new(0, 12)
    padding.PaddingRight = UDim.new(0, 12)
    padding.Parent = frame

    local layout = Instance.new('UIListLayout')
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 8)
    layout.Parent = frame

    if name and name ~= '' then
        local titleLabel = Instance.new('TextLabel')
        titleLabel.BackgroundTransparency = 1
        titleLabel.Size = UDim2.new(1, 0, 0, 20)
        titleLabel.Font = Enum.Font.GothamBold
        titleLabel.TextSize = 14
        titleLabel.TextXAlignment = Enum.TextXAlignment.Left
        titleLabel.TextColor3 = CascadeV2.Theme.Text
        titleLabel.Text = name
        titleLabel.Parent = frame

        local divider = Instance.new('Frame')
        divider.BackgroundColor3 = CascadeV2.Theme.Outline
        divider.BackgroundTransparency = 0.5
        divider.BorderSizePixel = 0
        divider.Size = UDim2.new(1, 0, 0, 1)
        divider.Parent = frame
    end

    section.Frame = frame
    table.insert(self.Sections, section)
    return section
end

--[[ ================== SECTION CONTROLS ================== ]]

-- Helper to create control container
local function newControlFrame(section, height)
    local frame = Instance.new('Frame')
    frame.BackgroundTransparency = 1
    frame.BorderSizePixel = 0
    frame.Size = UDim2.new(1, 0, 0, height or 0)
    frame.AutomaticSize = height and Enum.AutomaticSize.None or Enum.AutomaticSize.Y
    frame.Parent = section.Frame
    return frame
end

--[[ ================== TOGGLE ================== ]]

function Section:CreateToggle(options)
    options = options or {}
    local state = options.Default or false

    local control = { _connections = ConnectionManager.new() }
    local frame = newControlFrame(self, 28)

    local label = Instance.new('TextLabel')
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, -60, 1, 0)
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextColor3 = CascadeV2.Theme.Text
    label.Text = options.Name or 'Toggle'
    label.Parent = frame

    local switch = Instance.new('Frame')
    switch.Size = UDim2.new(0, 44, 0, 22)
    switch.AnchorPoint = Vector2.new(1, 0.5)
    switch.Position = UDim2.new(1, 0, 0.5, 0)
    switch.BackgroundColor3 = CascadeV2.Theme.ToggleOff
    switch.BorderSizePixel = 0
    switch.Parent = frame
    applyCorner(switch, 11)

    local knob = Instance.new('Frame')
    knob.Size = UDim2.new(0, 18, 0, 18)
    knob.AnchorPoint = Vector2.new(0, 0.5)
    knob.Position = UDim2.new(0, 2, 0.5, 0)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.BorderSizePixel = 0
    knob.Parent = switch
    applyCorner(knob, 9)

    local button = Instance.new('TextButton')
    button.BackgroundTransparency = 1
    button.Size = UDim2.new(1, 0, 1, 0)
    button.Text = ''
    button.Parent = frame

    local function updateVisuals(animate)
        local targetBg = state and CascadeV2.Theme.ToggleOn or CascadeV2.Theme.ToggleOff
        local targetPos = state and UDim2.new(1, -20, 0.5, 0) or UDim2.new(0, 2, 0.5, 0)

        if animate then
            createTween(switch, {BackgroundColor3 = targetBg}):Play()
            createTween(knob, {Position = targetPos}):Play()
        else
            switch.BackgroundColor3 = targetBg
            knob.Position = targetPos
        end
    end

    local function setState(newState, skipCallback)
        state = newState
        updateVisuals(true)
        if not skipCallback then
            safeCallback(options.Callback, state)
        end
    end

    control._connections:Add(button.MouseButton1Click:Connect(function()
        setState(not state)
    end))

    updateVisuals(false)

    function control:Set(value, skipCallback)
        setState(value, skipCallback)
    end

    function control:Get()
        return state
    end

    function control:Destroy()
        self._connections:Disconnect()
        frame:Destroy()
    end

    table.insert(self.Controls, control)
    return control
end

--[[ ================== BUTTON ================== ]]

function Section:CreateButton(options)
    options = options or {}

    local control = { _connections = ConnectionManager.new() }
    local frame = newControlFrame(self, 32)
    frame.BackgroundColor3 = CascadeV2.Theme.Accent
    frame.BackgroundTransparency = 0
    applyCorner(frame, 6)

    local btn = Instance.new('TextButton')
    btn.BackgroundTransparency = 1
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 13
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Text = options.Name or 'Button'
    btn.AutoButtonColor = false
    btn.Parent = frame

    control._connections:Add(btn.MouseEnter:Connect(function()
        createTween(frame, {BackgroundColor3 = CascadeV2.Theme.AccentLight}):Play()
    end))

    control._connections:Add(btn.MouseLeave:Connect(function()
        createTween(frame, {BackgroundColor3 = CascadeV2.Theme.Accent}):Play()
    end))

    control._connections:Add(btn.MouseButton1Down:Connect(function()
        createTween(frame, {BackgroundColor3 = CascadeV2.Theme.AccentDark}, 0.05):Play()
    end))

    control._connections:Add(btn.MouseButton1Up:Connect(function()
        createTween(frame, {BackgroundColor3 = CascadeV2.Theme.AccentLight}, 0.1):Play()
    end))

    control._connections:Add(btn.MouseButton1Click:Connect(function()
        safeCallback(options.Callback)
    end))

    function control:SetText(text)
        btn.Text = text
    end

    function control:Destroy()
        self._connections:Disconnect()
        frame:Destroy()
    end

    table.insert(self.Controls, control)
    return control
end

--[[ ================== SLIDER ================== ]]

function Section:CreateSlider(options)
    options = options or {}
    local min = options.Min or 0
    local max = options.Max or 100
    local increment = options.Increment or 1
    local value = math.clamp(options.Default or min, min, max)

    local control = { _connections = ConnectionManager.new() }
    local frame = newControlFrame(self)

    local labelContainer = Instance.new('Frame')
    labelContainer.BackgroundTransparency = 1
    labelContainer.Size = UDim2.new(1, 0, 0, 20)
    labelContainer.Parent = frame

    local label = Instance.new('TextLabel')
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, -60, 1, 0)
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextColor3 = CascadeV2.Theme.Text
    label.Text = options.Name or 'Slider'
    label.Parent = labelContainer

    local valueLabel = Instance.new('TextLabel')
    valueLabel.BackgroundTransparency = 1
    valueLabel.Size = UDim2.new(0, 60, 1, 0)
    valueLabel.AnchorPoint = Vector2.new(1, 0)
    valueLabel.Position = UDim2.new(1, 0, 0, 0)
    valueLabel.Font = Enum.Font.GothamSemibold
    valueLabel.TextSize = 13
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.TextColor3 = CascadeV2.Theme.Accent
    valueLabel.Parent = labelContainer

    local barContainer = Instance.new('Frame')
    barContainer.BackgroundTransparency = 1
    barContainer.Size = UDim2.new(1, 0, 0, 18)
    barContainer.Parent = frame

    local bar = Instance.new('Frame')
    bar.BackgroundColor3 = CascadeV2.Theme.SliderTrack
    bar.BorderSizePixel = 0
    bar.Size = UDim2.new(1, 0, 0, 6)
    bar.Position = UDim2.new(0, 0, 0.5, -3)
    bar.Parent = barContainer
    applyCorner(bar, 3)

    local fill = Instance.new('Frame')
    fill.BackgroundColor3 = CascadeV2.Theme.SliderFill
    fill.BorderSizePixel = 0
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.Parent = bar
    applyCorner(fill, 3)

    local knob = Instance.new('Frame')
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.new(0, 0, 0.5, 0)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.BorderSizePixel = 0
    knob.ZIndex = 2
    knob.Parent = barContainer
    applyCorner(knob, 7)

    local dragging = false

    local function formatValue(v)
        if increment >= 1 then
            return tostring(math.floor(v))
        else
            local decimals = math.max(0, math.ceil(-math.log10(increment)))
            return string.format('%.' .. decimals .. 'f', v)
        end
    end

    local function updateVisuals()
        local alpha = max > min and (value - min) / (max - min) or 0
        fill.Size = UDim2.new(alpha, 0, 1, 0)
        knob.Position = UDim2.new(alpha, 0, 0.5, 0)
        valueLabel.Text = formatValue(value)
    end

    local function setValueFromAlpha(alpha)
        alpha = math.clamp(alpha, 0, 1)
        local rawValue = min + (max - min) * alpha
        local snapped = math.floor(rawValue / increment + 0.5) * increment
        snapped = math.clamp(snapped, min, max)

        if snapped ~= value then
            value = snapped
            updateVisuals()
            safeCallback(options.Callback, value)
        end
    end

    local function setValueFromX(x)
        local barPos = bar.AbsolutePosition.X
        local barSize = bar.AbsoluteSize.X
        if barSize > 0 then
            local alpha = (x - barPos) / barSize
            setValueFromAlpha(alpha)
        end
    end

    control._connections:Add(barContainer.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or
           input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            setValueFromX(input.Position.X)
        end
    end))

    control._connections:Add(UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or
                        input.UserInputType == Enum.UserInputType.Touch) then
            setValueFromX(input.Position.X)
        end
    end))

    control._connections:Add(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or
           input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))

    updateVisuals()

    function control:Set(v, skipCallback)
        v = math.clamp(v, min, max)
        value = v
        updateVisuals()
        if not skipCallback then
            safeCallback(options.Callback, value)
        end
    end

    function control:Get()
        return value
    end

    function control:SetRange(newMin, newMax)
        min, max = newMin, newMax
        value = math.clamp(value, min, max)
        updateVisuals()
    end

    function control:Destroy()
        self._connections:Disconnect()
        frame:Destroy()
    end

    table.insert(self.Controls, control)
    return control
end

--[[ ================== DROPDOWN ================== ]]

function Section:CreateDropdown(options)
    options = options or {}
    local items = options.Options or {}
    local current = options.Default or items[1]
    local isOpen = false

    local control = { _connections = ConnectionManager.new() }
    local frame = newControlFrame(self)

    local header = Instance.new('Frame')
    header.BackgroundTransparency = 1
    header.Size = UDim2.new(1, 0, 0, 28)
    header.Parent = frame

    local label = Instance.new('TextLabel')
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(0.35, 0, 1, 0)
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextColor3 = CascadeV2.Theme.Text
    label.Text = options.Name or 'Dropdown'
    label.Parent = header

    local dropdownBtn = Instance.new('TextButton')
    dropdownBtn.BackgroundColor3 = CascadeV2.Theme.PanelAlt
    dropdownBtn.Size = UDim2.new(0.65, -4, 1, -4)
    dropdownBtn.Position = UDim2.new(0.35, 4, 0, 2)
    dropdownBtn.Font = Enum.Font.Gotham
    dropdownBtn.TextSize = 12
    dropdownBtn.TextColor3 = CascadeV2.Theme.Text
    dropdownBtn.Text = tostring(current or 'Select...')
    dropdownBtn.TextXAlignment = Enum.TextXAlignment.Left
    dropdownBtn.TextTruncate = Enum.TextTruncate.AtEnd
    dropdownBtn.AutoButtonColor = false
    dropdownBtn.Parent = header
    applyCorner(dropdownBtn, 4)
    applyStroke(dropdownBtn, CascadeV2.Theme.Outline, 1)

    local btnPadding = Instance.new('UIPadding')
    btnPadding.PaddingLeft = UDim.new(0, 10)
    btnPadding.PaddingRight = UDim.new(0, 24)
    btnPadding.Parent = dropdownBtn

    local arrow = Instance.new('TextLabel')
    arrow.BackgroundTransparency = 1
    arrow.Size = UDim2.new(0, 20, 1, 0)
    arrow.AnchorPoint = Vector2.new(1, 0)
    arrow.Position = UDim2.new(1, -4, 0, 0)
    arrow.Font = Enum.Font.GothamBold
    arrow.TextSize = 10
    arrow.TextColor3 = CascadeV2.Theme.SubText
    arrow.Text = '▼'
    arrow.Parent = dropdownBtn

    local listHolder = Instance.new('Frame')
    listHolder.BackgroundColor3 = CascadeV2.Theme.PanelAlt
    listHolder.BorderSizePixel = 0
    listHolder.Size = UDim2.new(1, 0, 0, 0)
    listHolder.ClipsDescendants = true
    listHolder.Visible = false
    listHolder.Parent = frame
    applyCorner(listHolder, 6)
    applyStroke(listHolder)

    local listScroll = Instance.new('ScrollingFrame')
    listScroll.BackgroundTransparency = 1
    listScroll.Size = UDim2.new(1, 0, 1, 0)
    listScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    listScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    listScroll.ScrollBarThickness = 2
    listScroll.ScrollBarImageColor3 = CascadeV2.Theme.Outline
    listScroll.Parent = listHolder

    local listPadding = Instance.new('UIPadding')
    listPadding.PaddingTop = UDim.new(0, 4)
    listPadding.PaddingBottom = UDim.new(0, 4)
    listPadding.PaddingLeft = UDim.new(0, 4)
    listPadding.PaddingRight = UDim.new(0, 4)
    listPadding.Parent = listScroll

    local listLayout = Instance.new('UIListLayout')
    listLayout.FillDirection = Enum.FillDirection.Vertical
    listLayout.Padding = UDim.new(0, 2)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = listScroll

    local function closeDropdown()
        if not isOpen then return end
        isOpen = false
        createTween(arrow, {Rotation = 0}):Play()
        local tween = createTween(listHolder, {Size = UDim2.new(1, 0, 0, 0)}, 0.15)
        tween:Play()
        tween.Completed:Once(function()
            if not isOpen then
                listHolder.Visible = false
            end
        end)
    end

    local function openDropdown()
        if isOpen then return end
        isOpen = true
        listHolder.Visible = true
        local targetHeight = math.min(#items * 28 + 8, 150)
        createTween(arrow, {Rotation = 180}):Play()
        createTween(listHolder, {Size = UDim2.new(1, 0, 0, targetHeight)}, 0.15):Play()
    end

    local function refreshOptions()
        for _, child in ipairs(listScroll:GetChildren()) do
            if child:IsA('TextButton') then
                child:Destroy()
            end
        end

        for i, item in ipairs(items) do
            local optBtn = Instance.new('TextButton')
            optBtn.BackgroundColor3 = CascadeV2.Theme.Panel
            optBtn.BackgroundTransparency = 1
            optBtn.BorderSizePixel = 0
            optBtn.Size = UDim2.new(1, 0, 0, 26)
            optBtn.Font = Enum.Font.Gotham
            optBtn.TextSize = 12
            optBtn.TextColor3 = CascadeV2.Theme.Text
            optBtn.TextXAlignment = Enum.TextXAlignment.Left
            optBtn.Text = tostring(item)
            optBtn.AutoButtonColor = false
            optBtn.LayoutOrder = i
            optBtn.Parent = listScroll
            applyCorner(optBtn, 4)

            local optPadding = Instance.new('UIPadding')
            optPadding.PaddingLeft = UDim.new(0, 8)
            optPadding.Parent = optBtn

            control._connections:Add(optBtn.MouseEnter:Connect(function()
                createTween(optBtn, {BackgroundTransparency = 0}):Play()
            end))

            control._connections:Add(optBtn.MouseLeave:Connect(function()
                createTween(optBtn, {BackgroundTransparency = 1}):Play()
            end))

            control._connections:Add(optBtn.MouseButton1Click:Connect(function()
                current = item
                dropdownBtn.Text = tostring(item)
                closeDropdown()
                safeCallback(options.Callback, current)
            end))
        end
    end

    refreshOptions()

    control._connections:Add(dropdownBtn.MouseButton1Click:Connect(function()
        if isOpen then
            closeDropdown()
        else
            openDropdown()
        end
    end))

    -- Close when clicking outside
    control._connections:Add(UserInputService.InputBegan:Connect(function(input)
        if not isOpen then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end

        task.defer(function()
            local mousePos = UserInputService:GetMouseLocation()
            local framePos = listHolder.AbsolutePosition
            local frameSize = listHolder.AbsoluteSize
            local btnPos = dropdownBtn.AbsolutePosition
            local btnSize = dropdownBtn.AbsoluteSize

            local inList = mousePos.X >= framePos.X and mousePos.X <= framePos.X + frameSize.X and
                          mousePos.Y >= framePos.Y and mousePos.Y <= framePos.Y + frameSize.Y
            local inBtn = mousePos.X >= btnPos.X and mousePos.X <= btnPos.X + btnSize.X and
                         mousePos.Y >= btnPos.Y and mousePos.Y <= btnPos.Y + btnSize.Y

            if not inList and not inBtn then
                closeDropdown()
            end
        end)
    end))

    function control:Set(value, skipCallback)
        current = value
        dropdownBtn.Text = tostring(value)
        if not skipCallback then
            safeCallback(options.Callback, current)
        end
    end

    function control:Get()
        return current
    end

    function control:SetOptions(newOptions)
        items = newOptions or {}
        refreshOptions()
        if not table.find(items, current) then
            current = items[1]
            dropdownBtn.Text = tostring(current or 'Select...')
        end
    end

    function control:Refresh()
        refreshOptions()
    end

    function control:Destroy()
        self._connections:Disconnect()
        frame:Destroy()
    end

    table.insert(self.Controls, control)
    return control
end

--[[ ================== TEXT INPUT ================== ]]

function Section:CreateInput(options)
    options = options or {}

    local control = { _connections = ConnectionManager.new() }
    local frame = newControlFrame(self)

    if options.Name then
        local labelContainer = Instance.new('Frame')
        labelContainer.BackgroundTransparency = 1
        labelContainer.Size = UDim2.new(1, 0, 0, 18)
        labelContainer.Parent = frame

        local label = Instance.new('TextLabel')
        label.BackgroundTransparency = 1
        label.Size = UDim2.new(1, 0, 1, 0)
        label.Font = Enum.Font.Gotham
        label.TextSize = 13
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextColor3 = CascadeV2.Theme.Text
        label.Text = options.Name
        label.Parent = labelContainer
    end

    local inputFrame = Instance.new('Frame')
    inputFrame.BackgroundColor3 = CascadeV2.Theme.PanelAlt
    inputFrame.Size = UDim2.new(1, 0, 0, 32)
    inputFrame.Parent = frame
    applyCorner(inputFrame, 6)
    local inputStroke = applyStroke(inputFrame)

    local textBox = Instance.new('TextBox')
    textBox.BackgroundTransparency = 1
    textBox.Size = UDim2.new(1, -20, 1, 0)
    textBox.Position = UDim2.new(0, 10, 0, 0)
    textBox.Font = Enum.Font.Gotham
    textBox.TextSize = 13
    textBox.TextColor3 = CascadeV2.Theme.Text
    textBox.PlaceholderText = options.Placeholder or 'Enter text...'
    textBox.PlaceholderColor3 = CascadeV2.Theme.SubText
    textBox.Text = options.Default or ''
    textBox.TextXAlignment = Enum.TextXAlignment.Left
    textBox.ClearTextOnFocus = options.ClearOnFocus or false
    textBox.Parent = inputFrame

    control._connections:Add(textBox.Focused:Connect(function()
        createTween(inputStroke, {Color = CascadeV2.Theme.Accent}):Play()
    end))

    control._connections:Add(textBox.FocusLost:Connect(function(enterPressed)
        createTween(inputStroke, {Color = CascadeV2.Theme.Outline}):Play()
        if enterPressed or options.CallbackOnChange then
            safeCallback(options.Callback, textBox.Text)
        end
    end))

    function control:Set(text)
        textBox.Text = text
    end

    function control:Get()
        return textBox.Text
    end

    function control:Destroy()
        self._connections:Disconnect()
        frame:Destroy()
    end

    table.insert(self.Controls, control)
    return control
end

--[[ ================== KEYBIND ================== ]]

function Section:CreateKeybind(options)
    options = options or {}
    local currentKey = options.Default or Enum.KeyCode.Unknown
    local listening = false

    local control = { _connections = ConnectionManager.new() }
    local frame = newControlFrame(self, 28)

    local label = Instance.new('TextLabel')
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, -80, 1, 0)
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextColor3 = CascadeV2.Theme.Text
    label.Text = options.Name or 'Keybind'
    label.Parent = frame

    local keyBtn = Instance.new('TextButton')
    keyBtn.BackgroundColor3 = CascadeV2.Theme.PanelAlt
    keyBtn.Size = UDim2.new(0, 70, 0, 24)
    keyBtn.AnchorPoint = Vector2.new(1, 0.5)
    keyBtn.Position = UDim2.new(1, 0, 0.5, 0)
    keyBtn.Font = Enum.Font.GothamSemibold
    keyBtn.TextSize = 11
    keyBtn.TextColor3 = CascadeV2.Theme.Text
    keyBtn.AutoButtonColor = false
    keyBtn.Parent = frame
    applyCorner(keyBtn, 4)
    applyStroke(keyBtn, CascadeV2.Theme.Outline, 1)

    local function getKeyName(key)
        if key == Enum.KeyCode.Unknown then return 'None' end
        local name = key.Name
        name = name:gsub('LeftControl', 'LCtrl'):gsub('RightControl', 'RCtrl')
        name = name:gsub('LeftShift', 'LShift'):gsub('RightShift', 'RShift')
        name = name:gsub('LeftAlt', 'LAlt'):gsub('RightAlt', 'RAlt')
        return name
    end

    local function updateDisplay()
        keyBtn.Text = listening and '...' or getKeyName(currentKey)
    end

    updateDisplay()

    control._connections:Add(keyBtn.MouseButton1Click:Connect(function()
        listening = true
        updateDisplay()
    end))

    control._connections:Add(UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if listening then
            if input.UserInputType == Enum.UserInputType.Keyboard then
                currentKey = input.KeyCode == Enum.KeyCode.Escape and Enum.KeyCode.Unknown or input.KeyCode
                listening = false
                updateDisplay()
                safeCallback(options.Callback, currentKey)
            end
        elseif not gameProcessed and input.KeyCode == currentKey and currentKey ~= Enum.KeyCode.Unknown then
            safeCallback(options.OnActivate)
        end
    end))

    function control:Set(key, skipCallback)
        currentKey = key
        updateDisplay()
        if not skipCallback then
            safeCallback(options.Callback, currentKey)
        end
    end

    function control:Get()
        return currentKey
    end

    function control:Destroy()
        self._connections:Disconnect()
        frame:Destroy()
    end

    table.insert(self.Controls, control)
    return control
end

--[[ ================== LABEL ================== ]]

function Section:CreateLabel(text)
    local control = {}

    local label = Instance.new('TextLabel')
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, 0, 0, 0)
    label.AutomaticSize = Enum.AutomaticSize.Y
    label.Font = Enum.Font.Gotham
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextColor3 = CascadeV2.Theme.SubText
    label.Text = text or ''
    label.TextWrapped = true
    label.Parent = self.Frame

    function control:Set(newText)
        label.Text = newText
    end

    function control:Destroy()
        label:Destroy()
    end

    table.insert(self.Controls, control)
    return control
end

--[[ ================== NOTIFICATIONS ================== ]]

function CascadeV2:Notify(options)
    local gui = ensureGui()
    if not gui then return end

    options = options or {}
    local holder = CascadeV2._notifHolder
    if not holder then return end

    local notifType = options.Type or 'Info'
    local accentColor = ({
        Error = CascadeV2.Theme.Error,
        Warning = CascadeV2.Theme.Warning,
        Success = CascadeV2.Theme.Success,
    })[notifType] or CascadeV2.Theme.Accent

    local frame = Instance.new('Frame')
    frame.BackgroundColor3 = CascadeV2.Theme.Notification
    frame.BorderSizePixel = 0
    frame.Size = UDim2.new(1, 0, 0, 0)
    frame.AutomaticSize = Enum.AutomaticSize.Y
    frame.ClipsDescendants = true
    frame.Parent = holder
    applyCorner(frame, 8)
    applyStroke(frame)

    local accentBar = Instance.new('Frame')
    accentBar.BackgroundColor3 = accentColor
    accentBar.BorderSizePixel = 0
    accentBar.Size = UDim2.new(0, 3, 1, 0)
    accentBar.Parent = frame

    local padding = Instance.new('UIPadding')
    padding.PaddingTop = UDim.new(0, 12)
    padding.PaddingBottom = UDim.new(0, 12)
    padding.PaddingLeft = UDim.new(0, 14)
    padding.PaddingRight = UDim.new(0, 12)
    padding.Parent = frame

    local layout = Instance.new('UIListLayout')
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.Padding = UDim.new(0, 4)
    layout.Parent = frame

    local title = Instance.new('TextLabel')
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(1, 0, 0, 18)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextColor3 = CascadeV2.Theme.Text
    title.Text = options.Title or 'Notification'
    title.TextTransparency = 1
    title.Parent = frame

    if options.Content and options.Content ~= '' then
        local body = Instance.new('TextLabel')
        body.BackgroundTransparency = 1
        body.Size = UDim2.new(1, 0, 0, 0)
        body.AutomaticSize = Enum.AutomaticSize.Y
        body.Font = Enum.Font.Gotham
        body.TextSize = 12
        body.TextXAlignment = Enum.TextXAlignment.Left
        body.TextYAlignment = Enum.TextYAlignment.Top
        body.TextWrapped = true
        body.TextColor3 = CascadeV2.Theme.SubText
        body.Text = options.Content
        body.TextTransparency = 1
        body.Parent = frame

        createTween(body, {TextTransparency = 0}, 0.3):Play()
    end

    frame.BackgroundTransparency = 1
    createTween(frame, {BackgroundTransparency = 0}, 0.3):Play()
    createTween(title, {TextTransparency = 0}, 0.3):Play()

    local duration = options.Duration or 4
    task.delay(duration, function()
        if frame.Parent then
