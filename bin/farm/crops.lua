--[[
crops.lua - Crop farming script

The turtle starts facing a wired modem. It checks fuel, then farms crops
in a zigzag pattern, harvesting mature plants and replanting.

For melons/pumpkins, only the fruit is harvested, not the stalks.
]]

local imv = require("/bin/imv")
local move = require("/lib/move")

-- Max age for each crop type
local MAX_AGES = {
    ["minecraft:wheat"] = 7,
    ["minecraft:carrots"] = 7,
    ["minecraft:potatoes"] = 7,
    ["minecraft:beetroots"] = 3,
    ["minecraft:nether_wart"] = 3,
    ["minecraft:cocoa"] = 2,
    ["minecraft:torchflower_crop"] = 2,
    ["minecraft:pitcher_crop"] = 4,
}

-- Crop to seed mapping for replanting
local CROP_TO_SEED = {
    ["minecraft:wheat"] = "minecraft:wheat_seeds",
    ["minecraft:carrots"] = "minecraft:carrot",
    ["minecraft:potatoes"] = "minecraft:potato",
    ["minecraft:beetroots"] = "minecraft:beetroot_seeds",
    ["minecraft:nether_wart"] = "minecraft:nether_wart",
    ["minecraft:torchflower_crop"] = "minecraft:torchflower_seeds",
    ["minecraft:pitcher_crop"] = "minecraft:pitcher_pod",
}

-- Blocks that are harvestable fruit (not stalks)
local FRUIT_BLOCKS = {
    ["minecraft:melon"] = true,
    ["minecraft:pumpkin"] = true,
}

-- Stalk blocks that should NOT be harvested
local STALK_BLOCKS = {
    ["minecraft:melon_stem"] = true,
    ["minecraft:pumpkin_stem"] = true,
    ["minecraft:attached_melon_stem"] = true,
    ["minecraft:attached_pumpkin_stem"] = true,
}

-- Check fuel and refuel from network if needed
local function checkAndRefuel()
    local fuelLevel = turtle.getFuelLevel()

    if fuelLevel == "unlimited" then
        return true
    end

    if fuelLevel >= 1000 then
        return true
    end

    print("Fuel low (" .. fuelLevel .. "), getting lava bucket...")
    local count, err = imv.move("../lava_bucket:1", "./")
    if count > 0 then
        -- Find and use the lava bucket
        for slot = 1, 16 do
            local item = turtle.getItemDetail(slot)
            if item and item.name == "minecraft:lava_bucket" then
                turtle.select(slot)
                if turtle.refuel() then
                    print("Refueled to " .. turtle.getFuelLevel())
                    return true
                end
            end
        end
    else
        print("Could not get lava bucket: " .. (err or "none available"))
    end

    return turtle.getFuelLevel() >= 1000
end

-- Find and select a seed for the given crop type
local function selectSeed(cropName)
    local seedName = CROP_TO_SEED[cropName]
    if not seedName then
        return false
    end

    for slot = 1, 16 do
        local item = turtle.getItemDetail(slot)
        if item and item.name == seedName then
            turtle.select(slot)
            return true
        end
    end
    return false
end

-- Check and harvest the block below if it's a mature crop or fruit
-- Returns true if we harvested something
local function checkAndHarvestBelow()
    local success, data = turtle.inspectDown()
    if not success then
        return false
    end

    local blockName = data.name

    -- Skip stalks - never harvest these
    if STALK_BLOCKS[blockName] then
        return false
    end

    -- Harvest fruit blocks (melon/pumpkin)
    if FRUIT_BLOCKS[blockName] then
        print("Harvesting " .. blockName)
        turtle.digDown()
        return true
    end

    -- Check if it's a crop with age
    local maxAge = MAX_AGES[blockName]
    if maxAge then
        local age = data.state and data.state.age
        if age and age >= maxAge then
            print("Harvesting mature " .. blockName)
            turtle.digDown()
            -- Replant
            if selectSeed(blockName) then
                turtle.placeDown()
                print("Replanted")
            end
            return true
        end
    end

    return false
end

-- Try to move forward (using move lib for position tracking), return false if blocked
local function tryMoveForward()
    return move.goForward(false)
end

-- Dump all harvested items to network
local function dumpToNetwork()
    print("Dumping harvested items to network...")
    local totalDumped = 0

    -- List of items to dump (crops, seeds, and fruits)
    local dumpItems = {
        "wheat", "carrot", "potato", "beetroot", "nether_wart",
        "wheat_seeds", "beetroot_seeds", "torchflower_seeds", "pitcher_pod",
        "melon_slice", "pumpkin", "poisonous_potato",
        "torchflower", "pitcher_plant"
    }

    for _, item in ipairs(dumpItems) do
        while true do
            local count, err = imv.move("./" .. item .. ":*", "../")
            if count > 0 then
                totalDumped = totalDumped + count
            else
                break
            end
        end
    end

    if totalDumped > 0 then
        print("Dumped " .. totalDumped .. " item(s)")
    end
end

-- Main farming function
local function farmCrops()
    print("Starting crop farm")
    print("Facing wired modem, ready to begin")

    while true do
        print("\n=== Starting farming cycle ===")

        -- Check and refuel if needed
        if not checkAndRefuel() then
            print("Warning: Low fuel, continuing anyway...")
        end

        -- Reset position tracking
        move.setHome()

        -- Turn around (face away from modem)
        move.turnRight()
        move.turnRight()

        -- Track which direction we turn at end of rows
        local turnRight = true

        -- Main farming loop
        while true do
            -- Check and harvest below current position
            checkAndHarvestBelow()

            -- Try to move forward
            if not tryMoveForward() then
                -- Hit a wall, harvest current spot first
                checkAndHarvestBelow()

                -- Try to turn to next row
                local turnSuccess = false
                if turnRight then
                    move.turnRight()
                    if move.goForward(false) then
                        move.turnRight()
                        turnSuccess = true
                    else
                        -- Can't move to next row, end of farm
                        move.turnLeft() -- undo the turn
                    end
                else
                    move.turnLeft()
                    if move.goForward(false) then
                        move.turnLeft()
                        turnSuccess = true
                    else
                        -- Can't move to next row, end of farm
                        move.turnRight() -- undo the turn
                    end
                end

                if turnSuccess then
                    -- Successfully turned to next row, flip direction for next time
                    turnRight = not turnRight
                else
                    -- End of farm reached
                    print("End of farm reached")
                    break
                end
            end
        end

        -- Return to start position
        print("Returning to start...")
        move.goHome()

        -- Dump harvested items to network
        dumpToNetwork()

        -- Small delay before next cycle
        print("Cycle complete, starting next cycle...")
        sleep(1)
    end
end

-- Run the farm
farmCrops()
