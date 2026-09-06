-- LucideBridge.lua
--
-- Local subset of the Lucide.Lua rendering approach with no external package or network dependency.
-- The rasterizer is adapted from:
-- https://github.com/xxpwnxxx420lord/Lucide.Lua
-- It writes PNGs to the Potassium workspace and returns getcustomasset paths.
-- This file intentionally avoids Lucide.Lua's remote HttpGet loader.

local Bridge = {}

local function safeCall(fn, ...)
    if type(fn) ~= "function" then
        return false
    end
    local ok, result = pcall(fn, ...)
    return ok, result
end

local function u32(value)
    value = bit32.band(value, 0xFFFFFFFF)
    return string.char(
        bit32.band(bit32.rshift(value, 24), 0xFF),
        bit32.band(bit32.rshift(value, 16), 0xFF),
        bit32.band(bit32.rshift(value, 8), 0xFF),
        bit32.band(value, 0xFF)
    )
end

local function u16le(value)
    return string.char(bit32.band(value, 0xFF), bit32.band(bit32.rshift(value, 8), 0xFF))
end

local crcTable = {}
for index = 0, 255 do
    local value = index
    for _ = 1, 8 do
        if bit32.band(value, 1) == 1 then
            value = bit32.bxor(0xEDB88320, bit32.rshift(value, 1))
        else
            value = bit32.rshift(value, 1)
        end
    end
    crcTable[index] = value
end

local function crc32(text)
    local value = 0xFFFFFFFF
    for index = 1, #text do
        value = bit32.bxor(crcTable[bit32.band(bit32.bxor(value, text:byte(index)), 0xFF)], bit32.rshift(value, 8))
    end
    return bit32.bxor(value, 0xFFFFFFFF)
end

local function pngChunk(kind, data)
    return u32(#data) .. kind .. data .. u32(crc32(kind .. data))
end

local function adler32(text)
    local a, b = 1, 0
    for index = 1, #text do
        a = (a + text:byte(index)) % 65521
        b = (b + a) % 65521
    end
    return u32(b * 65536 + a)
end

local function encodePNG(pixels, size)
    local rows = {}
    for y = 0, size - 1 do
        local row = { "\x00" }
        for x = 0, size - 1 do
            local offset = (y * size + x) * 4 + 1
            row[#row + 1] = string.char(
                math.max(0, math.min(255, pixels[offset])),
                math.max(0, math.min(255, pixels[offset + 1])),
                math.max(0, math.min(255, pixels[offset + 2])),
                math.max(0, math.min(255, pixels[offset + 3]))
            )
        end
        rows[#rows + 1] = table.concat(row)
    end
    local raw = table.concat(rows)
    local length = #raw
    local inverse = bit32.band(bit32.bnot(length), 0xFFFF)
    local idat = "\x78\x01\x01" .. u16le(length) .. u16le(inverse) .. raw .. adler32(raw)
    return "\x89PNG\r\n\x1a\n"
        .. pngChunk("IHDR", u32(size) .. u32(size) .. "\x08\x06\x00\x00\x00")
        .. pngChunk("IDAT", idat)
        .. pngChunk("IEND", "")
end

local function parseColor(value)
    local hex = tostring(value or "#ffffff"):gsub("#", "")
    if #hex == 3 then
        return tonumber(hex:sub(1, 1), 16) * 17, tonumber(hex:sub(2, 2), 16) * 17, tonumber(hex:sub(3, 3), 16) * 17
    end
    if #hex == 6 then
        return tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
    end
    return 255, 255, 255
end

local function distanceToSegment(px, py, ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    local lengthSquared = dx * dx + dy * dy
    if lengthSquared < 1e-10 then
        return math.sqrt((px - ax) ^ 2 + (py - ay) ^ 2)
    end
    local t = math.max(0, math.min(1, ((px - ax) * dx + (py - ay) * dy) / lengthSquared))
    return math.sqrt((px - ax - t * dx) ^ 2 + (py - ay - t * dy) ^ 2)
end

local function strokePolyline(pixels, size, points, halfWidth, red, green, blue)
    local antiAlias = 0.75
    for index = 1, #points - 1 do
        local a, b = points[index], points[index + 1]
        local margin = halfWidth + antiAlias + 1
        local x0 = math.max(0, math.floor(math.min(a[1], b[1]) - margin))
        local x1 = math.min(size - 1, math.ceil(math.max(a[1], b[1]) + margin))
        local y0 = math.max(0, math.floor(math.min(a[2], b[2]) - margin))
        local y1 = math.min(size - 1, math.ceil(math.max(a[2], b[2]) + margin))
        for py = y0, y1 do
            for px = x0, x1 do
                local distance = distanceToSegment(px + 0.5, py + 0.5, a[1], a[2], b[1], b[2])
                local coverage = math.max(0, math.min(1, (halfWidth + antiAlias - distance) / (antiAlias * 2)))
                if coverage > 0 then
                    local offset = (py * size + px) * 4 + 1
                    local inverse = 1 - coverage
                    pixels[offset] = math.floor(pixels[offset] * inverse + red * coverage + 0.5)
                    pixels[offset + 1] = math.floor(pixels[offset + 1] * inverse + green * coverage + 0.5)
                    pixels[offset + 2] = math.floor(pixels[offset + 2] * inverse + blue * coverage + 0.5)
                    pixels[offset + 3] = math.min(255, math.floor(pixels[offset + 3] + (255 - pixels[offset + 3]) * coverage + 0.5))
                end
            end
        end
    end
end

local function numbers(text)
    local result = {}
    for value in tostring(text or ""):gmatch("[+-]?%d*%.?%d+") do
        result[#result + 1] = tonumber(value)
    end
    return result
end

-- The bundled subset uses M/L/H/V/Z paths. This is sufficient for the selected
-- Lucide controls and keeps the bridge small enough for executor loadstring limits.
local function parsePath(path, scale)
    local subpaths = {}
    local current = {}
    local x, y, startX, startY = 0, 0, 0, 0
    local function addPoint(px, py)
        current[#current + 1] = { px * scale, py * scale }
        x, y = px, py
    end
    local function flush()
        if #current > 1 then
            subpaths[#subpaths + 1] = current
        end
        current = {}
    end
    for command, raw in tostring(path or ""):gmatch("([MmLlHhVvZz])([^MmLlHhVvZz]*)") do
        local values = numbers(raw)
        local position = 1
        local function nextValue()
            local value = values[position] or 0
            position = position + 1
            return value
        end
        if command == "M" or command == "m" then
            flush()
            local px, py = nextValue(), nextValue()
            if command == "m" then px, py = x + px, y + py end
            x, y, startX, startY = px, py, px, py
            current[#current + 1] = { x * scale, y * scale }
            while position <= #values do
                px, py = nextValue(), nextValue()
                if command == "m" then px, py = x + px, y + py end
                addPoint(px, py)
            end
        elseif command == "L" or command == "l" then
            while position <= #values do
                local px, py = nextValue(), nextValue()
                if command == "l" then px, py = x + px, y + py end
                addPoint(px, py)
            end
        elseif command == "H" or command == "h" then
            while position <= #values do
                local px = nextValue()
                if command == "h" then px = x + px end
                addPoint(px, y)
            end
        elseif command == "V" or command == "v" then
            while position <= #values do
                local py = nextValue()
                if command == "v" then py = y + py end
                addPoint(x, py)
            end
        elseif command == "Z" or command == "z" then
            addPoint(startX, startY)
            flush()
            x, y = startX, startY
        end
    end
    flush()
    return subpaths
end

local function render(nodes, options)
    local size = math.max(8, math.floor(options.size or 24))
    local scale = size / 24
    local halfWidth = (options.stroke_width or 2) * scale / 2
    local red, green, blue = parseColor(options.color)
    local pixels = {}
    for index = 1, size * size * 4 do pixels[index] = 0 end
    for _, element in ipairs(nodes) do
        local attrs = element.attrs or {}
        if element.tag == "path" then
            for _, points in ipairs(parsePath(attrs.d, scale)) do
                strokePolyline(pixels, size, points, halfWidth, red, green, blue)
            end
        elseif element.tag == "circle" then
            local cx, cy, radius = (tonumber(attrs.cx) or 0) * scale, (tonumber(attrs.cy) or 0) * scale, (tonumber(attrs.r) or 0) * scale
            local margin = radius + halfWidth + 2
            for py = math.max(0, math.floor(cy - margin)), math.min(size - 1, math.ceil(cy + margin)) do
                for px = math.max(0, math.floor(cx - margin)), math.min(size - 1, math.ceil(cx + margin)) do
                    local distance = math.abs(math.sqrt((px + 0.5 - cx) ^ 2 + (py + 0.5 - cy) ^ 2) - radius)
                    local coverage = math.max(0, math.min(1, (halfWidth + 0.75 - distance) / 1.5))
                    if coverage > 0 then
                        local offset = (py * size + px) * 4 + 1
                        local inverse = 1 - coverage
                        pixels[offset] = math.floor(pixels[offset] * inverse + red * coverage + 0.5)
                        pixels[offset + 1] = math.floor(pixels[offset + 1] * inverse + green * coverage + 0.5)
                        pixels[offset + 2] = math.floor(pixels[offset + 2] * inverse + blue * coverage + 0.5)
                        pixels[offset + 3] = math.min(255, math.floor(pixels[offset + 3] + (255 - pixels[offset + 3]) * coverage + 0.5))
                    end
                end
            end
        elseif element.tag == "line" then
            strokePolyline(pixels, size, {
                { (tonumber(attrs.x1) or 0) * scale, (tonumber(attrs.y1) or 0) * scale },
                { (tonumber(attrs.x2) or 0) * scale, (tonumber(attrs.y2) or 0) * scale },
            }, halfWidth, red, green, blue)
        elseif element.tag == "rect" then
            local x, y = (tonumber(attrs.x) or 0) * scale, (tonumber(attrs.y) or 0) * scale
            local width, height = (tonumber(attrs.width) or 0) * scale, (tonumber(attrs.height) or 0) * scale
            strokePolyline(pixels, size, {{ x, y }, { x + width, y }, { x + width, y + height }, { x, y + height }, { x, y }}, halfWidth, red, green, blue)
        end
    end
    return encodePNG(pixels, size)
end

local NODES = {
    zap = { { tag = "path", attrs = { d = "M13 2 3 14h9l-2 8 11-13h-9z" } } },
    ["panel-left"] = { { tag = "rect", attrs = { x = "3", y = "3", width = "18", height = "18" } }, { tag = "path", attrs = { d = "M9 3v18" } } },
    settings = { { tag = "circle", attrs = { cx = "12", cy = "12", r = "3" } }, { tag = "path", attrs = { d = "M12 2v5M12 17v5M2 12h5M17 12h5M5 5l3 3M16 16l3 3M19 5l-3 3M8 16l-3 3" } } },
    terminal = { { tag = "path", attrs = { d = "M4 17l6-6-6-6M13 19h7" } } },
    search = { { tag = "circle", attrs = { cx = "11", cy = "11", r = "8" } }, { tag = "path", attrs = { d = "m21 21-4.3-4.3" } } },
    check = { { tag = "path", attrs = { d = "M20 6 9 17l-5-5" } } },
    x = { { tag = "path", attrs = { d = "M18 6 6 18M6 6l12 12" } } },
    plus = { { tag = "path", attrs = { d = "M5 12h14M12 5v14" } } },
    minus = { { tag = "path", attrs = { d = "M5 12h14" } } },
    ["chevron-down"] = { { tag = "path", attrs = { d = "m6 9 6 6 6-6" } } },
    ["chevron-right"] = { { tag = "path", attrs = { d = "m9 18 6-6-6-6" } } },
    info = { { tag = "circle", attrs = { cx = "12", cy = "12", r = "9" } }, { tag = "path", attrs = { d = "M12 16v-4M12 8h.01" } } },
    activity = { { tag = "path", attrs = { d = "M3 12h4l2-7 4 14 3-7h5" } } },
    ["circle-gauge"] = { { tag = "circle", attrs = { cx = "12", cy = "12", r = "9" } }, { tag = "path", attrs = { d = "M12 12l4-3" } } },
    house = { { tag = "path", attrs = { d = "M3 11 12 3l9 8v10H3z" } }, { tag = "path", attrs = { d = "M9 21v-7h6v7" } } },
    bell = { { tag = "path", attrs = { d = "M6 17h12l-2-3v-4H8v4zM10 20h4" } } },
    copy = { { tag = "rect", attrs = { x = "8", y = "8", width = "11", height = "11" } }, { tag = "path", attrs = { d = "M5 16H4V4h12v1" } } },
    keyboard = { { tag = "rect", attrs = { x = "3", y = "6", width = "18", height = "12" } }, { tag = "path", attrs = { d = "M7 10h.01M11 10h.01M15 10h.01M7 14h10" } } },
    palette = { { tag = "path", attrs = { d = "M12 3L7 4 4 8v7l4 5h7l3-3v-3h3l-1-6-4-4z" } }, { tag = "circle", attrs = { cx = "7", cy = "9", r = "1" } }, { tag = "circle", attrs = { cx = "11", cy = "7", r = "1" } }, { tag = "circle", attrs = { cx = "15", cy = "8", r = "1" } } },
    ["sliders-horizontal"] = { { tag = "path", attrs = { d = "M3 6h18M3 12h18M3 18h18" } }, { tag = "circle", attrs = { cx = "8", cy = "6", r = "2" } }, { tag = "circle", attrs = { cx = "16", cy = "12", r = "2" } }, { tag = "circle", attrs = { cx = "10", cy = "18", r = "2" } } },
    ["toggle-right"] = { { tag = "rect", attrs = { x = "3", y = "7", width = "18", height = "10" } }, { tag = "circle", attrs = { cx = "16", cy = "12", r = "3" } } },
    moon = { { tag = "path", attrs = { d = "M20 15L14 19H9L5 15V10L9 5h5l4 3h-4l-2 2 2 3z" } } },
    sun = { { tag = "circle", attrs = { cx = "12", cy = "12", r = "4" } }, { tag = "path", attrs = { d = "M12 2v2M12 20v2M2 12h2M20 12h2M4 4l2 2M18 18l2 2M20 4l-2 2M6 18l-2 2" } } },
    ["refresh-cw"] = { { tag = "path", attrs = { d = "M20 11V8L18 5 15 4 12 3 9 4 6 6 4 9v4M4 13v6h6l-1-5M20 5l-5 5M4 19l5-5" } } },
    lock = { { tag = "rect", attrs = { x = "4", y = "10", width = "16", height = "11" } }, { tag = "path", attrs = { d = "M8 10V7L10 4h4l2 3v3" } } },
    key = { { tag = "circle", attrs = { cx = "7", cy = "15", r = "3" } }, { tag = "path", attrs = { d = "m9.5 12.5 8-8M15 5l2 2M17 3l2 2" } } },
    save = { { tag = "path", attrs = { d = "M4 3h13l3 3v15H4zM8 3v6h8V3M8 21v-6h8v6" } } },
    move = { { tag = "path", attrs = { d = "M12 2v20M2 12h20M5 5l-3 3 3 3M19 5l3 3-3 3M5 19l-3-3 3-3M19 19l3-3-3-3" } } },
    languages = { { tag = "path", attrs = { d = "M4 5h7M7 3v2M5 5L7 10l4 4M4 14h8M14 5h7M17 3v2M14 21l4-10 4 10M15 18h5" } } },
    ["scroll-text"] = { { tag = "rect", attrs = { x = "4", y = "3", width = "16", height = "18" } }, { tag = "path", attrs = { d = "M8 7h8M8 11h8M8 15h5" } } },
    type = { { tag = "path", attrs = { d = "M4 7V4h16v3M12 4v16M8 20h8" } } },
    ["file-text"] = { { tag = "path", attrs = { d = "M6 3h9l3 3v15H6zM9 12h6M9 16h6" } } },
    ["panel-left"] = { { tag = "rect", attrs = { x = "3", y = "3", width = "18", height = "18" } }, { tag = "path", attrs = { d = "M9 3v18" } } },
}

local aliases = {
    ["panelleft"] = "panel-left", ["panels-topleft"] = "panel-left", ["panels-topleft"] = "panel-left",
    ["circlegauge"] = "circle-gauge", ["slidershorizontal"] = "sliders-horizontal", ["toggleright"] = "toggle-right",
    ["chevrondown"] = "chevron-down", ["chevronright"] = "chevron-right", ["refreshcw"] = "refresh-cw",
    ["scrolltext"] = "scroll-text", ["filetext"] = "file-text",
}

local function normalize(name)
    local value = tostring(name or ""):lower():gsub("_", "-")
    return aliases[value] or value
end

local function ensureCache(folder)
    if type(makefolder) ~= "function" or type(isfolder) ~= "function"
        or type(writefile) ~= "function" or type(isfile) ~= "function"
        or type(getcustomasset) ~= "function" then
        return false
    end
    local current = ""
    for segment in tostring(folder or ""):gmatch("[^/]+") do
        current = current == "" and segment or (current .. "/" .. segment)
        local exists = false
        pcall(function() exists = isfolder(current) end)
        if not exists then
            local made = pcall(makefolder, current)
            if not made then
                local rechecked = false
                pcall(function() rechecked = isfolder(current) end)
                if not rechecked then return false end
            end
        end
    end
    return true
end

local function cacheFile(folder, key, size, strokeWidth, colorKey)
    return string.format("%s/%s_%d_%s_%s.png", tostring(folder or ""):gsub("/+$", ""), key:gsub("[^%w%-]", "_"), size, tostring(strokeWidth):gsub("[^%w%-]", "_"), colorKey)
end

local function cacheFolders(options)
    local result = { options.cacheFolder or "Surge/Assets/IconCache" }
    for _, folder in ipairs(options.fallbackFolders or {}) do
        local duplicate = false
        for _, existing in ipairs(result) do
            if existing == folder then
                duplicate = true
                break
            end
        end
        if not duplicate then
            table.insert(result, folder)
        end
    end
    return result
end

function Bridge:GetIcon(name, options)
    local key = normalize(name)
    local nodes = NODES[key]
    if not nodes then return nil, "unknown icon: " .. tostring(name) end
    options = options or {}
    local folders = cacheFolders(options)
    local primaryFolder = folders[1]
    local primaryReady = ensureCache(primaryFolder)
    local size = math.max(8, math.min(127, math.floor(tonumber(options.size) or 18)))
    local strokeWidth = math.max(0.5, math.min(8, tonumber(options.stroke_width) or 2))
    local color = tostring(options.color or "#ffffff")
    local colorKey = color:gsub("[^%w%-#]", "_")
    local file
    for _, folder in ipairs(folders) do
        local candidate = cacheFile(folder, key, size, strokeWidth, colorKey)
        local exists = false
        local existsOk = pcall(function()
            exists = isfile(candidate)
        end)
        if existsOk and exists then
            local ok, asset = pcall(getcustomasset, candidate)
            if ok then
                return asset
            end
        end
        if folder == primaryFolder then
            file = candidate
        end
    end
    if not primaryReady then
        return nil, "Potassium managed icon cache is unavailable"
    end
    local ok, png = pcall(render, nodes, { size = size, color = options.color or "#ffffff", stroke_width = strokeWidth })
    if not ok then return nil, tostring(png) end
    local wrote, errorMessage = pcall(writefile, file, png)
    if not wrote then return nil, tostring(errorMessage) end
    local assetOk, asset = pcall(getcustomasset, file)
    if not assetOk then return nil, tostring(asset) end
    return asset
end

function Bridge:HasIcon(name)
    return NODES[normalize(name)] ~= nil
end

Bridge.Source = "Lucide.Lua subset + local Lucide path data"
return Bridge
