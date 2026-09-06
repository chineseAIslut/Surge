-- SurgeBootstrap.lua
-- Configure Repository and Ref before publishing a release.
-- The repository URL and immutable ref are intentionally unset in this source tree.

local Distribution = {
    Repository = "",
    Ref = "",
    Version = "0.1.0",
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
    fail("Repository and immutable Ref are not configured")
end
if Distribution.Ref == "main" or Distribution.Ref == "master" or Distribution.Ref == "dev" or Distribution.Ref == "latest" then
    fail("Ref must be an immutable commit or release tag")
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

local function readValid(path, marker, expectedVersion)
    if not isfile(path) then
        return nil
    end
    local ok, body = pcall(readfile, path)
    if not ok or type(body) ~= "string" or not body:find(marker, 1, true) then
        return nil
    end
    local chunk = loadstring(body, "@" .. path)
    if not chunk then
        return nil
    end
    if expectedVersion then
        local loaded, module = pcall(chunk)
        if not loaded or type(module) ~= "table" or module.Version ~= expectedVersion then
            return nil
        end
    end
    return body
end

ensureFolder(Distribution.ManagedPaths.Assets)
ensureFolder(Distribution.ManagedPaths.Managed)
local librarySource = readValid(Distribution.ManagedPaths.Library, "return Surge", Distribution.Version)
if not librarySource then
    librarySource = fetch(Distribution.RepositoryPaths.Library, "Surge library", "return Surge")
    writefile(Distribution.ManagedPaths.Library, librarySource)
end
local bridgeSource = readValid(Distribution.ManagedPaths.LucideBridge, "return Bridge")
if not bridgeSource then
    bridgeSource = fetch(Distribution.RepositoryPaths.LucideBridge, "LucideBridge", "return Bridge")
    writefile(Distribution.ManagedPaths.LucideBridge, bridgeSource)
end

local chunk, compileError = loadstring(librarySource, "@github:" .. Distribution.Ref .. "/" .. Distribution.RepositoryPaths.Library)
assert(chunk, compileError)
local Surge = chunk()
assert(type(Surge) == "table" and Surge.Version == Distribution.Version, "Surge version mismatch")
Surge.Distribution.Repository = Distribution.Repository
Surge.Distribution.Ref = Distribution.Ref
return Surge
