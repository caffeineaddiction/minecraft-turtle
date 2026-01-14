local args = {...}

print("looping...")
if arg1 then
    if(arg1 == 'attack') then
        while true do
            turtle.attack()
        end
    elseif(arg1 == 'placeUp') then
        local delay = tonumber(args[2])
        while true do
            sleep(delay)
            turtle.placeUp()
            sleep(10)
            turtle.placeUp()
        end
    end
end
