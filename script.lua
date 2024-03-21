-- Constants
local GA = 1919
local TOPK_DECAY_LOOKUP_TABLE = 100 -- Adjust as needed

-- Helper function: Calculate maximum of two numbers
local function max(a, b)
    return a > b and a or b
end

local function murmurhash2(item, itemlen, i)
    local m = 0x5bd1e995
    local r = 24
    local h = seed ~ len

    local data = {string.byte(key, 1, len)}
    local i = 1

    while len >= 4 do
        local k = data[i] | (data[i+1] << 8) | (data[i+2] << 16) | (data[i+3] << 24)
        k = k * m
        k = (k ~ (k >> r)) * m

        h = (h * m) ~ k

        i = i + 4
        len = len - 4
    end

    if len == 3 then
        h = h ~ (data[i+2] << 16)
    end
    if len >= 2 then
        h = h ~ (data[i+1] << 8)
    end
    if len >= 1 then
        h = h ~ data[i]
        h = (h * m)
    end

    h = h ~ (h >> 13)
    h = (h * m)
    h = h ~ (h >> 15)

    return h
end

-- Helper function: Heapify down operation
local function heapifyDown(array, len, start)
    local child = start

    if len < 2 or math.floor((len - 2) / 2) < child then
        return
    end

    child = 2 * child + 1
    if child + 1 < len and array[child].count > array[child + 1].count then
        child = child + 1
    end

    if array[child].count > array[start].count then
        return
    end

    local top = array[start]
    repeat
        array[start] = array[child]
        start = child

        if math.floor((len - 2) / 2) < child then
            break
        end

        child = 2 * child + 1

        if child + 1 < len and array[child].count > array[child + 1].count then
            child = child + 1
        end
    until array[child].count < top.count

    array[start] = top
end

-- Main TopK structure
local TopK = {}
TopK.__index = TopK

function TopK.create(k, width, depth, decay)
    assert(k > 0)
    assert(width > 0)
    assert(depth > 0)
    assert(decay > 0 and decay <= 1)

    local topk = setmetatable({}, TopK)
    topk.k = k
    topk.width = width
    topk.depth = depth
    topk.decay = decay
    topk.data = {}
    topk.heap = {}

    -- Lookup table initialization
    topk.lookupTable = {}
    for i = 1, TOPK_DECAY_LOOKUP_TABLE do
        topk.lookupTable[i] = decay ^ i
    end

    return topk
end

function TopK:destroy()
    for i = 1, self.k do
        self.heap[i] = nil
    end

    self.heap = nil
    self.data = nil
end

function TopK:add(item, itemlen, increment)
    local fp = murmurhash2(item, itemlen, GA)
    local maxCount = 0
    local heapMin = self.heap[1] and self.heap[1].count or 0

    -- Get max item count
    for i = 1, self.depth do
        local loc = murmurhash2(item, itemlen, i) % self.width
        local runner = self.data[i * self.width + loc]
        local countPtr = runner and runner.count or 0

        if countPtr == 0 then
            runner = { fp = fp, count = increment }
            maxCount = max(maxCount, countPtr)
        elseif runner.fp == fp then
            runner.count = runner.count + increment
            maxCount = max(maxCount, countPtr)
        else
            local local_incr = increment

            for _ = 1, local_incr do
                local decay = countPtr < TOPK_DECAY_LOOKUP_TABLE and self.lookupTable[countPtr] or 0
                local chance = math.random()

                if chance < decay then
                    countPtr = countPtr - 1

                    if countPtr == 0 then
                        runner.fp = fp
                        runner.count = local_incr
                        maxCount = max(maxCount, countPtr)
                        break
                    end
                end
            end
        end
    end

    -- Update heap
    if maxCount >= heapMin then
        -- TODO: @kartik1998
    end
end

-- refer to https://github.com/RedisBloom/RedisBloom/blob/master/src/topk.c for other methods

-- Example usage
local topk = TopK.create(10, 100, 50, 0.9)
topk:add("example_item", string.len("example_item"), 1)
