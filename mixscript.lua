script_name("MixScript")
script_author("Assistant & BOJO Dev")
script_version("6.5")

require "lib.moonloader"
local ffi = require 'ffi'
local sampev = require 'lib.samp.events'
local imgui = require 'mimgui'

local guiVisible = imgui.new.bool(false)
local mathEnabled = imgui.new.bool(true)
local reactEnabled = imgui.new.bool(true)
local antiFallEnabled = imgui.new.bool(true)
local autoStopEnabled = imgui.new.bool(false)
local flipKeyEnabled = imgui.new.bool(false)
local vehicleHopEnabled = imgui.new.bool(false)
local speedBoostEnabled = imgui.new.bool(false)

-- Config persistence
local CFG_PATH = "config/mixscript.cfg"

-- VK codes
local VK_F9 = 0x78
local VK_2 = 0x32
local VK_3 = 0x33
local VK_B = 0x42
local VK_LMENU = 0xA4

-- Memory addresses
local VEHICLE_POINTER_SELF = 0x00B6F980
local VEH_SPEED = 68
local VEH_SPIN = 80

-- Anti-fall state
local antiFall = {
    patched = false,
    patch1_addr = 0x004BA3B9,
    patch1_patch = { 0xE9, 0xA7, 0x03, 0x00, 0x00, 0x90 },
    patch2_addr = 0x004B3296,
    patch2_patch = { 0x90, 0x90, 0x90 },
    orig1 = { 0x0F, 0x84, 0xA6, 0x03, 0x00, 0x00 },
    orig2 = { 0xD8, 0x65, 0x04 },
}

-- Speed boost state
local sb = {
    holdTime = 0,
    smoothX = 0, smoothY = 0, smoothZ = 0,
    hadVehicle = false,
    MAX_SPEED = 250.0,
    ACCEL_START = 0.1,
    ACCEL_INCREASE = 0.003,
    ACCEL_MAX = 2.5,
    SMOOTH_FACTOR = 0.15,
}

-- CONFIG
local CONFIG = {
    MATH_CMD = "/ans",
    MATH_MIN_DELAY = 8,
    MATH_MAX_DELAY = 13,
    MATH_TRIGGERS = {
        "math:", "solve", "what is", "calculate", "equation", "compute",
        "quick math", "math test", "solve this", "math problem",
        "first to solve", "who can solve", "fast math", "calculator",
        "question:", "answer this",
        "sagutin", "sino makakasagot", "paunahan sumagot",
        "unang makakasagot", "matematika", "paunahan i-solve",
        "[math]", "** math", ">> math", "reaction math", "mini-event: math"
    },
    REACTION_CMD = "",
    REACTION_MIN_DELAY = 3,
    REACTION_MAX_DELAY = 4,
    REACTION_TRIGGERS = {
        "type this", "first to type", "type the word", "reaction test",
        "reactiontest", "reaction: type", "first one to type", "fast typing",
        "type:", "reaction:", "copy this", "write this", "quick typing",
        "type exactly", "keyboard test", "fastest to type", "who can type",
        "paunahan i-type", "paunahan mag type", "unang makaka-type",
        "kopyahin", "i-type ang", "type nyo", "paunahan magtype",
        "[reaction]", "** reaction", ">> reaction", "mini-event: reaction"
    }
}

local mathMinDelay = imgui.new.int(CONFIG.MATH_MIN_DELAY)
local mathMaxDelay = imgui.new.int(CONFIG.MATH_MAX_DELAY)
local reactMinDelay = imgui.new.int(CONFIG.REACTION_MIN_DELAY)
local reactMaxDelay = imgui.new.int(CONFIG.REACTION_MAX_DELAY)

local function clampDelay()
    if mathMinDelay[0] < 1 then mathMinDelay[0] = 1 end
    if mathMaxDelay[0] < 1 then mathMaxDelay[0] = 1 end
    if mathMinDelay[0] > mathMaxDelay[0] then mathMinDelay[0] = mathMaxDelay[0] end
    if reactMinDelay[0] < 1 then reactMinDelay[0] = 1 end
    if reactMaxDelay[0] < 1 then reactMaxDelay[0] = 1 end
    if reactMinDelay[0] > reactMaxDelay[0] then reactMinDelay[0] = reactMaxDelay[0] end
    CONFIG.MATH_MIN_DELAY = mathMinDelay[0]
    CONFIG.MATH_MAX_DELAY = mathMaxDelay[0]
    CONFIG.REACTION_MIN_DELAY = reactMinDelay[0]
    CONFIG.REACTION_MAX_DELAY = reactMaxDelay[0]
end

local pending = {
    text = nil,
    cmd = "",
    sendTime = 0,
    info = ""
}

-- GUI colors
local GUI_COLORS = {
    header = imgui.ImVec4(0.15, 0.55, 0.85, 1.0),
    headerBg = imgui.ImVec4(0.10, 0.12, 0.18, 1.0),
    accent = imgui.ImVec4(0.20, 0.65, 0.90, 1.0),
    success = imgui.ImVec4(0.20, 0.75, 0.30, 1.0),
    danger = imgui.ImVec4(0.80, 0.20, 0.20, 1.0),
    warning = imgui.ImVec4(0.90, 0.70, 0.10, 1.0),
    text = imgui.ImVec4(0.85, 0.85, 0.90, 1.0),
    muted = imgui.ImVec4(0.50, 0.50, 0.55, 1.0),
    section = imgui.ImVec4(0.20, 0.70, 0.90, 1.0),
}

imgui.OnInitialize(function()
    local style = imgui.GetStyle()
    style.WindowRounding = 6.0
    style.FrameRounding = 4.0
    style.ItemSpacing = imgui.ImVec2(8, 6)
    style.ScrollbarSize = 10.0
end)

local function coloredText(color, text)
    imgui.PushStyleColor(imgui.Col.Text, color)
    imgui.TextUnformatted(text)
    imgui.PopStyleColor()
end

local function smallText(text)
    imgui.PushStyleColor(imgui.Col.Text, GUI_COLORS.muted)
    imgui.TextUnformatted(text)
    imgui.PopStyleColor()
end

local function sectionLabel(text)
    imgui.PushStyleColor(imgui.Col.Text, GUI_COLORS.accent)
    imgui.TextUnformatted(text)
    imgui.PopStyleColor()
end

-- Memory helpers
local function readPtr(addr)
    return ffi.cast("uint32_t*", addr)[0]
end

local function readFloat(addr)
    return ffi.cast("float*", addr)[0]
end

local function writeFloat(addr, val)
    ffi.cast("float*", addr)[0] = val
end

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

-- Anti-fall patch/unpatch
local function applyAntiFall()
    if antiFall.patched then return end
    local c1 = readBytes(antiFall.patch1_addr, #antiFall.orig1)
    local c2 = readBytes(antiFall.patch2_addr, #antiFall.orig2)
    if bytesEqual(c1, antiFall.orig1) and bytesEqual(c2, antiFall.orig2) then
        writeBytes(antiFall.patch1_addr, antiFall.patch1_patch)
        writeBytes(antiFall.patch2_addr, antiFall.patch2_patch)
    end
    antiFall.patched = true
end

local function restoreAntiFall()
    if not antiFall.patched then return end
    local c1 = readBytes(antiFall.patch1_addr, #antiFall.patch1_patch)
    local c2 = readBytes(antiFall.patch2_addr, #antiFall.patch2_patch)
    if bytesEqual(c1, antiFall.patch1_patch) and bytesEqual(c2, antiFall.patch2_patch) then
        writeBytes(antiFall.patch1_addr, antiFall.orig1)
        writeBytes(antiFall.patch2_addr, antiFall.orig2)
    end
    antiFall.patched = false
end

-- Save/Load config
local function saveConfig()
    local data = {
        mathEnabled = mathEnabled[0],
        reactEnabled = reactEnabled[0],
        antiFallEnabled = antiFallEnabled[0],
        autoStopEnabled = autoStopEnabled[0],
        flipKeyEnabled = flipKeyEnabled[0],
        vehicleHopEnabled = vehicleHopEnabled[0],
        speedBoostEnabled = speedBoostEnabled[0],
        mathMinDelay = mathMinDelay[0],
        mathMaxDelay = mathMaxDelay[0],
        reactMinDelay = reactMinDelay[0],
        reactMaxDelay = reactMaxDelay[0],
    }
    local ok, f = pcall(io.open, CFG_PATH, "w")
    if not ok or not f then return end
    f:write("return {\n")
    for k, v in pairs(data) do
        local sv
        if type(v) == "boolean" then sv = v and "true" or "false"
        else sv = tostring(v) end
        f:write(string.format("  %s = %s,\n", k, sv))
    end
    f:write("}\n")
    f:close()
end

local function loadConfig()
    local ok, f = pcall(io.open, CFG_PATH, "r")
    if not ok or not f then return end
    local content = f:read("*all")
    f:close()
    local ok2, cfg = pcall(loadstring, content)
    if not ok2 or not cfg then return end
    local t = cfg()
    if not t then return end

    if t.mathEnabled ~= nil then mathEnabled[0] = t.mathEnabled end
    if t.reactEnabled ~= nil then reactEnabled[0] = t.reactEnabled end
    if t.antiFallEnabled ~= nil then antiFallEnabled[0] = t.antiFallEnabled end
    if t.autoStopEnabled ~= nil then autoStopEnabled[0] = t.autoStopEnabled end
    if t.flipKeyEnabled ~= nil then flipKeyEnabled[0] = t.flipKeyEnabled end
    if t.vehicleHopEnabled ~= nil then vehicleHopEnabled[0] = t.vehicleHopEnabled end
    if t.speedBoostEnabled ~= nil then speedBoostEnabled[0] = t.speedBoostEnabled end
    if t.mathMinDelay ~= nil then
        mathMinDelay[0] = t.mathMinDelay
        CONFIG.MATH_MIN_DELAY = t.mathMinDelay
    end
    if t.mathMaxDelay ~= nil then
        mathMaxDelay[0] = t.mathMaxDelay
        CONFIG.MATH_MAX_DELAY = t.mathMaxDelay
    end
    if t.reactMinDelay ~= nil then
        reactMinDelay[0] = t.reactMinDelay
        CONFIG.REACTION_MIN_DELAY = t.reactMinDelay
    end
    if t.reactMaxDelay ~= nil then
        reactMaxDelay[0] = t.reactMaxDelay
        CONFIG.REACTION_MAX_DELAY = t.reactMaxDelay
    end
end

-- Vehicle functions
local function zeroVec(base)
    if base == 0 then return end
    writeFloat(base, 0.0)
    writeFloat(base + 4, 0.0)
    writeFloat(base + 8, 0.0)
end

local function doAutoStop()
    local vehAddr = readPtr(VEHICLE_POINTER_SELF)
    if vehAddr == 0 then return end
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

local function doFlipVehicle(v2)
    local mat = readPtr(v2 + 20)
    if mat == 0 then return end
    local fx = readFloat(mat + 4)
    local fy = readFloat(mat + 20)
    local flen = math.sqrt(fx*fx + fy*fy)
    if flen < 0.01 then return end
    fx = fx / flen
    fy = fy / flen
    writeFloat(mat + 0,  fy)
    writeFloat(mat + 4,  fx)
    writeFloat(mat + 8,  0.0)
    writeFloat(mat + 16, -fx)
    writeFloat(mat + 20, fy)
    writeFloat(mat + 24, 0.0)
    writeFloat(mat + 32, 0.0)
    writeFloat(mat + 36, 0.0)
    writeFloat(mat + 40, 1.0)
end

local function doVehicleHop()
    local v2 = readPtr(VEHICLE_POINTER_SELF)
    if v2 == 0 then return end
    local sz = readFloat(v2 + VEH_SPEED + 8)
    if sz < 0.25 then
        local hop = 0.25
        if sz < -0.1 then hop = 1.0 end
        writeFloat(v2 + VEH_SPEED + 8, sz + hop)
    end
end

local function clamp(val, min, max)
    if val < min then return min end
    if val > max then return max end
    return val
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function getFwdDir(vehAddr)
    local sx = readFloat(vehAddr + VEH_SPEED)
    local sy = readFloat(vehAddr + VEH_SPEED + 4)
    local hspd = math.sqrt(sx*sx + sy*sy)
    if hspd > 0.5 then
        return sx / hspd, sy / hspd
    end
    local mat = readPtr(vehAddr + 20)
    if mat == 0 then return 0, 0 end
    local fx = readFloat(mat + 16)
    local fy = readFloat(mat + 20)
    local flen = math.sqrt(fx*fx + fy*fy)
    if flen < 0.01 then return 0, 0 end
    return fx / flen, fy / flen
end

local function doSpeedBoost()
    local v2 = readPtr(VEHICLE_POINTER_SELF)
    if v2 == 0 then
        sb.hadVehicle = false
        return
    end
    if not sb.hadVehicle then
        sb.smoothX = readFloat(v2 + VEH_SPEED)
        sb.smoothY = readFloat(v2 + VEH_SPEED + 4)
        sb.smoothZ = readFloat(v2 + VEH_SPEED + 8)
        sb.hadVehicle = true
    end
    sb.holdTime = sb.holdTime + 1
    local sx = readFloat(v2 + VEH_SPEED)
    local sy = readFloat(v2 + VEH_SPEED + 4)
    local sz = readFloat(v2 + VEH_SPEED + 8)
    local hspd = math.sqrt(sx*sx + sy*sy)
    if hspd < sb.MAX_SPEED then
        local dx, dy = getFwdDir(v2)
        if dx ~= 0 or dy ~= 0 then
            local currentAccel = sb.ACCEL_START + (sb.holdTime * sb.ACCEL_INCREASE)
            if currentAccel > sb.ACCEL_MAX then currentAccel = sb.ACCEL_MAX end
            local targetHspd = hspd + currentAccel
            if targetHspd > sb.MAX_SPEED then targetHspd = sb.MAX_SPEED end
            local newX = dx * targetHspd
            local newY = dy * targetHspd
            sb.smoothX = lerp(sb.smoothX, newX, sb.SMOOTH_FACTOR)
            sb.smoothY = lerp(sb.smoothY, newY, sb.SMOOTH_FACTOR)
            sb.smoothZ = lerp(sb.smoothZ, sz, sb.SMOOTH_FACTOR)
            writeFloat(v2 + VEH_SPEED, sb.smoothX)
            writeFloat(v2 + VEH_SPEED + 4, sb.smoothY)
            writeFloat(v2 + VEH_SPEED + 8, sb.smoothZ)
            local spinX = readFloat(v2 + VEH_SPIN)
            local spinY = readFloat(v2 + VEH_SPIN + 4)
            local spinZ = readFloat(v2 + VEH_SPIN + 8)
            local spinLen = math.sqrt(spinX*spinX + spinY*spinY + spinZ*spinZ)
            if spinLen > 0.5 then
                writeFloat(v2 + VEH_SPIN, spinX * 0.9)
                writeFloat(v2 + VEH_SPIN + 4, spinY * 0.9)
                writeFloat(v2 + VEH_SPIN + 8, spinZ * 0.9)
            end
        end
    end
end

-- Apply anti-fall at startup
lua_thread.create(function()
    wait(5000)
    if antiFallEnabled[0] then
        applyAntiFall()
    end
end)

-- ========================
-- GUI RENDER
-- ========================
imgui.OnFrame(function() return guiVisible[0] end, function()
    imgui.SetNextWindowSize(imgui.ImVec2(460, 540), imgui.Cond.FirstUseEver)
    imgui.SetNextWindowPos(imgui.ImVec2(400, 200), imgui.Cond.FirstUseEver)

    imgui.Begin("MixScript", guiVisible, imgui.WindowFlags.NoCollapse)

    -- Header
    imgui.PushStyleColor(imgui.Col.ChildBg, GUI_COLORS.headerBg)
    imgui.BeginChild("##header", imgui.ImVec2(0, 42), true)
    imgui.SetCursorPos(imgui.ImVec2(12, 10))
    imgui.PushStyleColor(imgui.Col.Text, GUI_COLORS.header)
    imgui.TextUnformatted("[  MixScript  ]")
    imgui.PopStyleColor()
    imgui.SameLine()
    imgui.SetCursorPosY(10)
    coloredText(GUI_COLORS.muted, "v6.5")
    imgui.SameLine(imgui.GetContentRegionMax().x - 70)
    imgui.SetCursorPosY(9)
    local statusText = ""
    local statusColor = GUI_COLORS.muted
    if pending.text then
        statusText = "Pending"
        statusColor = GUI_COLORS.success
    else
        statusText = "Idle"
        statusColor = GUI_COLORS.muted
    end
    coloredText(statusColor, statusText)
    imgui.EndChild()
    imgui.PopStyleColor()

    imgui.Dummy(imgui.ImVec2(0, 4))

    -- === AUTO MATH ===
    if imgui.CollapsingHeader("AUTO MATH##mathSection", imgui.TreeNodeFlags.DefaultOpen) then
        imgui.PushStyleColor(imgui.Col.FrameBg, imgui.ImVec4(0.12, 0.14, 0.22, 0.8))
        imgui.BeginChild("##mathSectionBody", imgui.ImVec2(0, 190), true)

        imgui.SetCursorPos(imgui.ImVec2(10, 8))
        imgui.Checkbox("Math Solver", mathEnabled)
        imgui.SameLine()
        imgui.SetCursorPosX(200)
        imgui.Checkbox("Reaction Test", reactEnabled)

        imgui.SetCursorPos(imgui.ImVec2(10, 32))
        imgui.PushStyleColor(imgui.Col.Text, GUI_COLORS.muted)
        imgui.TextUnformatted("Math Delay (sec)")
        imgui.PopStyleColor()
        imgui.SetCursorPos(imgui.ImVec2(10, 48))
        imgui.PushItemWidth(100)
        imgui.DragInt("Min##mathMin", mathMinDelay, 0.2, 1, 30, "%d")
        imgui.SameLine()
        imgui.SetCursorPosX(140)
        imgui.DragInt("Max##mathMax", mathMaxDelay, 0.2, 1, 30, "%d")
        imgui.PopItemWidth()

        imgui.SetCursorPos(imgui.ImVec2(10, 78))
        imgui.PushStyleColor(imgui.Col.Text, GUI_COLORS.muted)
        imgui.TextUnformatted("Reaction Delay (sec)")
        imgui.PopStyleColor()
        imgui.SetCursorPos(imgui.ImVec2(10, 94))
        imgui.PushItemWidth(100)
        imgui.DragInt("Min##reactMin", reactMinDelay, 0.2, 1, 15, "%d")
        imgui.SameLine()
        imgui.SetCursorPosX(140)
        imgui.DragInt("Max##reactMax", reactMaxDelay, 0.2, 1, 15, "%d")
        imgui.PopItemWidth()

        imgui.SetCursorPos(imgui.ImVec2(10, 124))
        if imgui.Button("Math Triggers##mathTrigBtn", imgui.ImVec2(190, 0)) then
            imgui.OpenPopup("##mathTriggersPopup")
        end
        imgui.SameLine()
        imgui.SetCursorPosX(200)
        if imgui.Button("Reaction Triggers##reactTrigBtn", imgui.ImVec2(190, 0)) then
            imgui.OpenPopup("##reactTriggersPopup")
        end

        -- Math triggers popup
        if imgui.BeginPopup("##mathTriggersPopup") then
            imgui.BeginChild("##mathTrigList", imgui.ImVec2(300, 200), true)
            for _, t in ipairs(CONFIG.MATH_TRIGGERS) do
                imgui.PushStyleColor(imgui.Col.Text, GUI_COLORS.text)
                imgui.TextUnformatted("  . " .. t)
                imgui.PopStyleColor()
            end
            imgui.EndChild()
            imgui.EndPopup()
        end

        -- Reaction triggers popup
        if imgui.BeginPopup("##reactTriggersPopup") then
            imgui.BeginChild("##reactTrigList", imgui.ImVec2(300, 200), true)
            for _, t in ipairs(CONFIG.REACTION_TRIGGERS) do
                imgui.PushStyleColor(imgui.Col.Text, GUI_COLORS.text)
                imgui.TextUnformatted("  . " .. t)
                imgui.PopStyleColor()
            end
            imgui.EndChild()
            imgui.EndPopup()
        end

        imgui.EndChild()
        imgui.PopStyleColor()
    end

    imgui.Dummy(imgui.ImVec2(0, 4))

    -- === VEHICLE FEATURES ===
    if imgui.CollapsingHeader("VEHICLE FEATURES##vehSection", imgui.TreeNodeFlags.DefaultOpen) then
        imgui.PushStyleColor(imgui.Col.FrameBg, imgui.ImVec4(0.12, 0.14, 0.22, 0.8))
        imgui.BeginChild("##vehSectionBody", imgui.ImVec2(0, 92), true)

        imgui.SetCursorPos(imgui.ImVec2(10, 8))
        local afLabel = antiFall.patched and "Anti-Fall (Patched)" or "Anti-Fall (Unpatched)"
        local afColor = antiFall.patched and GUI_COLORS.success or GUI_COLORS.danger
        imgui.PushStyleColor(imgui.Col.Text, afColor)
        imgui.Checkbox(afLabel, antiFallEnabled)
        imgui.PopStyleColor()

        imgui.SameLine()
        imgui.SetCursorPosX(200)
        imgui.SetCursorPosY(8)
        imgui.Checkbox("Auto Stop  [3]", autoStopEnabled)

        imgui.SetCursorPos(imgui.ImVec2(10, 32))
        imgui.Checkbox("Flip Key  [2]", flipKeyEnabled)
        imgui.SameLine()
        imgui.SetCursorPosX(200)
        imgui.Checkbox("Vehicle Hop  [B]", vehicleHopEnabled)

        imgui.SetCursorPos(imgui.ImVec2(10, 56))
        imgui.Checkbox("Speed Boost  [L-Alt]", speedBoostEnabled)

        imgui.EndChild()
        imgui.PopStyleColor()
    end

    imgui.End()
end)

-- Chat message colors
local C = { GOLD = "{BFA100}", GREEN = "{33AA33}", CYAN = "{33CCFF}", GRAY = "{888888}", RED = "{FF5555}", WHITE = "{FFFFFF}", YELLOW = "{FFFF00}" }
local PREFIX = C.GOLD .. "[Auto]" .. C.WHITE .. " > "

local function msg(kind, text)
    if isSampAvailable() then
        local colors = { found = C.GREEN, scan = C.GOLD, warn = C.YELLOW, status = C.CYAN, error = C.RED, info = C.WHITE, debug = C.GRAY }
        sampAddChatMessage(PREFIX .. (colors[kind] or colors.info) .. text, 0xFFFFFFFF)
    end
end

local DEBUG = false
local playerNick = ""
local lastSendTime = 0
local SEND_COOLDOWN = 1.5
local MAX_EQ_LEN = 60

local function getLocalName()
    if playerNick == "" and isSampAvailable() then
        local res, id = sampGetPlayerIdByCharHandle(PLAYER_PED)
        if res then
            playerNick = sampGetPlayerNickname(id) or ""
        end
    end
    return playerNick
end

local function showStatus()
    local state = pending.text and "{FFFF00}Pending{FFFFFF}" or "{33AA33}Idle{FFFFFF}"
    local nextStr = ""
    if pending.text then
        local remain = math.ceil(pending.sendTime - os.clock())
        if remain < 0 then remain = 0 end
        nextStr = string.format(" | Next: {FFFF00}%s{FFFFFF} in {33AA33}%d{FFFFFF}s", pending.text, remain)
    end
    local triggers = table.concat(CONFIG.MATH_TRIGGERS, ", ")
    local reactTriggers = table.concat(CONFIG.REACTION_TRIGGERS, ", ")
    sampAddChatMessage(string.format("{BFA100}[Auto] {FFFFFF}Status: %s%s", state, nextStr), 0xFFFFFFFF)
    sampAddChatMessage(string.format("{BFA100}Math{888888}: [%s] %s {BFA100}| React{888888}: [%s] %s",
        CONFIG.MATH_CMD, triggers, CONFIG.REACTION_CMD ~= "" and CONFIG.REACTION_CMD or "(raw)", reactTriggers), 0xFFFFFFFF)
end

local function stripColorCodes(s)
    return (s:gsub("{%x%x%x%x%x%x}", ""))
end

-- Math logic
local function normalizeEquation(e)
    e = e:gsub("%s+", "")
    e = e:gsub("[xX×]", "*")
    e = e:gsub("[÷]", "/")
    e = e:gsub("[−–—]", "-")
    e = e:gsub("[＋]", "+")
    e = e:gsub("[／]", "/")
    e = e:gsub("[＊]", "*")
    e = e:gsub("[．]", ".")
    e = e:gsub("(%d)%(", "%1*(")
    e = e:gsub("%)(%d)", ")*%1")
    e = e:gsub("%)%(", ")*(")
    return e
end

local function extractEquationFromMessage(text)
    local msgText = stripColorCodes(text)
    local candidate = msgText:match("([%-%d%(][%d%+%-%*/xX×÷%.%s%(%)]+[%d%)])")
    if not candidate then return nil end
    if #candidate > MAX_EQ_LEN then return nil end
    candidate = normalizeEquation(candidate)
    if not (candidate:find("%d") and candidate:find("[%+%-%*/]")) then
        return nil
    end
    local numCount = 0
    for _ in candidate:gmatch("%d+") do numCount = numCount + 1 end
    if numCount < 2 then return nil end
    return candidate
end

-- Reaction logic
local function extractReactionString(text, trigger)
    local msgText = stripColorCodes(text)
    local match = msgText:match("['\"]([^'\"]+)['\"]")
    if match then
        match = match:gsub("^[%s%p]+", ""):gsub("[%s%p]+$", "")
        if #match >= 1 and #match <= 25 then return match end
    end
    local lowerMsg = msgText:lower()
    local typeWord = "%f[%a]type%f[%A]"
    local patterns = {
        typeWord .. "%s*[:%-=>]+%s*()(%S+)",
        typeWord .. "%s+the%s+word%s+()(%S+)",
        typeWord .. "%s+the%s+()(%S+)",
        typeWord .. "%s+word%s+()(%S+)",
        typeWord .. "%s+this%s+()(%S+)",
        typeWord .. "%s+phrase%s+()(%S+)",
        typeWord .. "%s+text%s+()(%S+)",
        typeWord .. "%s+exactly%s+()(%S+)",
        typeWord .. "%s+ang%s+()(%S+)",
        typeWord .. "%s+()(%S+)"
    }
    for _, pattern in ipairs(patterns) do
        local _, _, pos, wordLower = lowerMsg:find(pattern)
        if pos and wordLower then
            local targetWord = msgText:sub(pos, pos + #wordLower - 1)
            targetWord = targetWord:gsub("^[%s]+", ""):gsub("[%s%.!]+$", "")
            if #targetWord >= 1 and #targetWord <= 25 then return targetWord end
        end
    end
    return nil
end

-- ==========================================
-- MAIN LOOP
-- ==========================================
function main()
    while not isSampAvailable() do wait(100) end
    getLocalName()

    loadConfig()
    clampDelay()

    math.randomseed(os.clock() * 10000)

    pcall(sampRegisterChatCommand, "autostatus", showStatus)

    local guiKeyPressed = false
    local prevAntiFallToggle = antiFallEnabled[0]
    local saveTimer = 0

    while true do
        wait(0)

        -- Sync delay sliders to CONFIG
        clampDelay()

        -- Auto-save every ~2 seconds (200 iterations)
        saveTimer = saveTimer + 1
        if saveTimer >= 200 then
            saveTimer = 0
            saveConfig()
        end

        -- F9 GUI toggle
        local f9down = isKeyDown(VK_F9)
        if f9down and not guiKeyPressed and not sampIsChatInputActive() and not sampIsDialogActive() then
            guiVisible[0] = not guiVisible[0]
            guiKeyPressed = true
        elseif not f9down then
            guiKeyPressed = false
        end

        -- Anti-fall toggle monitoring
        local currentAF = antiFallEnabled[0]
        if currentAF ~= prevAntiFallToggle then
            if currentAF then
                applyAntiFall()
            else
                restoreAntiFall()
            end
            prevAntiFallToggle = currentAF
        end

        -- Auto Stop (Key 3)
        if autoStopEnabled[0] and isKeyJustPressed(VK_3) then
            doAutoStop()
        end

        -- Flip Key (Key 2)
        if flipKeyEnabled[0] and isKeyJustPressed(VK_2) then
            local v2 = readPtr(VEHICLE_POINTER_SELF)
            if v2 ~= 0 then
                doFlipVehicle(v2)
                printStringNow("~g~Flipped", 300, 1.0)
            end
        end

        -- Vehicle Hop (Key B - hold)
        if vehicleHopEnabled[0] and isKeyDown(VK_B) then
            doVehicleHop()
        end

        -- Speed Boost (Left Alt - hold)
        if speedBoostEnabled[0] and isKeyDown(VK_LMENU) then
            doSpeedBoost()
        elseif not isKeyDown(VK_LMENU) then
            sb.holdTime = 0
            sb.hadVehicle = false
        end

        -- Math/Reaction pending display
        if pending.text then
            local remaining = pending.sendTime - os.clock()
            if remaining > 0 then
                printStringNow(string.format("~w~Sending in ~y~%d~w~s", math.ceil(remaining)), 500)
            end
        end

        -- Send pending text
        if pending.text and os.clock() >= pending.sendTime then
            local chatPayload = pending.text
            if pending.cmd and pending.cmd ~= "" then
                chatPayload = pending.cmd .. " " .. pending.text
            end
            sampSendChat(chatPayload)
            local sentText = pending.text
            lastSendTime = os.clock()
            pending.text = nil
            pending.sendTime = 0
            pending.cmd = ""
            msg("info", ("Sent: %s"):format(sentText))
        end
    end
end

-- Restore anti-fall on exit
function onScriptTerminate(script, quitGame)
    saveConfig()
    if antiFall.patched then
        restoreAntiFall()
    end
end

-- ==========================================
-- CHAT SCANNER (sampev.onServerMessage)
-- ==========================================
function sampev.onServerMessage(color, text)
    local ok, err = pcall(function()
        if os.clock() - lastSendTime < SEND_COOLDOWN then return end
        if DEBUG then msg("debug", text) end

        local cleanText = stripColorCodes(text)
        local lowerText = cleanText:lower()

        local nick = getLocalName()
        if nick ~= "" and lowerText:find(nick:lower(), 1, true) then
            return
        end

        -- 1. Math test
        if mathEnabled[0] then
            for _, trigger in ipairs(CONFIG.MATH_TRIGGERS) do
                if lowerText:find(trigger:lower(), 1, true) then
                    local equation = extractEquationFromMessage(cleanText)
                    if equation then
                        local func = loadstring("return " .. equation)
                        if func then
                            local ok2, result = pcall(func)
                            if ok2 then
                                local answer = tostring(math.floor(tonumber(result) + 0.5))
                                local delay = math.random(CONFIG.MATH_MIN_DELAY, CONFIG.MATH_MAX_DELAY)
                                pending.text = answer
                                pending.cmd = CONFIG.MATH_CMD
                                pending.sendTime = os.clock() + delay
                                msg("found", ("Math Solved: %s = %s . %ds delay"):format(equation, answer, delay))
                                return
                            end
                        end
                    end
                end
            end
        end

        -- 2. Reaction test
        if reactEnabled[0] then
            for _, trigger in ipairs(CONFIG.REACTION_TRIGGERS) do
                if lowerText:find(trigger:lower(), 1, true) then
                    local reactionString = extractReactionString(cleanText, trigger)
                    if reactionString then
                        local delay = math.random(CONFIG.REACTION_MIN_DELAY, CONFIG.REACTION_MAX_DELAY)
                        pending.text = reactionString
                        pending.cmd = CONFIG.REACTION_CMD
                        pending.sendTime = os.clock() + delay
                        msg("found", ("Reaction String: '%s' . %ds delay"):format(reactionString, delay))
                        return
                    end
                end
            end
        end
    end)
    if not ok and DEBUG then
        msg("error", tostring(err))
    end
end
