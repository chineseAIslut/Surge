-- Final-Surge-Preview.lua
-- GitHub-only release preview for Surge v0.1.0.
-- No local development files or absolute paths are used.

local BOOTSTRAP_URL = "https://raw.githubusercontent.com/chineseAIslut/Surge/v0.1.0/SurgeBootstrap.lua"
local RELEASE_REF = "v0.1.0"

local function fail(message)
    local text = "[Final-Surge-Preview] " .. tostring(message)
    if type(warn) == "function" then
        pcall(warn, text)
    end
    if type(rconsoleerror) == "function" then
        pcall(rconsoleerror, text)
    end
    error(text, 0)
end

local function requestText(url)
    local requester = request or http_request or (http and http.request)
    if type(requester) ~= "function" then
        fail("Potassium request API is unavailable")
    end
    local ok, response = pcall(requester, {
        Url = url,
        Method = "GET",
    })
    if not ok or type(response) ~= "table" then
        fail("GitHub request failed: " .. tostring(response))
    end
    if response.Success ~= true or tonumber(response.StatusCode) < 200 or tonumber(response.StatusCode) >= 300 then
        fail("GitHub returned HTTP " .. tostring(response.StatusCode))
    end
    if type(response.Body) ~= "string" or response.Body == "" then
        fail("GitHub returned an empty bootstrap")
    end
    return response.Body
end

local function loadPublishedSurge()
    local bootstrapSource = requestText(BOOTSTRAP_URL)
    local bootstrapChunk, compileError = loadstring(
        bootstrapSource,
        "@github:chineseAIslut/Surge/" .. RELEASE_REF .. "/SurgeBootstrap.lua"
    )
    if not bootstrapChunk then
        fail("GitHub bootstrap failed to compile: " .. tostring(compileError))
    end
    local ok, Surge = pcall(bootstrapChunk)
    if not ok then
        fail("GitHub bootstrap failed: " .. tostring(Surge))
    end
    if type(Surge) ~= "table" or Surge.Version ~= "0.1.0" then
        fail("GitHub bootstrap returned an unexpected Surge version")
    end
    return Surge
end

local loaded, SurgeOrError = pcall(loadPublishedSurge)
if not loaded then
    fail(SurgeOrError)
end
local Surge = SurgeOrError
local distribution = Surge.Distribution or {}
if distribution.Repository ~= "https://github.com/chineseAIslut/Surge" or distribution.Ref ~= RELEASE_REF then
    fail("GitHub provenance mismatch")
end
local assetStatus = Surge:EnsureAssets()
if not assetStatus or assetStatus.ok ~= true then
    fail("Published asset setup failed: " .. tostring(assetStatus and assetStatus.error or "unknown error"))
end
for name, fileStatus in pairs(assetStatus.files or {}) do
    if fileStatus.source == "local" then
        fail("Published asset setup silently fell back to local development source: " .. tostring(name))
    end
end

local environment = type(getgenv) == "function" and getgenv() or _G
local previous = rawget(environment, "__FINAL_SURGE_PREVIEW_WINDOW")
if previous and type(previous.Unload) == "function" then
    pcall(function()
        previous:Unload()
    end)
end

environment.__FINAL_SURGE_PREVIEW_WINDOW = nil

environment.__FINAL_SURGE_PREVIEW_HANDLES = nil

local window = Surge:CreateWindow({
    id = "FinalSurgePreview",
    name = "Final Surge Preview",
    subtitle = "GitHub release v0.1.0",
    logo = "Zap",
    showName = "Surge",
    profile = "GitHub / Potassium",
    toggleKeybind = "RightShift",
    configuration = {
        version = 2,
        enabled = true,
        scriptId = "FinalSurgePreview",
        callbacksOnLoad = false,
        autoSave = false,
        autoLoad = false,
        customFolder = "Surge/Configs",
        fileName = "FinalSurgePreview",
    },
})

environment.__FINAL_SURGE_PREVIEW_WINDOW = window
window:CreateSection({ name = "Release surface", icon = "Zap" })
window:CreateTag({ text = "GITHUB", icon = "Check", order = 1 })
window:CreateTag({ text = "v0.1.0", icon = "Activity", order = 2 })
window:SetProfile("Pinned release / " .. RELEASE_REF)

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
overview:CreateSection({ name = "Controls", icon = "SlidersHorizontal" })
overview:CreateText({
    name = "Published release loaded",
    text = "This preview came from the pinned GitHub bootstrap. Every editable value below has a stable v2 config flag.",
    icon = "Check",
})
handles.button = overview:CreateButton({
    name = "Send callback feedback",
    description = "Shows a notification, toast, and console event.",
    icon = "Bell",
    callback = function()
        logEvent("button callback")
        window:Toast({ title = "Button fired", subtitle = "Callback completed", icon = "Check" })
        window:Notify({ title = "Callback reached the script", content = "The published Surge release handled the callback.", icon = "Info", duration = 4 })
    end,
})
handles.toggle = overview:CreateToggle({
    name = "Feature toggle",
    description = "Persistent boolean value.",
    value = false,
    flag = "FeatureToggle",
    icon = "ToggleRight",
    callback = function(value)
        logEvent("toggle = " .. tostring(value))
    end,
})
handles.slider = overview:CreateSlider({
    name = "Response threshold",
    description = "Range 0..100 with five-point increments.",
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
    description = "Single-select persistent value.",
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
    description = "Multi-select returns a copied table.",
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
    description = "Saved text value committed on focus loss.",
    value = "ready",
    placeholder = "Type a note",
    flag = "OperatorNote",
    icon = "Terminal",
    callback = function(value)
        logEvent("note = " .. tostring(value))
    end,
})
handles.numeric = overview:CreateInput({
    name = "Numeric limit",
    description = "Numeric input rejects malformed values.",
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
    description = "Escape cancels; Backspace clears the bind.",
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
    description = "Color and alpha are persisted together.",
    color = Color3.fromRGB(220, 220, 224),
    alpha = 0.85,
    flag = "GrayscaleAccent",
    icon = "Palette",
    callback = function(color, alpha)
        logEvent(string.format("color = %.2f alpha = %.2f", color.R, alpha))
    end,
})
overview:CreateDivider({ text = "Aliases", spacing = 20 })
overview:CreateText({
    text = "The published API also exposes CreateSwitch, CreateLabel, CreateParagraph, and PascalCase option aliases.",
    icon = "Info",
})

local components = window:CreateTab({ name = "Components", icon = "PanelLeft" })
components:CreateSection({ name = "Composition and states", icon = "Settings" })
local locked = components:CreateButton({
    name = "Locked action",
    description = "Unlock it with the neighboring action.",
    icon = "Lock",
    callback = function() logEvent("locked action fired") end,
})
locked:Lock("Unlock it first")
components:CreateButton({
    name = "Unlock action",
    description = "Calls Unlock on the locked handle.",
    icon = "Key",
    callback = function()
        locked:Unlock()
        logEvent("locked action unlocked")
    end,
})
components:CreateSwitch({
    name = "Switch alias",
    description = "CreateSwitch delegates to CreateToggle.",
    value = true,
    flag = "AliasSwitch",
    icon = "ToggleRight",
    callback = function(value) logEvent("switch = " .. tostring(value)) end,
})
components:CreateLabel({ name = "Title-only label", icon = "Terminal" })
components:CreateParagraph({ text = "Body-only paragraph rendered inside a normal scrolling tab." })
local divider = components:CreateDivider({ text = "nested", spacing = 20 })
local group = components:CreateGroup()
local left = group:CreateGroup({ direction = "column" })
left:CreateToggle({ name = "Nested toggle", value = true, flag = "NestedToggle", icon = "ToggleRight", callback = function(value) logEvent("nested toggle = " .. tostring(value)) end })
left:CreateSlider({ name = "Nested slider", range = { 0, 10 }, value = 4, increment = 1, flag = "NestedSlider", icon = "SlidersHorizontal", callback = function(value) logEvent("nested slider = " .. tostring(value)) end })
local right = group:CreateGroup({ direction = "column" })
right:CreateDropdown({ name = "Nested dropdown", options = { "One", "Two", "Three" }, value = "Two", flag = "NestedDropdown", icon = "ChevronDown", callback = function(value) logEvent("nested dropdown = " .. tostring(value)) end })
right:CreateStat({ name = "Nested stat", value = 14, prefix = "#", icon = "CircleGauge" })
components:CreateButton({
    name = "Rename divider",
    description = "Demonstrates Divider:Set.",
    icon = "Minus",
    callback = function()
        divider:Set("updated divider")
        logEvent("divider renamed")
    end,
})

local telemetry = window:CreateTab({ name = "Telemetry", icon = "Activity" })
telemetry:CreateSection({ name = "Output and progress", icon = "CircleGauge" })
handles.stat = telemetry:CreateStat({ name = "Callbacks observed", value = 0, suffix = " events", icon = "CircleGauge" })
handles.progress = telemetry:CreateProgress({ name = "Preview stages", range = { 0, 5 }, steps = 5, value = 2, icon = "Activity" })
handles.indeterminate = telemetry:CreateProgress({ name = "Background sync", indeterminate = true, showValue = false, icon = "RefreshCw" })
eventConsole = telemetry:CreateConsole({
    name = "Callback log",
    height = 156,
    follow = true,
    maxLines = 120,
    text = "Final Preview loaded\nGitHub release: " .. RELEASE_REF,
    icon = "Terminal",
})
handles.console = eventConsole
telemetry:CreateButton({
    name = "Advance telemetry",
    description = "Updates stat, progress, indeterminate state, and console.",
    icon = "RefreshCw",
    callback = function()
        handles.stat:Set(state.events)
        handles.progress:Set(math.min(5, 2 + state.events))
        handles.indeterminate:Set(1)
        eventConsole:Append("telemetry refreshed")
        window:Toast({ title = "Telemetry updated", subtitle = "Bottom toast", position = "Bottom", icon = "Activity" })
    end,
})
telemetry:CreateButton({
    name = "Open popup",
    description = "Displays boxes and neutral/primary/danger options.",
    icon = "Info",
    callback = function()
        window:Popup({
            title = "Published release",
            subtitle = "Surge v0.1.0 from GitHub",
            boxes = {
                { title = "Workspace setup", description = "Managed assets and configs are prepared automatically.", icon = "Check" },
                { title = "Typed configs", description = "Flags, validation, reset, and callback policy are available.", icon = "Save" },
                { title = "Local fallback", description = "Existing compatible caches are reused when downloads fail.", icon = "RefreshCw" },
            },
            options = {
                { text = "Close", style = "neutral" },
                { text = "Confirm", style = "primary", callback = function() logEvent("popup confirmed") end },
            },
        })
    end,
})

local lifecycle = window:CreateTab({ name = "Lifecycle", icon = "Settings" })
lifecycle:CreateSection({ name = "Release and config", icon = "PanelLeft" })
lifecycle:CreateText({
    name = "GitHub provenance",
    text = "This window was loaded through SurgeBootstrap.lua at the pinned v0.1.0 release. No local development path is used.",
    icon = "Check",
})
lifecycle:CreateButton({
    name = "Save config",
    description = "Saves the namespaced FinalSurgePreview config.",
    icon = "Save",
    callback = function()
        local ok, saveError = window:Save()
        local folder, path = window:GetPath()
        logEvent("save = " .. tostring(ok) .. " path = " .. tostring(path) .. (saveError and (" (" .. tostring(saveError) .. ")") or ""))
        logEvent("folder = " .. tostring(folder))
    end,
})
lifecycle:CreateButton({
    name = "Load config",
    description = "Restores values without callbacks by default.",
    icon = "RefreshCw",
    callback = function()
        local ok, summary = window:Load()
        logEvent("load = " .. tostring(ok) .. " applied = " .. tostring(summary and summary.applied or 0))
    end,
})
lifecycle:CreateButton({
    name = "Reset defaults",
    description = "Restores registered defaults without writing a file.",
    icon = "RefreshCw",
    callback = function()
        window:ResetDefaults({ callback = false, save = false })
        logEvent("defaults reset")
    end,
})
lifecycle:CreateButton({
    name = "Burst notifications",
    description = "Creates six messages including wrapped long content and repeated Close.",
    icon = "Bell",
    callback = function()
        for index = 1, 6 do
            local longCopy = index == 6
            local notice = window:Notify({
                title = longCopy and string.rep("Long notice ", 8) or ("Notice " .. index),
                content = longCopy and "Line one\nLine two with enough text to wrap." or "GitHub-loaded notification.",
                duration = 2.2,
            })
            local toast = window:Toast({
                title = longCopy and string.rep("Long toast ", 8) or ("Toast " .. index),
                subtitle = longCopy and "Line one\nLine two with enough text to wrap inside the viewport." or "Stacked release message",
                duration = 2.2,
                icon = "Check",
            })
            if longCopy then
                task.delay(0.4, function()
                    notice:Close()
                    notice:Close()
                    toast:Close()
                    toast:Close()
                end)
            end
        end
        logEvent("notification burst complete")
    end,
})
lifecycle:CreateButton({
    name = "Rapid tab changes",
    description = "Selects three tabs quickly; the last tab must remain active.",
    icon = "PanelLeft",
    callback = function()
        window:Navigate("Components")
        window:Navigate("Telemetry")
        window:Navigate("Overview")
        task.delay(Surge.Animation.Tab + 0.05, function()
            if not window.unloaded then logEvent("rapid tabs settled on Overview") end
        end)
    end,
})
lifecycle:CreateButton({
    name = "Hide then show",
    description = "Reverses the GitHub-loaded menu morph and restores the saved position.",
    icon = "RefreshCw",
    callback = function()
        window:Hide()
        task.delay(Surge.Animation.Menu + Surge.Animation.Fast + 0.12, function()
            if not window.unloaded then
                window:Show()
                logEvent("display transition complete")
            end
        end)
    end,
})
lifecycle:CreateButton({
    name = "Unload preview",
    description = "Destroys the window and clears the Final Preview globals.",
    icon = "X",
    callback = function()
        window:Unload()
        environment.__FINAL_SURGE_PREVIEW_WINDOW = nil
        environment.__FINAL_SURGE_PREVIEW_HANDLES = nil
    end,
})

window:Notify({ title = "Final Surge Preview loaded", content = "GitHub v0.1.0 is active.", icon = "Zap", duration = 6 })
window:Toast({ title = "Release ready", subtitle = "Pinned GitHub bootstrap", icon = "Check", duration = 4 })

handles.window = window
handles.stat:Set(0)
handles.progress:Set(2)
environment.__FINAL_SURGE_PREVIEW_HANDLES = handles

return window
