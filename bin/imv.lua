--[[
imv.lua - Item Move utility for CC:Tweaked

A flexible item transfer utility for moving items between inventories
on a wired modem network. Supports fuzzy matching for both locations
and item names.

COMMAND LINE USAGE:
  imv [-v] <source> <destination>

PATTERN FORMAT:
  <location>/<item>:<count>

  location: peripheral name, fuzzy match (chest23), ./ (self), * or ../ (any)
  item:     item name or fuzzy match, =name for exact match (defaults to *)
  count:    number, * or + for full stack (defaults to 1)

EXAMPLES:
  imv chest23/lava:1 ./        -- 1 lava from chest23 to self
  imv ./coal:* chest23         -- full stack of coal from self to chest23
  imv */diamond:+ ./           -- full stack of diamonds from anywhere to self
  imv ./lava:1 ../             -- 1 lava from self to any available chest
  imv */=bucket:1 ./           -- 1 empty bucket (exact match, not lava_bucket)

LIBRARY USAGE:
  local imv = require("imv")

  -- High-level move (same as CLI)
  local count, err = imv.move("chest23/lava:1", "./")
  local count, err = imv.move("./coal:*", "chest23", {verbose = true})

  -- Get turtle's network name
  local name = imv.getLocalName()  -- e.g., "turtle_6"

  -- Get all inventory peripherals on network
  local invs = imv.getAllInventories()  -- {"minecraft:chest_1", ...}

  -- Fuzzy match a location pattern
  local names, isAnyMode = imv.matchLocation("chest23")

  -- Parse a pattern string
  local location, item, count = imv.parsePattern("chest23/coal:10")

  -- Find items in an inventory
  local items = imv.findItems("minecraft:chest_23", "coal")
  -- Returns: {{slot=1, name="minecraft:coal", count=64, maxCount=64}, ...}

  -- Low-level transfer between specific slots
  local transferred = imv.transfer("minecraft:chest_23", 1, "turtle_6", 10)

API REFERENCE:

  imv.getLocalName()
    Returns the turtle's network name (e.g., "turtle_6") or nil

  imv.getAllInventories()
    Returns a list of all inventory peripheral names on the network

  imv.matchLocation(pattern)
    Fuzzy-matches a location pattern against available peripherals
    Returns: names (table), isAnyMode (boolean)

  imv.parsePattern(str)
    Parses a pattern like "chest23/coal:10" or "./lava:*"
    Returns: location (string), item (string), count (number|"max")

  imv.findItems(invName, itemPattern)
    Finds items matching pattern in the specified inventory
    Returns: {{slot, name, count, maxCount}, ...}

  imv.transfer(srcName, srcSlot, dstName, count)
    Transfers items between two inventory slots
    Returns: number of items transferred

  imv.move(srcPattern, dstPattern, opts)
    High-level move matching CLI behavior
    opts.verbose: print transfer details (default: false)
    Returns: totalTransferred (number), errorMsg (string|nil)
]]

local imv = {}

-- Get local name (turtle's network name)
function imv.getLocalName()
    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.getType(name) == "modem" then
            local modem = peripheral.wrap(name)
            if modem.getNameLocal then
                local localName = modem.getNameLocal()
                if localName then return localName end
            end
        end
    end
    return nil
end

-- Get all inventory peripherals
function imv.getAllInventories()
    local inventories = {}
    for _, name in ipairs(peripheral.getNames()) do
        local p = peripheral.wrap(name)
        if p and type(p.list) == "function" then
            table.insert(inventories, name)
        end
    end
    return inventories
end

-- Fuzzy match a pattern against peripheral names
function imv.matchLocation(pattern)
    if pattern == "./" or pattern == "." then
        return {imv.getLocalName()}, false
    end

    if pattern == "*" or pattern == "../" or pattern == ".." then
        return imv.getAllInventories(), true  -- true = "any" mode
    end

    local names = peripheral.getNames()
    local matches = {}

    -- Exact match first
    for _, name in ipairs(names) do
        if name == pattern then
            return {name}, false
        end
    end

    -- Normalize pattern for fuzzy matching
    -- "chest23" should match "minecraft:chest_23"
    local normalizedPattern = pattern:lower()

    for _, name in ipairs(names) do
        local normalizedName = name:lower()

        -- Direct substring match
        if normalizedName:find(normalizedPattern, 1, true) then
            table.insert(matches, name)
        else
            -- Try matching with underscores/colons removed
            local simpleName = normalizedName:gsub("[_:]", "")
            local simplePattern = normalizedPattern:gsub("[_:]", "")
            if simpleName:find(simplePattern, 1, true) then
                table.insert(matches, name)
            end
        end
    end

    -- Sort matches by length (prefer shorter/more specific matches)
    table.sort(matches, function(a, b) return #a < #b end)

    if #matches > 0 then
        return {matches[1]}, false
    end

    return {}, false
end

-- Parse a pattern like "chest23/lava:5" or "./coal" or just "chest23"
-- Supports both / and \ as separators
function imv.parsePattern(str)
    -- Normalize: replace \ with /
    str = str:gsub("\\", "/")

    -- Handle special cases: ./ ../ or * alone as location
    if str == "./" or str == "." or str == "../" or str == ".." or str == "*" then
        return str, "*", 1
    end

    -- Check for separator (now only /)
    -- Pattern: location/item:count or location/item or just location
    local location, rest = str:match("^(.-)/([^/]+)$")

    if not location or location == "" then
        -- No valid separator found, treat whole thing as location
        return str, "*", 1
    end

    -- Parse item:count from rest
    local item, countStr = rest:match("^([^:]+):?([%d%*%+]*)$")
    local count
    if countStr == "*" or countStr == "+" then
        count = "max"  -- sentinel: use item's maxCount
    else
        count = tonumber(countStr) or 1
    end

    return location, item or "*", count
end

-- Check if a name matches the local turtle
local function isLocalTurtle(name)
    return name == imv.getLocalName()
end

-- Check if item name matches pattern
-- Supports exact match with = prefix (e.g., =minecraft:bucket or =bucket)
local function itemMatches(itemName, itemPattern)
    if itemPattern == "*" then
        return true
    end

    local normalizedName = itemName:lower()

    -- Exact match mode: pattern starts with =
    if itemPattern:sub(1, 1) == "=" then
        local exactPattern = itemPattern:sub(2):lower()
        -- Match full name or short name (without namespace)
        local shortName = normalizedName:gsub("^[^:]+:", "")
        return normalizedName == exactPattern or shortName == exactPattern
    end

    -- Fuzzy match mode (default)
    local normalizedPattern = itemPattern:lower()

    if normalizedName:find(normalizedPattern, 1, true) then
        return true
    end

    -- Try without namespace
    local shortName = normalizedName:gsub("^[^:]+:", "")
    if shortName:find(normalizedPattern, 1, true) then
        return true
    end

    return false
end

-- Find items matching pattern in an inventory
function imv.findItems(invName, itemPattern)
    local results = {}

    -- Special case: local turtle inventory
    if isLocalTurtle(invName) then
        for slot = 1, 16 do
            local item = turtle.getItemDetail(slot)
            if item and itemMatches(item.name, itemPattern) then
                table.insert(results, {
                    slot = slot,
                    name = item.name,
                    count = item.count,
                    maxCount = item.maxCount or 64
                })
            end
        end
        return results
    end

    -- Remote inventory via peripheral
    local inv = peripheral.wrap(invName)
    if not inv or not inv.list then
        return {}
    end

    local ok, items = pcall(function() return inv.list() end)
    if not ok then return {} end

    for slot, item in pairs(items) do
        if itemMatches(item.name, itemPattern) then
            -- Get detailed info for maxCount
            local detail = inv.getItemDetail and inv.getItemDetail(slot)
            local maxCount = (detail and detail.maxCount) or 64
            table.insert(results, {
                slot = slot,
                name = item.name,
                count = item.count,
                maxCount = maxCount
            })
        end
    end

    return results
end

-- Transfer items between inventories
function imv.transfer(srcName, srcSlot, dstName, count)
    if isLocalTurtle(srcName) then
        -- Source is local turtle, destination must pull from us
        local dstInv = peripheral.wrap(dstName)
        if dstInv and dstInv.pullItems then
            return dstInv.pullItems(srcName, srcSlot, count)
        end
        return 0
    else
        -- Source is remote, it pushes to destination
        local srcInv = peripheral.wrap(srcName)
        if srcInv and srcInv.pushItems then
            return srcInv.pushItems(dstName, srcSlot, count)
        end
        return 0
    end
end

-- High-level move function
-- Returns: totalTransferred, errorMsg
function imv.move(srcPattern, dstPattern, opts)
    opts = opts or {}
    local verbose = opts.verbose or false

    local srcLoc, srcItem, srcCount = imv.parsePattern(srcPattern)
    local dstLoc, dstItem, dstCount = imv.parsePattern(dstPattern)

    -- Resolve locations
    local srcNames, srcAnyMode = imv.matchLocation(srcLoc)
    local dstNames, dstAnyMode = imv.matchLocation(dstLoc)

    if #srcNames == 0 then
        return 0, "Could not find source location: " .. srcLoc
    end

    if #dstNames == 0 then
        return 0, "Could not find destination location: " .. dstLoc
    end

    -- For non-any destination mode, only allow single destination
    if not dstAnyMode and #dstNames > 1 then
        return 0, "Destination must be a single location, matched: " .. #dstNames
    end

    local totalTransferred = 0
    local remaining = srcCount  -- may be "max" or a number

    -- Search through all source locations
    for _, srcName in ipairs(srcNames) do
        if type(remaining) == "number" and remaining <= 0 then break end

        local items = imv.findItems(srcName, srcItem)

        if #items > 0 then
            for _, item in ipairs(items) do
                if type(remaining) == "number" and remaining <= 0 then break end

                -- Calculate how many to transfer
                local toTransfer
                if remaining == "max" then
                    toTransfer = math.min(item.maxCount, item.count)
                    remaining = toTransfer  -- convert to number for tracking
                else
                    toTransfer = math.min(remaining, item.count)
                end

                if dstAnyMode then
                    -- Try each destination until we successfully transfer
                    for _, dstName in ipairs(dstNames) do
                        if dstName ~= srcName and toTransfer > 0 then
                            local ok, transferred = pcall(function()
                                return imv.transfer(srcName, item.slot, dstName, toTransfer)
                            end)

                            if ok and transferred and transferred > 0 then
                                totalTransferred = totalTransferred + transferred
                                remaining = remaining - transferred
                                toTransfer = toTransfer - transferred
                                if verbose then
                                    print(string.format("%s: %d x %s -> %s", srcName, transferred, item.name, dstName))
                                end
                            end
                        end
                        if toTransfer <= 0 then break end
                    end
                else
                    -- Single destination
                    local dstName = dstNames[1]
                    local ok, transferred = pcall(function()
                        return imv.transfer(srcName, item.slot, dstName, toTransfer)
                    end)

                    if ok and transferred and transferred > 0 then
                        totalTransferred = totalTransferred + transferred
                        remaining = remaining - transferred
                        if verbose then
                            print(string.format("%s: %d x %s -> %s", srcName, transferred, item.name, dstName))
                        end
                    end
                end
            end
        end
    end

    if totalTransferred == 0 then
        return 0, "No items matching '" .. srcItem .. "' found or destination full"
    end

    if verbose then
        print(string.format("Total: %d items transferred", totalTransferred))
    end

    -- Fire turtle_inventory event if local turtle was involved (as source or destination)
    local localName = imv.getLocalName()
    if localName then
        for _, name in ipairs(srcNames) do
            if name == localName then
                os.queueEvent("turtle_inventory")
                break
            end
        end
        for _, name in ipairs(dstNames) do
            if name == localName then
                os.queueEvent("turtle_inventory")
                break
            end
        end
    end

    return totalTransferred, nil
end

-- CLI entry point
local function main(args)
    -- Parse flags
    local verbose = false
    local filteredArgs = {}
    for _, arg in ipairs(args) do
        if arg == "-v" or arg == "--verbose" then
            verbose = true
        else
            table.insert(filteredArgs, arg)
        end
    end

    if #filteredArgs < 2 then
        print("Usage: imv [-v] <source> <destination>")
        print("Pattern: <location>/<item>:<count>")
        print("  -v: verbose output")
        print("  location: peripheral name, fuzzy match (chest23), ./ (self), * or ../ (any)")
        print("  item: item name or fuzzy match, optional (defaults to *)")
        print("  count: number, * or + for full stack (defaults to 1)")
        print("")
        print("Examples:")
        print("  imv chest23/lava:1 ./        -- 1 lava from chest23 to self")
        print("  imv ./coal:* chest23         -- full stack of coal from self to chest23")
        print("  imv */diamond:+ ./           -- full stack of diamonds from anywhere to self")
        print("  imv ./lava:1 ../             -- 1 lava from self to any available chest")
        print("")
        print("Use as library: local imv = require('imv')")
        return
    end

    local count, err = imv.move(filteredArgs[1], filteredArgs[2], {verbose = verbose})
    if err then
        print("Error: " .. err)
    end
end

-- Check if running as CLI or being required as library
-- When required, ... contains the module name; when run as program, ... contains CLI args
local args = {...}
if type(args[1]) == "string" and (args[1]:match("^%-") or #args >= 2 or args[1] == nil) then
    -- Likely CLI invocation
    if #args > 0 or select('#', ...) == 0 then
        main(args)
    end
end

return imv
