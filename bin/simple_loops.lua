local args = {...}

print("looping...")
if args[1] then
    if(args[1] == 'attack') then
        while true do
            turtle.attack()
        end
    elseif(args[1] == 'placeUp') then
        local delay = tonumber(args[2])
        while true do
            sleep(delay)
            turtle.placeUp()
            sleep(15)
            turtle.placeUp()
        end
    end
end
