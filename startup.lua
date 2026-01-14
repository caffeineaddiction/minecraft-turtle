local sPath = shell.path()
sPath = sPath .. ":/bin:/usr/bin"
shell.setPath(sPath)
shell.run("/update.lua")


local autorun = true
-- Giving a turtle an achillies heel of a wooden pickaxe
if turtle then
    x = turtle.getItemDetail(1)
    if x and x.name == "minecraft:wooden_pickaxe" then
        print("AAAHHH A wooden Pickaxe!!! STOPPNG!!")
        autorun = false
    end
end

shell.run("/bin/gohome.lua")

-- NOTE:  wrapper does not return
if peripheral.find("modem") then
    -- Use multishell if available (advanced computers/turtles) to run in separate tabs
    if multishell then
        -- Set current tab (startup) title to "main"
        local mainTab = multishell.getCurrent()
        multishell.setTitle(mainTab, "main")

        -- Environment for launched programs (need shell API)
        local env = {shell = shell}
        setmetatable(env, {__index = _G})

        -- Launch vncd in its own tab
        local vncdTab
        if autorun and fs.exists("/autorun.lua") then
            vncdTab = multishell.launch(env, "/bin/util/wrapper.lua", "/usr/bin/vncd", "/autorun.lua")
        else
            vncdTab = multishell.launch(env, "/bin/util/wrapper.lua", "/usr/bin/vncd")
        end
        if vncdTab then
            multishell.setTitle(vncdTab, "vncd")
        end

        -- Launch wsvncd in its own tab if installed
        if fs.exists("/usr/bin/wsvncd.lua") then
            local wsvncdTab = multishell.launch(env, "/bin/util/wrapper.lua", "/usr/bin/wsvncd.lua", "ws://192.168.41.134:3000")
            if wsvncdTab then
                multishell.setTitle(wsvncdTab, "wsvncd")
            end
        end

        -- Focus on vncd tab
        if vncdTab then
            multishell.setFocus(vncdTab)
        end
        return
    else
        -- Fallback for basic computers: run vncd only
        if autorun and fs.exists("/autorun.lua") then
            shell.run("/bin/util/wrapper", "/usr/bin/vncd", "/autorun.lua")
        else
            shell.run("/bin/util/wrapper", "/usr/bin/vncd")
        end
        return
    end
else
    -- clear the screen
    term.clear()
    term.setCursorPos(1, 1)
    -- Print "CraftOS 1.9" in yellow
    term.setTextColor(colors.yellow)
    print("CraftOS 1.9 (no network)")
    -- set the text color to white
    term.setTextColor(colors.white)
    -- run motd command
    shell.run("/rom/programs/motd.lua")

    if autorun and fs.exists("/autorun.lua") then
        shell.run("/autorun.lua")
    end
end

