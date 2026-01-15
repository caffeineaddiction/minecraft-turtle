--[[
lava_cauldron.lua - Lava farming from cauldrons

The turtle starts facing a wired modem. It grabs empty buckets from the network,
collects lava from cauldrons above it in a snake pattern, then deposits the
lava buckets back into the network.

Layout (viewed from above, T = turtle start position facing modem M):
  [C][C][C][C][C]
  [C][C][C][C][C]
  [T] <- facing [M]

The turtle moves in a snake pattern under the cauldrons.
]]

local imv = require("/bin/imv")
local move = require("/lib/move")

local SLEEP_TIME = 300 -- 5 minutes in seconds

-- Find and select a slot containing an empty bucket
-- Returns true if found, false otherwise
local function selectEmptyBucket()
    for slot = 1, 16 do
        local item = turtle.getItemDetail(slot)
        if item and item.name == "minecraft:bucket" then
            turtle.select(slot)
            return true
        end
    end
    return false
end

-- Count empty buckets in inventory
local function countEmptyBuckets()
    local count = 0
    for slot = 1, 16 do
        local item = turtle.getItemDetail(slot)
        if item and item.name == "minecraft:bucket" then
            count = count + item.count
        end
    end
    return count
end

-- Check if there's a cauldron above
local function isCauldronAbove()
    local success, data = turtle.inspectUp()
    if success and data.name and data.name:find("cauldron") then
        return true
    end
    return false
end

-- Try to fill bucket with lava from cauldron above
-- Only interacts if there's a cauldron above
local function tryFillBucket()
    if not isCauldronAbove() then
        return false
    end

    if selectEmptyBucket() then
        -- placeUp will use the bucket on the cauldron above
        if turtle.placeUp() then
            print("Filled bucket with lava")
            return true
        end
    end
    return false
end

-- Refuel with lava buckets until fuel >= maxFuel - 1000 or no more lava buckets
local function refuelLoop()
    local fuelLevel = turtle.getFuelLevel()
    local fuelLimit = turtle.getFuelLimit()

    -- Skip if unlimited fuel
    if fuelLevel == "unlimited" then
        return
    end

    local refueled = 0
    while turtle.getFuelLevel() < fuelLimit - 1000 do
        local found = false
        for slot = 1, 16 do
            local item = turtle.getItemDetail(slot)
            if item and item.name == "minecraft:lava_bucket" then
                turtle.select(slot)
                if turtle.refuel() then
                    refueled = refueled + 1
                    print("Refueled with lava bucket (fuel: " .. turtle.getFuelLevel() .. ")")
                    found = true
                    break
                end
            end
        end
        -- No more lava buckets found
        if not found then
            break
        end
    end

    if refueled > 0 then
        print("Used " .. refueled .. " lava bucket(s) for fuel")
    end
end

-- Check if we have any lava buckets in inventory
local function hasLavaBuckets()
    for slot = 1, 16 do
        local item = turtle.getItemDetail(slot)
        if item and item.name == "minecraft:lava_bucket" then
            return true
        end
    end
    return false
end

-- Deposit all lava buckets to the network (loops until none remain)
local function depositAllLavaBuckets()
    local totalDeposited = 0
    while hasLavaBuckets() do
        local count, err = imv.move("./lava_bucket:*", "../")
        if count > 0 then
            totalDeposited = totalDeposited + count
        else
            -- Failed to deposit, break to avoid infinite loop
            if err then
                print("Deposit error: " .. err)
            end
            break
        end
    end
    if totalDeposited > 0 then
        print("Deposited " .. totalDeposited .. " lava bucket(s) total")
    end
    return totalDeposited
end

-- Main farming loop
local function farmLava()
    print("Starting lava cauldron farm")
    print("Facing wired modem, ready to begin")

    while true do
        print("\n=== Starting farming cycle ===")

        -- Grab as many empty buckets as possible from network
        print("Grabbing empty buckets from network...")
        local grabbed, err = imv.move("../=bucket:*", "./")
        if grabbed > 0 then
            print("Grabbed " .. grabbed .. " empty bucket(s)")
        else
            print("No buckets grabbed: " .. (err or "none available"))
        end

        -- Check if we have at least 1 bucket
        local bucketCount = countEmptyBuckets()
        if bucketCount < 1 then
            print("No empty buckets available, waiting...")
            sleep(SLEEP_TIME)
            goto continue
        end

        print("Have " .. bucketCount .. " empty bucket(s), starting collection")

        -- Turn around (face away from modem)
        move.turnRight()
        move.turnRight()

        -- First row: 5 cauldrons
        for i = 1, 5 do
            tryFillBucket()
            move.goForward(false)
        end

        -- Turn to second row
        move.turnLeft()
        move.goForward(false)
        move.turnLeft()

        -- Second row: 5 cauldrons
        for i = 1, 5 do
            tryFillBucket()
            move.goForward(false)
        end

        -- Return to start position
        move.turnLeft()
        move.goForward(false)
        move.turnRight()

        -- Now facing the modem again

        -- Refuel until fuel is high enough or no more lava buckets
        refuelLoop()

        -- Deposit all remaining lava buckets to network
        print("Depositing lava buckets...")
        depositAllLavaBuckets()

        -- Sleep before next cycle
        print("Sleeping for " .. (SLEEP_TIME / 60) .. " minutes...")
        sleep(SLEEP_TIME)

        ::continue::
    end
end

-- Run the farm
farmLava()
