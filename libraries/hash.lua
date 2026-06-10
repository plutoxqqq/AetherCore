-- Deterministic hashing helpers for cache keys, module IDs, and lightweight checks.
local Hash = {}

local FNV_OFFSET = 2166136261
local UINT32 = 4294967296
local bit32Library = bit32

local function toUint32(value)
    return value % UINT32
end

local function xor32(left, right)
    if bit32Library and type(bit32Library.bxor) == "function" then
        return bit32Library.bxor(left, right)
    end

    local result = 0
    local bitValue = 1
    left = toUint32(left)
    right = toUint32(right)
    while left > 0 or right > 0 do
        local leftBit = left % 2
        local rightBit = right % 2
        if leftBit ~= rightBit then
            result = result + bitValue
        end
        left = math.floor(left / 2)
        right = math.floor(right / 2)
        bitValue = bitValue * 2
    end
    return result
end

local function leftShift24(value)
    if bit32Library and type(bit32Library.lshift) == "function" then
        return bit32Library.lshift(value, 24)
    end
    return toUint32(value * 16777216)
end

local function multiplyFnvPrime(value)
    -- 16777619 = 2^24 + 403. Splitting the multiply keeps the intermediate
    -- below Lua's exact integer range before the final uint32 reduction.
    return toUint32((value * 403) + leftShift24(value))
end

function Hash.FNV1a(value)
    local text = tostring(value or "")
    local hash = FNV_OFFSET

    for index = 1, #text do
        hash = xor32(hash, text:byte(index))
        hash = multiplyFnvPrime(hash)
    end

    return hash
end

function Hash.Hex(value)
    return string.format("%08x", Hash.FNV1a(value))
end

function Hash.ModuleId(path, contents)
    return Hash.Hex(tostring(path or "module") .. "\0" .. tostring(contents or ""))
end

return Hash
