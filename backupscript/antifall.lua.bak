--[[
    antifall.lua - Anti Bike Fall Off for GTA:SA / SA:MP
    MoonLoader - Fully Automatic Version
    
    Extracted from mod-s0beit-sa (cheat_vehicle.cpp + mod_sa.ini)
    Original patch by CrazyT
    
    Auto-patches on game load. No commands needed.
    Put this in MoonLoader\scripts\ folder.
--]]

local patch1_addr = 0x004BA3B9
local patch1_patch = { 0xE9, 0xA7, 0x03, 0x00, 0x00, 0x90 }

local patch2_addr = 0x004B3296
local patch2_patch = { 0x90, 0x90, 0x90 }

local function writeBytes(addr, bytes)
    for i = 1, #bytes do
        writeMemory(addr + (i - 1), 1, bytes[i], true)
    end
end

local function readBytes(addr, count)
    local bytes = {}
    for i = 1, count do
        bytes[i] = readMemory(addr + (i - 1), 1, true)
    end
    return bytes
end

local function bytesEqual(a, b)
    if #a ~= #b then return false end
    for i = 1, #a do
        if a[i] ~= b[i] then return false end
    end
    return true
end

local orig1 = { 0x0F, 0x84, 0xA6, 0x03, 0x00, 0x00 }
local orig2 = { 0xD8, 0x65, 0x04 }
local patched = false

lua_thread.create(function()
    -- wait for game to fully load
    wait(5000)

    -- verify we're on the right game version
    local c1 = readBytes(patch1_addr, #orig1)
    local c2 = readBytes(patch2_addr, #orig2)

    if bytesEqual(c1, orig1) and bytesEqual(c2, orig2) then
        writeBytes(patch1_addr, patch1_patch)
        writeBytes(patch2_addr, patch2_patch)
        patched = true
    else
        -- already patched by another script
        patched = true
    end
end)

function onScriptTerminate(script, quitGame)
    if patched then
        writeBytes(patch1_addr, orig1)
        writeBytes(patch2_addr, orig2)
    end
end
