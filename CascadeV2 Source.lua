local Players = game:GetService('Players')
local UserInputService = game:GetService('UserInputService')
local TweenService = game:GetService('TweenService')

local LocalPlayer = Players.LocalPlayer

local CascadeV2 = {}
CascadeV2.__index = CascadeV2

CascadeV2.Theme = {
    Background = Color3.fromRGB(16, 17, 20),
    Panel = Color3.fromRGB(24, 25, 30),
    PanelAlt = Color3.fromRGB(20, 21, 25),
    Accent = Color3.fromRGB(0, 140, 255),
    AccentDark = Color3.fromRGB(0, 100, 200),
    Text = Color3.fromRGB(235, 235, 245),
    SubText = Color3.fromRGB(170, 175, 190),
    Outline = Color3.fromRGB(45, 47, 55),
    ToggleOn = Color3.fromRGB(0, 175, 110),
    ToggleOff = Color3.fromRGB(55, 56, 65),
    SliderTrack = Color3.fromRGB(40, 42, 50),
    SliderFill = Color3.fromRGB(0, 140, 255),
    Notification = Color3.fromRGB(26, 27, 33),
}

CascadeV2._gui = nil
CascadeV2._notifHolder = nil
CascadeV2.Windows = {}

local Window = {}
Window.__index = Window

local Tab = {}
Tab.__index = Tab

local Section = {}
Section.__index = Section

local function ensureGui()
    if CascadeV2._gui then
        return CascadeV2._gui
    end

    local gui = Instance.new('ScreenGui')
    gui.Name = 'CascadeV2'
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Global

    local parent
    local ok, coreGui = pcall(function()
        return game:GetService('CoreGui')
    end)
    if ok and coreGui then
        parent = coreGui
    else
        local pgOk, playerGui = pcall(function()
            return LocalPlayer:WaitForChild('PlayerGui', 5)
        end)
        if pgOk and playerGui then
            parent = playerGui
        end
    end

    gui.Parent = parent
    CascadeV2._gui = gui

    local notifHolder = Instance.new('Frame')
    notifHolder.Name = 'Notifications'
    notifHolder.BackgroundTransparency = 1
    notifHolder.AnchorPoint = Vector2.new(1, 0)
    notifHolder.Position = UDim2.new(1, -20, 0, 20)
    notifHolder.Size = UDim2.new(0, 260, 1, -40)
    notifHolder.Parent = gui

    local list = Instance.new('UIListLayout')
    list.FillDirection = Enum.FillDirection.Vertical
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.HorizontalAlignment = Enum.HorizontalAlignment.Right
    list.Padding = UDim.new(0, 8)
    list.Parent = notifHolder

    CascadeV2._notifHolder = notifHolder

    return gui
end

local function applyCorner(instance, radius)
    local corner = Instance.new('UICorner')
    corner.CornerRadius = UDim.new(0, radius or 6)
    corner.Parent = instance
end

local function applyStroke(instance)
    local stroke = Instance.new('UIStroke')
    stroke.Color = CascadeV2.Theme.Outline
    stroke.Thickness = 1
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.LineJoinMode = Enum.LineJoinMode.Round
    stroke.Parent = instance
end

local function makeDraggable(frame, dragArea)
    dragArea = dragArea or frame

    local dragging = false
    local dragStart
    local startPos

    dragArea.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
end

function CascadeV2:CreateWindow(options)
    options = options or {}
    ensureGui()

    local window = setmetatable({}, Window)
    window.Title = options.Name or 'CascadeV2'
    window.Size = options.Size or UDim2.new(0, 520, 0, 320)
    window.Keybind = options.Keybind or Enum.KeyCode.RightControl
    window.Tabs = {}
    window.CurrentTab = nil

    local root = Instance.new('Frame')
    root.Name = 'Window'
    root.BackgroundColor3 = CascadeV2.Theme.Panel
    root.BorderSizePixel = 0
    root.Size = window.Size
    root.Position = UDim2.new(0.5, -window.Size.X.Offset / 2, 0.5, -window.Size.Y.Offset / 2)
    root.Parent = CascadeV2._gui
    applyCorner(root, 8)
    applyStroke(root)

    window.Root = root

    local topBar = Instance.new('Frame')
    topBar.Name = 'TopBar'
    topBar.BackgroundColor3 = CascadeV2.Theme.PanelAlt
    topBar.BorderSizePixel = 0
    topBar.Size = UDim2.new(1, 0, 0, 32)
    topBar.Parent = root
    applyCorner(topBar, 8)

    local title = Instance.new('TextLabel')
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(1, -60, 1, 0)
    title.Position = UDim2.new(0, 12, 0, 0)
    title.Font = Enum.Font.GothamSemibold
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextColor3 = CascadeV2.Theme.Text
    title.Text = window.Title
    title.Parent = topBar

    local close = Instance.new('TextButton')
    close.BackgroundTransparency = 1
    close.Size = UDim2.new(0, 32, 1, 0)
    close.Position = UDim2.new(1, -32, 0, 0)
    close.Font = Enum.Font.GothamSemibold
    close.TextSize = 14
    close.Text = 'X'
    close.TextColor3 = CascadeV2.Theme.SubText
    close.Parent = topBar

    close.MouseButton1Click:Connect(function()
        root.Visible = false
    end)

    makeDraggable(root, topBar)

    local content = Instance.new('Frame')
    content.Name = 'Content'
    content.BackgroundColor3 = CascadeV2.Theme.Background
    content.BorderSizePixel = 0
    content.Position = UDim2.new(0, 0, 0, 32)
    content.Size = UDim2.new(1, 0, 1, -32)
    content.Parent = root

    local sidebar = Instance.new('Frame')
    sidebar.Name = 'Sidebar'
    sidebar.BackgroundColor3 = CascadeV2.Theme.PanelAlt
    sidebar.BorderSizePixel = 0
    sidebar.Position = UDim2.new(0, 0, 0, 0)
    sidebar.Size = UDim2.new(0, 120, 1, 0)
    sidebar.Parent = content

    local sideList = Instance.new('UIListLayout')
    sideList.FillDirection = Enum.FillDirection.Vertical
    sideList.SortOrder = Enum.SortOrder.LayoutOrder
    sideList.Padding = UDim.new(0, 4)
    sideList.Parent = sidebar

    local pages = Instance.new('Frame')
    pages.Name = 'Pages'
    pages.BackgroundTransparency = 1
    pages.Position = UDim2.new(0, 120, 0, 0)
    pages.Size = UDim2.new(1, -120, 1, 0)
    pages.Parent = content

    window.Sidebar = sidebar
    window.Pages = pages

    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == window.Keybind then
            root.Visible = not root.Visible
        end
    end)

    table.insert(CascadeV2.Windows, window)
    return window
end

function Window:_setActiveTab(tab)
    self.CurrentTab = tab
    for _, t in ipairs(self.Tabs) do
        t.Page.Visible = (t == tab)
        t.Button.BackgroundColor3 = t == tab and CascadeV2.Theme.Accent or CascadeV2.Theme.PanelAlt
        t.Button.TextColor3 = t == tab and Color3.new(1, 1, 1) or CascadeV2.Theme.Text
    end
end

function Window:CreateTab(name)
    local tab = setmetatable({}, Tab)
    tab.Window = self
    tab.Name = name or 'Tab'
    tab.Sections = {}

    local btn = Instance.new('TextButton')
    btn.Name = 'TabButton'
    btn.Size = UDim2.new(1, 0, 0, 32)
    btn.BackgroundColor3 = CascadeV2.Theme.PanelAlt
    btn.BorderSizePixel = 0
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 13
    btn.TextColor3 = CascadeV2.Theme.Text
    btn.Text = tab.Name
    btn.Parent = self.Sidebar

    local page = Instance.new('ScrollingFrame')
    page.Name = 'Page'
    page.BackgroundColor3 = CascadeV2.Theme.Panel
    page.BorderSizePixel = 0
    page.Position = UDim2.new(0, 12, 0, 12)
    page.Size = UDim2.new(1, -24, 1, -24)
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.ScrollBarThickness = 4
    page.ScrollBarImageColor3 = CascadeV2.Theme.Outline
    page.Visible = false
    page.Parent = self.Pages

    local layout = Instance.new('UIListLayout')
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 8)
    layout.Parent = page

    tab.Button = btn
    tab.Page = page

    btn.MouseButton1Click:Connect(function()
        self:_setActiveTab(tab)
    end)

    table.insert(self.Tabs, tab)
    if not self.CurrentTab then
        self:_setActiveTab(tab)
    end

    return tab
end

function Tab:CreateSection(name)
    local section = setmetatable({}, Section)
    section.Tab = self
    section.Controls = {}

    local frame = Instance.new('Frame')
    frame.Name = 'Section'
    frame.BackgroundColor3 = CascadeV2.Theme.PanelAlt
    frame.BorderSizePixel = 0
    frame.Size = UDim2.new(1, 0, 0, 0)
    frame.AutomaticSize = Enum.AutomaticSize.Y
    frame.Parent = self.Page
    applyCorner(frame, 6)
    applyStroke(frame)

    local padding = Instance.new('UIPadding')
    padding.PaddingTop = UDim.new(0, 8)
    padding.PaddingBottom = UDim.new(0, 8)
    padding.PaddingLeft = UDim.new(0, 8)
    padding.PaddingRight = UDim.new(0, 8)
    padding.Parent = frame

    local layout = Instance.new('UIListLayout')
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 6)
    layout.Parent = frame

    local title = Instance.new('TextLabel')
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(1, 0, 0, 18)
    title.Font = Enum.Font.GothamSemibold
    title.TextSize = 13
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextColor3 = CascadeV2.Theme.Text
    title.Text = name or 'Section'
    title.Parent = frame

    section.Frame = frame
    return section
end

local function newControlFrame(section)
    local frame = Instance.new('Frame')
    frame.BackgroundColor3 = CascadeV2.Theme.Panel
    frame.BorderSizePixel = 0
    frame.Size = UDim2.new(1, 0, 0, 0)
    frame.AutomaticSize = Enum.AutomaticSize.Y
    frame.Parent = section.Frame
    applyCorner(frame, 6)
    applyStroke(frame)

    local padding = Instance.new('UIPadding')
    padding.PaddingTop = UDim.new(0, 6)
    padding.PaddingBottom = UDim.new(0, 6)
    padding.PaddingLeft = UDim.new(0, 8)
    padding.PaddingRight = UDim.new(0, 8)
    padding.Parent = frame

    return frame
end

function Section:CreateToggle(options)
    options = options or {}
    local state = options.Default or false

    local frame = newControlFrame(self)

    local container = Instance.new('Frame')
    container.BackgroundTransparency = 1
    container.Size = UDim2.new(1, 0, 0, 24)
    container.Parent = frame

    local label = Instance.new('TextLabel')
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, -50, 1, 0)
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextColor3 = CascadeV2.Theme.Text
    label.Text = options.Name or 'Toggle'
    label.Parent = container

    local switch = Instance.new('Frame')
    switch.Size = UDim2.new(0, 42, 0, 20)
    switch.AnchorPoint = Vector2.new(1, 0.5)
    switch.Position = UDim2.new(1, 0, 0.5, 0)
    switch.BackgroundColor3 = state and CascadeV2.Theme.ToggleOn or CascadeV2.Theme.ToggleOff
    switch.BorderSizePixel = 0
    switch.Parent = container
    applyCorner(switch, 10)

    local knob = Instance.new('Frame')
    knob.Size = UDim2.new(0, 18, 0, 18)
    knob.Position = state and UDim2.new(1, -2, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.BorderSizePixel = 0
    knob.Parent = switch
    applyCorner(knob, 9)

    local button = Instance.new('TextButton')
    button.BackgroundTransparency = 1
    button.Size = UDim2.new(1, 0, 1, 0)
    button.Text = ''
    button.Parent = container

    local function setState(v)
        state = v
        TweenService:Create(
            switch,
            TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
            {BackgroundColor3 = v and CascadeV2.Theme.ToggleOn or CascadeV2.Theme.ToggleOff}
        ):Play()
        TweenService:Create(
            knob,
            TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
            {Position = v and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)}
        ):Play()
        if options.Callback then
            task.spawn(options.Callback, state)
        end
    end

    button.MouseButton1Click:Connect(function()
        setState(not state)
    end)

    return {
        Set = setState
    }
end

function Section:CreateButton(options)
    options = options or {}

    local frame = newControlFrame(self)

    local btn = Instance.new('TextButton')
    btn.BackgroundColor3 = CascadeV2.Theme.Accent
    btn.BorderSizePixel = 0
    btn.Size = UDim2.new(1, 0, 0, 28)
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 13
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Text = options.Name or 'Button'
    btn.Parent = frame
    applyCorner(btn, 6)

    btn.MouseButton1Click:Connect(function()
        if options.Callback then
            task.spawn(options.Callback)
        end
    end)

    return btn
end

function Section:CreateSlider(options)
    options = options or {}
    local min = options.Min or 0
    local max = options.Max or 100
    local value = options.Default or min

    local frame = newControlFrame(self)

    local labelContainer = Instance.new('Frame')
    labelContainer.BackgroundTransparency = 1
    labelContainer.Size = UDim2.new(1, 0, 0, 20)
    labelContainer.Parent = frame

    local label = Instance.new('TextLabel')
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, -40, 1, 0)
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextColor3 = CascadeV2.Theme.Text
    label.Text = options.Name or 'Slider'
    label.Parent = labelContainer

    local valueLabel = Instance.new('TextLabel')
    valueLabel.BackgroundTransparency = 1
    valueLabel.Size = UDim2.new(0, 40, 1, 0)
    valueLabel.AnchorPoint = Vector2.new(1, 0)
    valueLabel.Position = UDim2.new(1, 0, 0, 0)
    valueLabel.Font = Enum.Font.Gotham
    valueLabel.TextSize = 13
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.TextColor3 = CascadeV2.Theme.SubText
    valueLabel.Text = tostring(value)
    valueLabel.Parent = labelContainer

    local bar = Instance.new('Frame')
    bar.BackgroundColor3 = CascadeV2.Theme.SliderTrack
    bar.BorderSizePixel = 0
    bar.Size = UDim2.new(1, 0, 0, 6)
    bar.Parent = frame
    applyCorner(bar, 3)

    local fill = Instance.new('Frame')
    fill.BackgroundColor3 = CascadeV2.Theme.SliderFill
    fill.BorderSizePixel = 0
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.Parent = bar
    applyCorner(fill, 3)

    local dragging = false

    local function setValueFromX(x)
        local pos = bar.AbsolutePosition.X
        local size = bar.AbsoluteSize.X
        local alpha = math.clamp((x - pos) / size, 0, 1)
        local newValue = math.floor(min + (max - min) * alpha + 0.5)
        value = newValue
        fill.Size = UDim2.new(alpha, 0, 1, 0)
        valueLabel.Text = tostring(value)
        if options.Callback then
            task.spawn(options.Callback, value)
        end
    end

    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            setValueFromX(input.Position.X)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            setValueFromX(input.Position.X)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    local function setValueDirect(v)
        v = math.clamp(v, min, max)
        local alpha = (v - min) / (max - min)
        fill.Size = UDim2.new(alpha, 0, 1, 0)
        valueLabel.Text = tostring(v)
        value = v
    end

    setValueDirect(value)

    return {
        Set = function(v)
            setValueDirect(v)
            if options.Callback then
                task.spawn(options.Callback, value)
            end
        end
    }
end

function Section:CreateDropdown(options)
    options = options or {}
    local items = options.Options or {}
    local current = options.Default or items[1]

    local frame = newControlFrame(self)

    local header = Instance.new('Frame')
    header.BackgroundColor3 = CascadeV2.Theme.Panel
    header.BorderSizePixel = 0
    header.Size = UDim2.new(1, 0, 0, 28)
    header.Parent = frame
    applyCorner(header, 6)
    applyStroke(header)

    local label = Instance.new('TextLabel')
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(0.4, -8, 1, 0)
    label.Position = UDim2.new(0, 8, 0, 0)
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextColor3 = CascadeV2.Theme.Text
    label.Text = options.Name or 'Dropdown'
    label.Parent = header

    local selected = Instance.new('TextButton')
    selected.BackgroundTransparency = 1
    selected.Size = UDim2.new(0.6, -16, 1, 0)
    selected.Position = UDim2.new(0.4, 4, 0, 0)
    selected.Font = Enum.Font.Gotham
    selected.TextSize = 13
    selected.TextXAlignment = Enum.TextXAlignment.Left
    selected.TextColor3 = CascadeV2.Theme.Text
    selected.Text = tostring(current or '')
    selected.Parent = header

    local arrow = Instance.new('TextLabel')
    arrow.BackgroundTransparency = 1
    arrow.Size = UDim2.new(0, 16, 1, 0)
    arrow.AnchorPoint = Vector2.new(1, 0)
    arrow.Position = UDim2.new(1, -8, 0, 0)
    arrow.Font = Enum.Font.GothamBold
    arrow.TextSize = 14
    arrow.TextColor3 = CascadeV2.Theme.SubText
    arrow.Text = '▼'
    arrow.Parent = header

    local listHolder = Instance.new('Frame')
    listHolder.BackgroundColor3 = CascadeV2.Theme.PanelAlt
    listHolder.BorderSizePixel = 0
    listHolder.Size = UDim2.new(1, 0, 0, 0)
    listHolder.Visible = false
    listHolder.Parent = frame
    applyCorner(listHolder, 6)
    applyStroke(listHolder)

    local listPadding = Instance.new('UIPadding')
    listPadding.PaddingTop = UDim.new(0, 4)
    listPadding.PaddingBottom = UDim.new(0, 4)
    listPadding.PaddingLeft = UDim.new(0, 4)
    listPadding.PaddingRight = UDim.new(0, 4)
    listPadding.Parent = listHolder

    local listLayout = Instance.new('UIListLayout')
    listLayout.FillDirection = Enum.FillDirection.Vertical
    listLayout.Padding = UDim.new(0, 2)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = listHolder

    listHolder.AutomaticSize = Enum.AutomaticSize.Y

    local function refreshOptions()
        for _, child in ipairs(listHolder:GetChildren()) do
            if child:IsA('TextButton') then
                child:Destroy()
            end
        end
        for _, item in ipairs(items) do
            local optBtn = Instance.new('TextButton')
            optBtn.BackgroundColor3 = CascadeV2.Theme.Panel
            optBtn.BorderSizePixel = 0
            optBtn.Size = UDim2.new(1, 0, 0, 24)
            optBtn.Font = Enum.Font.Gotham
            optBtn.TextSize = 12
            optBtn.TextColor3 = CascadeV2.Theme.Text
            optBtn.TextXAlignment = Enum.TextXAlignment.Left
            optBtn.Text = tostring(item)
            optBtn.Parent = listHolder
            applyCorner(optBtn, 4)
            optBtn.MouseButton1Click:Connect(function()
                current = item
                selected.Text = tostring(item)
                listHolder.Visible = false
                if options.Callback then
                    task.spawn(options.Callback, current)
                end
            end)
        end
    end

    refreshOptions()

    selected.MouseButton1Click:Connect(function()
        listHolder.Visible = not listHolder.Visible
    end)

    return {
        Set = function(value)
            current = value
            selected.Text = tostring(value)
            if options.Callback then
                task.spawn(options.Callback, current)
            end
        end,
        SetOptions = function(newOptions)
            items = newOptions or {}
            refreshOptions()
        end
    }
end

function CascadeV2:Notify(options)
    ensureGui()
    options = options or {}

    local holder = CascadeV2._notifHolder
    if not holder then return end

    local frame = Instance.new('Frame')
    frame.BackgroundColor3 = CascadeV2.Theme.Notification
    frame.BorderSizePixel = 0
    frame.Size = UDim2.new(1, 0, 0, 60)
    frame.Parent = holder
    applyCorner(frame, 6)
    applyStroke(frame)

    local title = Instance.new('TextLabel')
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(1, -12, 0, 22)
    title.Position = UDim2.new(0, 6, 0, 4)
    title.Font = Enum.Font.GothamSemibold
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextColor3 = CascadeV2.Theme.Text
    title.Text = options.Title or 'CascadeV2'
    title.Parent = frame

    local body = Instance.new('TextLabel')
    body.BackgroundTransparency = 1
    body.Size = UDim2.new(1, -12, 1, -26)
    body.Position = UDim2.new(0, 6, 0, 24)
    body.Font = Enum.Font.Gotham
    body.TextSize = 12
    body.TextXAlignment = Enum.TextXAlignment.Left
    body.TextYAlignment = Enum.TextYAlignment.Top
    body.TextWrapped = true
    body.TextColor3 = CascadeV2.Theme.SubText
    body.Text = options.Content or ''
    body.Parent = frame

    frame.BackgroundTransparency = 1
    TweenService:Create(
        frame,
        TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        {BackgroundTransparency = 0}
    ):Play()

    local duration = options.Duration or 3
    task.delay(duration, function()
        if frame.Parent then
            local tween = TweenService:Create(
                frame,
                TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
                {BackgroundTransparency = 1}
            )
            tween:Play()
            tween.Completed:Wait()
            frame:Destroy()
        end
    end)
end

return CascadeV2
