-- vehiclehop.lua
-- Hold B to make vehicle hop/bounce (s0beit-style vehicle hop)

script_name("VehicleHop")
script_author("BOJO Dev")
script_version("1.0")

require 'lib.moonloader'
local ffi = require 'ffi'

local VEHICLE_POINTER_SELF = 0x00B6F980
local VEH_SPEED = 68

local VK_B = 0x42

local HOP_SPEED = 0.5

local function readPtr(addr)
    return ffi.cast("uint32_t*", addr)[0]
end

local function readFloat(addr)
    return ffi.cast("float*", addr)[0]
end

local function writeFloat(addr, val)
    ffi.cast("float*", addr)[0] = val
end

function main()
    repeat wait(100) until isSampAvailable()
    wait(3000)

    while true do
        wait(0)

        if isKeyDown(VK_B) then
            local v2 = readPtr(VEHICLE_POINTER_SELF)
            if v2 ~= 0 then
                local sz = readFloat(v2 + VEH_SPEED + 8)

                if sz < HOP_SPEED / 2.0 then
                    local hop = HOP_SPEED / 2.0
                    if sz < -0.1 then
                        hop = HOP_SPEED * 2.0
                    end
                    writeFloat(v2 + VEH_SPEED + 8, sz + hop)
                end
            end
        end
    end
end
