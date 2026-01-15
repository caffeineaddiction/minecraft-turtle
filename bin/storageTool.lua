storageLib = require("/lib/storage")

args = {...}

for i = 1, #args do
    if args[i] == "--get" then
        if(#args >= i+2) then 
            storageLib.getItems(args[i+1], args[i+2])
        else
            storageLib.getItems(args[i+1] )
        end
    elseif args[i] == "--put" then
        storageLib.pushItem(args[i+1])
    elseif args[i] == "--list" then
        storageLib.printInventorySummary(args[i+1])
    elseif args[i] == "--setLocal" then
        storageLib.setLocalChest(args[i+1])
    elseif args[i] == "--listChest" then
        chestNum = tonumber(args[i+1])
        chestName = "minecraft:chest_" .. chestNum
        storageLib.printChestSummary(chestName)
    end
end