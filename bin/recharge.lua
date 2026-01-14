local move = require("/lib/move")
local lib_debug = require("/lib/lib_debug")

local function hasBucket()
    for slot = 1, 16 do
        local item = turtle.getItemDetail(slot)
        if item and (item.name == "minecraft:bucket" or item.name == "minecraft:lava_bucket") then
            return true
        end
    end
    return false
end

local function findEmptyBucket()
    for slot = 1, 16 do
        local item = turtle.getItemDetail(slot)
        if item and item.name == "minecraft:bucket" then
            return slot
        end
    end
    return nil
end

local function checkFuel()
    local fuelLevel = turtle.getFuelLevel()
    local fuelLimit = turtle.getFuelLimit()
    return fuelLevel > fuelLimit - 1000
end

local function scoopLava()
    local bucketSlot = findEmptyBucket()
    if bucketSlot then
        turtle.select(bucketSlot)
        if turtle.place() then
            lib_debug.print_debug("Collected lava in front")
            if not move.refuel() then
                lib_debug.print_debug("Failed to refuel with lava")
            end
        else
            lib_debug.print_debug("Failed to collect lava in front")
        end
    else
        lib_debug.print_debug("No empty bucket available to collect lava")
    end
end

local function lavaScoop()
    if not hasBucket() then
        error("No bucket found in inventory")
    end

    if checkFuel() then
        print("Fuel level: " .. turtle.getFuelLevel())
        return
    end

    while true do
        block, info = turtle.inspect()
        if info and info.name == "minecraft:lava_cauldron" then
            scoopLava()

            if checkFuel() then
                print("Fuel level: " .. turtle.getFuelLevel())
                move.goUp()
                return
            end
        else
            sleep(5)
        end 
    end
end

lavaScoop()