-- wrapper.lua (/usr/bin/wrapper)
-- a wrapper script that restarts a program if it crashes or exits abnormally

-- shell.run("background", "/bin/util/wrapper", "/usr/bin/vncd")
-- shell.run("background", "/bin/util/wrapper", "/bin/util/blockd")
-- shell.run("background", "/bin/util/wrapper", "gps", "host", 0, 311, 0)
-- shell.run("background", "/bin/util/wrapper", "--title", "mytitle", "/usr/bin/vncd")

local args = {...}
if #args == 0 then
    print("Usage: wrapper [--title <title>] <program> [arg1] [arg2] ...")
    return
end

-- Parse optional --title argument
local title = nil
local programStart = 1
if args[1] == "--title" and args[2] then
    title = args[2]
    programStart = 3
end

if #args < programStart then
    print("Usage: wrapper [--title <title>] <program> [arg1] [arg2] ...")
    return
end

local program = args[programStart]
local programArgs = {table.unpack(args, programStart + 1)}

-- If no explicit title, extract from program path (e.g., "/usr/bin/vncd" -> "vncd")
if not title then
    title = program:match("([^/]+)$") or program  -- get filename from path
    title = title:gsub("%.lua$", "")  -- remove .lua extension if present
end

-- Set multishell tab title if available
if multishell then
    multishell.setTitle(multishell.getCurrent(), title)
end

local function runProgram()
    print("Starting program: " .. program)
    local result = shell.run(program, table.unpack(programArgs))
    print("Program exited with result: " .. tostring(result))
    return result
end

print("Wrapper started for program: " .. program)

while true do
    local result = runProgram()
    os.sleep()
    -- Giving a turtle an achillies heel of a wooden pickaxe
    if turtle then
        x = turtle.getItemDetail(1)
        if x and x.name == "minecraft:wooden_pickaxe" then
            print("AAAHHH A wooden Pickaxe!!! STOPPNG!!")
            return
        end
    end
end