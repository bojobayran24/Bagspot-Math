-- flipkey.lua
-- Press 2 to instantly flip vehicle upright (like XSF server's SetVehicleZAngle)

script_name("FlipKey")
script_author("BOJO Dev")
script_version("1.0")

require 'lib.moonloader'
local ffi = require 'ffi'

local VEHICLE_POINTER_SELF = 0x00B6F980

local VK_2 = 0x32

local function readPtr(addr)
    return ffi.cast("uint32_t*", addr)[0]
end

local function readFloat(addr)
    return ffi.cast("float*", addr)[0]
end

local function writeFloat(addr, val)
    ffi.cast("float*", addr)[0] = val
end

-- CMatrix_Padded row-major float[16]:
-- m[0] right.x | m[1] front.x | m[2]  up.x | m[3]  pos.x
-- m[4] right.y | m[5] front.y | m[6]  up.y | m[7]  pos.y
-- m[8] right.z | m[9] front.z | m[10] up.z | m[11] pos.z

local function flipVehicle(v2)
    local mat = readPtr(v2 + 20)
    if mat == 0 then return end

    local fx = readFloat(mat + 4)   -- front.x
    local fy = readFloat(mat + 20)  -- front.y
    local flen = math.sqrt(fx*fx + fy*fy)
    if flen < 0.01 then return end

    -- Keep heading direction, set upright
    fx = fx / flen
    fy = fy / flen

    -- up = (0, 0, 1), front = (fx, fy, 0), right = (fy, -fx, 0)
    writeFloat(mat + 0,  fy)     -- right.x
    writeFloat(mat + 4,  fx)     -- front.x
    writeFloat(mat + 8,  0.0)    -- up.x
    writeFloat(mat + 16, -fx)    -- right.y
    writeFloat(mat + 20, fy)     -- front.y
    writeFloat(mat + 24, 0.0)    -- up.y
    writeFloat(mat + 32, 0.0)    -- right.z
    writeFloat(mat + 36, 0.0)    -- front.z
    writeFloat(mat + 40, 1.0)    -- up.z
end

function main()
    repeat wait(100) until isSampAvailable()
    wait(3000)

    while true do
        wait(0)

        if isKeyJustPressed(VK_2) then
            local v2 = readPtr(VEHICLE_POINTER_SELF)
            if v2 ~= 0 then
                flipVehicle(v2)
                printStringNow("~g~Flipped", 300, 1.0)
            end
        end
    end
end
