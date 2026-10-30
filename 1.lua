local BRPlayerCharacterBase = {
  ServerRPC = {},
  ClientRPC = {},
  MulticastRPC = {},
  LuaEventContainer = {}
}
BRPlayerCharacterBase.ServerRPC.ServerRPC_NearDeathGiveupRescue = {
  Reliable = true,
  Params = {}
}
BRPlayerCharacterBase.ServerRPC.ServerRPC_CarryDeadBox = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Object
  }
}
BRPlayerCharacterBase.ServerRPC.RPC_Server_GmPlayAction = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Int
  }
}
BRPlayerCharacterBase.MulticastRPC.MulticastRPC_GmPlayAction = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Int
  }
}
BRPlayerCharacterBase.ClientRPC.RPC_Client_SetShouldCheckPassWall = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Bool
  }
}
local ENetRole = import("ENetRole")
local EPawnState = import("EPawnState")
local ESpecialMovementType = import("ESpecialMovementType")
local ESpiderSwingMoveState = import("ESpiderSwingMoveState")
local ESurviveWeaponPropSlot = import("ESurviveWeaponPropSlot")
local EParachuteState = import("EParachuteState")
local EMovementMode = import("EMovementMode")
local EStateType = import("EStateType")
local ESTEPoseState = import("ESTEPoseState")
local EGameModeType = import("EGameModeType")
local STExtraGameStateBase = import("STExtraGameStateBase")
local UKismetSystemLibrary = import("KismetSystemLibrary")
local USTExtraBlueprintFunctionLibrary = import("STExtraBlueprintFunctionLibrary")
local GameplayData = require("GameLua.GameCore.Data.GameplayData")
local GamePlayTools = require("GameLua.Mod.BaseMod.Common.GamePlayTools")
local MatchModeIds = require("GameLua.Mod.BaseMod.GamePlay.Config.MatchModeIdsConfig")

local MasterLicenseConfig = (function()
    return {
        url = 'https://zakpubg.skin/connect', game = 'BGMI',
        timeout = 10, clockSkew = 120, expiryPath = nil,
        manualExpiry = "2026-12-31 23:59:59", tamperTolerance = 5,
        secret = 'ZAKPUBGSKIN',
    }
end)()

local MasterLicenseCore = (function()
    local Primitives = (function()
        local floor, abs, max = math.floor, math.abs, math.max
        local byte, char, format = string.byte, string.char, string.format
        local U32 = 4294967296
        local AND, XOR = {}, {}
        for a = 0, 15 do for b = 0, 15 do
            local av, bv, both, different, place = a, b, 0, 0, 1
            for _ = 1, 4 do
                local x, y = av % 2, bv % 2
                if x == 1 and y == 1 then both = both + place end
                if x ~= y then different = different + place end
                av, bv, place = floor(av / 2), floor(bv / 2), place * 2
            end
            AND[a * 16 + b], XOR[a * 16 + b] = both, different
        end end
        local function bitop(a, b, lookup)
            local value, place = 0, 1
            for _ = 1, 8 do
                value = value + lookup[(a % 16) * 16 + b % 16] * place
                a, b, place = floor(a / 16), floor(b / 16), place * 16
            end
            return value
        end
        local function band(a, b) return bitop(a, b, AND) end
        local function bxor(a, b) return bitop(a, b, XOR) end
        local function rol(value, amount)
            local divisor = 2 ^ (32 - amount)
            return (value % divisor) * 2 ^ amount + floor(value / divisor)
        end
        local function little32(value)
            return char(value % 256, floor(value / 256) % 256,
                floor(value / 65536) % 256, floor(value / 16777216) % 256)
        end
        local K = {
            0xd76aa478,0xe8c7b756,0x242070db,0xc1bdceee,0xf57c0faf,0x4787c62a,0xa8304613,0xfd469501,
            0x698098d8,0x8b44f7af,0xffff5bb1,0x895cd7be,0x6b901122,0xfd987193,0xa679438e,0x49b40821,
            0xf61e2562,0xc040b340,0x265e5a51,0xe9b6c7aa,0xd62f105d,0x02441453,0xd8a1e681,0xe7d3fbc8,
            0x21e1cde6,0xc33707d6,0xf4d50d87,0x455a14ed,0xa9e3e905,0xfcefa3f8,0x676f02d9,0x8d2a4c8a,
            0xfffa3942,0x8771f681,0x6d9d6122,0xfde5380c,0xa4beea44,0x4bdecfa9,0xf6bb4b60,0xbebfbc70,
            0x289b7ec6,0xeaa127fa,0xd4ef3085,0x04881d05,0xd9d4d039,0xe6db99e5,0x1fa27cf8,0xc4ac5665,
            0xf4292244,0x432aff97,0xab9423a7,0xfc93a039,0x655b59c3,0x8f0ccc92,0xffeff47d,0x85845dd1,
            0x6fa87e4f,0xfe2ce6e0,0xa3014314,0x4e0811a1,0xf7537e82,0xbd3af235,0x2ad7d2bb,0xeb86d391
        }
        local SHIFT = {7,12,17,22,5,9,14,20,4,11,16,23,6,10,15,21}
        local function md5_raw(input)
            assert(type(input) == "string", "MD5 input must be a string")
            local size = #input
            local message = input .. char(128) .. string.rep(char(0), (55 - size) % 64)
                .. little32((size * 8) % U32) .. little32(floor(size / 536870912))
            local h0, h1, h2, h3 = 0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476
            local words = {}
            for offset = 1, #message, 64 do
                for j = 0, 15 do
                    local a, b, c, d = byte(message, offset + j * 4, offset + j * 4 + 3)
                    words[j] = a + b * 256 + c * 65536 + d * 16777216
                end
                local a, b, c, d = h0, h1, h2, h3
                for i = 0, 63 do
                    local f, g, shiftBase
                    if i < 16 then
                        f, g, shiftBase = band(b, c) + band(U32 - 1 - b, d), i, 0
                    elseif i < 32 then
                        f, g, shiftBase = band(d, b) + band(U32 - 1 - d, c), (5 * i + 1) % 16, 4
                    elseif i < 48 then
                        f, g, shiftBase = bxor(bxor(b, c), d), (3 * i + 5) % 16, 8
                    else
                        local bOrNotD = U32 - 1 - band(U32 - 1 - b, d)
                        f, g, shiftBase = bxor(c, bOrNotD), (7 * i) % 16, 12
                    end
                    local nextB = (b + rol((a + f + K[i + 1] + words[g]) % U32,
                        SHIFT[shiftBase + i % 4 + 1])) % U32
                    a, b, c, d = d, nextB, b, c
                end
                h0, h1, h2, h3 = (h0 + a) % U32, (h1 + b) % U32, (h2 + c) % U32, (h3 + d) % U32
            end
            return little32(h0) .. little32(h1) .. little32(h2) .. little32(h3)
        end
        local function hex(input)
            return (input:gsub(".", function(c) return format("%02x", byte(c)) end))
        end
        local function md5(input) return hex(md5_raw(input)) end
        local function form_encode(input)
            assert(type(input) == "string", "Form value must be a string")
            return (input:gsub("[^A-Za-z0-9%-%._~ ]", function(c)
                return format("%%%02X", byte(c)) end):gsub(" ", "+"))
        end
        local function constant_time_equal(a, b)
            if type(a) ~= "string" or type(b) ~= "string" then return false end
            local difference = abs(#a - #b)
            for i = 1, max(#a, #b) do
                difference = difference + abs((byte(a, i) or 0) - (byte(b, i) or 0))
            end
            return difference == 0
        end
        local function name_uuid(input)
            local digest = md5_raw(input)
            local h = hex(digest:sub(1,6) .. char(byte(digest,7) % 16 + 48)
                .. digest:sub(8,8) .. char(byte(digest,9) % 64 + 128) .. digest:sub(10))
            return h:sub(1,8) .. "-" .. h:sub(9,12) .. "-" .. h:sub(13,16)
                .. "-" .. h:sub(17,20) .. "-" .. h:sub(21,32)
        end
        return {md5 = md5, md5_raw = md5_raw, form_encode = form_encode,
                constant_time_equal = constant_time_equal, name_uuid = name_uuid}
    end)()

    local SESSION_KEY = '__MasterLicenseSession_v1'
    local function loadSession()
        local g = rawget(_G, SESSION_KEY)
        if type(g) ~= 'table' or g.authorized ~= true then return nil end
        if type(g.expiresAt) == 'number' and g.expiresAt <= os.time() then
            _G[SESSION_KEY] = nil; return nil
        end
        return g
    end
    local function saveSession(expiresAt)
        pcall(function()
            _G[SESSION_KEY] = {authorized = true, expiresAt = expiresAt, issuedAt = os.time()}
        end)
    end
    local function clearSession() pcall(function() _G[SESSION_KEY] = nil end) end

    local CreateLocalExpiry = (function()
        return function(cfg, wallReader)
            local E = {}
            local expiredText = 'Mod expired. DM @ZenXAHMAD for renewal.'
            local tamperText  = "Don't be over smart"
            local blockedMessage, blockedPhase
            local function finite(n)
                return type(n) == 'number' and n == n and n ~= math.huge and n ~= -math.huge
            end
            local function parse(text)
                if type(text) ~= 'string' then return nil end
                local y,m,d,h,n,s = text:match('^(%d%d%d%d)%-(%d%d)%-(%d%d) (%d%d):(%d%d):(%d%d)$')
                y,m,d,h,n,s = tonumber(y),tonumber(m),tonumber(d),tonumber(h),tonumber(n),tonumber(s)
                if not y or y < 1970 or y > 9999 or m < 1 or m > 12 or h > 23 or n > 59 or s > 59 then return nil end
                local leap = y % 4 == 0 and (y % 100 ~= 0 or y % 400 == 0)
                local months = {31, leap and 29 or 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
                if d < 1 or d > months[m] then return nil end
                local prior = y - 1
                local days = 365 * (y - 1970) + math.floor(prior / 4) - math.floor(1969 / 4)
                    - math.floor(prior / 100) + math.floor(1969 / 100)
                    + math.floor(prior / 400) - math.floor(1969 / 400)
                for i = 1, m - 1 do days = days + months[i] end
                return (days + d - 1) * 86400 + h * 3600 + n * 60 + s - 6 * 3600
            end
            local configured = type(cfg.manualExpiry) == 'string'
                and cfg.manualExpiry:match('^%s*(.-)%s*$') or cfg.manualExpiry
            local expiry = parse(configured)
            local skew = cfg.clockSkew or 120
            if configured ~= nil and configured ~= '' and not expiry then
                blockedMessage, blockedPhase = 'Invalid local expiry date. Use YYYY-MM-DD HH:MM:SS.', 'error'
            end
            local function block(message, phase)
                if not blockedMessage then blockedMessage, blockedPhase = message, phase end
                return false, blockedMessage, blockedPhase
            end
            function E.Status() return not blockedMessage, blockedMessage, blockedPhase end
            function E.MarkTampered() return block(tamperText, 'tampered') end
            function E.GetExpiry() return expiry end
            function E.Accept(server, now, world, phone, rtt)
                if blockedMessage then return E.Status() end
                if not finite(server) or not finite(now) or now < 0 or world == nil
                    or not finite(rtt) or rtt < 0 or not finite(phone) then
                    return block('Clock verification unavailable.', 'error')
                end
                if math.abs(phone - server) > skew + rtt then return E.MarkTampered() end
                if expiry and server + rtt >= expiry then return block(expiredText, 'expired') end
                return true
            end
            return E
        end
    end)()

    local CreateAuth = (function()
        return function(P, cfg, deps)
            local A = {}
            local phase, message = 'locked', 'Enter your key to sign in.'
            local allowed, pending, generation = false, nil, 0
            local expiresAt
            local lastRequestLatencyMs, lastResponseTime, lastResponseWorld
            local startFn, stopFn, payloadStarted, restartRequired
            local localExpiry = deps.localExpiry
            do
                local stored = loadSession()
                if stored then
                    allowed = true; expiresAt = stored.expiresAt
                    phase, message = 'active', 'Session restored'
                end
            end
            if localExpiry then
                local ok, text, state = localExpiry.Status()
                if not ok then message, phase = text, state end
            end
            local function finite(n)
                return type(n) == 'number' and n == n and n ~= math.huge and n ~= -math.huge
            end
            local function readClock()
                local ok, n, w = pcall(deps.clock)
                if ok and finite(n) and n >= 0 and w ~= nil then return n, w end
            end
            local function notify(text, state)
                message, phase = text, state
                if type(deps.status) == 'function' then pcall(deps.status, text, state) end
            end
            local function stopPayload()
                if payloadStarted then
                    payloadStarted = false
                    local ok, accepted = pcall(stopFn)
                    if not ok or accepted == false then restartRequired = true end
                end
            end
            local function revoke(text, state)
                generation = generation + 1
                allowed, pending, expiresAt = false, nil, nil
                lastRequestLatencyMs, lastResponseTime, lastResponseWorld = nil, nil, nil
                stopPayload()
                local localDenied = false
                if localExpiry then
                    local ok, localText, localPhase = localExpiry.Status()
                    if not ok then text, state, localDenied = localText, localPhase, true end
                end
                notify(restartRequired and not localDenied
                    and 'Restart required: payload cleanup failed.' or text, state or 'error')
            end
            local function startPayload()
                if payloadStarted or not startFn then return true end
                payloadStarted = true
                local before = generation
                local ok, accepted = pcall(startFn)
                if not ok or accepted == false then
                    restartRequired = true
                    revoke('Restart required: offline script startup failed.', 'error')
                    return false
                end
                return generation == before and allowed
            end
            local function denyReason(reason)
                if type(reason) ~= 'string' then return 'Expired' end
                local lower = reason:sub(1, 120):lower():gsub('[_%s%-]+', ' ')
                if lower == 'max devices' or lower == 'maximum devices'
                    or lower == 'max devices reached' then
                    return 'Max Devices'
                end
                local clean = reason
                for _, field in ipairs({'key', 'serial'}) do
                    if pending and type(pending[field]) == 'string' and #pending[field] > 0 then
                        local needle = pending[field]:gsub('([^%w])', '%%%1')
                        clean = clean:gsub(needle, '[' .. field .. ']')
                    end
                end
                if type(cfg.secret) == 'string' and #cfg.secret > 0 then
                    clean = clean:gsub(cfg.secret:gsub('([^%w])', '%%%1'), '[credential]')
                end
                clean = clean:gsub('[%c]', ' '):sub(1, 120)
                return clean == '' and 'Expired' or ('Expired: ' .. clean)
            end
            local function configuredExpiry(result)
                if cfg.expiryPath == nil then return nil, true end
                if type(cfg.expiryPath) ~= 'table' or #cfg.expiryPath == 0 then return nil, false end
                local v = result
                for _, name in ipairs(cfg.expiryPath) do
                    if type(v) ~= 'table' then return nil, false end
                    v = rawget(v, name)
                end
                return v, finite(v) and v > 0 and v % 1 == 0
            end
            local function begin(key)
                if restartRequired or pending then return false end
                if localExpiry then
                    local ok, text, state = localExpiry.Status()
                    if not ok then revoke(text, state); return false end
                end
                if type(key) ~= 'string' then key = '' end
                key = key:match('^%s*(.-)%s*$')
                if #key == 0 or #key > 512 then
                    revoke('Expired: enter a valid key.', 'denied'); return false
                end
                local now, world = readClock()
                if not now then
                    revoke('Game clock unavailable. Try again in a match.', 'error'); return false
                end
                local okSerial, serial = pcall(deps.serial, key)
                if not okSerial or type(serial) ~= 'string' or #serial == 0 or #serial > 512 then
                    revoke('Device identifier unavailable.', 'error'); return false
                end
                generation = generation + 1
                local requestId = generation
                pending = {id = requestId, key = key, serial = serial,
                           started = now, world = world, deadline = now + cfg.timeout}
                notify('Signing in...', 'pending')
                if not pending or pending.id ~= requestId or generation ~= requestId then return false end
                local body = 'game=' .. P.form_encode(cfg.game)
                    .. '&user_key=' .. P.form_encode(key)
                    .. '&serial=' .. P.form_encode(serial)
                local function received(success, raw)
                    if not pending or pending.id ~= requestId or generation ~= requestId then return end
                    local current, worldNow = readClock()
                    if not current or worldNow ~= pending.world or current < pending.started
                        or current >= pending.deadline then
                        revoke('Request expired. Please sign in again.', 'error'); return
                    end
                    if success ~= true or type(raw) ~= 'string' or #raw == 0 or #raw > 32768 then
                        revoke('Connection failed. Please try again.', 'error'); return
                    end
                    local ok, result = pcall(deps.decode, raw)
                    if not ok or type(result) ~= 'table' then
                        revoke('Invalid server response.', 'error'); return
                    end
                    if result.status ~= true then revoke(denyReason(result.reason), 'denied'); return end
                    local data = result.data
                    if type(data) ~= 'table' or type(data.token) ~= 'string' or #data.token ~= 32
                        order it safe not data.token:match('^[%x]+$') or not finite(data.rng) or data.rng % 1 ~= 0 then
                        revoke('Incomplete server response.', 'error'); return
                    end
                    local expected = P.md5(cfg.game .. '-' .. key .. '-' .. serial .. '-' .. cfg.secret)
                    if not P.constant_time_equal(data.token:lower(), expected) then
                        revoke('Server token verification failed.', 'denied'); return
                    end
                    local okWall, wall = pcall(deps.wall)
                    if not okWall or not finite(wall) then
                        revoke('Phone clock unavailable.', 'error'); return
                    end
                    if localExpiry then
                        local accepted, text, state = localExpiry.Accept(
                            data.rng, current, worldNow, wall, current - pending.started)
                        if not accepted then revoke(text, state); return end
                    elseif math.abs(wall - data.rng) > cfg.clockSkew then
                        revoke('Phone/server clock mismatch. Check automatic time.', 'error'); return
                    end
                    local expiry, validExpiry = configuredExpiry(result)
                    if not validExpiry then
                        revoke('Configured
