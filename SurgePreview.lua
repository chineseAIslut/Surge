-- SurgePreview.lua
-- Execute through a Potassium script runner. The library itself is loaded from
-- the documented workspace-relative .Surge/Surge.lua path.

local function loadSurge()
    assert(type(readfile) == "function", "SurgePreview requires Potassium readfile()")
    assert(type(loadstring) == "function", "SurgePreview requires Potassium loadstring()")
    local source = readfile(".Surge/Surge.lua")
    local chunk, compileError = loadstring(source, "@.Surge/Surge.lua")
    assert(chunk, compileError)
    return chunk()
end

local environment = type(getgenv) == "function" and getgenv() or _G
local previous = rawget(environment, "__SURGE_PREVIEW_WINDOW")
if previous and type(previous.Unload) == "function" then
    pcall(function()
        previous:Unload()
    end)
end

local Surge = loadSurge()
local window = Surge:CreateWindow({
    id = "SurgePreview",
    name = "Surge Preview",
    subtitle = "Monochrome component gallery",
    logo = "Zap",
    showName = "Surge",
    profile = "Potassium / stable preview",
    toggleKeybind = "RightShift",
    locale = "en",
    translations = {
        de = {
            ["Surge Preview"] = "Surge Vorschau",
            ["Monochrome component gallery"] = "Monochrome Komponenten",
            ["Core controls"] = "Kernsteuerung",
            ["Callbacks observed"] = "Callbacks beobachtet",
        },
    },
    configuration = {
        version = 2,
        enabled = true,
        scriptId = "SurgePreview",
        callbacksOnLoad = false,
        autoSave = false,
        autoLoad = false,
        customFolder = "Surge/Configs",
        fileName = "SurgePreview",
    },
})

environment.__SURGE_PREVIEW_WINDOW = window
window:CreateSection({ name = "Core surface", icon = "Zap" })
window:CreateTag({ text = "PREVIEW", icon = "Activity", order = 1 })
window:CreateTag({ text = "MONO ", icon = "PanelLeft", order = 2 })
window:SetProfile("Potassium / stable preview")

local state = { events = 0 }
local eventConsole
local function logEvent(message)
    state.events = state.events + 1
    if eventConsole then
        eventConsole:Append(string.format("[%02d] %s", state.events, tostring(message)))
    end
end

local handles = {}

local overview = window:CreateTab({ name = "Overview", icon = "House" })
overview:CreateSection({ name = "Core controls", icon = "SlidersHorizontal" })
overview:CreateText({
    name = "Surge is online",
    text = "This page intentionally contains longer copy so the tab scroll area and rounded outlines remain visible at compact window sizes. Every active control reports through the callback log.",
    icon = "Zap",
})

handles.button = overview:CreateButton({
    name = "Send callback feedback",
    description = "Fires a notification, toast, and console entry.",
    icon = "Bell",
    callback = function()
        logEvent("button callback")
        window:Toast({ title = "Button fired", subtitle = "Callback completed", icon = "Check" })
        window:Notify({ title = "Surge callback", content = "The button callback reached the script.", icon = "Info", duration = 4 })
    end,
})
handles.toggle = overview:CreateToggle({
    name = "Feature toggle",
    description = "Boolean value with a live callback.",
    value = false,
    flag = "FeatureToggle",
    icon = "ToggleRight",
    callback = function(value)
        logEvent("toggle = " .. tostring(value))
    end,
})
handles.slider = overview:CreateSlider({
    name = "Response threshold",
    description = "Snaps to five-point increments.",
    range = { 0, 100 },
    increment = 5,
    value = 35,
    suffix = "%",
    flag = "ResponseThreshold",
    icon = "SlidersHorizontal",
    callback = function(value, dragging)
        if not dragging then
            logEvent("slider = " .. tostring(value))
        end
    end,
})
handles.profile = overview:CreateDropdown({
    name = "Active profile",
    description = "Single select returns a string to the callback.",
    options = { "Observe", "Operate", "Inspect" },
    value = "Observe",
    flag = "ActiveProfile",
    icon = "PanelLeft",
    callback = function(value)
        logEvent("profile = " .. tostring(value))
    end,
})
handles.modules = overview:CreateDropdown({
    name = "Visible modules",
    description = "Multi select returns a copied table.",
    options = { "Input", "State", "Output", "Storage" },
    value = { "Input", "Output" },
    multiSelect = true,
    flag = "VisibleModules",
    icon = "Settings",
    callback = function(values)
        logEvent("modules = " .. table.concat(values, ", "))
    end,
})
handles.note = overview:CreateInput({
    name = "Operator note",
    description = "Commits on focus loss or Enter.",
    value = "ready",
    placeholder = "Type a note",
    flag = "OperatorNote",
    icon = "Terminal",
    callback = function(value)
        logEvent("input = " .. tostring(value))
    end,
})
handles.numeric = overview:CreateInput({
    name = "Numeric limit",
    description = "Malformed numeric text restores the previous value.",
    value = "12",
    placeholder = "Enter a number",
    numeric = true,
    flag = "NumericLimit",
    icon = "CircleGauge",
    callback = function(value)
        logEvent("numeric = " .. tostring(value))
    end,
})
handles.keybind = overview:CreateKeybind({
    name = "Preview hotkey",
    description = "Escape cancels capture; Backspace clears it.",
    value = "F6",
    flag = "PreviewHotkey",
    icon = "Keyboard",
    callback = function(value)
        logEvent("keybind pressed = " .. tostring(value))
    end,
    onChanged = function(value)
        logEvent("keybind changed = " .. tostring(value))
    end,
})
handles.color = overview:CreateColorPicker({
    name = "Grayscale accent",
    description = "The palette remains black, white, and grayscale.",
    color = Color3.fromRGB(220, 220, 224),
    alpha = 0.85,
    flag = "GrayscaleAccent",
    icon = "Palette",
    callback = function(color, alpha)
        logEvent(string.format("color = %.2f alpha = %.2f", color.R, alpha))
    end,
})
local divider = overview:CreateDivider({ text = "interactive", spacing = 20 })
overview:CreateText({
    name = "Aliases",
    text = "CreateLabel, CreateParagraph, and CreateSwitch are compatibility aliases. Use MoveTo and MoveUp on handles to reorder rows.",
    icon = "Info",
})

local components = window:CreateTab({ name = "Components", icon = "PanelLeft" })
components:CreateSection({ name = "States and composition", icon = "Settings" })
local lockedButton = components:CreateButton({
    name = "Locked action",
    description = "This button demonstrates the locked state.",
    icon = "Settings",
    callback = function()
        logEvent("locked action fired")
    end,
})
lockedButton:Lock("Unlock it from the controls below")
handles.lockedButton = lockedButton
local unlockButton = components:CreateButton({
    name = "Unlock action",
    description = "Unlocks the preceding button through its handle.",
    icon = "Keyboard",
    callback = function()
        lockedButton:Unlock()
        logEvent("locked action unlocked")
    end,
})
handles.unlockButton = unlockButton
local switch = components:CreateSwitch({
    name = "Alias switch",
    description = "CreateSwitch delegates to CreateToggle.",
    value = true,
    icon = "ToggleRight",
    callback = function(value)
        logEvent("alias switch = " .. tostring(value))
    end,
})
handles.switch = switch
components:CreateLabel({ name = "Title-only label", icon = "Terminal" })
components:CreateParagraph({ text = "Body-only paragraph with a longer sentence that stays readable inside a scrolling tab." })
local labelledDivider = components:CreateDivider({ text = "states", spacing = 22 })
components:CreateButton({
    name = "Rename divider",
    description = "Uses Divider:Set(text) and keeps the line visible.",
    icon = "Minus",
    callback = function()
        labelledDivider:Set("updated divider")
        logEvent("divider text updated")
    end,
})
local grid = components:CreateGroup()
local left = grid:CreateGroup({ direction = "column" })
left:CreateToggle({ name = "Nested left toggle", value = true, icon = "ToggleRight", callback = function(v) logEvent("left = " .. tostring(v)) end })
left:CreateSlider({ name = "Nested left slider", range = { 0, 10 }, value = 4, increment = 1, icon = "SlidersHorizontal", callback = function(v) logEvent("nested slider = " .. tostring(v)) end })
local right = grid:CreateGroup({ direction = "column" })
right:CreateDropdown({ name = "Nested dropdown", options = { "One", "Two", "Three" }, value = "Two", icon = "ChevronDown", callback = function(v) logEvent("nested dropdown = " .. tostring(v)) end })
right:CreateStat({ name = "Nested stat", value = 14, prefix = "#", icon = "CircleGauge" })
components:CreateText({
    name = "Long-form content",
    text = string.rep("Surge keeps copy inside normal text rows and lets the surrounding ScrollingFrame carry overflow. ", 8),
    icon = "Terminal",
})

local telemetry = window:CreateTab({ name = "Telemetry", icon = "Activity" })
telemetry:CreateSection({ name = "Read-only and output", icon = "CircleGauge" })
handles.stat = telemetry:CreateStat({
    name = "Callbacks observed",
    description = "Updates show positive and negative deltas.",
    value = 0,
    suffix = " events",
    icon = "CircleGauge",
})
handles.progress = telemetry:CreateProgress({
    name = "Preview stages",
    description = "Segmented progress supports range and formatter output.",
    range = { 0, 5 },
    steps = 5,
    value = 2,
    icon = "Activity",
})
handles.indeterminate = telemetry:CreateProgress({
    name = "Background sync",
    description = "Indeterminate mode sweeps until Set is called.",
    indeterminate = true,
    showValue = false,
    icon = "RefreshCw",
})
eventConsole = telemetry:CreateConsole({
    name = "Callback log",
    description = "Append, Set, Clear, Get, Copy, SetHeight, follow, and maxLines.",
    height = 156,
    follow = true,
    maxLines = 120,
    text = table.concat({ "Preview loaded", "Long content begins below:", string.rep("diagnostic line / ", 8) }, "\n"),
    icon = "Terminal",
})
handles.console = eventConsole
telemetry:CreateButton({
    name = "Advance telemetry",
    description = "Drives stat, progress, indeterminate, and console handles.",
    icon = "RefreshCw",
    callback = function()
        handles.stat:Set(state.events)
        handles.progress:Set(math.min(5, 2 + state.events))
        handles.indeterminate:Set(1)
        eventConsole:Append("telemetry refreshed")
        window:Toast({ title = "Telemetry updated", subtitle = "Bottom toast", icon = "Activity", position = "Bottom" })
    end,
})
telemetry:CreateButton({
    name = "Exercise console methods",
    description = "Calls SetHeight, Copy, Get, and Clear without hiding the console.",
    icon = "Copy",
    callback = function()
        eventConsole:SetHeight(180)
        eventConsole:Append("console methods exercised")
        logEvent("console length = " .. tostring(#eventConsole:Get()))
        eventConsole:Copy()
    end,
})
telemetry:CreateButton({
    name = "Open changelog popup",
    description = "Shows boxes, a scrollable list, and neutral/primary/danger options.",
    icon = "Info",
    callback = function()
        local popup = window:Popup({
            title = "What's new",
            subtitle = "Surge enhancement pass",
            boxes = {
                { title = "Stable handles", description = "Value controls can be reordered and locked.", icon = "Check" },
                { title = "Monochrome rendering", description = "Local line icons avoid remote asset assumptions.", icon = "Zap" },
                { title = "Long content", description = "Tabs, console, dropdowns, and boxes scroll internally.", icon = "Terminal" },
            },
            options = {
                { text = "Cancel", style = "neutral" },
                { text = "Inspect", style = "danger", callback = function() logEvent("popup danger option") end },
                { text = "Got it", style = "primary", callback = function() logEvent("popup confirmed") end },
            },
        })
        handles.popup = popup
    end,
})

local lifecycle = window:CreateTab({ name = "Lifecycle", icon = "Settings" })
lifecycle:CreateSection({ name = "Runtime controls", icon = "PanelLeft" })
lifecycle:CreateText({
    name = "Repeatable load",
    text = "Run this preview again to unload the prior SurgePreview instance. The close button and Unload preview button both disconnect tracked connections and destroy the ScreenGui.",
    icon = "RefreshCw",
})
lifecycle:CreateButton({
    name = "Apply grayscale theme",
    description = "Exercises a partial live theme update.",
    icon = "Palette",
    callback = function()
        window:ChangeTheme({ Surface = Color3.fromRGB(24, 24, 27), SurfaceRaised = Color3.fromRGB(34, 34, 38), TextMuted = Color3.fromRGB(170, 170, 176) })
        window:Toast({ title = "Theme refreshed", subtitle = "Graphite values applied", icon = "Check" })
    end,
})
lifecycle:CreateButton({
    name = "Translate labels",
    description = "Registers German strings and applies the locale to tracked copy.",
    icon = "Info",
    callback = function()
        window:RegisterTranslations({ de = { ["Repeatable load"] = "Wiederholbares Laden", ["Runtime controls"] = "Laufzeitsteuerung" } })
        window:SetLocale("de")
        window:Toast({ title = "Locale set", subtitle = "Tracked copy refreshed", icon = "Check" })
    end,
})
local function addAnimationScenarios()
    lifecycle:CreateButton({
        name = "Rapid tab changes",
        description = "Switches tabs repeatedly; the last target must remain visible and usable.",
        icon = "PanelLeft",
        callback = function()
            window:Navigate("Components")
            window:Navigate("Telemetry")
            window:Navigate("Overview")
            task.delay(Surge.Animation.Tab + 0.05, function()
                if not window.unloaded then
                    logEvent("rapid tabs settled; final = Overview")
                end
            end)
        end,
    })
    lifecycle:CreateButton({
        name = "Notification burst",
        description = "Stacks six notifications and toasts, including long wrapped copy and repeated Close.",
        icon = "Bell",
        callback = function()
            for index = 1, 6 do
                local longCopy = index == 6
                local notification = window:Notify({
                    title = longCopy and string.rep("Long notice title ", 8) or ("Notice " .. index),
                    content = longCopy and "Line one\nLine two with enough text to wrap inside the viewport." or ("Animated notification " .. index),
                    duration = 2.2,
                })
                local toast = window:Toast({
                    title = longCopy and string.rep("Long toast title ", 8) or ("Toast " .. index),
                    subtitle = longCopy and "Line one\nLine two with enough text to wrap inside the available viewport." or "Animated stack",
                    icon = "Check",
                    duration = 2.2,
                })
                if longCopy then
                    task.delay(0.4, function()
                        notification:Close()
                        notification:Close()
                        toast:Close()
                        toast:Close()
                    end)
                end
            end
            logEvent("notification burst = 6")
        end,
    })
    lifecycle:CreateButton({
        name = "Rapid hide/show",
        description = "Reverses the menu morph repeatedly and leaves the menu shown.",
        icon = "RefreshCw",
        callback = function()
            window:Hide()
            task.delay(0.08, function()
                if window.unloaded then
                    return
                end
                window:Show()
                task.delay(0.08, function()
                    if window.unloaded then
                        return
                    end
                    window:Hide()
                    task.delay(Surge.Animation.Menu + Surge.Animation.Fast + 0.12, function()
                        if not window.unloaded then
                            window:Show()
                            logEvent("rapid hide/show complete")
                        end
                    end)
                end)
            end)
        end,
    })
end
addAnimationScenarios()
lifecycle:CreateText({
    name = "Animation smoke checks",
    text = "Use Rapid tab changes, Notification burst, and Rapid hide/show. After each transition only the latest tab or display endpoint should remain visible and interactive.",
    icon = "Activity",
})

lifecycle:CreateButton({
    name = "Move callback log",
    description = "Moves the telemetry tab's console row to the bottom of its page.",
    icon = "PanelLeft",
    callback = function()
        if handles.console then
            handles.console:MoveToBottom()
            logEvent("console moved to bottom")
        end
    end,
})
lifecycle:CreateButton({
    name = "Save and list config",
    description = "Uses workspace-relative JSON persistence and reports results in the callback log.",
    icon = "Check",
    callback = function()
        local saved, saveError = window:Save()
        local configs = window:ListConfigs()
        logEvent("save = " .. tostring(saved) .. (saveError and (" (" .. tostring(saveError) .. ")") or ""))
        logEvent("configs = " .. table.concat(configs, ", "))
    end,
})
lifecycle:CreateButton({
    name = "Load config",
    description = "Loads the namespaced v2 config without firing callbacks by default.",
    icon = "RefreshCw",
    callback = function()
        local loaded, loadResult = window:Load()
        logEvent("load = " .. tostring(loaded) .. (loadResult and (" applied=" .. tostring(loadResult.applied or 0)) or ""))
    end,
})
lifecycle:CreateButton({
    name = "Reset defaults",
    description = "Restores registered values in memory without writing a config.",
    icon = "Undo",
    callback = function()
        window:ResetDefaults({ callback = false, save = false })
        logEvent("defaults reset")
    end,
})
lifecycle:CreateButton({
    name = "Hide then show",
    description = "Exercises the collapsed pill path and restores the window.",
    icon = "PanelLeft",
    callback = function()
        window:Hide()
        task.delay(Surge.Animation.Menu + Surge.Animation.Fast + 0.12, function()
            if not window.unloaded then
                window:Show()
                logEvent("window shown after hide")
            end
        end)
    end,
})
lifecycle:CreateButton({
    name = "Unload preview",
    description = "Destroys the ScreenGui and disconnects tracked input/render connections.",
    icon = "X",
    callback = function()
        window:Unload()
        environment.__SURGE_PREVIEW_WINDOW = nil
        environment.__SURGE_PREVIEW_HANDLES = nil
    end,
})

window:Notify({ title = "Surge Preview loaded", content = "Four populated tabs cover controls, components, telemetry, and lifecycle.", icon = "Zap", duration = 6 })
window:Toast({ title = "Ready", subtitle = "All Surge surfaces mounted", icon = "Check", duration = 4 })

handles.window = window
handles.divider = divider
handles.eventCount = state
handles.telemetry = telemetry
handles.lifecycle = lifecycle
environment.__SURGE_PREVIEW_HANDLES = handles

-- Exercise safe, non-destructive initial state changes without hiding controls.
handles.stat:Set(0)
handles.progress:Set(2)

return window
