-- autostop.lua
-- Press "3" to instantly stop vehicle (car/bike/plane/boat)
-- Uses s0beit memory offsets for instant velocity/rotation zeroing

script_name("AutoStop")
script_author("BOJO Dev")
script_version("1.0")

require 'lib.moonloader'
local ffi = require 'ffi'
local encoding = require 'encoding'
encoding.default = 'CP1251'
local u8 = encoding.UTF8

-- GTA memory addresses (from s0beit src/cheat.h)
local VEHICLE_POINTER_SELF = 0x00B6F980

-- vehicle_info offsets (cheat.h lines 558-580)
local VEH_SPEED       = 68      -- CVector speed[3]
local VEH_SPIN        = 80      -- CVector spin[3]

local VK_KEY_3 = 0x33

-- FFI memory helpers
local function readPtr(addr)
    return ffi.cast("uint32_t*", addr)[0]
end

local function readFloat(addr)
    return ffi.cast("float*", addr)[0]
end

local function writeFloat(addr, val)
    ffi.cast("float*", addr)[0] = val
end

local function zeroVec(base)
    if base == 0 then return end
    writeFloat(base, 0.0)
    writeFloat(base + 4, 0.0)
    writeFloat(base + 8, 0.0)
end

function main()
    repeat wait(100) until isSampAvailable()
    wait(3000)

    while true do
        wait(0)

        if isKeyJustPressed(VK_KEY_3) then
            local vehAddr = readPtr(VEHICLE_POINTER_SELF)
            if vehAddr == 0 then goto skip end

            local untilTime = os.clock() + 0.35
            while os.clock() < untilTime do
                wait(0)
                local v2 = readPtr(VEHICLE_POINTER_SELF)
                if v2 == 0 then break end

                local sx = readFloat(v2 + VEH_SPEED)
                local sy = readFloat(v2 + VEH_SPEED + 4)
                local sz = readFloat(v2 + VEH_SPEED + 8)
                if math.sqrt(sx*sx + sy*sy + sz*sz) < 0.05 then break end

                writeFloat(v2 + VEH_SPEED, sx * 0.78)
                writeFloat(v2 + VEH_SPEED + 4, sy * 0.78)
                writeFloat(v2 + VEH_SPEED + 8, sz * 0.78)

                writeFloat(v2 + VEH_SPIN, 0.0)
                writeFloat(v2 + VEH_SPIN + 4, 0.0)
                writeFloat(v2 + VEH_SPIN + 8, 0.0)
            end

            printStringNow("~w~STOP", 300, 1.0)
        end

        ::skip::
    end
end
