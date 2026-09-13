-- SurgeBootstrap.lua
-- Fetch the latest Surge sources from the repository's main branch.
-- The bootstrap uses Potassium's documented request/filesystem APIs.

local Distribution = {
    Repository = "https://github.com/chineseAIslut/Surge",
    Ref = "main",
    RepositoryPaths = {
        Library = "Surge.lua",
        LucideBridge = "assets/LucideBridge.lua",
    },
    ManagedPaths = {
        Root = "Surge",
        Assets = "Surge/Assets",
        Managed = "Surge/Managed",
        Library = "Surge/Managed/Surge.lua",
        LucideBridge = "Surge/Assets/LucideBridge.lua",
    },
}

local function fail(message)
    error("Surge bootstrap: " .. message, 2)
end

if Distribution.Repository == "" or Distribution.Ref == "" then
    fail("Repository and live Ref are not configured")
end

local requester = request or http_request or (http and http.request)
if type(requester) ~= "function" then
    fail("Potassium request API is unavailable")
end
if type(makefolder) ~= "function" or type(isfolder) ~= "function"
    or type(writefile) ~= "function" or type(isfile) ~= "function"
    or type(readfile) ~= "function" then
    fail("Potassium workspace filesystem APIs are unavailable")
end

local function ensureFolder(path)
    local current = ""
    for segment in path:gmatch("[^/]+") do
        current = current == "" and segment or (current .. "/" .. segment)
        local exists = false
        pcall(function() exists = isfolder(current) end)
        if not exists then
            local ok, errorMessage = pcall(makefolder, current)
            if not ok then
                local rechecked = false
                pcall(function() rechecked = isfolder(current) end)
                if not rechecked then
                    fail("cannot create " .. current .. ": " .. tostring(errorMessage))
                end
            end
        end
    end
end

local function fetch(path, label, marker)
    local url = Distribution.Repository:gsub("/+$", "") .. "/raw/" .. Distribution.Ref .. "/" .. path
    local ok, response = pcall(requester, { Url = url, Method = "GET" })
    if not ok or type(response) ~= "table" then
        fail(label .. " request failed: " .. tostring(response))
    end
    if response.Success ~= true or tonumber(response.StatusCode) < 200 or tonumber(response.StatusCode) >= 300 then
        fail(label .. " returned HTTP " .. tostring(response.StatusCode))
    end
    if type(response.Body) ~= "string" or response.Body == "" or not response.Body:find(marker, 1, true) then
        fail(label .. " response is empty or invalid")
    end
    local chunk, compileError = loadstring(response.Body, "@github:" .. Distribution.Ref .. "/" .. path)
    if not chunk then
        fail(label .. " failed to compile: " .. tostring(compileError))
    end
    return response.Body
end

ensureFolder(Distribution.ManagedPaths.Assets)
ensureFolder(Distribution.ManagedPaths.Managed)
local librarySource = fetch(Distribution.RepositoryPaths.Library, "Surge library", "return Surge")
local bridgeSource = fetch(Distribution.RepositoryPaths.LucideBridge, "LucideBridge", "return Bridge")
writefile(Distribution.ManagedPaths.Library, librarySource)
writefile(Distribution.ManagedPaths.LucideBridge, bridgeSource)

local chunk, compileError = loadstring(librarySource, "@github:" .. Distribution.Ref .. "/" .. Distribution.RepositoryPaths.Library)
assert(chunk, compileError)
local Surge = chunk()
assert(type(Surge) == "table" and type(Surge.Version) == "string", "Surge library returned an invalid module")
Surge.Distribution.Repository = Distribution.Repository
Surge.Distribution.Ref = Distribution.Ref
return Surge
