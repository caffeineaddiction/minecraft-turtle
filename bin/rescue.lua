-- Capture arguments passed to the script
local args = {...}

local fuelBefore = turtle.getFuelLevel()
print("Fuel level: " .. fuelBefore)

-- Convert arguments to numbers
local arg1 = tonumber(args[1])


--give warning prints if these are not met

-- Check if all arguments were provided and are valid integers
if arg1 then

    print("current fuel: " .. turtle.getFuelLevel())
    print("continue?")
    io.read()


    for i = 1, arg1 do
        turtle.digDown()
        turtle.down()
    end

    for i = 1, arg1 do
        turtle.up()
    end
    
else
    print("Please provide arguments: maxDepth")
end