--[[
make.lua - Crafting meta-command for CC:Tweaked

Commands:
  make clear                  Clear inventory to network
  make get <item> [count]     Get materials for crafting an item
  make craft <item> [count]   Arrange materials and craft
  make <item> [count]         Shorthand: clear, get, craft in one step
  make list                   List available recipes

Recipes are defined in items.json in the same directory.

Batch Crafting:
  When crafting more than 1 item, the script will batch crafts for efficiency.
  For example, "make dried_kelp_block 65" will:
    - Craft 64 in one turtle.craft(64) call (max stack size)
    - Craft 1 more in a second call
  This is much faster than calling turtle.craft() 65 times.

  Recipes can specify "maxStackSize" to override the default of 64.
]]

-- Load imv module (try multiple paths)
local imv
local imvPaths = {"/bin/imv.lua", "/bin/imv", "imv"}
for _, path in ipairs(imvPaths) do
    local ok, result = pcall(function()
        if fs.exists(path) then
            return dofile(path)
        else
            return require(path:gsub("%.lua$", ""):gsub("^/", ""):gsub("/", "."))
        end
    end)
    if ok and type(result) == "table" then
        imv = result
        break
    end
end
if not imv then
    error("Could not load imv module")
end

-- Get the directory this script is in
local scriptPath = shell.getRunningProgram()
local scriptDir = scriptPath:match("(.*/)")
if not scriptDir then scriptDir = "" end

-- Load recipes from JSON
local function loadRecipes()
    local jsonPath = scriptDir .. "items.json"
    local file = fs.open(jsonPath, "r")
    if not file then
        error("Could not open recipes file: " .. jsonPath)
    end
    local content = file.readAll()
    file.close()
    return textutils.unserialiseJSON(content)
end

-- Find a recipe by name (fuzzy match)
local function findRecipe(recipes, name)
    name = name:lower()

    -- Exact match first
    if recipes.recipes[name] then
        return name, recipes.recipes[name]
    end

    -- Fuzzy match
    for recipeName, recipe in pairs(recipes.recipes) do
        if recipeName:find(name, 1, true) then
            return recipeName, recipe
        end
        -- Also check output item name
        if recipe.output and recipe.output:lower():find(name, 1, true) then
            return recipeName, recipe
        end
    end

    return nil, nil
end

-- Clear inventory to network
local function doClear(quiet)
    if not quiet then
        print("Clearing inventory to network...")
    end
    local count, err = imv.move("./*:++", "../")
    if not quiet then
        if err and count == 0 then
            print("Warning: " .. err)
        else
            print("Moved " .. count .. " items to network")
        end
    end
    return count
end

-- Get materials for a recipe (multiplied by count)
local function doGet(recipeName, recipe, count, quiet)
    count = count or 1
    if not quiet then
        print("Getting materials for: " .. recipeName .. " x" .. count)
    end

    local success = true
    for _, ingredient in ipairs(recipe.ingredients) do
        local needed = ingredient.count * count
        -- Use exact match (=) prefix if not already specified to avoid fuzzy matching issues
        -- e.g., "dried_kelp" should not match "dried_kelp_block"
        local itemPattern = ingredient.item
        if not itemPattern:match("^=") then
            itemPattern = "=" .. itemPattern
        end
        local pattern = "../" .. itemPattern .. ":" .. needed
        if not quiet then
            print("  Fetching " .. needed .. "x " .. ingredient.item)
        end
        local got, err = imv.move(pattern, "./")
        if err or got < needed then
            print("  Warning: only got " .. (got or 0) .. "/" .. needed)
            success = false
        end
    end

    return success
end

-- Find item in turtle inventory matching pattern
local function findInInventory(pattern)
    pattern = pattern:lower()
    for slot = 1, 16 do
        local item = turtle.getItemDetail(slot)
        if item then
            local name = item.name:lower()
            local shortName = name:gsub("^[^:]+:", "")
            if name:find(pattern, 1, true) or shortName:find(pattern, 1, true) then
                return slot, item
            end
        end
    end
    return nil
end

-- Clear the crafting grid (slots 1-3, 5-7, 9-11)
local function clearGrid()
    local gridSlots = {1, 2, 3, 5, 6, 7, 9, 10, 11}
    local storageSlots = {4, 8, 12, 13, 14, 15, 16}

    for _, gridSlot in ipairs(gridSlots) do
        if turtle.getItemCount(gridSlot) > 0 then
            turtle.select(gridSlot)
            -- Find an empty storage slot
            for _, storeSlot in ipairs(storageSlots) do
                if turtle.getItemCount(storeSlot) == 0 then
                    turtle.transferTo(storeSlot)
                    break
                end
            end
        end
    end
end

-- Arrange items according to recipe grid (supports batch crafting with amountPerSlot)
local function arrangeGrid(recipe, amountPerSlot)
    amountPerSlot = amountPerSlot or 1

    -- First, clear the grid and consolidate items to storage slots
    clearGrid()

    -- Track what we've placed
    local placed = {}

    -- For each grid position in the recipe
    for slotStr, itemPattern in pairs(recipe.grid) do
        local targetSlot = tonumber(slotStr)

        -- Find this item in inventory (not in grid slots)
        local sourceSlot = nil
        for slot = 1, 16 do
            -- Skip if already a grid slot with something placed
            if not placed[slot] then
                local item = turtle.getItemDetail(slot)
                if item then
                    local name = item.name:lower()
                    local shortName = name:gsub("^[^:]+:", "")
                    local pattern = itemPattern:lower()
                    if name:find(pattern, 1, true) or shortName:find(pattern, 1, true) then
                        sourceSlot = slot
                        break
                    end
                end
            end
        end

        if not sourceSlot then
            return false, "Missing item: " .. itemPattern
        end

        -- Move amountPerSlot items to target slot
        turtle.select(sourceSlot)
        if sourceSlot ~= targetSlot then
            -- If target has items, swap them
            if turtle.getItemCount(targetSlot) > 0 then
                -- Find temp slot
                local tempSlot = nil
                for s = 1, 16 do
                    if turtle.getItemCount(s) == 0 then
                        tempSlot = s
                        break
                    end
                end
                if tempSlot then
                    local currentSlot = turtle.getSelectedSlot()
                    turtle.select(targetSlot)
                    turtle.transferTo(tempSlot)
                    turtle.select(sourceSlot)
                end
            end
            turtle.transferTo(targetSlot, amountPerSlot)
        elseif amountPerSlot < turtle.getItemCount(sourceSlot) then
            -- Source is target, but we need to move excess out
            local excess = turtle.getItemCount(sourceSlot) - amountPerSlot
            for s = 1, 16 do
                if s ~= sourceSlot and turtle.getItemCount(s) == 0 then
                    turtle.transferTo(s, excess)
                    break
                end
            end
        end

        placed[targetSlot] = true
    end

    return true
end

-- Craft a batch of items (arranges grid with batchSize per slot, calls turtle.craft(batchSize))
local function craftBatch(recipe, batchSize)
    batchSize = batchSize or 1

    -- Arrange the grid with batchSize items per slot
    local ok, err = arrangeGrid(recipe, batchSize)
    if not ok then
        return false, err
    end

    -- Select an empty output slot (prefer slot 4)
    local outputSlot = nil
    for _, slot in ipairs({4, 8, 12, 13, 14, 15, 16}) do
        if turtle.getItemCount(slot) == 0 then
            outputSlot = slot
            break
        end
    end

    if outputSlot then
        turtle.select(outputSlot)
    end

    -- Craft the batch!
    return turtle.craft(batchSize)
end

-- Calculate max batch size based on stack limits (default 64)
local function getMaxBatchSize(recipe)
    -- Default max stack size is 64
    local maxStack = recipe.maxStackSize or 64
    return maxStack
end

-- Craft the item with batch support for efficiency
local function doCraft(recipeName, recipe, count)
    count = count or 1
    local maxBatch = getMaxBatchSize(recipe)
    local outputPerCraft = recipe.outputCount or 1

    print("Crafting: " .. recipeName .. " x" .. count)

    -- If count is 1 or recipe has special constraints, use simple mode
    if count == 1 then
        doClear(false)
        if not doGet(recipeName, recipe, 1, true) then
            print("  Failed to get materials")
            return false, 0
        end
        local ok, err = craftBatch(recipe, 1)
        if ok then
            print("  Crafted " .. outputPerCraft .. "x " .. recipe.output)
            doClear(true)
            return true, 1
        else
            print("  Failed: " .. (err or "crafting error"))
            return false, 0
        end
    end

    -- Batch crafting mode
    local crafted = 0
    local remaining = count

    while remaining > 0 do
        -- Calculate batch size for this iteration
        local batchSize = math.min(remaining, maxBatch)

        -- Clear inventory before getting materials
        doClear(crafted > 0)

        -- Get materials for this batch
        if not doGet(recipeName, recipe, batchSize, true) then
            print("  [" .. crafted .. "/" .. count .. "] Failed to get materials for batch of " .. batchSize)
            if crafted > 0 then
                doClear(true)
                print("Partial completion: " .. crafted .. "x " .. recipeName)
            end
            return false, crafted
        end

        -- Craft the batch
        local ok, err = craftBatch(recipe, batchSize)
        if ok then
            crafted = crafted + batchSize
            remaining = remaining - batchSize
            local itemsMade = batchSize * outputPerCraft
            print("  [" .. crafted .. "/" .. count .. "] Crafted " .. itemsMade .. "x " .. recipe.output .. " (batch of " .. batchSize .. ")")
        else
            print("  [" .. crafted .. "/" .. count .. "] Batch failed: " .. (err or "crafting error"))
            if crafted > 0 then
                doClear(true)
                print("Partial completion: " .. crafted .. "x " .. recipeName)
            end
            return false, crafted
        end
    end

    -- Final clear to send crafted items to network
    doClear(true)
    print("Completed: " .. crafted .. "x " .. recipeName .. " (" .. (crafted * outputPerCraft) .. " items)")
    return true, crafted
end

-- List available recipes
local function doList(recipes)
    print("Available recipes:")
    local names = {}
    for name, _ in pairs(recipes.recipes) do
        table.insert(names, name)
    end
    table.sort(names)
    for _, name in ipairs(names) do
        local recipe = recipes.recipes[name]
        local ingredients = {}
        for _, ing in ipairs(recipe.ingredients) do
            table.insert(ingredients, ing.count .. "x " .. ing.item)
        end
        print("  " .. name .. ": " .. table.concat(ingredients, ", "))
    end
end

-- Main
local function main(args)
    if #args == 0 then
        print("Usage:")
        print("  make clear               - Clear inventory to network")
        print("  make get <item> [count]  - Get materials for item")
        print("  make craft <item> [count]- Arrange and craft item")
        print("  make <item> [count]      - Clear, get, and craft")
        print("  make list                - List available recipes")
        return
    end

    local cmd = args[1]:lower()

    if cmd == "clear" then
        doClear()
        return
    end

    if cmd == "list" then
        local recipes = loadRecipes()
        doList(recipes)
        return
    end

    local recipes = loadRecipes()

    if cmd == "get" then
        if not args[2] then
            print("Usage: make get <item> [count]")
            return
        end
        local recipeName, recipe = findRecipe(recipes, args[2])
        if not recipe then
            print("Unknown recipe: " .. args[2])
            print("Use 'make list' to see available recipes")
            return
        end
        local count = tonumber(args[3]) or 1
        doClear()
        doGet(recipeName, recipe, count)
        return
    end

    if cmd == "craft" then
        if not args[2] then
            print("Usage: make craft <item> [count]")
            return
        end
        local recipeName, recipe = findRecipe(recipes, args[2])
        if not recipe then
            print("Unknown recipe: " .. args[2])
            print("Use 'make list' to see available recipes")
            return
        end
        local count = tonumber(args[3]) or 1
        -- doCraft handles getting materials for each iteration
        doCraft(recipeName, recipe, count)
        return
    end

    -- Default: treat as item name, do full clear->get->craft
    local recipeName, recipe = findRecipe(recipes, cmd)
    if not recipe then
        print("Unknown command or recipe: " .. cmd)
        print("Use 'make list' to see available recipes")
        return
    end

    local count = tonumber(args[2]) or 1
    print("=== Making: " .. recipeName .. " x" .. count .. " ===")
    -- doCraft handles clearing, getting materials, and crafting for each iteration
    doCraft(recipeName, recipe, count)
end

main({...})
