-- Surge v0.1.0
--
-- DIRECTION CONTRACT
-- THESIS: Surge is a compact monochrome instrument panel for executor-run scripts;
-- it refuses neon executor chrome, remote models, and opaque lifecycle behavior.
-- OWN-WORLD: black, white, and graphite layers; rounded panels; code-drawn Lucide-style
-- line icons; translucent surfaces and one-pixel edges do the visual work.
-- FIRST VIEWPORT: a centred window with a Zap mark, a narrow tab rail, and dense but
-- readable controls that show state in text as well as contrast.
-- VISITOR PATH: load -> create window -> select tab -> operate values -> unload.
-- SIGNATURE INTERACTION: every control is a handle; every handle can be driven from code.
-- CROSS-SURFACE REACH: the same handles power notifications, popups, saving, and teardown.
-- HONEST RISK: executor APIs and Roblox UI behavior vary; Surge reports missing optional
-- filesystem features instead of claiming universal compatibility.

local Surge = {
    Name = "Surge",
    Version = "0.1.0",
}
Surge.Distribution = {
    AssetVersion = 2,
    Version = Surge.Version,
    Repository = "https://github.com/chineseAIslut/Surge",
    Ref = "main",
    SourcePaths = {
        Library = ".Surge/Surge.lua",
        LucideBridge = ".Surge/assets/LucideBridge.lua",
    },
    RepositoryPaths = {
        Library = "Surge.lua",
        LucideBridge = "assets/LucideBridge.lua",
    },
    ManagedPaths = {
        Root = "Surge",
        Assets = "Surge/Assets",
        Configs = "Surge/Configs",
        Managed = "Surge/Managed",
        Library = "Surge/Managed/Surge.lua",
        LucideBridge = "Surge/Assets/LucideBridge.lua",
        IconCache = "Surge/Assets/IconCache",
        Manifest = "Surge/Managed/manifest.json",
    },
}

local Window = {}
Window.__index = Window
local Tab = {}
Tab.__index = Tab
local Group = {}
Group.__index = Group

local unpack = table.unpack or unpack
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
Surge.Animation = {
    Press = 0.06,
    Toggle = 0.12,
    Theme = 0.18,
    Fast = 0.10,
    Standard = 0.16,
    Tab = 0.14,
    Menu = 0.22,
    Message = 0.16,
    EasingStyle = Enum.EasingStyle.Quad,
    EaseIn = Enum.EasingDirection.In,
    EaseOut = Enum.EasingDirection.Out,
    EaseInOut = Enum.EasingDirection.InOut,
}


local function copyTable(source)
    local result = {}
    if type(source) ~= "table" then
        return result
    end
    for key, value in pairs(source) do
        if type(value) == "table" then
            result[key] = copyTable(value)
        else
            result[key] = value
        end
    end
    return result
end

local function mergeTables(base, override)
    local result = copyTable(base)
    if type(override) ~= "table" then
        return result
    end
    for key, value in pairs(override) do
        if type(value) == "table" and type(result[key]) == "table" then
            result[key] = mergeTables(result[key], value)
        else
            result[key] = value
        end
    end
    return result
end

local function opt(tableValue, defaultValue, ...)
    if type(tableValue) ~= "table" then
        return defaultValue
    end
    for index = 1, select("#", ...) do
        local key = select(index, ...)
        if tableValue[key] ~= nil then
            return tableValue[key]
        end
    end
    return defaultValue
end

local function asString(value, fallback)
    if value == nil then
        return fallback or ""
    end
    return tostring(value)
end

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function round(value)
    if value >= 0 then
        return math.floor(value + 0.5)
    end
    return math.ceil(value - 0.5)
end

local function safeCall(callback, ...)
    if type(callback) ~= "function" then
        return true
    end
    return pcall(callback, ...)
end

local function globalEnvironment()
    if type(getgenv) == "function" then
        local ok, environment = pcall(getgenv)
        if ok and type(environment) == "table" then
            return environment
        end
    end
    return _G
end

local function ensureSharedState()
    local environment = globalEnvironment()
    local shared = rawget(environment, "__SURGE_SHARED_STATE")
    if type(shared) ~= "table" then
        shared = {
            windows = {},
            icons = {},
        }
        rawset(environment, "__SURGE_SHARED_STATE", shared)
    end
    return shared
end

local Shared = ensureSharedState()
local LucideBridge
local LucideBridgeError
local function loadLucideBridge()
    if type(readfile) ~= "function" or type(loadstring) ~= "function" then
        return nil, "readfile/loadstring unavailable"
    end
    local candidates = {
        Surge.Distribution.ManagedPaths.LucideBridge,
        Surge.Distribution.SourcePaths.LucideBridge,
    }
    local lastError = "LucideBridge file unavailable"
    for _, path in ipairs(candidates) do
        local ok, source = pcall(readfile, path)
        if ok and type(source) == "string" and source ~= "" then
            local chunk, compileError = loadstring(source, "@" .. path)
            if chunk then
                local loaded, module = pcall(chunk)
                if loaded and type(module) == "table" then
                    return module
                end
                lastError = tostring(module)
            else
                lastError = tostring(compileError)
            end
        else
            lastError = tostring(source)
        end
    end
    return nil, lastError
end
LucideBridge, LucideBridgeError = loadLucideBridge()
Surge.Lucide = LucideBridge
Surge.LucideError = LucideBridgeError

local function instance(className, properties, parent)
    local object = Instance.new(className)
    if properties then
        for property, value in pairs(properties) do
            local ok = pcall(function()
                object[property] = value
            end)
            if not ok then
                -- Optional Roblox properties differ between client builds. Keep the
                -- object usable when an optional property is unavailable.
            end
        end
    end
    if parent then
        object.Parent = parent
    end
    return object
end

local function corner(parent, radius)
    return instance("UICorner", {
        CornerRadius = UDim.new(0, radius or 8),
    }, parent)
end

local function stroke(parent, color, transparency, thickness)
    return instance("UIStroke", {
        Color = color or Color3.new(1, 1, 1),
        Transparency = transparency == nil and 0 or transparency,
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, parent)
end

local function listLayout(parent, padding, direction, horizontalAlignment)
    return instance("UIListLayout", {
        Padding = UDim.new(0, padding or 0),
        FillDirection = direction or Enum.FillDirection.Vertical,
        HorizontalAlignment = horizontalAlignment or Enum.HorizontalAlignment.Left,
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, parent)
end

local function padding(parent, left, top, right, bottom)
    return instance("UIPadding", {
        PaddingLeft = UDim.new(0, left or 0),
        PaddingTop = UDim.new(0, top or 0),
        PaddingRight = UDim.new(0, right or 0),
        PaddingBottom = UDim.new(0, bottom or 0),
    }, parent)
end

local function enumKey(value)
    if value == nil then
        return nil
    end
    if typeof and typeof(value) == "EnumItem" then
        return value
    end
    if type(value) == "string" then
        local mouseNames = {
            MouseButton1 = Enum.UserInputType.MouseButton1,
            MouseButton2 = Enum.UserInputType.MouseButton2,
            MouseButton3 = Enum.UserInputType.MouseButton3,
        }
        if mouseNames[value] then
            return mouseNames[value]
        end
        local ok, key = pcall(function()
            return Enum.KeyCode[value]
        end)
        if ok then
            return key
        end
    end
    return value
end

local function keyName(value)
    if value == nil then
        return "None"
    end
    if typeof and typeof(value) == "EnumItem" then
        return value.Name
    end
    return tostring(value)
end

local DefaultTheme = {
    Window = Color3.fromRGB(15, 15, 17),
    Surface = Color3.fromRGB(22, 22, 25),
    SurfaceRaised = Color3.fromRGB(29, 29, 33),
    SurfaceInput = Color3.fromRGB(10, 10, 12),
    Overlay = Color3.fromRGB(0, 0, 0),
    Text = Color3.fromRGB(245, 245, 247),
    TextMuted = Color3.fromRGB(166, 166, 172),
    TextFaint = Color3.fromRGB(112, 112, 120),
    Border = Color3.fromRGB(55, 55, 62),
    BorderStrong = Color3.fromRGB(88, 88, 96),
    Accent = Color3.fromRGB(245, 245, 247),
    AccentContrast = Color3.fromRGB(16, 16, 18),
    ToggleOff = Color3.fromRGB(57, 57, 64),
    ProgressTrack = Color3.fromRGB(42, 42, 48),
    Danger = Color3.fromRGB(232, 232, 236),
    Icon = Color3.fromRGB(218, 218, 224),
    WindowTransparency = 0.04,
    SurfaceTransparency = 0.08,
    RaisedTransparency = 0.02,
    InputTransparency = 0.04,
    OverlayTransparency = 0.42,
}

Surge.Themes = {
    Monochrome = copyTable(DefaultTheme),
    Graphite = copyTable(DefaultTheme),
}

local ICONS = {
    Zap = {
        segments = {
            { 13, 2, 5, 13 }, { 5, 13, 11, 13 }, { 11, 13, 9, 22 },
            { 9, 22, 19, 9 }, { 19, 9, 13, 9 }, { 13, 9, 13, 2 },
        },
    },
    PanelLeft = {
        segments = {
            { 4, 4, 20, 4 }, { 20, 4, 20, 20 }, { 20, 20, 4, 20 }, { 4, 20, 4, 4 },
            { 9, 4, 9, 20 },
        },
    },
    House = {
        segments = {
            { 3, 11, 12, 3 }, { 12, 3, 21, 11 }, { 5, 9, 5, 21 }, { 5, 21, 19, 21 },
            { 19, 21, 19, 9 }, { 9, 21, 9, 14 }, { 9, 14, 15, 14 }, { 15, 14, 15, 21 },
        },
    },
    Settings = {
        segments = {
            { 12, 3, 12, 6 }, { 12, 18, 12, 21 }, { 3, 12, 6, 12 }, { 18, 12, 21, 12 },
            { 5.6, 5.6, 7.7, 7.7 }, { 16.3, 16.3, 18.4, 18.4 },
            { 5.6, 18.4, 7.7, 16.3 }, { 16.3, 7.7, 18.4, 5.6 },
        },
        circles = { { 12, 12, 4.1 } },
    },
    SlidersHorizontal = {
        segments = {
            { 3, 6, 21, 6 }, { 3, 12, 21, 12 }, { 3, 18, 21, 18 },
        },
        circles = { { 8, 6, 2 }, { 16, 12, 2 }, { 10, 18, 2 } },
    },
    ToggleRight = {
        segments = { { 7, 7, 17, 7 }, { 17, 7, 17, 17 }, { 17, 17, 7, 17 }, { 7, 17, 7, 7 } },
        circles = { { 15, 12, 3 } },
    },
    Terminal = {
        segments = { { 4, 6, 10, 12 }, { 10, 12, 4, 18 }, { 13, 18, 20, 18 } },
    },
    Palette = {
        segments = {
            { 12, 3, 7, 4 }, { 7, 4, 4, 8 }, { 4, 8, 4, 15 }, { 4, 15, 8, 20 },
            { 8, 20, 15, 20 }, { 15, 20, 18, 17 }, { 18, 17, 18, 14 }, { 18, 14, 21, 14 },
            { 21, 14, 20, 8 }, { 20, 8, 16, 4 }, { 16, 4, 12, 3 },
        },
        dots = { { 8, 9 }, { 12, 7 }, { 16, 9 } },
    },
    Keyboard = {
        segments = {
            { 3, 6, 21, 6 }, { 21, 6, 21, 18 }, { 21, 18, 3, 18 }, { 3, 18, 3, 6 },
            { 6, 10, 8, 10 }, { 10, 10, 12, 10 }, { 14, 10, 16, 10 }, { 18, 10, 19, 10 },
            { 7, 14, 17, 14 },
        },
    },
    Plus = { segments = { { 12, 4, 12, 20 }, { 4, 12, 20, 12 } } },
    X = { segments = { { 5, 5, 19, 19 }, { 19, 5, 5, 19 } } },
    ChevronDown = { segments = { { 5, 9, 12, 16 }, { 12, 16, 19, 9 } } },
    ChevronRight = { segments = { { 9, 5, 16, 12 }, { 16, 12, 9, 19 } } },
    Check = { segments = { { 4, 12, 10, 18 }, { 10, 18, 20, 6 } } },
    Minus = { segments = { { 4, 12, 20, 12 } } },
    Info = {
        segments = { { 12, 10, 12, 18 } },
        circles = { { 12, 12, 9 } },
        dots = { { 12, 6 } },
    },
    Bell = {
        segments = {
            { 6, 17, 18, 17 }, { 8, 17, 8, 10 }, { 8, 10, 10, 6 }, { 10, 6, 14, 6 },
            { 14, 6, 16, 10 }, { 16, 10, 16, 17 }, { 10, 20, 14, 20 },
        },
    },
    Search = {
        segments = {
            { 17.5, 17.5, 21, 21 }, { 5, 10, 5.8, 7 }, { 5.8, 7, 8, 5.2 },
            { 8, 5.2, 11, 4.5 }, { 11, 4.5, 14, 5.2 }, { 14, 5.2, 16.2, 7 },
            { 16.2, 7, 17, 10 }, { 17, 10, 16.2, 13 }, { 16.2, 13, 14, 15 },
            { 14, 15, 11, 15.8 }, { 11, 15.8, 8, 15 }, { 8, 15, 5.8, 13 }, { 5.8, 13, 5, 10 },
        },
    },
    Copy = {
        segments = {
            { 8, 8, 19, 8 }, { 19, 8, 19, 19 }, { 19, 19, 8, 19 }, { 8, 19, 8, 8 },
            { 5, 5, 5, 15 }, { 5, 5, 15, 5 },
        },
    },
    RefreshCw = {
        segments = {
            { 20, 11, 20, 8 }, { 20, 8, 18, 5 }, { 18, 5, 15, 4 }, { 15, 4, 12, 3 },
            { 12, 3, 9, 4 }, { 9, 4, 6, 6 }, { 6, 6, 4, 9 }, { 4, 9, 4, 13 },
            { 4, 13, 4, 19 }, { 4, 19, 10, 19 }, { 4, 19, 9, 14 },
            { 20, 5, 15, 10 },
        },
    },
    Activity = {
        segments = {
            { 3, 12, 7, 12 }, { 7, 12, 9, 5 }, { 9, 5, 14, 19 },
            { 14, 19, 17, 12 }, { 17, 12, 21, 12 },
        },
    },
    CircleGauge = {
        segments = {
            { 12, 3, 7, 4 }, { 7, 4, 4, 8 }, { 4, 8, 3, 12 }, { 3, 12, 4, 16 },
            { 4, 16, 7, 20 }, { 7, 20, 12, 21 }, { 12, 21, 17, 20 }, { 17, 20, 20, 16 },
            { 20, 16, 21, 12 }, { 21, 12, 20, 8 }, { 20, 8, 17, 4 }, { 17, 4, 12, 3 },
            { 12, 12, 12, 7 }, { 12, 12, 16, 14 },
        },
    },
    Moon = { segments = { { 18, 15, 14, 19 }, { 14, 19, 9, 19 }, { 9, 19, 5, 15 }, { 5, 15, 5, 10 }, { 5, 10, 9, 5 }, { 9, 5, 14, 5 }, { 14, 5, 18, 8 }, { 18, 8, 14, 8 }, { 14, 8, 12, 10 }, { 12, 10, 14, 13 }, { 14, 13, 18, 15 } } },
    Sun = { segments = { { 12, 3, 12, 6 }, { 12, 18, 12, 21 }, { 3, 12, 6, 12 }, { 18, 12, 21, 12 }, { 5, 5, 7, 7 }, { 17, 17, 19, 19 }, { 5, 19, 7, 17 }, { 17, 7, 19, 5 } }, circles = { { 12, 12, 4 } } },
}

local IconAliases = {
    ["zap"] = "Zap", ["lightning"] = "Zap", ["panel-left"] = "PanelLeft", ["panelleft"] = "PanelLeft",
    ["home"] = "House", ["house"] = "House", ["settings"] = "Settings", ["sliders-horizontal"] = "SlidersHorizontal",
    ["toggle-right"] = "ToggleRight", ["terminal"] = "Terminal", ["palette"] = "Palette", ["keyboard"] = "Keyboard",
    ["plus"] = "Plus", ["x"] = "X", ["close"] = "X", ["chevron-down"] = "ChevronDown", ["chevron-right"] = "ChevronRight",
    ["check"] = "Check", ["minus"] = "Minus", ["info"] = "Info", ["bell"] = "Bell", ["search"] = "Search",
    ["copy"] = "Copy", ["refresh-cw"] = "RefreshCw", ["moon"] = "Moon", ["sun"] = "Sun",
    ["activity"] = "Activity", ["circle-gauge"] = "CircleGauge", ["circlegauge"] = "CircleGauge",
}

Surge.Icons = ICONS

function Surge:RegisterIcon(name, definition)
    assert(type(name) == "string" and name ~= "", "Surge:RegisterIcon expects a non-empty name")
    assert(type(definition) == "table", "Surge:RegisterIcon expects a definition table")
    ICONS[name] = copyTable(definition)
    Shared.icons[name] = ICONS[name]
    return ICONS[name]
end

local function canonicalIcon(name)
    if type(name) ~= "string" then
        return nil
    end
    return IconAliases[string.lower(name)] or name
end

function Window:_bind(object, property, themeKey)
    if not object then
        return
    end
    local value = self.Theme[themeKey]
    if value ~= nil then
        pcall(function()
            object[property] = value
        end)
    end
    table.insert(self._bindings, {
        object = object,
        property = property,
        themeKey = themeKey,
    })
end

function Window:_refresh(fn)
    table.insert(self._refreshers, fn)
end

function Window:_connect(signal, callback)
    if not signal then
        return nil
    end
    local ok, connection = pcall(function()
        return signal:Connect(callback)
    end)
    if ok and connection then
        table.insert(self._connections, connection)
        return connection
    end
    return nil
end

local function disposeTweenRecord(record, cancel)
    if record.connection then
        local connection = record.connection
        record.connection = nil
        pcall(function()
            connection:Disconnect()
        end)
    end
    if record.tween then
        if cancel then
            pcall(function()
                record.tween:Cancel()
            end)
        end
        pcall(function()
            record.tween:Destroy()
        end)
    end
end

local function tweenPropertiesOverlap(record, properties)
    if type(properties) == "string" then
        return record.properties and record.properties[properties] == true
    end
    for property in pairs(properties or {}) do
        if record.properties and record.properties[property] then
            return true
        end
    end
    return false
end

function Window:_cancelTween(object, properties)
    if not self._tweens or not object then
        return
    end
    local records = self._tweens[object]
    if not records then
        return
    end
    local recordCount = #records
    if properties == nil then
        self._tweens[object] = nil
        for index = 1, recordCount do
            disposeTweenRecord(records[index], true)
        end
        return
    end
    local keep = 1
    for index = 1, recordCount do
        local record = records[index]
        if tweenPropertiesOverlap(record, properties) then
            disposeTweenRecord(record, true)
        else
            records[keep] = record
            keep = keep + 1
        end
    end
    for index = keep, recordCount do
        records[index] = nil
    end
    if keep == 1 then
        self._tweens[object] = nil
    end
end

function Window:_cancelAllTweens()
    local recordsByObject = self._tweens or {}
    self._tweens = {}
    for _, records in pairs(recordsByObject) do
        for index = 1, #records do
            disposeTweenRecord(records[index], true)
        end
    end
end
function Window:_cancelTweenTree(root)
    if not root then
        return
    end
    self:_cancelTween(root)
    for _, descendant in ipairs(root:GetDescendants()) do
        self:_cancelTween(descendant)
    end
end


function Window:_tween(object, properties, duration, easingStyle, easingDirection)
    if self.unloaded or not object or not object.Parent or type(properties) ~= "table" then
        return nil
    end
    self._tweens = self._tweens or {}
    local propertySet = {}
    for property in pairs(properties) do
        propertySet[property] = true
    end
    self:_cancelTween(object, propertySet)
    local ok, tween = pcall(function()
        return TweenService:Create(object, TweenInfo.new(
            tonumber(duration) or Surge.Animation.Standard,
            easingStyle or Surge.Animation.EasingStyle,
            easingDirection or Surge.Animation.EaseOut
        ), properties)
    end)
    if not ok or not tween then
        for property, value in pairs(properties) do
            pcall(function()
                object[property] = value
            end)
        end
        return nil
    end
    local records = self._tweens[object]
    if not records then
        records = {}
        self._tweens[object] = records
    end
    local record = { tween = tween, properties = propertySet }
    table.insert(records, record)
    local connectionOk, connection = pcall(function()
        return tween.Completed:Connect(function()
            local activeRecords = self._tweens[object]
            if not activeRecords then
                return
            end
            local found
            for index, candidate in ipairs(activeRecords) do
                if candidate == record then
                    table.remove(activeRecords, index)
                    found = true
                    break
                end
            end
            if not found then
                return
            end
            if #activeRecords == 0 then
                self._tweens[object] = nil
            end
            disposeTweenRecord(record, false)
        end)
    end)
    if connectionOk then
        record.connection = connection
    end
    tween:Play()
    return tween
end

function Window:_safeCallback(callback, ...)
    local ok, errorMessage = safeCall(callback, ...)
    if not ok and not self.unloaded then
        if type(self._onError) == "function" then
            safeCall(self._onError, errorMessage)
        else
            self:Notify({
                title = "Callback error",
                content = tostring(errorMessage),
                duration = 5,
                icon = "Info",
            })
        end
    end
end

local function captureVisualProperties(root)
    local entries = {}
    local function add(object, property)
        local ok, value = pcall(function()
            return object[property]
        end)
        if ok and type(value) == "number" then
            table.insert(entries, {
                object = object,
                property = property,
                value = value,
            })
        end
    end
    local function visit(object)
        if object:IsA("GuiObject") then
            add(object, "BackgroundTransparency")
        end
        if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
            add(object, "TextTransparency")
        end
        if object:IsA("ImageLabel") or object:IsA("ImageButton") then
            add(object, "ImageTransparency")
        end
        if object:IsA("UIStroke") then
            add(object, "Transparency")
        end
    end
    visit(root)
    for _, descendant in ipairs(root:GetDescendants()) do
        visit(descendant)
    end
    return entries
end

function Window:_setVisualTransparency(entries, target)
    for _, entry in ipairs(entries or {}) do
        local object = entry.object
        if object and object.Parent then
            self:_cancelTween(object, entry.property)
            local value = target == "restore" and entry.value or target
            pcall(function()
                object[entry.property] = value
            end)
        end
    end
end

function Window:_animateVisualTransparency(entries, target, duration, easingDirection)
    local grouped = {}
    for _, entry in ipairs(entries or {}) do
        local object = entry.object
        if object and object.Parent then
            local properties = grouped[object] or {}
            properties[entry.property] = target == "restore" and entry.value or target
            grouped[object] = properties
        end
    end
    for object, properties in pairs(grouped) do
        self:_tween(object, properties, duration, Surge.Animation.EasingStyle, easingDirection or Surge.Animation.EaseOut)
    end
end

function Window:_captureVisual(root)
    return captureVisualProperties(root)
end
function Window:_showTransient(root, duration)
    local state = {
        root = root,
        closed = false,
        closing = false,
        token = 0,
        fullSize = root.Size,
        visuals = self:_captureVisual(root),
    }
    self:_setVisualTransparency(state.visuals, 1)
    self:_animateVisualTransparency(state.visuals, "restore", Surge.Animation.Message, Surge.Animation.EaseOut)
    state.timer = task.delay(duration, function()
        if not self.unloaded and root.Parent then
            self:_closeTransient(state)
        end
    end)
    return state
end

function Window:_closeTransient(state)
    if self.unloaded or not state or state.closed or state.closing then
        return
    end
    state.closing = true
    state.token = state.token + 1
    local token = state.token
    if state.timer and type(task.cancel) == "function" then
        pcall(task.cancel, state.timer)
        state.timer = nil
    end
    local root = state.root
    if not root or not root.Parent then
        state.closed = true
        return
    end
    self:_animateVisualTransparency(state.visuals, 1, Surge.Animation.Message, Surge.Animation.EaseIn)
    self:_tween(root, {
        Size = UDim2.new(state.fullSize.X.Scale, state.fullSize.X.Offset, 0, 0),
    }, Surge.Animation.Message, Surge.Animation.EasingStyle, Surge.Animation.EaseIn)
    task.delay(Surge.Animation.Message + 0.03, function()
        if self.unloaded or state.token ~= token then
            return
        end
        state.closed = true
        if root.Parent then
            root:Destroy()
        end
    end)
end


function Window:_makeIcon(parent, name, size, themeKey)
    local canonical = canonicalIcon(name)
    if not canonical then
        return nil
    end
    if LucideBridge and type(LucideBridge.GetIcon) == "function" then
        local bridgeOk, asset = pcall(function()
            return LucideBridge:GetIcon(canonical, {
                size = size or 18,
                color = "#ffffff",
                stroke_width = 1.8,
                cacheFolder = Surge.Distribution.ManagedPaths.IconCache,
                fallbackFolders = { ".Surge/icon-cache" },
            })
        end)
        if bridgeOk and asset then
            local image = instance("ImageLabel", {
                Name = "Icon_" .. canonical,
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Size = UDim2.fromOffset(size or 18, size or 18),
                Image = asset,
                ImageTransparency = 0,
                ScaleType = Enum.ScaleType.Fit,
                ClipsDescendants = false,
            }, parent)
            self:_bind(image, "ImageColor3", themeKey or "Icon")
            return image
        end
    end
    local definition = ICONS[canonical]
    if not definition then
        return nil
    end
    local icon = instance("Frame", {
        Name = "Icon_" .. canonical,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(size or 18, size or 18),
        ClipsDescendants = false,
    }, parent)
    local pixelSize = size or 18
    local thickness = math.max(1, pixelSize / 13)
    local function addLine(line)
        local x1, y1, x2, y2 = line[1], line[2], line[3], line[4]
        local dx, dy = x2 - x1, y2 - y1
        local length = math.sqrt(dx * dx + dy * dy)
        local angle = math.deg(math.atan2(dy, dx))
        local part = instance("Frame", {
            BackgroundTransparency = 0,
            BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(x1 / 24, 0, y1 / 24, 0),
            Size = UDim2.new(0, length * (pixelSize / 24), 0, thickness),
            Rotation = angle,
        }, icon)
        corner(part, thickness / 2)
        self:_bind(part, "BackgroundColor3", themeKey or "Icon")
    end
    for _, line in ipairs(definition.segments or {}) do
        addLine(line)
    end
    for _, circleData in ipairs(definition.circles or {}) do
        local cx, cy, radius = circleData[1], circleData[2], circleData[3]
        local circle = instance("Frame", {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Position = UDim2.new((cx - radius) / 24, 0, (cy - radius) / 24, 0),
            Size = UDim2.new((radius * 2) / 24, 0, (radius * 2) / 24, 0),
        }, icon)
        instance("UICorner", {
            CornerRadius = UDim.new(1, 0),
        }, circle)
        local outline = stroke(circle, self.Theme[themeKey or "Icon"], 0, thickness)
        self:_bind(outline, "Color", themeKey or "Icon")
    end
    for _, dotData in ipairs(definition.dots or {}) do
        local dot = instance("Frame", {
            BackgroundTransparency = 0,
            BorderSizePixel = 0,
            Position = UDim2.new(dotData[1] / 24, -thickness / 2, dotData[2] / 24, -thickness / 2),
            Size = UDim2.fromOffset(thickness, thickness),
        }, icon)
        instance("UICorner", {
            CornerRadius = UDim.new(1, 0),
        }, dot)
        self:_bind(dot, "BackgroundColor3", themeKey or "Icon")
    end
    return icon
end

function Surge:CreateIcon(parent, name, options)
    options = options or {}
    local window = options.window
    if not window then
        local dummy = setmetatable({
            Theme = mergeTables(DefaultTheme, options.theme),
            _bindings = {},
            _refreshers = {},
        }, Window)
        return dummy:_makeIcon(parent, name, options.size or 18, options.themeKey or "Icon")
    end
    return window:_makeIcon(parent, name, options.size or 18, options.themeKey or "Icon")
end

local function resolveGuiParent()
    if type(gethui) == "function" then
        local ok, hiddenGui = pcall(gethui)
        if ok and hiddenGui then
            return hiddenGui
        end
    end
    local ok, coreGui = pcall(function()
        return game:GetService("CoreGui")
    end)
    if ok and coreGui then
        return coreGui
    end
    return nil
end

local function safeName(value)
    local result = tostring(value or "Surge")
    result = result:gsub("[^%w%._%-]", "_")
    if result == "" then
        result = "Surge"
    end
    return result
end

local function colorFromValue(value)
    if typeof and typeof(value) == "Color3" then
        return value
    end
    if type(value) == "string" then
        local hex = value:gsub("#", "")
        if #hex == 6 then
            local r = tonumber(hex:sub(1, 2), 16)
            local g = tonumber(hex:sub(3, 4), 16)
            local b = tonumber(hex:sub(5, 6), 16)
            if r and g and b then
                return Color3.fromRGB(r, g, b)
            end
        end
    end
    return Color3.new(1, 1, 1)
end

local function formatNumber(value)
    if math.abs(value - math.floor(value)) < 0.00001 then
        return tostring(math.floor(value))
    end
    return string.format("%.2f", value):gsub("0+$", ""):gsub("%.$", "")
end

local function textLabel(window, parent, properties, themeKey)
    local label = instance("TextLabel", properties, parent)
    if themeKey then
        window:_bind(label, "TextColor3", themeKey)
    end
    if window and type(window._trackText) == "function" and type(properties and properties.Text) == "string" then
        window:_trackText(label, properties.Text)
    end
    return label
end
local function monochromeColor(value)
    local color = colorFromValue(value)
    local channel = (color.R + color.G + color.B) / 3
    return Color3.new(channel, channel, channel)
end

local function controlButton(parent, name, properties)
    local button = instance("TextButton", {
        Name = name,
        AutoButtonColor = false,
        BorderSizePixel = 0,
        Text = "",
        TextTransparency = 1,
        Active = true,
    }, parent)
    for property, value in pairs(properties or {}) do
        pcall(function()
            button[property] = value
        end)
    end
    return button
end

function Window:_build(options)
    local parent = resolveGuiParent()
    assert(parent, "Surge could not resolve a UI parent; Potassium's gethui() or CoreGui is required")

    local nonce = tostring(math.floor(os.clock() * 1000000)):sub(-8)
    self.Gui = instance("ScreenGui", {
        Name = "Surge_" .. safeName(self.Id) .. "_" .. nonce,
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = opt(options, 9999, "DisplayOrder", "displayOrder"),
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, parent)

    self._shadow = instance("Frame", {
        Name = "Shadow",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(self.Width + 12, self.Height + 12),
        BackgroundColor3 = self.Theme.Overlay,
        BackgroundTransparency = 0.7,
        BorderSizePixel = 0,
        ZIndex = 1,
    }, self.Gui)
    self._shadowCorner = corner(self._shadow, self.CornerRadius + 4)

    self._root = instance("Frame", {
        Name = "Window",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(self.Width, self.Height),
        BackgroundTransparency = self.Theme.WindowTransparency,
        BorderSizePixel = 0,
        ClipsDescendants = false,
        ZIndex = 2,
    }, self.Gui)
    self._rootCorner = corner(self._root, self.CornerRadius)
    stroke(self._root, self.Theme.Border, 0.08, 1)
    self:_bind(self._root, "BackgroundColor3", "Window")

    local sizeConstraint = instance("UISizeConstraint", {
        MinSize = Vector2.new(520, 330),
        MaxSize = Vector2.new(980, 760),
    }, self._root)

    self._topbar = instance("Frame", {
        Name = "Topbar",
        Size = UDim2.new(1, 0, 0, 58),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 4,
    }, self._root)

    local logoHolder = instance("Frame", {
        Name = "Logo",
        Position = UDim2.fromOffset(14, 13),
        Size = UDim2.fromOffset(32, 32),
        BackgroundColor3 = self.Theme.SurfaceRaised,
        BackgroundTransparency = self.Theme.RaisedTransparency,
        BorderSizePixel = 0,
        ZIndex = 5,
    }, self._topbar)
    corner(logoHolder, 10)
    stroke(logoHolder, self.Theme.BorderStrong, 0.18, 1)
    self:_bind(logoHolder, "BackgroundColor3", "SurfaceRaised")
    local logoIcon = self:_makeIcon(logoHolder, self.Logo, 19, "Accent")
    if logoIcon then
        logoIcon.AnchorPoint = Vector2.new(0.5, 0.5)
        logoIcon.Position = UDim2.fromScale(0.5, 0.5)
    end

    self._title = textLabel(self, self._topbar, {
        Name = "Title",
        Position = UDim2.fromOffset(58, 10),
        Size = UDim2.new(0, 180, 0, 22),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Font = Enum.Font.GothamSemibold,
        Text = self.Name,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        ZIndex = 5,
    }, "Text")
    self._subtitle = textLabel(self, self._topbar, {
        Name = "Subtitle",
        Position = UDim2.fromOffset(58, 31),
        Size = UDim2.new(0, 180, 0, 17),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Font = Enum.Font.Gotham,
        Text = self.Subtitle,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        ZIndex = 5,
    }, "TextMuted")

    self._tagContainer = instance("Frame", {
        Name = "Tags",
        Position = UDim2.fromOffset(250, 18),
        Size = UDim2.new(1, -376, 0, 24),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 5,
    }, self._topbar)
    listLayout(self._tagContainer, 5, Enum.FillDirection.Horizontal)
padding(self._tagContainer, 1, 1, 1, 1)

    local actionStart = -112
    local function chromeButton(name, iconName, label, callback)
        local button = controlButton(self._topbar, name, {
            Position = UDim2.new(1, actionStart, 0, 13),
            Size = UDim2.fromOffset(30, 30),
            BackgroundColor3 = self.Theme.SurfaceRaised,
            BackgroundTransparency = 1,
            ZIndex = 6,
        })
        button:SetAttribute("SurgeLabel", label)
        self:_bind(button, "BackgroundColor3", "SurfaceRaised")
        corner(button, 8)
        local icon = self:_makeIcon(button, iconName, 15, "Icon")
        if icon then
            icon.AnchorPoint = Vector2.new(0.5, 0.5)
            icon.Position = UDim2.fromScale(0.5, 0.5)
        end
        self:_connect(button.MouseEnter, function()
            self:_tween(button, { BackgroundTransparency = 0.55 }, Surge.Animation.Fast)
        end)
        self:_connect(button.MouseLeave, function()
            self:_tween(button, { BackgroundTransparency = 1 }, Surge.Animation.Fast)
        end)
        self:_connect(button.Activated, callback)
        actionStart = actionStart + 34
        return button
    end

    chromeButton("Close", "X", "Close Surge", function()
        self:Unload()
    end)
    chromeButton("Minimise", "Minus", "Minimise Surge", function()
        self:ToggleMinimise()
    end)
    chromeButton("Hide", "PanelLeft", "Hide Surge", function()
        self:Hide()
    end)

    self._body = instance("Frame", {
        Name = "Body",
        Position = UDim2.fromOffset(0, 58),
        Size = UDim2.new(1, 0, 1, -58),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 3,
    }, self._root)

    self._sidebar = instance("Frame", {
        Name = "Sidebar",
        Size = UDim2.new(0, self.SidebarWidth, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 4,
    }, self._body)
    self._sidebarList = instance("ScrollingFrame", {
        Name = "TabList",
        Position = UDim2.fromOffset(10, 12),
        Size = UDim2.new(1, -20, 1, self.Profile ~= "" and -58 or -24),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = self.Theme.BorderStrong,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ZIndex = 5,
    }, self._sidebar)
    listLayout(self._sidebarList, 6)
    padding(self._sidebarList, 2, 2, 4, 2)
    self._profileLabel = textLabel(self, self._sidebar, {
        Position = UDim2.new(0, 14, 1, -34),
        Size = UDim2.new(1, -28, 0, 20),
        BackgroundTransparency = 1,
        Font = Enum.Font.Gotham,
        Text = self.Profile,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Visible = self.Profile ~= "",
        ZIndex = 6,
    }, "TextMuted")

    self._contentHost = instance("Frame", {
        Name = "ContentHost",
        Position = UDim2.fromOffset(self.SidebarWidth, 0),
        Size = UDim2.new(1, -self.SidebarWidth, 1, 0),
        BackgroundColor3 = self.Theme.Surface,
        BackgroundTransparency = self.Theme.SurfaceTransparency,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 4,
    }, self._body)
    self:_bind(self._contentHost, "BackgroundColor3", "Surface")
    corner(self._contentHost, self.CornerRadius)
    self._tabTransitionBlocker = controlButton(self._contentHost, "TabTransitionBlocker", {
        Position = UDim2.fromScale(0, 0),
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Visible = false,
        ZIndex = 80,
    })


    self._notifyLayer = instance("Frame", {
        Name = "Notifications",
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -18, 1, -18),
        Size = UDim2.fromOffset(320, 360),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 50,
    }, self.Gui)
    local notificationLayout = listLayout(self._notifyLayer, 8, Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Right)
    notificationLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom

    self._toastLayer = instance("Frame", {
        Name = "Toasts",
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 18),
        Size = UDim2.fromOffset(360, 300),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 55,
    }, self.Gui)
    local toastLayout = listLayout(self._toastLayer, 8, Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Center)
    self._toastLayout = toastLayout
    toastLayout.VerticalAlignment = Enum.VerticalAlignment.Top

    self._pill = controlButton(self.Gui, "CollapsedPill", {
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -24, 1, -24),
        Size = UDim2.fromOffset(132, 40),
        BackgroundColor3 = self.Theme.SurfaceRaised,
        BackgroundTransparency = self.Theme.RaisedTransparency,
        ZIndex = 30,
        Visible = false,
    })
    corner(self._pill, 14)
    stroke(self._pill, self.Theme.BorderStrong, 0.08, 1)
    self:_bind(self._pill, "BackgroundColor3", "SurfaceRaised")
    local pillIcon = self:_makeIcon(self._pill, self.Logo, 16, "Accent")
    if pillIcon then
        pillIcon.Position = UDim2.fromOffset(12, 12)
    end
    local pillText = textLabel(self, self._pill, {
        Position = UDim2.fromOffset(36, 0),
        Size = UDim2.new(1, -46, 1, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamSemibold,
        Text = self.ShowName,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        ZIndex = 31,
    }, "TextMuted")
    self._displayBlocker = controlButton(self.Gui, "DisplayTransitionBlocker", {
        Position = UDim2.fromScale(0, 0),
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Visible = false,
        ZIndex = 90,
    })
    self._morphShadow = instance("Frame", {
        Name = "DisplayMorphShadow",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = self._root.Position,
        Size = self._shadow.Size,
        BackgroundColor3 = self.Theme.Overlay,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 91,
    }, self.Gui)
    self._morphShadowCorner = corner(self._morphShadow, self.CornerRadius + 4)
    self._morph = instance("Frame", {
        Name = "DisplayMorph",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = self._root.Position,
        Size = self._root.Size,
        BackgroundColor3 = self.Theme.Window,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Active = false,
        Visible = false,
        ZIndex = 92,
    }, self.Gui)
    self._morphCorner = corner(self._morph, self.CornerRadius)
    stroke(self._morph, self.Theme.Border, 0.08, 1)
    self:_bind(self._morph, "BackgroundColor3", "Window")

    self:_installPillDrag()
    self:_installDrag()
    self:_installToggleKey()
end

function Window:_installDrag()
    local dragging = false
    local dragInput
    local dragStart
    local startPosition
    self:_connect(self._topbar.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPosition = self._root.Position
            dragInput = input
            self:_connect(input.Changed, function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    self:_connect(self._topbar.InputChanged, function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    self:_connect(UserInputService.InputChanged, function(input)
        if input == dragInput and dragging and self._root and self._root.Parent then
            local delta = input.Position - dragStart
            self._root.Position = UDim2.new(
                startPosition.X.Scale,
                startPosition.X.Offset + delta.X,
                startPosition.Y.Scale,
                startPosition.Y.Offset + delta.Y
            )
            self._shadow.Position = UDim2.new(
                self._root.Position.X.Scale,
                self._root.Position.X.Offset,
                self._root.Position.Y.Scale,
                self._root.Position.Y.Offset
            )
        end
    end)
end
function Window:_installPillDrag()
    local dragging = false
    local moved = false
    local dragInput
    local dragStart
    local startPosition
    self:_connect(self._pill.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            moved = false
            dragStart = input.Position
            startPosition = self._pill.Position
        end
    end)
    self:_connect(self._pill.InputChanged, function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    self:_connect(UserInputService.InputChanged, function(input)
        if input ~= dragInput or not dragging then
            return
        end
        local delta = input.Position - dragStart
        if not moved and delta.Magnitude < 6 then
            return
        end
        moved = true
        local camera = workspace.CurrentCamera
        local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
        local size = self._pill.AbsoluteSize
        local baseX = startPosition.X.Scale * viewport.X
        local baseY = startPosition.Y.Scale * viewport.Y
        local x = clamp(startPosition.X.Offset + delta.X, size.X + 4 - baseX, viewport.X - 4 - baseX)
        local y = clamp(startPosition.Y.Offset + delta.Y, size.Y + 4 - baseY, viewport.Y - 4 - baseY)
        -- Keep the original bottom-right anchor. Changing AnchorPoint mid-drag
        -- introduces a visible coordinate jump on some Roblox clients.
        self._pill.Position = UDim2.new(startPosition.X.Scale, x, startPosition.Y.Scale, y)
    end)
    self:_connect(UserInputService.InputEnded, function(input)
        if not dragging then
            return
        end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            if not moved then
                self:Show()
            end
        end
    end)
end

function Window:_installToggleKey()
    local key = enumKey(self.ToggleKeybind)
    if not key or (typeof and typeof(key) ~= "EnumItem") then
        return
    end
    self:_connect(UserInputService.InputBegan, function(input, gameProcessed)
        if gameProcessed or self.unloaded then
            return
        end
        if input.KeyCode == key or input.UserInputType == key then
            self:ToggleHide()
        end
    end)
end

local function nextLayoutOrder(parent)
    local maximum = -1
    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA("GuiObject") then
            maximum = math.max(maximum, child.LayoutOrder)
        end
    end
    return maximum + 1
end
function Window:_newRow(host, height, name)
    local parent = (host and host._container) or self._page
    local width = UDim2.new(1, 0, 0, height)
    if host and host._widthScale then
        width = UDim2.new(host._widthScale, host._widthOffset or 0, 0, height)
    end
    local layoutOrder = host and host._order or nextLayoutOrder(parent)
    local row = instance("Frame", {
        Name = name or "Element",
        Size = width,
        BackgroundColor3 = self.Theme.SurfaceRaised,
        BackgroundTransparency = self.Theme.RaisedTransparency,
        BorderSizePixel = 0,
        LayoutOrder = layoutOrder,
        ZIndex = 7,
    }, parent)
    if host then
        host._order = host._order + 1
    end
    corner(row, 10)
    stroke(row, self.Theme.Border, 0.22, 1)
    self:_bind(row, "BackgroundColor3", "SurfaceRaised")
    return row
end

function Window:_newLabelBlock(row, options, iconName, rightWidth)
    local left = instance("Frame", {
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(1, -(rightWidth or 22) - 24, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = row.ZIndex + 1,
    }, row)
    local iconOffset = 0
    if iconName then
        local icon = self:_makeIcon(left, iconName, 16, "Icon")
        if icon then
            icon.Position = UDim2.fromOffset(0, 18)
            iconOffset = 24
        end
    end
    local title = textLabel(self, left, {
        Position = UDim2.fromOffset(iconOffset, 9),
        Size = UDim2.new(1, -iconOffset, 0, 19),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamSemibold,
        Text = asString(opt(options, "Element", "name", "Name"), "Element"),
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = row.ZIndex + 2,
    }, "Text")
    local description = asString(opt(options, "", "description", "Description"), "")
    local detail = textLabel(self, left, {
        Position = UDim2.fromOffset(iconOffset, 29),
        Size = UDim2.new(1, -iconOffset, 0, 17),
        BackgroundTransparency = 1,
        Font = Enum.Font.Gotham,
        Text = description,
        TextSize = 11,
        TextColor3 = self.Theme.TextMuted,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Visible = description ~= "",
        ZIndex = row.ZIndex + 2,
    }, "TextMuted")
    return left, title, detail
end

function Window:_registerValue(handle, flag)
    if (not flag or flag == "") and self.Configuration.Version == 1 then
        flag = safeName(handle.name)
    end
    if not flag or flag == "" then
        table.insert(self._configErrors, "Config flag required for " .. tostring(handle.name))
        return false
    end
    local key = tostring(flag)
    if self.Configuration.Version == 2 and (#key > 64 or not key:match("^[A-Za-z][A-Za-z0-9_.-]*$")) then
        table.insert(self._configErrors, "Invalid config flag: " .. key)
        return false
    end
    if self._values[key] and self._values[key] ~= handle then
        table.insert(self._configErrors, "Duplicate config flag: " .. key)
        handle._configDuplicate = true
        return false
    end
    handle._flag = key
    self._values[key] = handle
    self.Flags[key] = handle.value
    local defaultValue = type(handle.GetSaveValue) == "function" and handle:GetSaveValue() or handle.value
    self._configDefaults[key] = defaultValue == nil and { kind = "none" } or copyTable(defaultValue)
    local pending = self._pendingConfig and self._pendingConfig[key]
    if pending then
        self._pendingConfig[key] = nil
        self._loadingConfig = true
        self:_applyConfigValue(handle, pending.value, pending.fire == true)
        self._loadingConfig = false
    end
    return true
end

function Window:_scheduleConfigSave()
    if self._loadingConfig or not self.Configuration.Enabled or not self.Configuration.AutoSave or self.unloaded then
        return
    end
    self._configSaveToken = self._configSaveToken + 1
    local token = self._configSaveToken
    if self._configSaveTask and type(task.cancel) == "function" then
        pcall(task.cancel, self._configSaveTask)
    end
    self._configSaveTask = task.delay(self.Configuration.SaveDelay, function()
        if not self.unloaded and token == self._configSaveToken then
            self:Save()
        end
    end)
end

function Window:_valueChanged(handle, value)
    if handle._flag then
        self.Flags[handle._flag] = value
        self:_scheduleConfigSave()
    end
end

function Window:GetConfigErrors()
    return copyTable(self._configErrors)
end

function Window:_closeDropdownMenu()
    if self._dropdownMenu then
        pcall(function()
            self._dropdownMenu:Destroy()
        end)
        self._dropdownMenu = nil
    end
    if self._dropdownDismiss then
        pcall(function()
            self._dropdownDismiss:Destroy()
        end)
        self._dropdownDismiss = nil
    end
end
function Window:_trackText(label, source)
    if not label or type(source) ~= "string" then
        return
    end
    table.insert(self._copyBindings, { label = label, source = source })
    label.Text = self:_translate(source)
end

function Window:_translate(source)
    if type(self._translator) == "function" then
        local ok, translated = pcall(self._translator, source, self.Locale)
        if ok and type(translated) == "string" then
            return translated
        end
    end
    local localeTable = self._translations[self.Locale]
    if type(localeTable) == "table" and localeTable[source] ~= nil then
        return tostring(localeTable[source])
    end
    return source
end

function Window:_refreshLocale()
    for _, binding in ipairs(self._copyBindings) do
        if binding.label and binding.label.Parent then
            binding.label.Text = self:_translate(binding.source)
        end
    end
end

function Window:SetLocale(locale)
    self.Locale = asString(locale, "en")
    self:_refreshLocale()
    return self
end

function Window:SetTranslator(translator)
    self._translator = type(translator) == "function" and translator or nil
    self:_refreshLocale()
    return self
end

function Window:RegisterTranslations(translations)
    if type(translations) ~= "table" then
        return self
    end
    for locale, values in pairs(translations) do
        if type(values) == "table" then
            self._translations[locale] = mergeTables(self._translations[locale] or {}, values)
        end
    end
    self:_refreshLocale()
    return self
end

function Window:_attachElementHandle(handle, row)
    if type(handle) ~= "table" or not row then
        return handle
    end
    handle._row = row
    local function rowsInParent()
        local rows = {}
        local parent = row.Parent
        if not parent then
            return rows
        end
        for _, child in ipairs(parent:GetChildren()) do
            if child:IsA("GuiObject") then
                table.insert(rows, child)
            end
        end
        table.sort(rows, function(left, right)
            if left.LayoutOrder == right.LayoutOrder then
                return left.Name < right.Name
            end
            return left.LayoutOrder < right.LayoutOrder
        end)
        return rows
    end
    local function moveTo(index)
        local rows = rowsInParent()
        for position, candidate in ipairs(rows) do
            if candidate == row then
                table.remove(rows, position)
                break
            end
        end
        local target = clamp(tonumber(index) or (#rows + 1), 1, #rows + 1)
        table.insert(rows, target, row)
        for position, candidate in ipairs(rows) do
            candidate.LayoutOrder = position - 1
        end
    end
    function handle:MoveTo(index)
        moveTo(index)
        return self
    end
    function handle:MoveToTop()
        moveTo(1)
        return self
    end
    function handle:MoveToBottom()
        moveTo(#rowsInParent() + 1)
        return self
    end
    function handle:MoveUp()
        local rows = rowsInParent()
        for position, candidate in ipairs(rows) do
            if candidate == row then
                moveTo(position - 1)
                break
            end
        end
        return self
    end
    function handle:MoveDown()
        local rows = rowsInParent()
        for position, candidate in ipairs(rows) do
            if candidate == row then
                moveTo(position + 1)
                break
            end
        end
        return self
    end
    return handle
end

function Window:CreateTab(properties, legacyIcon)
    if self.unloaded then
        return nil
    end
    if type(properties) == "string" then
        properties = { name = properties, icon = legacyIcon }
    end
    properties = properties or {}
    local tab = setmetatable({
        Window = self,
        Name = asString(opt(properties, "Tab", "name", "Name"), "Tab"),
        Icon = opt(properties, nil, "icon", "Icon"),
        _container = nil,
        _order = 0,
        Selected = false,
    }, Tab)

    tab._button = controlButton(self._sidebarList, "Tab_" .. safeName(tab.Name), {
        Size = UDim2.new(1, 0, 0, 42),
        LayoutOrder = nextLayoutOrder(self._sidebarList),
        BackgroundColor3 = self.Theme.SurfaceRaised,
        BackgroundTransparency = 1,
        ZIndex = 6,
    })
    corner(tab._button, 10)
    local activeBar = instance("Frame", {
        Name = "ActiveBar",
        Position = UDim2.fromOffset(0, 8),
        Size = UDim2.fromOffset(3, 26),
        BackgroundColor3 = self.Theme.Accent,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 8,
    }, tab._button)
    corner(activeBar, 2)
    self:_bind(activeBar, "BackgroundColor3", "Accent")
    tab._activeBar = activeBar
    local icon = self:_makeIcon(tab._button, tab.Icon or "PanelLeft", 16, "Icon")
    if icon then
        icon.Position = UDim2.fromOffset(14, 13)
    end
    tab._label = textLabel(self, tab._button, {
        Position = UDim2.fromOffset(40, 0),
        Size = UDim2.new(1, -48, 1, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamSemibold,
        Text = tab.Name,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 8,
    }, "TextMuted")

    tab._page = instance("ScrollingFrame", {
        Name = "Page_" .. safeName(tab.Name),
        Position = UDim2.fromOffset(14, 12),
        Size = UDim2.new(1, -28, 1, -24),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = self.Theme.BorderStrong,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        Visible = false,
        ZIndex = 6,
    }, self._contentHost)
    listLayout(tab._page, 8)
padding(tab._page, 2, 1, 6, 3)
    tab._pageOrigin = tab._page.Position
    tab._container = tab._page
    table.insert(self._tabs, tab)
    self:_connect(tab._button.Activated, function()
        tab:Select()
    end)
    if not self._activeTab then
        tab:Select(true)
    end
    return tab
end

function Tab:Select(noAnimation)
    local window = self.Window
    if window.unloaded then
        return self
    end
    window:_closeDropdownMenu()
    window._tabTransitionToken = (window._tabTransitionToken or 0) + 1
    local token = window._tabTransitionToken
    local previousSelection = window._activeTab
    local selectedIndex
    local previousIndex
    for index, tab in ipairs(window._tabs) do
        if tab == self then
            selectedIndex = index
        elseif tab == previousSelection then
            previousIndex = index
        end
    end
    local direction = selectedIndex and previousIndex and selectedIndex > previousIndex and 1 or -1
    local function shifted(position, amount)
        return UDim2.new(position.X.Scale, position.X.Offset + amount, position.Y.Scale, position.Y.Offset)
    end
    local outgoing
    for _, tab in ipairs(window._tabs) do
        if tab ~= self and tab._page.Visible then
            if tab == previousSelection then
                outgoing = tab
                break
            end
            outgoing = outgoing or tab
        end
    end
    for _, tab in ipairs(window._tabs) do
        window:_cancelTweenTree(tab._page)
        if tab._transitionVisuals then
            window:_setVisualTransparency(tab._transitionVisuals, "restore")
        end
        tab._transitionVisuals = window:_captureVisual(tab._page)
        tab._page.Position = tab._pageOrigin
        tab._page.Visible = false
        local active = tab == self
        tab.Selected = active
        tab._activeBar.BackgroundTransparency = active and 0 or 1
        tab._button.BackgroundTransparency = active and window.Theme.RaisedTransparency or 1
        tab._label.TextColor3 = active and window.Theme.Text or window.Theme.TextMuted
    end
    window._activeTab = self
    local blocker = window._tabTransitionBlocker
    local function settle()
        if not self._page.Parent then
            for _, tab in ipairs(window._tabs) do
                tab._page.Visible = false
            end
            if blocker then
                blocker.Visible = false
            end
            return
        end
        for _, tab in ipairs(window._tabs) do
            window:_cancelTweenTree(tab._page)
            if tab._transitionVisuals then
                window:_setVisualTransparency(tab._transitionVisuals, "restore")
            end
            tab._page.Position = tab._pageOrigin
            tab._page.Visible = tab == self
            tab.Selected = tab == self
        end
        if blocker then
            blocker.Visible = false
        end
    end
    if noAnimation then
        self._page.Visible = true
        window:_setVisualTransparency(self._transitionVisuals, "restore")
        if blocker then
            blocker.Visible = false
        end
        return self
    end
    local duration = math.max(0, tonumber(Surge.Animation.Tab) or 0.14)
    local fadeOut = duration * 0.45
    local fadeIn = duration * 0.55
    if not outgoing then
        blocker.Visible = true
        self._page.Visible = true
        window:_setVisualTransparency(self._transitionVisuals, 1)
        window:_animateVisualTransparency(self._transitionVisuals, "restore", fadeIn, Surge.Animation.EaseOut)
        task.delay(fadeIn + 0.02, function()
            if window._tabTransitionToken == token and not window.unloaded then
                settle()
            end
        end)
        return self
    end
    blocker.Visible = true
    outgoing._page.Visible = true
    window:_animateVisualTransparency(outgoing._transitionVisuals, 1, fadeOut, Surge.Animation.EaseIn)
    task.delay(fadeOut + 0.01, function()
        if window.unloaded or window._tabTransitionToken ~= token then
            return
        end
        outgoing._page.Visible = false
        outgoing._page.Position = outgoing._pageOrigin
        window:_setVisualTransparency(outgoing._transitionVisuals, "restore")
        self._page.Visible = true
        self._page.Position = shifted(self._pageOrigin, direction * 16)
        window:_setVisualTransparency(self._transitionVisuals, 1)
        window:_animateVisualTransparency(self._transitionVisuals, "restore", fadeIn, Surge.Animation.EaseOut)
        window:_tween(self._page, {
            Position = self._pageOrigin,
        }, fadeIn, Surge.Animation.EasingStyle, Surge.Animation.EaseOut)
        task.delay(fadeIn + 0.02, function()
            if window._tabTransitionToken == token and not window.unloaded then
                settle()
            end
        end)
    end)
    return self
end

function Tab:Deselect(noAnimation)
    local window = self.Window
    window._tabTransitionToken = (window._tabTransitionToken or 0) + 1
    window:_cancelTweenTree(self._page)
    if self._transitionVisuals then
        window:_setVisualTransparency(self._transitionVisuals, "restore")
    end
    if window._tabTransitionBlocker then
        window._tabTransitionBlocker.Visible = false
    end
    self.Selected = false
    self._page.Visible = false
    self._activeBar.BackgroundTransparency = 1
    self._button.BackgroundTransparency = 1
    self._label.TextColor3 = window.Theme.TextMuted
    return self
end

function Tab:Remove()
    local window = self.Window
    window._tabTransitionToken = (window._tabTransitionToken or 0) + 1
    if window._tabTransitionBlocker then
        window._tabTransitionBlocker.Visible = false
    end
    if self._transitionVisuals then
        window:_setVisualTransparency(self._transitionVisuals, "restore")
    end
    if window._activeTab == self then
        window._activeTab = nil
    end
    if self._button then
        self._button:Destroy()
    end
    if self._page then
        window:_cancelTweenTree(self._page)
        self._page:Destroy()
    end
    for index, tab in ipairs(window._tabs) do
        if tab == self then
            table.remove(window._tabs, index)
            break
        end
    end
    local first = window._tabs[1]
    if first then
        first:Select(true)
    end
end

function Tab:_host(host)
    if host then
        return host
    end
    if not self._defaultHost then
        self._defaultHost = {
            _container = self._page,
            _widthScale = 1,
            _widthOffset = 0,
            _order = 0,
        }
    end
    return self._defaultHost
end
function Tab:CreateGroup(properties, host)
    properties = properties or {}
    local direction = string.lower(asString(opt(properties, "row", "direction", "Direction")))
    local isRow = direction == "row" or direction == "horizontal"
    local parent = (host and host._container) or self._page
    local width = host and UDim2.new(host._widthScale or 1, host._widthOffset or 0, 0, 0) or UDim2.new(1, 0, 0, 0)
    local groupFrame = instance("Frame", {
        Name = "Group",
        Size = width,
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = host and host._order or nextLayoutOrder(parent),
        ZIndex = 6,
    }, parent)
    if host then
        host._order = host._order + 1
    else
        self._order = self._order + 1
    end
    listLayout(groupFrame, 8, isRow and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical)
    local group = setmetatable({
        Tab = self,
        _container = groupFrame,
        _widthScale = isRow and 0.5 or 1,
        _widthOffset = isRow and -4 or 0,
        _order = 0,
    }, Group)
    return group
end

function Group:CreateButton(properties)
    return self.Tab:CreateButton(properties, self)
end
function Group:CreateToggle(properties)
    return self.Tab:CreateToggle(properties, self)
end
function Group:CreateSlider(properties)
    return self.Tab:CreateSlider(properties, self)
end
function Group:CreateDropdown(properties)
    return self.Tab:CreateDropdown(properties, self)
end
function Group:CreateStat(properties)
    return self.Tab:CreateStat(properties, self)
end
function Group:CreateText(properties)
    return self.Tab:CreateText(properties, self)
end
function Group:CreateSection(properties)
    return self.Tab:CreateSection(properties, self)
end
function Group:CreateGroup(properties)
    return self.Tab:CreateGroup(properties, self)
end

function Tab:CreateSection(properties, host)
    properties = type(properties) == "string" and { name = properties } or (properties or {})
    host = self:_host(host)
    local name = asString(opt(properties, "Section", "name", "Name"), "Section")
    local row = self.Window:_newRow(host, 28, "Section")
    local rowStroke = row:FindFirstChildOfClass("UIStroke")
    if rowStroke then
        rowStroke:Destroy()
    end
    row.BackgroundTransparency = 1
    local line = instance("Frame", {
        Position = UDim2.new(0, 0, 1, -1),
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = self.Window.Theme.Border,
        BorderSizePixel = 0,
        ZIndex = 8,
    }, row)
    self.Window:_bind(line, "BackgroundColor3", "Border")
    local iconName = opt(properties, nil, "icon", "Icon")
    if iconName then
        local icon = self.Window:_makeIcon(row, iconName, 13, "Icon")
        if icon then
            icon.Position = UDim2.fromOffset(0, 7)
        end
    end
    local sectionLabel = textLabel(self.Window, row, {
        Position = UDim2.fromOffset(iconName and 20 or 1, 2),
        Size = UDim2.new(1, -(iconName and 20 or 1), 0, 18),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamSemibold,
        Text = string.upper(name),
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        ZIndex = 8,
    }, "TextFaint")
    local handle = {
        Name = name,
        Set = function(_, value)
            name = asString(value, name)
            sectionLabel.Text = string.upper(name)
        end,
        Remove = function()
            row:Destroy()
        end,
    }
    self.Window:_attachElementHandle(handle, row)
    return handle
end
function Tab:CreateDivider(properties, host)
    properties = properties or {}
    host = self:_host(host)
    local text = asString(opt(properties, "", "text", "Text"), "")
    local spacing = math.max(8, tonumber(opt(properties, 12, "spacing", "Spacing")) or 12)
    local showLine = opt(properties, true, "line", "Line") ~= false
    local row = self.Window:_newRow(host, spacing, "Divider")
    local rowStroke = row:FindFirstChildOfClass("UIStroke")
    if rowStroke then
        rowStroke:Destroy()
    end
    row.BackgroundTransparency = 1
    local parts = {}
    local function clearParts()
        for _, part in ipairs(parts) do
            if part and part.Parent then
                part:Destroy()
            end
        end
        parts = {}
    end
    local function render()
        clearParts()
        if showLine and text == "" then
            local line = instance("Frame", {
                Position = UDim2.new(0, 0, 0.5, 0),
                Size = UDim2.new(1, 0, 0, 1),
                BackgroundColor3 = self.Window.Theme.Border,
                BorderSizePixel = 0,
                ZIndex = 8,
            }, row)
            self.Window:_bind(line, "BackgroundColor3", "Border")
            table.insert(parts, line)
        elseif text ~= "" then
            local labelWidth = math.max(36, #text * 7 + 12)
            local left = instance("Frame", {
                Position = UDim2.new(0, 0, 0.5, 0),
                Size = UDim2.new(0.5, -(labelWidth / 2 + 8), 0, 1),
                BackgroundColor3 = self.Window.Theme.Border,
                BorderSizePixel = 0,
                ZIndex = 8,
            }, row)
            local right = instance("Frame", {
                Position = UDim2.new(0.5, labelWidth / 2 + 8, 0.5, 0),
                Size = UDim2.new(0.5, -(labelWidth / 2 + 8), 0, 1),
                BackgroundColor3 = self.Window.Theme.Border,
                BorderSizePixel = 0,
                ZIndex = 8,
            }, row)
            self.Window:_bind(left, "BackgroundColor3", "Border")
            self.Window:_bind(right, "BackgroundColor3", "Border")
            local label = textLabel(self.Window, row, {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0.5, 0, 0.5, 0),
                Size = UDim2.fromOffset(labelWidth, spacing),
                BackgroundTransparency = 1,
                Font = Enum.Font.GothamSemibold,
                Text = text,
                TextSize = 9,
                TextXAlignment = Enum.TextXAlignment.Center,
                TextYAlignment = Enum.TextYAlignment.Center,
                ZIndex = 9,
            }, "TextFaint")
            table.insert(parts, left)
            table.insert(parts, right)
            table.insert(parts, label)
        end
    end
    render()
    local handle = {
        text = text,
        Set = function(selfHandle, value)
            if type(value) == "boolean" then
                row.Visible = value
            else
                selfHandle.text = asString(value, "")
                text = selfHandle.text
                render()
            end
        end,
        Remove = function()
            row:Destroy()
        end,
    }
    self.Window:_attachElementHandle(handle, row)
    return handle
end


function Tab:CreateText(properties, host)
    properties = properties or {}
    host = self:_host(host)
    local titleText = asString(opt(properties, "", "name", "Name"), "")
    local bodyText = asString(opt(properties, "", "text", "Text", "description", "Description"), "")
    local height = bodyText ~= "" and 72 or 44
    local row = self.Window:_newRow(host, height, "Text")
    row.BackgroundTransparency = self.Window.Theme.SurfaceTransparency
    local iconName = opt(properties, nil, "icon", "Icon")
    local left = instance("Frame", {
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(1, -24, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 8,
    }, row)
    local iconOffset = 0
    if iconName then
        local icon = self.Window:_makeIcon(left, iconName, 16, "Icon")
        if icon then
            icon.Position = UDim2.fromOffset(0, 14)
            iconOffset = 24
        end
    end
    local title = textLabel(self.Window, left, {
        Position = UDim2.fromOffset(iconOffset, bodyText ~= "" and 9 or 12),
        Size = UDim2.new(1, -iconOffset, 0, 20),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamSemibold,
        Text = titleText,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        Visible = titleText ~= "",
        ZIndex = 9,
    }, "Text")
    local body = textLabel(self.Window, left, {
        Position = UDim2.fromOffset(iconOffset, titleText ~= "" and 31 or 12),
        Size = UDim2.new(1, -iconOffset, 0, bodyText ~= "" and 30 or 20),
        BackgroundTransparency = 1,
        Font = Enum.Font.Gotham,
        Text = bodyText,
        TextSize = 11,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Visible = bodyText ~= "",
        ZIndex = 9,
    }, "TextMuted")
    local handle = {
        name = titleText,
        text = bodyText,
    }
    local function resize()
        local hasTitle = handle.name ~= ""
        local hasBody = handle.text ~= ""
        if hasBody then
            row.AutomaticSize = Enum.AutomaticSize.Y
            left.AutomaticSize = Enum.AutomaticSize.Y
            left.Size = UDim2.new(1, -24, 0, 0)
            body.AutomaticSize = Enum.AutomaticSize.Y
            body.Size = UDim2.new(1, -iconOffset, 0, 0)
        else
            row.AutomaticSize = Enum.AutomaticSize.None
            left.AutomaticSize = Enum.AutomaticSize.None
            left.Size = UDim2.new(1, -24, 1, 0)
            body.AutomaticSize = Enum.AutomaticSize.None
            body.Size = UDim2.new(1, -iconOffset, 0, 20)
            row.Size = UDim2.new(row.Size.X.Scale, row.Size.X.Offset, 0, 44)
        end
        title.Position = UDim2.fromOffset(iconOffset, hasBody and 9 or 12)
        title.Visible = hasTitle
        body.Position = UDim2.fromOffset(iconOffset, hasTitle and 31 or 12)
        body.Visible = hasBody
    end
    function handle:SetTitle(value)
        handle.name = asString(value, "")
        title.Text = handle.name
        resize()
    end
    function handle:Set(value)
        handle.text = asString(value, "")
        body.Text = handle.text
        resize()
    end
    function handle:Remove()
        row:Destroy()
    end
    resize()
    self.Window:_attachElementHandle(handle, row)
    return handle
end

Tab.CreateLabel = Tab.CreateText
Tab.CreateParagraph = Tab.CreateText

function Tab:CreateButton(properties, host)
    properties = properties or {}
    host = self:_host(host)
    local window = self.Window
    local label = asString(opt(properties, "Button", "name", "Name"), "Button")
    local row = self.Window:_newRow(host, opt(properties, 52, "height", "Height"), "Button")
    local _, title, detail = self.Window:_newLabelBlock(row, properties, opt(properties, nil, "icon", "Icon"), 22)
    local click = controlButton(row, "ButtonHitbox", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        ZIndex = 10,
    })
    local hovered = false
    local pressToken = 0
    local handle = {
        name = label,
        Set = function(selfHandle, value)
            selfHandle.name = asString(value, label)
            title.Text = selfHandle.name
        end,
        Fire = function()
            window:_safeCallback(opt(properties, nil, "callback", "Callback"))
        end,
        Remove = function()
            window:_cancelTween(row)
            row:Destroy()
        end,
    }
    function handle:Lock(reason)
        handle._locked = true
        click.Active = false
        detail.Text = asString(reason, detail.Text)
    end
    function handle:Unlock()
        handle._locked = false
        click.Active = true
        detail.Text = asString(opt(properties, "", "description", "Description"), "")
    end
    function handle:IsLocked()
        return handle._locked == true
    end
    self.Window:_connect(click.MouseEnter, function()
        hovered = true
        self.Window:_tween(row, { BackgroundTransparency = 0.01 }, Surge.Animation.Fast)
    end)
    self.Window:_connect(click.MouseLeave, function()
        hovered = false
        self.Window:_tween(row, { BackgroundTransparency = self.Window.Theme.RaisedTransparency }, Surge.Animation.Fast)
    end)
    self.Window:_connect(click.Activated, function()
        if handle._locked then
            return
        end
        pressToken = pressToken + 1
        local token = pressToken
        self.Window:_tween(row, { BackgroundTransparency = 0.18 }, Surge.Animation.Press, Surge.Animation.EasingStyle, Surge.Animation.EaseOut)
        task.delay(0.07, function()
            if row.Parent and not self.Window.unloaded and token == pressToken then
                self.Window:_tween(row, {
                    BackgroundTransparency = hovered and 0.01 or self.Window.Theme.RaisedTransparency,
                }, Surge.Animation.Fast, Surge.Animation.EasingStyle, Surge.Animation.EaseOut)
            end
        end)
        handle:Fire()
    end)
    self.Window:_attachElementHandle(handle, row)
    return handle
end

function Tab:CreateToggle(properties, host)
    properties = properties or {}
    host = self:_host(host)
    local window = self.Window
    local value = opt(properties, false, "value", "Value", "CurrentValue") == true
    local flag = opt(properties, nil, "flag", "Flag")
    local row = self.Window:_newRow(host, 56, "Toggle")
    local _, title, detail = self.Window:_newLabelBlock(row, properties, opt(properties, nil, "icon", "Icon"), 60)
    local hitbox = controlButton(row, "ToggleHitbox", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        ZIndex = 9,
    })
    local track = instance("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.fromOffset(38, 20),
        BackgroundColor3 = self.Window.Theme.ToggleOff,
        BorderSizePixel = 0,
        ZIndex = 11,
    }, row)
    corner(track, 10)
    local knob = instance("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 3, 0.5, 0),
        Size = UDim2.fromOffset(14, 14),
        BackgroundColor3 = self.Window.Theme.TextMuted,
        BorderSizePixel = 0,
        ZIndex = 12,
    }, track)
    corner(knob, 7)
    local handle = { value = value, name = asString(opt(properties, "Toggle", "name", "Name"), "Toggle") }
    local function updateVisual()
        local active = handle.value
        track.BackgroundColor3 = active and self.Window.Theme.Accent or self.Window.Theme.ToggleOff
        knob.BackgroundColor3 = active and self.Window.Theme.AccentContrast or self.Window.Theme.TextMuted
        local position = active and UDim2.new(1, -17, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
        self.Window:_tween(knob, { Position = position }, Surge.Animation.Toggle)
    end
    self.Window:_refresh(updateVisual)
    function handle:Set(nextValue, skipCallback)
        handle.value = nextValue == true
        updateVisual()
        window:_valueChanged(handle, handle.value)
        if not skipCallback then
            window:_safeCallback(opt(properties, nil, "callback", "Callback"), handle.value)
        end
    end
    function handle:Lock(reason)
        handle._locked = true
        hitbox.Active = false
        detail.Text = asString(reason, detail.Text)
    end
    function handle:Unlock()
        handle._locked = false
        hitbox.Active = true
        detail.Text = asString(opt(properties, "", "description", "Description"), "")
    end
    function handle:IsLocked()
        return handle._locked == true
    end
    function handle:Remove()
        row:Destroy()
    end
    handle._configType = "boolean"
    self.Window:_registerValue(handle, opt(properties, nil, "flag", "Flag"))
    self.Window:_connect(hitbox.Activated, function()
        if not handle._locked then
            handle:Set(not handle.value)
        end
    end)
    updateVisual()
    self.Window:_attachElementHandle(handle, row)
    return handle
end

function Tab:CreateSlider(properties, host)
    properties = properties or {}
    host = self:_host(host)
    local window = self.Window
    local range = opt(properties, { 0, 100 }, "range", "Range")
    local minimum = tonumber(range[1]) or 0
    local maximum = tonumber(range[2]) or 100
    if maximum < minimum then
        minimum, maximum = maximum, minimum
    end
    local increment = math.abs(tonumber(opt(properties, 1, "increment", "Increment")) or 1)
    local value = tonumber(opt(properties, minimum, "value", "Value", "CurrentValue")) or minimum
    value = clamp(value, minimum, maximum)
    local suffix = asString(opt(properties, "", "suffix", "Suffix"), "")
    local row = self.Window:_newRow(host, 78, "Slider")
    local _, title, detail = self.Window:_newLabelBlock(row, properties, opt(properties, nil, "icon", "Icon"), 90)
    local valueLabel = textLabel(self.Window, row, {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -14, 0, 10),
        Size = UDim2.fromOffset(78, 18),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamSemibold,
        Text = formatNumber(value) .. suffix,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextYAlignment = Enum.TextYAlignment.Center,
        ZIndex = 9,
    }, "Text")
    local track = instance("Frame", {
        Position = UDim2.fromOffset(14, 51),
        Size = UDim2.new(1, -28, 0, 5),
        BackgroundColor3 = self.Window.Theme.ProgressTrack,
        BorderSizePixel = 0,
        ZIndex = 9,
    }, row)
    corner(track, 3)
    self.Window:_bind(track, "BackgroundColor3", "ProgressTrack")
    local fill = instance("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = self.Window.Theme.Accent,
        BorderSizePixel = 0,
        ZIndex = 10,
    }, track)
    corner(fill, 3)
    self.Window:_bind(fill, "BackgroundColor3", "Accent")
    local hitbox = controlButton(row, "SliderHitbox", {
        Position = UDim2.fromOffset(10, 40),
        Size = UDim2.new(1, -20, 0, 24),
        BackgroundTransparency = 1,
        ZIndex = 11,
    })
    local handle = { value = value, name = asString(opt(properties, "Slider", "name", "Name"), "Slider") }
    local dragging = false
    local function snap(nextValue)
        local steps = math.floor(((nextValue - minimum) / increment) + 0.5)
        return clamp(minimum + steps * increment, minimum, maximum)
    end
    local function render(animate)
        local ratio = maximum == minimum and 0 or (handle.value - minimum) / (maximum - minimum)
        local targetSize = UDim2.new(clamp(ratio, 0, 1), 0, 1, 0)
        if animate then
            window:_tween(fill, { Size = targetSize }, Surge.Animation.Fast, Surge.Animation.EasingStyle, Surge.Animation.EaseOut)
        else
            window:_cancelTween(fill)
            fill.Size = targetSize
        end
        valueLabel.Text = formatNumber(handle.value) .. suffix
    end
    self.Window:_refresh(render)
    function handle:Set(nextValue, skipCallback)
        local number = tonumber(nextValue)
        if not number then
            return
        end
        handle.value = snap(number)
        render(not dragging)
        window:_valueChanged(handle, handle.value)
        if not skipCallback then
            window:_safeCallback(opt(properties, nil, "callback", "Callback"), handle.value, false)
        end
    end
    function handle:Lock(reason)
        handle._locked = true
        hitbox.Active = false
        detail.Text = asString(reason, detail.Text)
    end
    function handle:Unlock()
        handle._locked = false
        hitbox.Active = true
        detail.Text = asString(opt(properties, "", "description", "Description"), "")
    end
    function handle:IsLocked()
        return handle._locked == true
    end
    function handle:Remove()
        window:_cancelTween(fill)
        row:Destroy()
    end
    handle._configType = "number"
    handle._configRange = { min = minimum, max = maximum, increment = increment }
    self.Window:_registerValue(handle, opt(properties, nil, "flag", "Flag"))
    local function setFromInput(input, isDragging, animate)
        if self.Window._activeTab ~= self or (self.Window._tabTransitionBlocker and self.Window._tabTransitionBlocker.Visible) then
            return
        end
        if handle._locked or not input or track.AbsoluteSize.X <= 0 then
            return
        end
        local ratio = clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        local nextValue = snap(minimum + (maximum - minimum) * ratio)
        handle.value = nextValue
        render(animate == true)
        self.Window:_valueChanged(handle, handle.value)
        self.Window:_safeCallback(opt(properties, nil, "callback", "Callback"), handle.value, isDragging)
    end
    self.Window:_connect(hitbox.InputBegan, function(input)
        if self.Window._activeTab == self and not (self.Window._tabTransitionBlocker and self.Window._tabTransitionBlocker.Visible)
            and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            dragging = true
            setFromInput(input, true, true)
        end
    end)
    self.Window:_connect(UserInputService.InputChanged, function(input)
        if dragging and self.Window._activeTab == self and not (self.Window._tabTransitionBlocker and self.Window._tabTransitionBlocker.Visible)
            and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            setFromInput(input, true, false)
        elseif dragging and (self.Window._activeTab ~= self or (self.Window._tabTransitionBlocker and self.Window._tabTransitionBlocker.Visible)) then
            dragging = false
        end
    end)
    self.Window:_connect(UserInputService.InputEnded, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            dragging = false
            if self.Window._activeTab == self and not (self.Window._tabTransitionBlocker and self.Window._tabTransitionBlocker.Visible) then
                self.Window:_safeCallback(opt(properties, nil, "callback", "Callback"), handle.value, false)
            end
        end
    end)
    render(false)
    self.Window:_attachElementHandle(handle, row)
    return handle
end

function Tab:CreateDropdown(properties, host)
    properties = properties or {}
    host = self:_host(host)
    local options = copyTable(opt(properties, {}, "options", "Options"))
    local multiple = opt(properties, false, "multiSelect", "MultipleOptions") == true
    local current = opt(properties, nil, "value", "Value", "CurrentOption")
    local selected = {}
    local function addSelected(value)
        if value == nil then
            return
        end
        if type(value) == "table" then
            for _, item in ipairs(value) do
                addSelected(item)
            end
        else
            if multiple then
                for _, item in ipairs(selected) do
                    if item == value then
                        return
                    end
                end
                table.insert(selected, value)
            elseif #selected == 0 then
                table.insert(selected, value)
            end
        end
    end
    addSelected(current)
    local row = self.Window:_newRow(host, 72, "Dropdown")
    local _, title, detail = self.Window:_newLabelBlock(row, properties, opt(properties, nil, "icon", "Icon"), 200)
    local field = controlButton(row, "DropdownField", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.fromOffset(182, 32),
        BackgroundColor3 = self.Window.Theme.SurfaceInput,
        BackgroundTransparency = self.Window.Theme.InputTransparency,
        ZIndex = 11,
    })
    corner(field, 8)
    stroke(field, self.Window.Theme.Border, 0.18, 1)
    self.Window:_bind(field, "BackgroundColor3", "SurfaceInput")
    local fieldLabel = textLabel(self.Window, field, {
        Position = UDim2.fromOffset(11, 0),
        Size = UDim2.new(1, -34, 1, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 12,
    }, "TextMuted")
    local chevron = self.Window:_makeIcon(field, "ChevronDown", 14, "Icon")
    if chevron then
        chevron.AnchorPoint = Vector2.new(1, 0.5)
        chevron.Position = UDim2.new(1, -10, 0.5, 0)
    end
    local handle = { value = selected, name = asString(opt(properties, "Dropdown", "name", "Name"), "Dropdown") }
    local menu
    local function displayValue()
        if #selected == 0 then
            return asString(opt(properties, "None", "placeholder", "Placeholder"), "None")
        end
        local values = {}
        for _, item in ipairs(selected) do
            table.insert(values, tostring(item))
        end
        return table.concat(values, ", ")
    end
    local function refreshLabel()
        fieldLabel.Text = displayValue()
        fieldLabel.TextColor3 = #selected == 0 and self.Window.Theme.TextMuted or self.Window.Theme.Text
    end
    local function contains(item)
        for _, selectedItem in ipairs(selected) do
            if selectedItem == item then
                return true
            end
        end
        return false
    end
    local function emit(skipCallback)
        handle.value = copyTable(selected)
        self.Window:_valueChanged(handle, handle.value)
        if not skipCallback then
            local callbackValue = multiple and copyTable(selected) or selected[1]
            self.Window:_safeCallback(opt(properties, nil, "callback", "Callback"), callbackValue)
        end
    end
    local function closeMenu()
        if menu then
            menu:Destroy()
            menu = nil
        end
        self.Window:_closeDropdownMenu()
    end
    local toggleItem
    local function renderMenuOptions()
        if not menu or not menu.Parent then
            return
        end
        for _, child in ipairs(menu:GetChildren()) do
            if child:IsA("GuiButton") then
                child:Destroy()
            end
        end
        for _, item in ipairs(options) do
            local selectedItem = contains(item)
            local itemButton = controlButton(menu, "Option_" .. safeName(item), {
                Size = UDim2.new(1, 0, 0, 28),
                BackgroundColor3 = selectedItem and self.Window.Theme.SurfaceInput or self.Window.Theme.SurfaceRaised,
                BackgroundTransparency = selectedItem and 0 or 1,
                ZIndex = 62,
            })
            corner(itemButton, 6)
            local itemLabel = textLabel(self.Window, itemButton, {
                Position = UDim2.fromOffset(9, 0),
                Size = UDim2.new(1, -28, 1, 0),
                BackgroundTransparency = 1,
                Font = Enum.Font.Gotham,
                Text = tostring(item),
                TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Center,
                ZIndex = 63,
            }, selectedItem and "Text" or "TextMuted")
            if selectedItem then
                local check = self.Window:_makeIcon(itemButton, "Check", 13, "Accent")
                if check then
                    check.AnchorPoint = Vector2.new(1, 0.5)
                    check.Position = UDim2.new(1, -8, 0.5, 0)
                end
            end
            self.Window:_connect(itemButton.Activated, function()
                toggleItem(item)
            end)
        end
    end
    toggleItem = function(item)
        if multiple then
            if contains(item) then
                for index, selectedItem in ipairs(selected) do
                    if selectedItem == item then
                        table.remove(selected, index)
                        break
                    end
                end
            else
                table.insert(selected, item)
            end
        else
            selected = { item }
        end
        refreshLabel()
        if multiple and menu then
            renderMenuOptions()
        end
        emit(false)
        if not multiple then
            closeMenu()
        end
    end
    local function openMenu()
        closeMenu()
        local absolutePosition = field.AbsolutePosition
        local absoluteSize = field.AbsoluteSize
        local menuHeight = math.min(210, math.max(42, #options * 34 + 10))
        local y = absolutePosition.Y + absoluteSize.Y + 4
        local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
        if y + menuHeight > viewport.Y - 8 then
            y = absolutePosition.Y - menuHeight - 4
        end
        self.Window._dropdownDismiss = controlButton(self.Window.Gui, "DropdownDismiss", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            ZIndex = 60,
        })
        self.Window:_connect(self.Window._dropdownDismiss.Activated, closeMenu)
        menu = instance("ScrollingFrame", {
            Name = "DropdownMenu",
            Position = UDim2.fromOffset(absolutePosition.X, y),
            Size = UDim2.fromOffset(math.max(absoluteSize.X, 182), menuHeight),
            BackgroundColor3 = self.Window.Theme.SurfaceRaised,
            BackgroundTransparency = self.Window.Theme.RaisedTransparency,
            BorderSizePixel = 0,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 3,
            ZIndex = 61,
        }, self.Window.Gui)
        self.Window._dropdownMenu = menu
        corner(menu, 9)
        stroke(menu, self.Window.Theme.BorderStrong, 0.05, 1)
        self.Window:_bind(menu, "BackgroundColor3", "SurfaceRaised")
        listLayout(menu, 4)
        padding(menu, 5, 5, 5, 5)
        renderMenuOptions()
    end
    function handle:Set(value, skipCallback)
        selected = {}
        addSelected(value)
        refreshLabel()
        if menu then
            renderMenuOptions()
        end
        emit(skipCallback)
    end
    function handle:Refresh(nextOptions)
        options = copyTable(nextOptions or {})
        local valid = {}
        for _, selectedItem in ipairs(selected) do
            for _, optionItem in ipairs(options) do
                if selectedItem == optionItem then
                    table.insert(valid, selectedItem)
                    break
                end
            end
        end
        selected = valid
        refreshLabel()
        if menu then
            renderMenuOptions()
        end
        emit(false)
    end
    function handle:Add(item)
        for _, optionItem in ipairs(options) do
            if optionItem == item then
                return
            end
        end
        table.insert(options, item)
        if menu then
            renderMenuOptions()
        end
    end
    function handle:Remove(item)
        if item == nil then
            closeMenu()
            row:Destroy()
            return
        end
        local removed = false
        for index, optionItem in ipairs(options) do
            if optionItem == item then
                table.remove(options, index)
                removed = true
                break
            end
        end
        if removed then
            local wasSelected = contains(item)
            if wasSelected then
                for index, selectedItem in ipairs(selected) do
                    if selectedItem == item then
                        table.remove(selected, index)
                        break
                    end
                end
                refreshLabel()
            end
            if menu then
                renderMenuOptions()
            end
            if wasSelected then
                emit(false)
            end
        end
    end
    function handle:Lock(reason)
        handle._locked = true
        closeMenu()
        field.Active = false
        detail.Text = asString(reason, detail.Text)
    end
    function handle:Unlock()
        handle._locked = false
        field.Active = true
        detail.Text = asString(opt(properties, "", "description", "Description"), "")
    end
    function handle:IsLocked()
        return handle._locked == true
    end
    handle._configType = "dropdown"
    handle._configOptions = options
    handle._configMultiple = multiple
    self.Window:_registerValue(handle, opt(properties, nil, "flag", "Flag"))
    self.Window:_connect(field.Activated, function()
        if not handle._locked then
            if menu and not menu.Parent then
                menu = nil
            end
            if menu then
                closeMenu()
            else
                openMenu()
            end
        end
    end)
    self.Window:_refresh(refreshLabel)
    refreshLabel()
    self.Window:_attachElementHandle(handle, row)
    return handle
end

function Tab:CreateInput(properties, host)
    properties = properties or {}
    host = self:_host(host)
    local value = asString(opt(properties, "", "value", "Value", "CurrentValue"), "")
    local window = self.Window
    local row = self.Window:_newRow(host, 66, "Input")
    local _, title, detail = self.Window:_newLabelBlock(row, properties, opt(properties, nil, "icon", "Icon"), 206)
    local field = instance("TextBox", {
        Name = "InputField",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.fromOffset(190, 32),
        BackgroundColor3 = self.Window.Theme.SurfaceInput,
        BackgroundTransparency = self.Window.Theme.InputTransparency,
        BorderSizePixel = 0,
        ClearTextOnFocus = opt(properties, false, "clearOnFocus", "ClearOnFocus") == true,
        Font = Enum.Font.Gotham,
        PlaceholderText = asString(opt(properties, "", "placeholder", "Placeholder", "PlaceholderText"), ""),
        Text = value,
        TextColor3 = self.Window.Theme.Text,
        PlaceholderColor3 = self.Window.Theme.TextMuted,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        ZIndex = 11,
    }, row)
    corner(field, 8)
    stroke(field, self.Window.Theme.Border, 0.18, 1)
    padding(field, 10, 0, 10, 0)
    self.Window:_bind(field, "BackgroundColor3", "SurfaceInput")
    self.Window:_bind(field, "TextColor3", "Text")
    self.Window:_bind(field, "PlaceholderColor3", "TextMuted")
    local numeric = opt(properties, false, "numeric", "Numeric") == true
    local handle = { value = value, name = asString(opt(properties, "Input", "name", "Name"), "Input") }
    local function commit()
        local nextValue = field.Text
        if numeric and tonumber(nextValue) == nil then
            field.Text = handle.value
            return
        end
        handle.value = nextValue
        self.Window:_valueChanged(handle, handle.value)
        self.Window:_safeCallback(opt(properties, nil, "callback", "Callback"), handle.value)
        if opt(properties, false, "removeTextAfterFocusLost", "RemoveTextAfterFocusLost") == true then
            field.Text = ""
        end
    end
    function handle:Set(nextValue, skipCallback)
        handle.value = asString(nextValue, "")
        field.Text = handle.value
        window:_valueChanged(handle, handle.value)
        if not skipCallback then
            window:_safeCallback(opt(properties, nil, "callback", "Callback"), handle.value)
        end
    end
    function handle:Lock(reason)
        handle._locked = true
        field.TextEditable = false
        detail.Text = asString(reason, detail.Text)
    end
    function handle:Unlock()
        handle._locked = false
        field.TextEditable = true
        detail.Text = asString(opt(properties, "", "description", "Description"), "")
    end
    function handle:IsLocked()
        return handle._locked == true
    end
    function handle:Remove()
        row:Destroy()
    end
    handle._configType = "string"
    handle._configNumeric = numeric
    self.Window:_registerValue(handle, opt(properties, nil, "flag", "Flag"))
    self.Window:_connect(field.FocusLost, function()
        if not handle._locked then
            commit()
        end
    end)
    self.Window:_attachElementHandle(handle, row)
    return handle
end

function Tab:CreateKeybind(properties, host)
    properties = properties or {}
    host = self:_host(host)
    local value = enumKey(opt(properties, nil, "value", "Value", "CurrentKeybind"))
    local row = self.Window:_newRow(host, 60, "Keybind")
    local _, title, detail = self.Window:_newLabelBlock(row, properties, opt(properties, nil, "icon", "Icon"), 156)
    local field = controlButton(row, "KeybindField", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.fromOffset(140, 32),
        BackgroundColor3 = self.Window.Theme.SurfaceInput,
        BackgroundTransparency = self.Window.Theme.InputTransparency,
        ZIndex = 11,
    })
    corner(field, 8)
    stroke(field, self.Window.Theme.Border, 0.18, 1)
    self.Window:_bind(field, "BackgroundColor3", "SurfaceInput")
    local fieldLabel = textLabel(self.Window, field, {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamSemibold,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        ZIndex = 12,
    }, "Text")
    local hold = opt(properties, false, "hold", "Hold") == true
    local threshold = tonumber(opt(properties, 0.2, "holdThreshold", "HoldThreshold")) or 0.2
    local capturing = false
    local held = false
    local handle = { value = value, name = asString(opt(properties, "Keybind", "name", "Name"), "Keybind") }
    local function render()
        fieldLabel.Text = capturing and "Press a key" or keyName(handle.value)
    end
    local function changed(nextValue, skipCallback)
        handle.value = enumKey(nextValue)
        render()
        self.Window:_valueChanged(handle, handle.value)
        if not skipCallback then
            self.Window:_safeCallback(opt(properties, nil, "onChanged", "OnChanged"), handle.value)
        end
    end
    function handle:Set(nextValue, skipChanged)
        changed(nextValue, skipChanged)
    end
    function handle:Lock(reason)
        handle._locked = true
        field.Active = false
        detail.Text = asString(reason, detail.Text)
    end
    function handle:Unlock()
        handle._locked = false
        field.Active = true
        detail.Text = asString(opt(properties, "", "description", "Description"), "")
    end
    function handle:IsLocked()
        return handle._locked == true
    end
    function handle:Remove()
        row:Destroy()
    end
    handle._configType = "keybind"
    self.Window:_registerValue(handle, opt(properties, nil, "flag", "Flag"))
    self.Window:_connect(field.Activated, function()
        if not handle._locked and self.Window._activeTab == self
            and not (self.Window._tabTransitionBlocker and self.Window._tabTransitionBlocker.Visible) then
            capturing = true
            render()
        end
    end)
    self.Window:_connect(UserInputService.InputBegan, function(input, gameProcessed)
        local blocked = self.Window._tabTransitionBlocker and self.Window._tabTransitionBlocker.Visible
        if gameProcessed or handle._locked or self.Window._activeTab ~= self or blocked then
            if capturing then
                capturing = false
                render()
            end
            return
        end
        local key = input.KeyCode ~= Enum.KeyCode.Unknown and input.KeyCode or input.UserInputType
        if capturing then
            if input.KeyCode == Enum.KeyCode.Escape then
                capturing = false
                render()
                return
            end
            if input.KeyCode == Enum.KeyCode.Backspace then
                capturing = false
                changed(nil, false)
                return
            end
            if input.UserInputType == Enum.UserInputType.Keyboard or input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseButton2 then
                capturing = false
                changed(key, false)
                return
            end
        end
        if handle.value and (input.KeyCode == handle.value or input.UserInputType == handle.value) then
            if hold then
                held = true
                task.delay(threshold, function()
                    if held and not self.Window.unloaded and self.Window._activeTab == self
                        and not (self.Window._tabTransitionBlocker and self.Window._tabTransitionBlocker.Visible) then
                        self.Window:_safeCallback(opt(properties, nil, "callback", "Callback"), true)
                    end
                end)
            else
                self.Window:_safeCallback(opt(properties, nil, "callback", "Callback"), handle.value)
            end
        end
    end)
    self.Window:_connect(UserInputService.InputEnded, function(input)
        if handle.value and (input.KeyCode == handle.value or input.UserInputType == handle.value) then
            if hold then
                held = false
                if self.Window._activeTab == self and not (self.Window._tabTransitionBlocker and self.Window._tabTransitionBlocker.Visible) then
                    self.Window:_safeCallback(opt(properties, nil, "callback", "Callback"), false)
                end
            end
        end
    end)
    render()
    self.Window:_attachElementHandle(handle, row)
    return handle
end

function Tab:CreateColorPicker(properties, host)
    properties = properties or {}
    host = self:_host(host)
    local value = colorFromValue(opt(properties, Color3.new(1, 1, 1), "color", "Color", "CurrentColor"))
    local alpha = clamp(tonumber(opt(properties, 1, "alpha", "Alpha")) or 1, 0, 1)
    local row = self.Window:_newRow(host, 60, "ColorPicker")
    local _, title, detail = self.Window:_newLabelBlock(row, properties, opt(properties, nil, "icon", "Icon"), 82)
    local swatch = controlButton(row, "ColorSwatch", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.fromOffset(58, 28),
        BackgroundColor3 = value,
        BackgroundTransparency = 1 - alpha,
        ZIndex = 11,
    })
    corner(swatch, 8)
    stroke(swatch, self.Window.Theme.BorderStrong, 0.1, 1)
    local handle = { value = value, alpha = alpha, name = asString(opt(properties, "Color", "name", "Name"), "Color") }
    function handle:GetSaveValue()
        return { color = handle.value, alpha = handle.alpha }
    end
    function handle:SetSaveValue(saved)
        if type(saved) == "table" then
            if saved.color ~= nil then
                handle:Set(saved.color, true)
            end
            if saved.alpha ~= nil then
                handle:SetAlpha(saved.alpha, true)
            end
        end
    end
    function handle:Lock(reason)
        handle._locked = true
        swatch.Active = false
        detail.Text = asString(reason, detail.Text)
    end
    function handle:Unlock()
        handle._locked = false
        swatch.Active = true
        detail.Text = asString(opt(properties, "", "description", "Description"), "")
    end
    function handle:IsLocked()
        return handle._locked == true
    end
    local popup
    local function emit(skipCallback)
        self.Window:_valueChanged(handle, handle.value)
        if not skipCallback then
            self.Window:_safeCallback(opt(properties, nil, "callback", "Callback"), handle.value, handle.alpha)
        end
    end
    local function render()
        swatch.BackgroundColor3 = handle.value
        swatch.BackgroundTransparency = 1 - handle.alpha
    end
    local function closePopup()
        if popup then
            popup:Destroy()
            popup = nil
        end
    end
    local function openPopup()
        closePopup()
        local position = swatch.AbsolutePosition
        popup = instance("Frame", {
            Name = "ColorPickerPopup",
            Position = UDim2.fromOffset(position.X - 126, position.Y + swatch.AbsoluteSize.Y + 6),
            Size = UDim2.fromOffset(170, 128),
            BackgroundColor3 = self.Window.Theme.SurfaceRaised,
            BackgroundTransparency = self.Window.Theme.RaisedTransparency,
            BorderSizePixel = 0,
            ZIndex = 65,
        }, self.Window.Gui)
        corner(popup, 9)
        stroke(popup, self.Window.Theme.BorderStrong, 0.05, 1)
        self.Window:_bind(popup, "BackgroundColor3", "SurfaceRaised")
        local heading = textLabel(self.Window, popup, {
            Position = UDim2.fromOffset(10, 8),
            Size = UDim2.new(1, -20, 0, 16),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamSemibold,
            Text = "Grayscale",
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            ZIndex = 66,
        }, "TextMuted")
        local values = { 0.06, 0.16, 0.28, 0.40, 0.52, 0.66, 0.82, 1 }
        for index, channel in ipairs(values) do
            local swatchButton = controlButton(popup, "Gray_" .. index, {
                Position = UDim2.fromOffset(10 + ((index - 1) % 4) * 36, 31 + math.floor((index - 1) / 4) * 31),
                Size = UDim2.fromOffset(28, 24),
                BackgroundColor3 = Color3.new(channel, channel, channel),
                ZIndex = 67,
            })
            corner(swatchButton, 6)
            stroke(swatchButton, self.Window.Theme.Border, 0.2, 1)
            self.Window:_connect(swatchButton.Activated, function()
                handle.value = Color3.new(channel, channel, channel)
                render()
                emit(false)
                closePopup()
            end)
        end
        local alphaLabel = textLabel(self.Window, popup, {
            Position = UDim2.fromOffset(10, 94),
            Size = UDim2.fromOffset(62, 20),
            BackgroundTransparency = 1,
            Font = Enum.Font.Gotham,
            Text = "Opacity " .. formatNumber(handle.alpha * 100) .. "%",
            TextSize = 9,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            ZIndex = 67,
        }, "TextMuted")
        local alphaTrack = instance("Frame", {
            Position = UDim2.fromOffset(80, 101),
            Size = UDim2.fromOffset(76, 4),
            BackgroundColor3 = self.Window.Theme.ProgressTrack,
            BorderSizePixel = 0,
            ZIndex = 67,
        }, popup)
        corner(alphaTrack, 2)
        self.Window:_bind(alphaTrack, "BackgroundColor3", "ProgressTrack")
        local alphaFill = instance("Frame", {
            Size = UDim2.new(handle.alpha, 0, 1, 0),
            BackgroundColor3 = self.Window.Theme.Accent,
            BorderSizePixel = 0,
            ZIndex = 68,
        }, alphaTrack)
        corner(alphaFill, 2)
        self.Window:_bind(alphaFill, "BackgroundColor3", "Accent")
        local alphaHitbox = controlButton(popup, "AlphaHitbox", {
            Position = UDim2.fromOffset(76, 91),
            Size = UDim2.fromOffset(84, 22),
            BackgroundTransparency = 1,
            ZIndex = 69,
        })
        local function setAlphaFromInput(input)
            local ratio = clamp((input.Position.X - alphaTrack.AbsolutePosition.X) / alphaTrack.AbsoluteSize.X, 0, 1)
            handle.alpha = ratio
            alphaFill.Size = UDim2.new(ratio, 0, 1, 0)
            alphaLabel.Text = "Opacity " .. formatNumber(ratio * 100) .. "%"
            render()
            emit(false)
        end
        self.Window:_connect(alphaHitbox.InputBegan, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                setAlphaFromInput(input)
            end
        end)
    end
    function handle:Set(nextColor, skipCallback)
        handle.value = colorFromValue(nextColor)
        render()
        emit(skipCallback)
    end
    function handle:SetAlpha(nextAlpha, skipCallback)
        handle.alpha = clamp(tonumber(nextAlpha) or 1, 0, 1)
        render()
        emit(skipCallback)
    end
    function handle:Remove()
        closePopup()
        row:Destroy()
    end
    handle._configType = "color"
    handle._configCallback = opt(properties, nil, "callback", "Callback")
    self.Window:_registerValue(handle, opt(properties, nil, "flag", "Flag"))
    self.Window:_connect(swatch.Activated, function()
        if handle._locked then
            return
        end
        if popup then
            closePopup()
        else
            openPopup()
        end
    end)
    self.Window:_refresh(render)
    render()
    self.Window:_attachElementHandle(handle, row)
    return handle
end

function Tab:CreateStat(properties, host)
    properties = properties or {}
    host = self:_host(host)
    local value = tonumber(opt(properties, 0, "value", "Value")) or 0
    local prefix = asString(opt(properties, "", "prefix", "Prefix"), "")
    local suffix = asString(opt(properties, "", "suffix", "Suffix"), "")
    local baseline = value
    local previous = value
    local row = self.Window:_newRow(host, 58, "Stat")
    local _, title, detail = self.Window:_newLabelBlock(row, properties, opt(properties, nil, "icon", "Icon"), 118)
    local valueLabel = textLabel(self.Window, row, {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -14, 0, 9),
        Size = UDim2.fromOffset(100, 22),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamSemibold,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextYAlignment = Enum.TextYAlignment.Center,
        ZIndex = 9,
    }, "Text")
    local changeLabel = textLabel(self.Window, row, {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -14, 0, 31),
        Size = UDim2.fromOffset(100, 16),
        BackgroundTransparency = 1,
        Font = Enum.Font.Gotham,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextYAlignment = Enum.TextYAlignment.Center,
        ZIndex = 9,
    }, "TextMuted")
    local handle = { value = value, name = asString(opt(properties, "Stat", "name", "Name"), "Stat") }
    local function render()
        valueLabel.Text = prefix .. formatNumber(handle.value) .. suffix
        local delta = handle.value - (opt(properties, "previous", "changeBaseline") == "initial" and baseline or previous)
        local percent = baseline == 0 and 0 or (delta / math.abs(baseline)) * 100
        changeLabel.Text = (delta >= 0 and "+" or "") .. formatNumber(delta) .. "  (" .. formatNumber(percent) .. "%)"
    end
    function handle:Set(nextValue)
        local number = tonumber(nextValue)
        if not number then
            return
        end
        previous = handle.value
        handle.value = number
        render()
    end
    function handle:ResetBaseline(nextValue)
        baseline = tonumber(nextValue) or handle.value
        previous = handle.value
        render()
    end
    function handle:Remove()
        row:Destroy()
    end
    self.Window:_refresh(render)
    render()
    self.Window:_attachElementHandle(handle, row)
    return handle
end

function Tab:CreateProgress(properties, host)
    properties = properties or {}
    host = self:_host(host)
    local range = opt(properties, { 0, 1 }, "range", "Range")
    local minimum = tonumber(range[1]) or 0
    local maximum = tonumber(range[2]) or 1
    if maximum < minimum then
        minimum, maximum = maximum, minimum
    end
    local value = clamp(tonumber(opt(properties, minimum, "value", "Value")) or minimum, minimum, maximum)
    local indeterminate = opt(properties, false, "indeterminate", "Indeterminate") == true
    local customText = opt(properties, nil, "text", "Text")
    local formatter = opt(properties, nil, "format", "Format")
    local steps = tonumber(opt(properties, nil, "steps", "Steps"))
    local showValue = opt(properties, true, "showValue", "ShowValue") ~= false
    local row = self.Window:_newRow(host, 64, "Progress")
    local _, title, detail = self.Window:_newLabelBlock(row, properties, opt(properties, nil, "icon", "Icon"), 92)
    local readout = textLabel(self.Window, row, {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -14, 0, 10),
        Size = UDim2.fromOffset(78, 18),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamSemibold,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextYAlignment = Enum.TextYAlignment.Center,
        ZIndex = 9,
    }, "Text")
    readout.Visible = showValue
    local track = instance("Frame", {
        Position = UDim2.fromOffset(14, 45),
        Size = UDim2.new(1, -28, 0, 7),
        BackgroundColor3 = self.Window.Theme.ProgressTrack,
        ClipsDescendants = true,
        ZIndex = 9,
    }, row)
    corner(track, 4)
    self.Window:_bind(track, "BackgroundColor3", "ProgressTrack")
    local fill = instance("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = self.Window.Theme.Accent,
        BorderSizePixel = 0,
        ZIndex = 10,
    }, track)
    corner(fill, 4)
    self.Window:_bind(fill, "BackgroundColor3", "Accent")
    local segments = {}
    if steps and steps >= 2 then
        fill.Visible = false
        for index = 1, math.floor(steps) do
            local segment = instance("Frame", {
                Position = UDim2.new((index - 1) / steps, 1, 0, 0),
                Size = UDim2.new(1 / steps, -2, 1, 0),
                BackgroundColor3 = self.Window.Theme.ProgressTrack,
                BorderSizePixel = 0,
                ZIndex = 10,
            }, track)
            corner(segment, 3)
            self.Window:_bind(segment, "BackgroundColor3", "ProgressTrack")
            table.insert(segments, segment)
        end
    end
    local handle = { value = value, name = asString(opt(properties, "Progress", "name", "Name"), "Progress") }
    local function percentage()
        return maximum == minimum and 0 or clamp((handle.value - minimum) / (maximum - minimum), 0, 1)
    end
    local function render()
        local ratio = percentage()
        if steps and steps >= 2 then
            fill.Visible = false
            local completed = math.floor(ratio * math.floor(steps) + 0.5)
            for index, segment in ipairs(segments) do
                segment.BackgroundColor3 = index <= completed and self.Window.Theme.Accent or self.Window.Theme.ProgressTrack
            end
        elseif indeterminate then
            fill.Visible = true
            fill.Size = UDim2.new(0.28, 0, 1, 0)
            local travel = 1 - 0.28
            fill.Position = UDim2.new(((os.clock() * 0.35) % 2) / 2 * travel, 0, 0, 0)
        else
            fill.Visible = true
            fill.Position = UDim2.new(0, 0, 0, 0)
            fill.Size = UDim2.new(ratio, 0, 1, 0)
        end
        if customText then
            readout.Text = tostring(customText)
        elseif type(formatter) == "function" then
            local ok, result = pcall(formatter, handle.value, minimum, maximum)
            readout.Text = ok and tostring(result) or ""
        else
            readout.Text = formatNumber(percentage() * 100) .. "%"
        end
    end
    self.Window:_connect(RunService.RenderStepped, function()
        if indeterminate and not self.Window.unloaded then
            render()
        end
    end)
    function handle:Set(nextValue)
        local number = tonumber(nextValue)
        if not number then
            return
        end
        handle.value = clamp(number, minimum, maximum)
        indeterminate = false
        render()
    end
    function handle:Get()
        return handle.value
    end
    function handle:GetPercentage()
        return percentage()
    end
    function handle:SetRange(nextMinimum, nextMaximum)
        minimum = tonumber(nextMinimum) or minimum
        maximum = tonumber(nextMaximum) or maximum
        if maximum < minimum then
            minimum, maximum = maximum, minimum
        end
        handle.value = clamp(handle.value, minimum, maximum)
        render()
    end
    function handle:SetText(nextText)
        customText = nextText
        render()
    end
    function handle:SetIndeterminate(state)
        indeterminate = state == true
        render()
    end
    function handle:Remove()
        row:Destroy()
    end
    self.Window:_refresh(render)
    render()
    self.Window:_attachElementHandle(handle, row)
    return handle
end

function Tab:CreateConsole(properties, host)
    properties = properties or {}
    host = self:_host(host)
    local lines = {}
    local initial = asString(opt(properties, "", "text", "Text", "code", "Code"), "")
    for line in (initial .. "\n"):gmatch("(.-)\n") do
        table.insert(lines, line)
    end
    if #lines == 1 and lines[1] == "" then
        lines = {}
    end
    local height = math.max(48, tonumber(opt(properties, 120, "height", "Height")) or 120)
    local maxLines = math.max(1, tonumber(opt(properties, 200, "maxLines", "MaxLines")) or 200)
    local follow = opt(properties, false, "follow", "Follow") == true
    local row = self.Window:_newRow(host, height + 48, "Console")
    local name = asString(opt(properties, "", "name", "Name"), "")
    if name ~= "" then
        textLabel(self.Window, row, {
            Position = UDim2.fromOffset(12, 8),
            Size = UDim2.new(1, -70, 0, 18),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamSemibold,
            Text = name,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            ZIndex = 9,
        }, "Text")
    end
    local copyButton = controlButton(row, "CopyConsole", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -10, 0, 7),
        Size = UDim2.fromOffset(28, 22),
        BackgroundTransparency = 1,
        ZIndex = 11,
    })
    local copyIcon = self.Window:_makeIcon(copyButton, "Copy", 13, "Icon")
    if copyIcon then
        copyIcon.AnchorPoint = Vector2.new(0.5, 0.5)
        copyIcon.Position = UDim2.fromScale(0.5, 0.5)
    end
    local scroll = instance("ScrollingFrame", {
        Position = UDim2.fromOffset(10, 31),
        Size = UDim2.new(1, -20, 0, height),
        BackgroundColor3 = self.Window.Theme.SurfaceInput,
        BackgroundTransparency = self.Window.Theme.InputTransparency,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 4,
        ZIndex = 9,
    }, row)
    corner(scroll, 8)
    stroke(scroll, self.Window.Theme.Border, 0.18, 1)
    self.Window:_bind(scroll, "BackgroundColor3", "SurfaceInput")
    local body = textLabel(self.Window, scroll, {
        Position = UDim2.fromOffset(10, 8),
        Size = UDim2.new(1, -20, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Font = Enum.Font.Code,
        Text = "",
        TextSize = 12,
        TextWrapped = false,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        ZIndex = 10,
    }, "TextMuted")
    local handle = { name = name }
    local function render()
        while #lines > maxLines do
            table.remove(lines, 1)
        end
        body.Text = table.concat(lines, "\n")
        if follow then
            task.defer(function()
                if scroll.Parent then
                    scroll.CanvasPosition = Vector2.new(0, math.max(0, body.AbsoluteSize.Y - scroll.AbsoluteSize.Y))
                end
            end)
        end
    end
    function handle:Set(text)
        lines = {}
        local content = asString(text, "")
        for line in (content .. "\n"):gmatch("(.-)\n") do
            table.insert(lines, line)
        end
        if #lines == 1 and lines[1] == "" then
            lines = {}
        end
        render()
    end
    function handle:Append(text)
        local content = asString(text, "")
        for line in (content .. "\n"):gmatch("(.-)\n") do
            table.insert(lines, line)
        end
        render()
    end
    function handle:Clear()
        lines = {}
        render()
    end
    function handle:Get()
        return table.concat(lines, "\n")
    end
    function handle:Copy()
        if type(setclipboard) ~= "function" then
            return false
        end
        local ok = pcall(setclipboard, self:Get())
        return ok
    end
    function handle:SetHeight(nextHeight)
        local nextValue = math.max(48, tonumber(nextHeight) or height)
        height = nextValue
        row.Size = UDim2.new(row.Size.X.Scale, row.Size.X.Offset, 0, height + 48)
        scroll.Size = UDim2.new(1, -20, 0, height)
    end
    function handle:Remove()
        row:Destroy()
    end
    self.Window:_connect(copyButton.Activated, function()
        handle:Copy()
    end)
    render()
    self.Window:_attachElementHandle(handle, row)
    return handle
end

function Window:CreateTag(properties)
    properties = type(properties) == "string" and { name = properties } or (properties or {})
    local text = asString(opt(properties, "Tag", "name", "Name", "text", "Text", "title", "Title"), "Tag")
    local iconName = opt(properties, nil, "icon", "Icon")
    local customColor = opt(properties, nil, "color", "Color")
    if customColor then
        customColor = monochromeColor(customColor)
    end
    local tag = instance("Frame", {
        Name = "Tag_" .. safeName(text),
        Size = UDim2.fromOffset(math.max(40, #text * 6 + (iconName and 28 or 16)), 20),
        BackgroundColor3 = customColor or self.Theme.SurfaceRaised,
        BackgroundTransparency = self.Theme.RaisedTransparency,
        BorderSizePixel = 0,
        LayoutOrder = tonumber(opt(properties, 0, "order", "Order")) or 0,
        ZIndex = 6,
    }, self._tagContainer)
    corner(tag, 7)
    stroke(tag, self.Theme.Border, 0.18, 1)
    if not customColor then
        self:_bind(tag, "BackgroundColor3", "SurfaceRaised")
    end
    local window = self
    local icon
    local function updateIcon(nextIcon)
        if icon then
            icon:Destroy()
            icon = nil
        end
        if nextIcon then
            icon = window:_makeIcon(tag, nextIcon, 12, "Icon")
            if icon then
                icon.Name = "TagIcon"
                icon.Position = UDim2.fromOffset(7, 4)
            end
        end
    end
    updateIcon(iconName)
    local tagTextTheme = "TextMuted"
    if customColor then
        local average = (customColor.R + customColor.G + customColor.B) / 3
        tagTextTheme = average > 0.5 and "AccentContrast" or "Text"
    end
    local label = textLabel(self, tag, {
        Position = UDim2.fromOffset(icon and 22 or 0, 0),
        Size = UDim2.new(1, icon and -22 or 0, 1, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamSemibold,
        Text = text,
        TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        ZIndex = 7,
    }, tagTextTheme)
    local handle = {}
    local function resize()
        label.Position = UDim2.fromOffset(icon and 22 or 0, 0)
        label.Size = UDim2.new(1, icon and -22 or 0, 1, 0)
        tag.Size = UDim2.fromOffset(math.max(40, #text * 6 + (icon and 28 or 16)), 20)
    end
    function handle:SetText(nextText)
        text = asString(nextText, "")
        label.Text = text
        resize()
    end
    function handle:SetColor(nextColor)
        if nextColor then
            local color = monochromeColor(nextColor)
            tag.BackgroundColor3 = color
            local average = (color.R + color.G + color.B) / 3
            label.TextColor3 = average > 0.5 and window.Theme.AccentContrast or window.Theme.Text
        end
    end
    function handle:SetIcon(nextIcon)
        updateIcon(nextIcon)
        resize()
    end
    function handle:Set(nextValue)
        if type(nextValue) == "table" then
            if nextValue.order ~= nil or nextValue.Order ~= nil then
                tag.LayoutOrder = tonumber(opt(nextValue, tag.LayoutOrder, "order", "Order")) or tag.LayoutOrder
            end
            if nextValue.text ~= nil or nextValue.Text ~= nil or nextValue.title ~= nil or nextValue.Title ~= nil then
                handle:SetText(opt(nextValue, "", "text", "Text", "title", "Title", "name", "Name"))
            end
            if nextValue.color ~= nil or nextValue.Color ~= nil then
                handle:SetColor(opt(nextValue, nil, "color", "Color"))
            end
            if nextValue.icon ~= nil or nextValue.Icon ~= nil then
                handle:SetIcon(opt(nextValue, nil, "icon", "Icon"))
            end
        else
            handle:SetText(nextValue)
        end
        return handle
    end
    function handle:Remove()
        tag:Destroy()
    end
    resize()
    return handle
end

function Window:CreateSection(properties)
    properties = type(properties) == "string" and { name = properties } or (properties or {})
    local name = asString(opt(properties, "Section", "name", "Name"), "Section")
    local iconName = opt(properties, nil, "icon", "Icon")
    local section = instance("Frame", {
        Name = "SidebarSection_" .. safeName(name),
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = nextLayoutOrder(self._sidebarList),
        ZIndex = 6,
    }, self._sidebarList)
    local icon
    if iconName then
        icon = self:_makeIcon(section, iconName, 12, "Icon")
        if icon then
            icon.Position = UDim2.fromOffset(4, 6)
        end
    end
    local label = textLabel(self, section, {
        Position = UDim2.fromOffset(icon and 22 or 4, 2),
        Size = UDim2.new(1, icon and -26 or -8, 1, -2),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamSemibold,
        Text = string.upper(name),
        TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        ZIndex = 7,
    }, "TextFaint")
    local handle = {
        Name = name,
        Set = function(_, value)
            name = asString(value, name)
            label.Text = string.upper(name)
        end,
        Remove = function()
            section:Destroy()
        end,
    }
    self:_attachElementHandle(handle, section)
    return handle
end

function Window:SetProfile(text)
    self.Profile = asString(text, "")
    if self._sidebarList then
        self._sidebarList.Size = UDim2.new(1, -20, 1, self.Profile ~= "" and -58 or -24)
    end
    if self._profileLabel then
        self._profileLabel.Text = self.Profile
        self._profileLabel.Visible = self.Profile ~= ""
    end
    return self
end
function Window:_displayRect(object)
    local position = object.AbsolutePosition
    local size = object.AbsoluteSize
    return {
        position = position,
        size = size,
        center = position + size / 2,
    }
end

function Window:_displayGuiOffset()
    local ok, position = pcall(function()
        return self.Gui.AbsolutePosition
    end)
    if ok and typeof(position) == "Vector2" then
        return position
    end
    return Vector2.new(0, 0)
end

function Window:_displayLocalPoint(point)
    return point - self:_displayGuiOffset()
end

function Window:_displayPillShadowRect(rect)
    local size = rect.size + Vector2.new(12, 12)
    return {
        position = rect.center - size / 2,
        size = size,
        center = rect.center,
    }
end

function Window:_cancelDisplayMotion()
    for _, object in ipairs({
        self._root,
        self._shadow,
        self._morph,
        self._morphShadow,
        self._morphCorner,
        self._morphShadowCorner,
    }) do
        self:_cancelTween(object)
    end
end

function Window:_captureDisplayVisuals()
    local entries = {}
    for _, root in ipairs({ self._topbar, self._body }) do
        if root then
            for _, entry in ipairs(self:_captureVisual(root)) do
                table.insert(entries, entry)
            end
        end
    end
    return entries
end

function Window:_displayGuard(token)
    return not self.unloaded and self._displayToken == token
end

function Window:_displaySetMorph(rect, shadowRect, color, transparency, radius, shadowTransparency)
    local center = self:_displayLocalPoint(rect.center)
    local shadowCenter = self:_displayLocalPoint(shadowRect.center)
    self._morph.Position = UDim2.fromOffset(center.X, center.Y)
    self._morph.Size = UDim2.fromOffset(rect.size.X, rect.size.Y)
    self._morph.BackgroundColor3 = color
    self._morph.BackgroundTransparency = transparency
    self._morphCorner.CornerRadius = UDim.new(0, radius)
    self._morphShadow.Position = UDim2.fromOffset(shadowCenter.X, shadowCenter.Y)
    self._morphShadow.Size = UDim2.fromOffset(shadowRect.size.X, shadowRect.size.Y)
    self._morphShadow.BackgroundTransparency = shadowTransparency
end

function Window:_displayAnimateMorph(token, target, targetShadow, color, transparency, radius, shadowTransparency, onComplete)
    local duration = math.max(0, tonumber(Surge.Animation.Menu) or 0.22)
    local center = self:_displayLocalPoint(target.center)
    local shadowCenter = self:_displayLocalPoint(targetShadow.center)
    self:_tween(self._morph, {
        Position = UDim2.fromOffset(center.X, center.Y),
        Size = UDim2.fromOffset(target.size.X, target.size.Y),
        BackgroundColor3 = color,
        BackgroundTransparency = transparency,
    }, duration, Surge.Animation.EasingStyle, Surge.Animation.EaseInOut)
    self:_tween(self._morphCorner, {
        CornerRadius = UDim.new(0, radius),
    }, duration, Surge.Animation.EasingStyle, Surge.Animation.EaseInOut)
    self:_tween(self._morphShadow, {
        Position = UDim2.fromOffset(shadowCenter.X, shadowCenter.Y),
        Size = UDim2.fromOffset(targetShadow.size.X, targetShadow.size.Y),
        BackgroundTransparency = shadowTransparency,
    }, duration, Surge.Animation.EasingStyle, Surge.Animation.EaseInOut)
    task.delay(duration + 0.03, function()
        if self:_displayGuard(token) then
            onComplete()
        end
    end)
end

function Window:_displayStoreRootGeometry()
    self._displayRootPosition = self._root.Position
    self._displayRootSize = self._root.Size
    self._displayShadowPosition = self._shadow.Position
    self._displayShadowSize = self._shadow.Size
    self._displayBodyVisible = self._body.Visible
end

function Window:_displayRestoreRootGeometry()
    if self._displayRootPosition then
        self._root.Position = self._displayRootPosition
    end
    if self._displayRootSize then
        self._root.Size = self._displayRootSize
    end
    if self._displayShadowPosition then
        self._shadow.Position = self._displayShadowPosition
    end
    if self._displayShadowSize then
        self._shadow.Size = self._displayShadowSize
    end
end

function Window:_displayFinishHidden(token)
    if not self:_displayGuard(token) then
        return
    end
    self._root.Visible = false
    self._shadow.Visible = false
    self._morph.Visible = false
    self._morphShadow.Visible = false
    self._pill.Visible = true
    self._displayBlocker.Visible = false
    self._displayState = "hidden"
end

function Window:_displayFinishShown(token)
    if not self:_displayGuard(token) then
        return
    end
    self._root.Visible = true
    self._root.BackgroundTransparency = self.Theme.WindowTransparency
    self._shadow.Visible = true
    self._pill.Visible = false
    self._morph.Visible = false
    self._morphShadow.Visible = false
    self._body.Visible = self._displayBodyVisible
    self._displayState = "showing"
    self:_setVisualTransparency(self._displayVisuals, 1)
    local duration = math.max(0, tonumber(Surge.Animation.Fast) or 0.1)
    self:_animateVisualTransparency(self._displayVisuals, "restore", duration, Surge.Animation.EaseOut)
    task.delay(duration + 0.02, function()
        if self:_displayGuard(token) then
            self._displayState = "shown"
            self._displayBlocker.Visible = false
        end
    end)
end

function Window:_displayStartMorphToPill(token)
    if not self:_displayGuard(token) then
        return
    end
    local source = self._morph.Visible and self:_displayRect(self._morph) or self:_displayRect(self._root)
    local sourceShadow = self._morphShadow.Visible and self:_displayRect(self._morphShadow) or self:_displayRect(self._shadow)
    local pillRect = self:_displayRect(self._pill)
    local pillShadow = self:_displayPillShadowRect(pillRect)
    if not self._morph.Visible then
        self._root.Visible = false
        self._shadow.Visible = false
        self._morph.Visible = true
        self._morphShadow.Visible = true
        self:_displaySetMorph(source, sourceShadow, self.Theme.Window, self.Theme.WindowTransparency, self.CornerRadius, 0.7)
    end
    self:_displayAnimateMorph(token, pillRect, pillShadow, self.Theme.SurfaceRaised, self.Theme.RaisedTransparency, 14, 1, function()
        self:_displayFinishHidden(token)
    end)
end

function Window:_displayStartMorphToRoot(token)
    if not self:_displayGuard(token) then
        return
    end
    self:_displayRestoreRootGeometry()
    local rootRect = self:_displayRect(self._root)
    local rootShadow = self:_displayRect(self._shadow)
    local pillRect = self:_displayRect(self._pill)
    local pillShadow = self:_displayPillShadowRect(pillRect)
    if not self._morph.Visible then
        self._pill.Visible = false
        self._root.Visible = false
        self._shadow.Visible = false
        self._morph.Visible = true
        self._morphShadow.Visible = true
        self:_displaySetMorph(pillRect, pillShadow, self.Theme.SurfaceRaised, self.Theme.RaisedTransparency, 14, 1)
    end
    self:_displayAnimateMorph(token, rootRect, rootShadow, self.Theme.Window, self.Theme.WindowTransparency, self.CornerRadius, 0.7, function()
        self:_displayFinishShown(token)
    end)
end

function Window:_displayBegin(token, state)
    self:_cancelDisplayMotion()
    self._displayState = state
    self._displayBlocker.Visible = true
end

function Window:Show()
    if self.unloaded then
        return self
    end
    local previous = self._displayState or (self._root.Visible and "shown" or "hidden")
    if previous == "shown" or previous == "showing" then
        return self
    end
    self:_closeDropdownMenu()
    self._displayToken = (self._displayToken or 0) + 1
    local token = self._displayToken
    self:_displayBegin(token, "showing")
    if not self._displayVisuals then
        self._displayVisuals = self:_captureDisplayVisuals()
    end
    if previous == "hiding" and not self._morph.Visible then
        self:_setVisualTransparency(self._displayVisuals, 1)
        self:_displayFinishShown(token)
    else
        self:_displayStartMorphToRoot(token)
    end
    return self
end

function Window:Hide()
    if self.unloaded then
        return self
    end
    local previous = self._displayState or (self._root.Visible and "shown" or "hidden")
    if previous == "hidden" or previous == "hiding" then
        return self
    end
    self:_closeDropdownMenu()
    self._displayToken = (self._displayToken or 0) + 1
    local token = self._displayToken
    self:_displayBegin(token, "hiding")
    if previous == "shown" then
        self:_displayStoreRootGeometry()
        self._displayVisuals = self:_captureDisplayVisuals()
    elseif not self._displayVisuals then
        self._displayVisuals = self:_captureDisplayVisuals()
    end
    if previous == "showing" and self._morph.Visible then
        self:_displayStartMorphToPill(token)
    else
        local duration = math.max(0, tonumber(Surge.Animation.Fast) or 0.1)
        self:_animateVisualTransparency(self._displayVisuals, 1, duration, Surge.Animation.EaseIn)
        task.delay(duration + 0.01, function()
            if self:_displayGuard(token) then
                self:_displayStartMorphToPill(token)
            end
        end)
    end
    return self
end

function Window:ToggleHide()
    local state = self._displayState or (self._root.Visible and "shown" or "hidden")
    if state == "hidden" or state == "hiding" then
        return self:Show()
    end
    return self:Hide()
end

function Window:ToggleMinimise()
    if self.unloaded then
        return self
    end
    self:_closeDropdownMenu()
    self._minimised = not self._minimised
    self._body.Visible = not self._minimised
    self._root.Size = self._minimised and UDim2.fromOffset(self.Width, 58) or UDim2.fromOffset(self.Width, self.Height)
    self._shadow.Size = self._minimised and UDim2.fromOffset(self.Width + 12, 70) or UDim2.fromOffset(self.Width + 12, self.Height + 12)
    self._shadow.Position = UDim2.new(
        self._root.Position.X.Scale,
        self._root.Position.X.Offset,
        self._root.Position.Y.Scale,
        self._root.Position.Y.Offset
    )
    return self
end

function Window:Navigate(tabOrName)
    self:_closeDropdownMenu()
    for _, tab in ipairs(self._tabs) do
        if tab == tabOrName or tab.Name == tabOrName then
            tab:Select()
            return tab
        end
    end
    return nil
end

function Window:ChangeTheme(nextTheme)
    local selectedTheme
    if type(nextTheme) == "string" then
        selectedTheme = Surge.Themes[nextTheme] or Surge.Themes["Monochrome"]
    else
        selectedTheme = nextTheme
    end
    self.Theme = mergeTables(self.Theme, selectedTheme or {})
    for _, binding in ipairs(self._bindings) do
        if binding.object and binding.object.Parent then
            local value = self.Theme[binding.themeKey]
            if value ~= nil then
                if typeof and typeof(value) == "Color3" then
                    self:_tween(binding.object, { [binding.property] = value }, Surge.Animation.Theme)
                else
                    pcall(function()
                        binding.object[binding.property] = value
                    end)
                end
            end
        end
    end
    for _, refresh in ipairs(self._refreshers) do
        safeCall(refresh)
    end
    return self
end

local function pathSegment(value)
    local result = tostring(value or "")
    result = result:gsub("[^%w%._%-]", "_")
    result = result:gsub("%.%.", "_")
    if result == "" then
        return "Surge"
    end
    return result
end

local function joinPath(...)
    local parts = { ... }
    local output = {}
    for _, part in ipairs(parts) do
        local value = tostring(part or ""):gsub("^/+", ""):gsub("/+$", "")
        if value ~= "" then
            table.insert(output, value)
        end
    end
    return table.concat(output, "/")
end

local function serialise(value)
    local valueType = typeof and typeof(value) or type(value)
    if valueType == "Color3" then
        return { __type = "Color3", r = value.R, g = value.G, b = value.B }
    end
    if valueType == "EnumItem" then
        local enumType = tostring(value.EnumType):gsub("^Enum%.", "")
        return { __type = "EnumItem", enumType = enumType, name = value.Name }
    end
    if type(value) == "table" then
        local result = {}
        for key, item in pairs(value) do
            result[key] = serialise(item)
        end
        return result
    end
    if type(value) == "string" or type(value) == "number" or type(value) == "boolean" then
        return value
    end
    return nil
end

local function deserialise(value)
    if type(value) ~= "table" then
        return value
    end
    if value.__type == "Color3" then
        return Color3.new(value.r or 1, value.g or 1, value.b or 1)
    end
    if value.__type == "EnumItem" and (value.enumType == "KeyCode" or value.enumType == "Enum.KeyCode") then
        local ok, key = pcall(function()
            return Enum.KeyCode[value.name]
        end)
        if ok then
            return key
        end
    end
    local result = {}
    for key, item in pairs(value) do
        result[key] = deserialise(item)
    end
    return result
end

local function validConfigComponent(value)
    local raw = tostring(value or "")
    if raw == "" or raw == "." or raw == ".." or raw:find("[/\\]") or raw:find("%.%.") then
        return nil
    end
    local clean = pathSegment(raw)
    if #clean > 64 or not clean:match("^[A-Za-z0-9_.-]+$") then
        return nil
    end
    return clean
end

function Window:_configFolder()
    local configured = tostring(self.Configuration.FolderName or ".Surge/configs"):gsub("\\", "/")
    local segments = {}
    for segment in configured:gmatch("[^/]+") do
        local clean = validConfigComponent(segment)
        if not clean then
            return nil, "Invalid configuration folder"
        end
        table.insert(segments, clean)
    end
    if self.Configuration.Version == 2 then
        local scriptId = validConfigComponent(self.Configuration.ScriptId)
        if not scriptId then
            return nil, "Invalid configuration scriptId"
        end
        table.insert(segments, scriptId)
    end
    if #segments == 0 then
        return nil, "Configuration folder is empty"
    end
    return table.concat(segments, "/")
end

function Window:_configPath(name)
    local folder, folderError = self:_configFolder()
    if not folder then
        return nil, folderError
    end
    local fileName = validConfigComponent(name or self.Configuration.FileName or self.Id)
    if not fileName then
        return nil, "Invalid configuration name"
    end
    if not fileName:lower():match("%.json$") then
        fileName = fileName .. ".json"
    end
    return folder, joinPath(folder, fileName)
end

function Window:_ensureFolder(folder)
    if type(isfolder) ~= "function" or type(makefolder) ~= "function" then
        return false, "Potassium filesystem functions are unavailable"
    end
    local current = ""
    for segment in folder:gmatch("[^/]+") do
        current = joinPath(current, segment)
        local exists = false
        local ok = pcall(function()
            exists = isfolder(current)
        end)
        if not ok then
            return false, "isfolder failed for " .. current
        end
        if not exists then
            local made, errorMessage = pcall(makefolder, current)
            if not made then
                return false, tostring(errorMessage)
            end
        end
    end
    return true
end

function Window:_validateConfigValue(handle, value)
    local kind = handle._configType
    if kind == "boolean" then
        if type(value) == "boolean" then return value, true end
        return nil, false
    elseif kind == "number" then
        if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
            return nil, false
        end
        local range = handle._configRange or {}
        local minimum = tonumber(range.min)
        local maximum = tonumber(range.max)
        if minimum and maximum then
            value = clamp(value, minimum, maximum)
        end
        return value, true
    elseif kind == "dropdown" then
        local options = handle._configOptions or {}
        local function validOption(candidate)
            for _, option in ipairs(options) do
                if option == candidate then
                    return true
                end
            end
            return false
        end
        if handle._configMultiple then
            if type(value) ~= "table" then return nil, false end
            local result = {}
            for _, candidate in ipairs(value) do
                if validOption(candidate) and not table.find(result, candidate) then
                    table.insert(result, candidate)
                end
            end
            return result, true
        end
        return validOption(value) and value or nil, validOption(value)
    elseif kind == "string" then
        local text = tostring(value or "")
        if handle._configNumeric and tonumber(text) == nil then
            return nil, false
        end
        return text, true
    elseif kind == "keybind" then
        if value == nil or (typeof and typeof(value) == "EnumItem") then
            return value, true
        end
        return nil, false
    elseif kind == "color" then
        if type(value) ~= "table" or value.color == nil then return nil, false end
        local alpha = clamp(tonumber(value.alpha) or 1, 0, 1)
        return { color = value.color, alpha = alpha }, true
    end
    return value, true
end

function Window:_applyConfigValue(handle, value, fireCallback)
    local valid, ok = self:_validateConfigValue(handle, value)
    if not ok then
        return false, "invalid value"
    end
    local skipCallback = not fireCallback
    if handle._configType == "color" then
        handle:Set(valid.color, true)
        handle:SetAlpha(valid.alpha, true)
        if fireCallback and type(handle._configCallback) == "function" then
            self:_safeCallback(handle._configCallback, valid.color, valid.alpha)
        end
    elseif type(handle.Set) == "function" then
        handle:Set(valid, skipCallback)
    else
        return false, "handle has no setter"
    end
    return true
end

function Window:Save(name, options)
    if not self.Configuration.Enabled then
        return false, "Configuration persistence is disabled"
    end
    if type(name) == "table" then
        options = name
        name = options.name or options.Name
    end
    options = options or {}
    if type(writefile) ~= "function" then
        return false, "Potassium writefile is unavailable"
    end
    local folder, path = self:_configPath(name)
    if not folder then return false, path end
    local folderOk, folderError = self:_ensureFolder(folder)
    if not folderOk then return false, folderError end
    if type(isfile) == "function" and isfile(path) and type(readfile) == "function" and not options.overwrite then
        local readOk, previous = pcall(readfile, path)
        if readOk then
            local decodeOk, previousData = pcall(function() return HttpService:JSONDecode(previous) end)
            if not decodeOk or type(previousData) ~= "table" then
                return false, "Existing configuration is invalid; delete it before replacing"
            end
        end
    end
    local values = {}
    for flag, handle in pairs(self._values) do
        local value = type(handle.GetSaveValue) == "function" and handle:GetSaveValue() or handle.value
        values[flag] = {
            type = handle._configType or "unknown",
            value = value == nil and { kind = "none" } or serialise(value),
        }
    end
    local payload
    if self.Configuration.Version == 2 then
        payload = {
            schema = "Surge.Config",
            version = 2,
            scriptId = self.Configuration.ScriptId,
            windowId = self.Id,
            values = values,
        }
    else
        local legacy = {}
        for flag, entry in pairs(values) do
            legacy[flag] = entry.value
        end
        payload = { version = 1, values = legacy }
    end
    local ok, encoded = pcall(function() return HttpService:JSONEncode(payload) end)
    if not ok then return false, tostring(encoded) end
    local wrote, errorMessage = pcall(writefile, path, encoded)
    if not wrote then return false, tostring(errorMessage) end
    return true
end

function Window:Load(name)
    if not self.Configuration.Enabled then
        return false, "Configuration persistence is disabled"
    end
    if type(readfile) ~= "function" or type(isfile) ~= "function" then
        return false, "Potassium readfile/isfile are unavailable"
    end
    local _, path = self:_configPath(name)
    if not path then return false, "Invalid configuration path" end
    local exists = false
    local checkOk = pcall(function() exists = isfile(path) end)
    if not checkOk or not exists then return false, "Configuration file not found" end
    local readOk, contents = pcall(readfile, path)
    if not readOk then return false, tostring(contents) end
    local decodeOk, data = pcall(function() return HttpService:JSONDecode(contents) end)
    if not decodeOk or type(data) ~= "table" or type(data.values) ~= "table" then
        return false, "Configuration JSON is invalid"
    end
    local version = tonumber(data.version) or 1
    if version > 2 then return false, "Unsupported configuration version" end
    if version == 2 and (data.schema ~= "Surge.Config" or data.scriptId ~= self.Configuration.ScriptId) then
        return false, "Configuration belongs to another script"
    end
    local pending = {}
    local fire = version == 1 or self.Configuration.CallbacksOnLoad
    local summary = { version = version, applied = 0, skipped = {} }
    for flag, entry in pairs(data.values) do
        local raw = version == 2 and type(entry) == "table" and entry.value or entry
        if type(raw) == "table" and raw.kind == "none" then raw = nil end
        local restored = deserialise(raw)
        local handle = self._values[flag]
        if handle then
            local valid, ok = self:_validateConfigValue(handle, restored)
            if ok then
                table.insert(pending, { handle = handle, value = valid })
            else
                table.insert(summary.skipped, flag .. ": invalid value")
            end
        else
            self._pendingConfig[flag] = { value = restored, fire = fire }
        end
    end
    self._loadingConfig = true
    for _, item in ipairs(pending) do
        local applied = self:_applyConfigValue(item.handle, item.value, fire)
        if applied then summary.applied = summary.applied + 1 end
    end
    self._loadingConfig = false
    return true, summary
end

function Window:ListConfigs()
    if not self.Configuration.Enabled or type(listfiles) ~= "function" then return {} end
    local folder = self:_configFolder()
    if not folder then return {} end
    local ok, files = pcall(listfiles, folder)
    if not ok or type(files) ~= "table" then return {} end
    local result = {}
    for _, file in ipairs(files) do
        local item = tostring(file):match("([^/\\]+)$")
        if item and item:lower():match("%.json$") then
            table.insert(result, item:gsub("%.json$", ""))
        end
    end
    table.sort(result)
    return result
end

function Window:DeleteConfig(name)
    if not self.Configuration.Enabled or type(delfile) ~= "function" or type(isfile) ~= "function" then
        return false
    end
    local _, path = self:_configPath(name)
    if not path then return false end
    local exists = false
    pcall(function() exists = isfile(path) end)
    if not exists then return false end
    return pcall(delfile, path)
end

function Window:GetPath(name)
    return self:_configPath(name)
end

function Window:ResetDefaults(options)
    options = options or {}
    local fire = options.callback == true or options.callbacks == true
    self._loadingConfig = true
    for flag, handle in pairs(self._values) do
        local defaultValue = self._configDefaults[flag]
        if type(defaultValue) == "table" and defaultValue.kind == "none" then
            defaultValue = nil
        end
        if defaultValue ~= nil or handle._configType == "keybind" then
            self:_applyConfigValue(handle, defaultValue == nil and nil or copyTable(defaultValue), fire)
        end
    end
    self._loadingConfig = false
    if options.save ~= false and self.Configuration.Enabled then
        self:Save({ overwrite = true })
    end
    return true
end

Window.ResetConfig = Window.ResetDefaults

function Window:Get(flag)
    return self.Flags[flag]
end

function Window:Set(flag, value)
    local handle = self._values[flag]
    if not handle or type(handle.Set) ~= "function" then return false end
    handle:Set(value)
    return true
end

function Window:Notify(properties)
    if self.unloaded or not self._notifyLayer or not self._notifyLayer.Parent then
        return { Close = function() end }
    end
    properties = properties or {}
    local title = asString(opt(properties, "Notice", "title", "Title"), "Notice")
    local content = asString(opt(properties, "", "content", "Content"), "")
    local duration = tonumber(opt(properties, nil, "duration", "Duration"))
    if not duration then
        duration = clamp(2.5 + (#content / 80), 3, 9)
    end
    self._notificationSequence = (self._notificationSequence or 0) + 1
    local existing = {}
    for _, child in ipairs(self._notifyLayer:GetChildren()) do
        if child:IsA("GuiObject") then
            table.insert(existing, child)
        end
    end
    table.sort(existing, function(left, right)
        return left.LayoutOrder < right.LayoutOrder
    end)
    while #existing >= 6 do
        local oldest = table.remove(existing, 1)
        self:_cancelTweenTree(oldest)
        oldest:Destroy()
    end
    local card = instance("Frame", {
        Name = "Notification",
        LayoutOrder = self._notificationSequence,
        Size = UDim2.fromOffset(300, content ~= "" and 72 or 48),
        BackgroundColor3 = self.Theme.SurfaceRaised,
        BackgroundTransparency = self.Theme.RaisedTransparency,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 70,
    }, self._notifyLayer)
    corner(card, 10)
    stroke(card, self.Theme.BorderStrong, 0.05, 1)
    self:_bind(card, "BackgroundColor3", "SurfaceRaised")
    local iconName = opt(properties, "Info", "icon", "Icon")
    local icon = self:_makeIcon(card, iconName, 16, "Icon")
    if icon then
        icon.Position = UDim2.fromOffset(12, 15)
    end
    textLabel(self, card, {
        Position = UDim2.fromOffset(38, 10),
        Size = UDim2.new(1, -50, 0, 18),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamSemibold,
        Text = title,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        ZIndex = 71,
    }, "Text")
    if content ~= "" then
        textLabel(self, card, {
            Position = UDim2.fromOffset(38, 31),
            Size = UDim2.new(1, -50, 0, 30),
            BackgroundTransparency = 1,
            Font = Enum.Font.Gotham,
            Text = content,
            TextSize = 10,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            ZIndex = 71,
        }, "TextMuted")
    end
    local dismiss = controlButton(card, "Dismiss", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        ZIndex = 72,
    })
    local state
    self:_connect(dismiss.Activated, function()
        self:_closeTransient(state)
    end)
    state = self:_showTransient(card, duration)
    return {
        Close = function()
            self:_closeTransient(state)
        end,
    }
end

function Window:Toast(properties)
    if self.unloaded or not self._toastLayer or not self._toastLayer.Parent then
        return { Close = function() end }
    end
    properties = properties or {}
    local title = asString(opt(properties, "Saved", "title", "Title"), "Saved")
    local subtitle = asString(opt(properties, "", "subtitle", "Subtitle"), "")
    local subtitleAbove = opt(properties, false, "subtitleAbove", "SubtitleAbove") == true
    local duration = tonumber(opt(properties, nil, "duration", "Duration"))
    if not duration then
        duration = clamp(2.5 + (#title + #subtitle) / 80, 3, 9)
    end
    local position = string.lower(asString(opt(properties, "top", "position", "Position")))
    local camera = workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
    local maxWidth = math.max(64, math.min(420, viewport.X - 32))
    local requestedMinWidth = tonumber(opt(properties, 128, "minWidth", "MinWidth")) or 128
    local minWidth = math.min(maxWidth, math.max(128, requestedMinWidth))
    local naturalWidth = math.max(#title, #subtitle) * 6.2 + 56
    local width = math.min(maxWidth, math.max(minWidth, naturalWidth))
    local contentWidth = math.max(64, width - 44)
    local charsPerLine = math.max(10, math.floor(contentWidth / 6))
    local function lineCount(text)
        if text == "" then
            return 0
        end
        local count = 0
        for line in (text .. "\n"):gmatch("(.-)\n") do
            count = count + math.max(1, math.ceil(#line / charsPerLine))
        end
        return math.max(1, count)
    end
    local titleLines = lineCount(title)
    local subtitleLines = lineCount(subtitle)
    local maxHeight = math.max(64, viewport.Y - 36)
    local availableTextHeight = math.max(34, maxHeight - 20)
    local titleHeight = math.max(18, titleLines * 15)
    local subtitleHeight = subtitle ~= "" and math.max(16, subtitleLines * 14) or 0
    if subtitle ~= "" and titleHeight + subtitleHeight + 4 > availableTextHeight then
        local ratio = availableTextHeight / (titleHeight + subtitleHeight + 4)
        titleHeight = math.max(18, math.floor(titleHeight * ratio))
        subtitleHeight = math.max(16, availableTextHeight - titleHeight - 4)
    elseif subtitle == "" then
        titleHeight = math.min(titleHeight, availableTextHeight)
    end
    local height = math.min(maxHeight, 10 + titleHeight + (subtitle ~= "" and (4 + subtitleHeight) or 0) + 10)
    local titleY
    local subtitleY
    if subtitle ~= "" and subtitleAbove then
        subtitleY = 10
        titleY = 10 + subtitleHeight + 4
    else
        titleY = 10
        subtitleY = 10 + titleHeight + 4
    end
    self._toastSequence = (self._toastSequence or 0) + 1
    local existing = {}
    for _, child in ipairs(self._toastLayer:GetChildren()) do
        if child:IsA("GuiObject") then
            table.insert(existing, child)
        end
    end
    table.sort(existing, function(left, right)
        return left.LayoutOrder < right.LayoutOrder
    end)
    while #existing >= 6 do
        local oldest = table.remove(existing, 1)
        self:_cancelTweenTree(oldest)
        oldest:Destroy()
    end
    self._toastLayer.Size = UDim2.fromOffset(maxWidth, maxHeight)
    if position == "bottom" then
        self._toastLayer.AnchorPoint = Vector2.new(0.5, 1)
        self._toastLayer.Position = UDim2.new(0.5, 0, 1, -18)
        self._toastLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
    else
        self._toastLayer.AnchorPoint = Vector2.new(0.5, 0)
        self._toastLayer.Position = UDim2.new(0.5, 0, 0, 18)
        self._toastLayout.VerticalAlignment = Enum.VerticalAlignment.Top
    end
    local pill = instance("Frame", {
        Name = "Toast",
        LayoutOrder = self._toastSequence,
        Size = UDim2.fromOffset(width, height),
        BackgroundColor3 = self.Theme.SurfaceRaised,
        BackgroundTransparency = self.Theme.RaisedTransparency,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 80,
    }, self._toastLayer)
    corner(pill, 14)
    stroke(pill, self.Theme.BorderStrong, 0.05, 1)
    self:_bind(pill, "BackgroundColor3", "SurfaceRaised")
    local icon = self:_makeIcon(pill, opt(properties, "Check", "icon", "Icon"), 15, "Accent")
    if icon then
        icon.Position = UDim2.fromOffset(12, math.max(9, math.floor((height - 15) / 2)))
    end
    textLabel(self, pill, {
        Position = UDim2.fromOffset(34, titleY),
        Size = UDim2.new(1, -44, 0, titleHeight),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamSemibold,
        Text = title,
        TextSize = 11,
        TextWrapped = true,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        ZIndex = 81,
    }, "Text")
    if subtitle ~= "" then
        textLabel(self, pill, {
            Position = UDim2.fromOffset(34, subtitleY),
            Size = UDim2.new(1, -44, 0, subtitleHeight),
            BackgroundTransparency = 1,
            Font = Enum.Font.Gotham,
            Text = subtitle,
            TextSize = 10,
            TextWrapped = true,
            TextTruncate = Enum.TextTruncate.AtEnd,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            ZIndex = 81,
        }, "TextMuted")
    end
    local state = self:_showTransient(pill, duration)
    return {
        Close = function()
            self:_closeTransient(state)
        end,
    }
end

function Window:Popup(properties)
    properties = properties or {}
    local boxes = opt(properties, {}, "boxes", "Boxes")
    local hasBoxes = type(boxes) == "table" and #boxes > 0
    local overlay = instance("Frame", {
        Name = "PopupOverlay",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = self.Theme.Overlay,
        BackgroundTransparency = self.Theme.OverlayTransparency,
        BorderSizePixel = 0,
        ZIndex = 100,
    }, self.Gui)
    local dismissable = opt(properties, true, "dismissable", "Dismissable") ~= false
    local dismiss = controlButton(overlay, "PopupDismiss", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        ZIndex = 100,
        Active = dismissable,
    })
    local cardHeight = math.min(420, 220 + (hasBoxes and #boxes * 48 or 0))
    local card = instance("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(380, cardHeight),
        BackgroundColor3 = self.Theme.Surface,
        BackgroundTransparency = self.Theme.SurfaceTransparency,
        BorderSizePixel = 0,
        ZIndex = 102,
    }, overlay)
    corner(card, 14)
    stroke(card, self.Theme.BorderStrong, 0.02, 1)
    self:_bind(card, "BackgroundColor3", "Surface")
    local title = textLabel(self, card, {
        Position = UDim2.fromOffset(20, 18),
        Size = UDim2.new(1, -40, 0, 24),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamSemibold,
        Text = asString(opt(properties, "Popup", "title", "Title"), "Popup"),
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        ZIndex = 103,
    }, "Text")
    local subtitle = asString(opt(properties, "", "subtitle", "Subtitle"), "")
    local content = asString(opt(properties, "", "content", "Content"), "")
    if subtitle ~= "" then
        textLabel(self, card, {
            Position = UDim2.fromOffset(20, 44),
            Size = UDim2.new(1, -40, 0, 18),
            BackgroundTransparency = 1,
            Font = Enum.Font.Gotham,
            Text = subtitle,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            ZIndex = 103,
        }, "TextMuted")
    end
    if content ~= "" and not hasBoxes then
        textLabel(self, card, {
            Position = UDim2.fromOffset(20, subtitle ~= "" and 70 or 50),
            Size = UDim2.new(1, -40, 0, 65),
            BackgroundTransparency = 1,
            Font = Enum.Font.Gotham,
            Text = content,
            TextSize = 12,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            ZIndex = 103,
        }, "TextMuted")
    end
    if hasBoxes then
        local boxList = instance("ScrollingFrame", {
            Position = UDim2.fromOffset(20, subtitle ~= "" and 68 or 48),
            Size = UDim2.new(1, -40, 0, cardHeight - (subtitle ~= "" and 124 or 104)),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 3,
            ZIndex = 103,
        }, card)
        listLayout(boxList, 6)
        padding(boxList, 0, 2, 0, 2)
        for index, box in ipairs(boxes) do
            local boxFrame = instance("Frame", {
                Name = "PopupBox_" .. index,
                Size = UDim2.new(1, 0, 0, 42),
                BackgroundColor3 = self.Theme.SurfaceRaised,
                BackgroundTransparency = self.Theme.RaisedTransparency,
                BorderSizePixel = 0,
                ZIndex = 104,
            }, boxList)
            corner(boxFrame, 8)
            self:_bind(boxFrame, "BackgroundColor3", "SurfaceRaised")
            local boxIcon = self:_makeIcon(boxFrame, opt(box, nil, "icon", "Icon"), 14, "Icon")
            if boxIcon then
                boxIcon.Position = UDim2.fromOffset(8, 14)
            end
            local boxTitle = asString(opt(box, "Update", "title", "Title"), "Update")
            local boxDescription = asString(opt(box, "", "description", "Description"), "")
            textLabel(self, boxFrame, {
                Position = UDim2.fromOffset(boxIcon and 30 or 10, 5),
                Size = UDim2.new(1, -(boxIcon and 38 or 18), 0, 16),
                BackgroundTransparency = 1,
                Font = Enum.Font.GothamSemibold,
                Text = boxTitle,
                TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Center,
                ZIndex = 105,
            }, "Text")
            textLabel(self, boxFrame, {
                Position = UDim2.fromOffset(boxIcon and 30 or 10, 21),
                Size = UDim2.new(1, -(boxIcon and 38 or 18), 0, 14),
                BackgroundTransparency = 1,
                Font = Enum.Font.Gotham,
                Text = boxDescription,
                TextSize = 9,
                TextTruncate = Enum.TextTruncate.AtEnd,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Center,
                ZIndex = 105,
            }, "TextMuted")
        end
    end
    local options = opt(properties, { { text = "Close" } }, "options", "Options")
    local buttonRow = instance("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 20, 1, -18),
        Size = UDim2.new(1, -40, 0, 38),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 103,
    }, card)
    listLayout(buttonRow, 8, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Right)
    local handle = {}
    local function close()
        if overlay and overlay.Parent then
            overlay:Destroy()
        end
    end
    handle.Close = close
    for index, option in ipairs(options) do
        local optionText = asString(opt(option, "Option", "text", "Text"), "Option")
        local style = string.lower(asString(opt(option, "neutral", "style", "Style"), "neutral"))
        local button = controlButton(buttonRow, "PopupOption_" .. index, {
            Size = UDim2.fromOffset(math.max(78, #optionText * 7 + 22), 34),
            BackgroundColor3 = style == "primary" and self.Theme.Accent or self.Theme.SurfaceRaised,
            BackgroundTransparency = style == "primary" and 0 or self.Theme.RaisedTransparency,
            ZIndex = 104,
        })
        corner(button, 8)
        stroke(button, style == "primary" and self.Theme.Accent or self.Theme.Border, 0.12, 1)
        self:_bind(button, "BackgroundColor3", style == "primary" and "Accent" or "SurfaceRaised")
        local label = textLabel(self, button, {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamSemibold,
            Text = optionText,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Center,
            ZIndex = 105,
        }, style == "primary" and "AccentContrast" or "Text")
        self:_connect(button.Activated, function()
            self:_safeCallback(opt(option, nil, "callback", "Callback"))
            close()
        end)
    end
    self:_connect(dismiss.Activated, function()
        if dismissable then
            close()
        end
    end)
    self:_connect(UserInputService.InputBegan, function(input)
        if input.KeyCode == Enum.KeyCode.Escape and dismissable then
            close()
        end
    end)
    return handle
end

function Window:Unload()
    if self.unloaded then
        return false
    end
    self.unloaded = true
    self._displayToken = (self._displayToken or 0) + 1
    self:_cancelAllTweens()
    if self._dropdownDismiss then
        pcall(function() self._dropdownDismiss:Destroy() end)
    end
    for _, connection in ipairs(self._connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    self._connections = {}
    if self.Gui then
        pcall(function()
            self.Gui:Destroy()
        end)
    end
    if Shared.windows[self.Id] == self then
        Shared.windows[self.Id] = nil
    end
    self._tabs = {}
    self._values = {}
    self.Flags = {}
    return true
end

function Surge:EnsureWorkspace()
    local paths = self.Distribution.ManagedPaths
    local result = { ok = true, created = {}, errors = {} }
    if type(isfolder) ~= "function" or type(makefolder) ~= "function" then
        return { ok = false, error = "Potassium isfolder/makefolder are unavailable" }
    end
    local function ensureFolder(path)
        local exists = false
        local checked = pcall(function()
            exists = isfolder(path)
        end)
        if checked and exists then
            return true
        end
        if type(isfile) == "function" then
            local fileExists = false
            pcall(function()
                fileExists = isfile(path)
            end)
            if fileExists then
                table.insert(result.errors, path .. " is a file")
                result.ok = false
                return false
            end
        end
        local made, errorMessage = pcall(makefolder, path)
        if made then
            table.insert(result.created, path)
            return true
        end
        table.insert(result.errors, path .. ": " .. tostring(errorMessage))
        result.ok = false
        return false
    end
    ensureFolder(paths.Root)
    ensureFolder(paths.Assets)
    ensureFolder(paths.Configs)
    ensureFolder(paths.Managed)
    if #result.errors > 0 then
        result.error = table.concat(result.errors, "; ")
    end
    return result
end

function Surge:EnsureAssets(options)
    options = options or {}
    local setup = self:EnsureWorkspace()
    if not setup.ok then
        return setup
    end
    if type(readfile) ~= "function" or type(writefile) ~= "function" or type(isfile) ~= "function" then
        return { ok = false, error = "Potassium readfile/writefile/isfile are unavailable", setup = setup }
    end
    local paths = self.Distribution.ManagedPaths
    local sources = self.Distribution.SourcePaths
    local distribution = self.Distribution
    local result = { ok = true, setup = setup, files = {} }
    local manifestValid = false
    if type(HttpService) == "userdata" or type(HttpService) == "table" then
        local ok, existing = pcall(readfile, paths.Manifest)
        if ok then
            local decodeOk, manifest = pcall(function() return HttpService:JSONDecode(existing) end)
            manifestValid = decodeOk and type(manifest) == "table"
                and manifest.assetVersion == distribution.AssetVersion
                and manifest.version == distribution.Version
        end
    end
    local function validSource(body, marker)
        if type(body) ~= "string" or body == "" or string.find(body, marker, 1, true) == nil then
            return false
        end
        if type(loadstring) == "function" then
            local chunk = loadstring(body, "@managed:" .. marker)
            return chunk ~= nil
        end
        return true
    end
    local function readValid(path, marker)
        local exists = false
        pcall(function()
            exists = isfile(path)
        end)
        if not exists then
            return nil
        end
        local ok, body = pcall(readfile, path)
        if ok and validSource(body, marker) then
            return body
        end
        return nil
    end
    local function requestBody(path)
        local requester = request or http_request or (http and http.request)
        if type(requester) ~= "function" then
            return nil, "Potassium request API is unavailable"
        end
        local repository = tostring(distribution.Repository or ""):gsub("/+$", "")
        local ref = tostring(distribution.Ref or "")
        if repository == "" or ref == "" then
            return nil, "GitHub repository/ref is not configured"
        end
        local responseOk, response = pcall(requester, {
            Url = repository .. "/raw/" .. ref .. "/" .. path,
            Method = "GET",
        })
        if not responseOk or type(response) ~= "table" then
            return nil, "GitHub request failed: " .. tostring(response)
        end
        if response.Success ~= true or tonumber(response.StatusCode) < 200 or tonumber(response.StatusCode) >= 300 then
            return nil, string.format("GitHub request returned HTTP %s", tostring(response.StatusCode))
        end
        if type(response.Body) ~= "string" or response.Body == "" then
            return nil, "GitHub response body is empty"
        end
        return response.Body
    end
    local function syncFile(name, managedPath, sourcePath, repositoryPath, marker)
        local cachedBody = readValid(managedPath, marker)
        local managedBody = manifestValid and cachedBody or nil
        local body = managedBody
        local source = managedBody and "cache" or nil
        if not body then
            local remoteBody
            local remoteError
            if tostring(distribution.Repository or "") ~= "" and tostring(distribution.Ref or "") ~= "" then
                remoteBody, remoteError = requestBody(repositoryPath)
            end
            if validSource(remoteBody, marker) then
                body = remoteBody
                source = "download"
            else
                local localBody = readValid(sourcePath, marker)
                if localBody then
                    body = localBody
                    source = "local"
                elseif cachedBody then
                    body = cachedBody
                    source = "stale-cache"
                elseif remoteError then
                    result.ok = false
                    result.error = remoteError
                    return false
                else
                    result.ok = false
                    result.error = name .. " is unavailable"
                    return false
                end
            end
            local wrote, writeError = pcall(writefile, managedPath, body)
            if not wrote then
                result.ok = false
                result.error = name .. " write failed: " .. tostring(writeError)
                return false
            end
        end
        result.files[name] = { path = managedPath, source = source or "cache" }
        return true
    end
    syncFile("Library", paths.Library, sources.Library, distribution.RepositoryPaths.Library, "return Surge")
    syncFile("LucideBridge", paths.LucideBridge, sources.LucideBridge, distribution.RepositoryPaths.LucideBridge, "return Bridge")
    if type(HttpService) == "userdata" or type(HttpService) == "table" then
        local manifest = {
            product = "Surge",
            assetVersion = distribution.AssetVersion,
            configSchema = "Surge.Config",
            version = distribution.Version,
            repository = distribution.Repository ~= "" and distribution.Repository or nil,
            ref = distribution.Ref ~= "" and distribution.Ref or nil,
            files = result.files,
        }
        local encodedOk, encoded = pcall(function()
            return HttpService:JSONEncode(manifest)
        end)
        if encodedOk then
            local existing = readValid(paths.Manifest, "{")
            if existing ~= encoded then
                pcall(writefile, paths.Manifest, encoded)
            end
        end
    end
    return result
end

function Surge:GetBootstrap()
    local distribution = self.Distribution
    local repository = tostring(distribution.Repository or ""):gsub("/+$", "")
    local ref = tostring(distribution.Ref or "")
    if repository == "" or ref == "" then
        return false, "Surge bootstrap repository/ref is unset; configure Surge.Distribution before publishing"
    end
    local quote = function(value)
        return string.format("%q", tostring(value))
    end
    local base = repository .. "/raw/" .. ref .. "/"
    local libraryUrl = base .. distribution.RepositoryPaths.Library
    local bridgeUrl = base .. distribution.RepositoryPaths.LucideBridge
    local paths = distribution.ManagedPaths
    local code = table.concat({
        "local function fetch(url, label)",
        "    local requester = request or http_request or (http and http.request)",
        "    assert(type(requester) == \"function\", \"Potassium request API is unavailable\")",
        "    local response = assert(requester({ Url = url, Method = \"GET\" }), label .. \" request failed\")",
        "    assert(response.Success == true and response.StatusCode >= 200 and response.StatusCode < 300, label .. \" HTTP \" .. tostring(response.StatusCode))",
        "    assert(type(response.Body) == \"string\" and response.Body ~= \"\", label .. \" response is empty\")",
        "    return response.Body",
        "end",
        "local function ensure(path)",
        "    local current = \"\"",
        "    for segment in path:gmatch(\"[^/]+\") do",
        "        current = current == \"\" and segment or (current .. \"/\" .. segment)",
        "        if not isfolder(current) then makefolder(current) end",
        "    end",
        "end",
        "local librarySource = fetch(" .. quote(libraryUrl) .. ", \"Surge library\")",
        "local bridgeSource = fetch(" .. quote(bridgeUrl) .. ", \"LucideBridge\")",
        "assert(loadstring(librarySource, \"@github:" .. ref .. "/" .. distribution.RepositoryPaths.Library .. "\"), \"Surge library failed to compile\")",
        "assert(loadstring(bridgeSource, \"@github:" .. ref .. "/" .. distribution.RepositoryPaths.LucideBridge .. "\"), \"LucideBridge failed to compile\")",
        "ensure(" .. quote(paths.Assets) .. ")",
        "ensure(" .. quote(paths.Managed) .. ")",
        "writefile(" .. quote(paths.Library) .. ", librarySource)",
        "writefile(" .. quote(paths.LucideBridge) .. ", bridgeSource)",
        "local chunk = assert(loadstring(librarySource, \"@github:" .. ref .. "/" .. distribution.RepositoryPaths.Library .. "\"))",
        "local Surge = chunk()",
        "assert(type(Surge) == \"table\" and type(Surge.Version) == \"string\", \"Surge library returned an invalid module\")",
        "return Surge",
    }, "\n")
    return code
end

function Surge:CreateWindow(properties)
    properties = properties or {}
    local name = asString(opt(properties, "Surge Window", "name", "Name"), "Surge Window")
    local id = safeName(opt(properties, name, "id", "Id"))
    local previous = Shared.windows[id]
    if previous and type(previous.Unload) == "function" then
        pcall(function()
            previous:Unload()
        end)
    end
    local theme = opt(properties, nil, "theme", "Theme")
    if type(theme) == "string" then
        theme = Surge.Themes[theme]
    end
    local window = setmetatable({
        Name = name,
        Id = id,
        Subtitle = asString(opt(properties, "", "subtitle", "Subtitle", "LoadingSubtitle"), ""),
        Logo = opt(properties, "Zap", "logo", "Logo", "icon", "Icon") or "Zap",
        ShowName = asString(opt(properties, "Surge", "showName", "ShowName"), "Surge"),
        Profile = asString(opt(properties, "", "profile", "Profile"), ""),
        ToggleKeybind = opt(properties, nil, "toggleKeybind", "ToggleKeybind"),
        Width = clamp(tonumber(opt(properties, 680, "width", "Width")) or 680, 520, 980),
        Height = clamp(tonumber(opt(properties, 440, "height", "Height")) or 440, 330, 760),
        SidebarWidth = clamp(tonumber(opt(properties, 142, "sidebarWidth", "SidebarWidth")) or 142, 120, 240),
        CornerRadius = tonumber(opt(properties, 14, "cornerRadius", "CornerRadius")) or 14,
        Theme = mergeTables(DefaultTheme, theme or {}),
        _bindings = {},
        _refreshers = {},
        _connections = {},
        _tweens = {},
        _displayState = "shown",
        _displayToken = 0,
        _displayRootPosition = nil,
        _displayRootSize = nil,
        _displayShadowPosition = nil,
        _displayShadowSize = nil,
        _displayBodyVisible = true,
        _displayVisuals = nil,
        _copyBindings = {},
        _translations = copyTable(opt(properties, {}, "translations", "Translations")),
        _translator = opt(properties, nil, "translator", "Translator"),
        Locale = asString(opt(properties, "en", "locale", "Locale"), "en"),
        _tabs = {},
        _values = {},
        Flags = {},
        _configErrors = {},
        _configDefaults = {},
        _configSaveToken = 0,
        _configSaveTask = nil,
        _pendingConfig = {},
        _activeTab = nil,
        _onError = opt(properties, nil, "onError", "OnError"),
        unloaded = false,
        _minimised = false,
        Configuration = {
            Version = 1,
            Enabled = false,
            CallbacksOnLoad = false,
            AutoSave = false,
            AutoLoad = false,
            SaveDelay = 0.35,
            ScriptId = id,
            FolderName = ".Surge/configs",
            FileName = id,
        },
    }, Window)
    local configuration = opt(properties, nil, "configuration", "Configuration", "ConfigurationSaving")
    if type(configuration) == "table" then
        window.Configuration.Version = tonumber(opt(configuration, 1, "version", "Version")) or 1
        window.Configuration.ScriptId = pathSegment(opt(configuration, id, "scriptId", "ScriptId"))
        window.Configuration.Enabled = opt(configuration, false, "enabled", "Enabled") == true
        window.Configuration.CallbacksOnLoad = opt(configuration, false, "callbacksOnLoad", "CallbacksOnLoad", "callbackOnLoad", "CallbackOnLoad") == true
        window.Configuration.AutoSave = opt(configuration, false, "autoSave", "AutoSave") == true
        window.Configuration.AutoLoad = opt(configuration, false, "autoLoad", "AutoLoad") == true
        window.Configuration.SaveDelay = math.max(0.05, tonumber(opt(configuration, 0.35, "saveDelay", "SaveDelay")) or 0.35)
        local defaultFolder = window.Configuration.Version == 2 and Surge.Distribution.ManagedPaths.Configs or ".Surge/configs"
        window.Configuration.FolderName = opt(configuration, defaultFolder, "customFolder", "CustomFolder", "FolderName")
        window.Configuration.FileName = opt(configuration, id, "fileName", "FileName")
    end
    pcall(function()
        Surge:EnsureAssets()
    end)
    window:_build(properties)
    Shared.windows[id] = window
    if window.Configuration.Enabled and window.Configuration.AutoLoad then
        task.defer(function()
            if not window.unloaded then
                window:Load()
            end
        end)
    end
    return window
end

function Surge:Destroy(id)
    local key = safeName(id)
    local window = Shared.windows[key]
    if window and type(window.Unload) == "function" then
        return window:Unload()
    end
    return false
end

function Surge:DestroyAll()
    local windows = {}
    for _, window in pairs(Shared.windows) do
        table.insert(windows, window)
    end
    for _, window in ipairs(windows) do
        if window and type(window.Unload) == "function" then
            pcall(function()
                window:Unload()
            end)
        end
    end
end

function Surge:GetWindow(id)
    return Shared.windows[safeName(id)]
end

function Surge:GetVersion()
    return self.Version
end

for name, definition in pairs(Shared.icons) do
    if not ICONS[name] then
        ICONS[name] = definition
    end
end
Tab.CreateSwitch = Tab.CreateToggle
Window.CreateNotification = Window.Notify
Window.CreateToast = Window.Toast


return Surge
