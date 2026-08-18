#!/usr/bin/lua
local nixio = require("nixio")
local cjson = require("cjson")

local duration_s = tonumber(arg[1] or "60") or 60
local label = arg[2] or "idle"

local function now_ms()
  local sec, usec = nixio.gettimeofday()
  return sec * 1000 + math.floor(usec / 1000)
end

local function read_exact(sock, length)
  local parts, total = {}, 0
  while total < length do
    local chunk, err, partial = sock:recv(length - total)
    chunk = chunk or partial
    if not chunk or #chunk == 0 then return nil, err or "closed" end
    parts[#parts + 1] = chunk
    total = total + #chunk
  end
  return #parts == 1 and parts[1] or table.concat(parts)
end

local function u32be(raw, offset)
  local a, b, c, d = raw:byte(offset, offset + 3)
  return a * 16777216 + b * 65536 + c * 256 + d
end

local function u64be(raw, offset)
  return u32be(raw, offset) * 4294967296 + u32be(raw, offset + 4)
end

local function percentile(values, ratio)
  if #values == 0 then return 0 end
  table.sort(values)
  local index = math.max(1, math.min(#values, math.ceil(#values * ratio)))
  return values[index]
end

local sock = assert(nixio.socket("inet", "stream"))
assert(sock:connect("127.0.0.1", 8190))
sock:setblocking(true)

local started = now_ms()
local deadline = started + duration_s * 1000
local previous_id, previous_arrival, previous_capture
local first_id, last_id
local count, id_gaps = 0, 0
local receive_gaps, producer_gaps = {}, {}
local slow_events = {}

while now_ms() < deadline do
  local header, header_err = read_exact(sock, 8)
  if not header then error(header_err) end
  local packet_length = u32be(header, 1)
  local frame_id = u32be(header, 5)
  local meta_length_raw = assert(read_exact(sock, 4))
  local meta_length = u32be(meta_length_raw, 1)
  if packet_length < 4 + meta_length or meta_length ~= 52 then error("invalid packet") end
  local meta = assert(read_exact(sock, meta_length))
  local frame_length = packet_length - 4 - meta_length
  assert(read_exact(sock, frame_length))
  local arrival = now_ms()
  local capture_done = u64be(meta, 21)
  local capture_ms = u32be(meta, 33)
  local receive_gap = previous_arrival and arrival - previous_arrival or 0
  local producer_gap = previous_capture and capture_done - previous_capture or 0
  local id_gap = previous_id and math.max(0, frame_id - previous_id - 1) or 0
  count = count + 1
  first_id = first_id or frame_id
  last_id = frame_id
  id_gaps = id_gaps + id_gap
  if previous_arrival then
    receive_gaps[#receive_gaps + 1] = receive_gap
    producer_gaps[#producer_gaps + 1] = producer_gap
  end
  if receive_gap >= 33 or producer_gap >= 33 or id_gap > 0 then
    slow_events[#slow_events + 1] = {
      frameId = frame_id,
      receiveGapMs = receive_gap,
      producerGapMs = producer_gap,
      captureMs = capture_ms,
      idGap = id_gap,
    }
  end
  previous_id, previous_arrival, previous_capture = frame_id, arrival, capture_done
end
sock:close()

table.sort(slow_events, function(a, b) return a.receiveGapMs > b.receiveGapMs end)
while #slow_events > 20 do table.remove(slow_events) end
local elapsed_s = (now_ms() - started) / 1000
print(cjson.encode({
  label = label,
  durationSeconds = elapsed_s,
  frames = count,
  fps = elapsed_s > 0 and count / elapsed_s or 0,
  firstFrameId = first_id or 0,
  lastFrameId = last_id or 0,
  idGaps = id_gaps,
  receiveGapP50Ms = percentile(receive_gaps, 0.50),
  receiveGapP95Ms = percentile(receive_gaps, 0.95),
  receiveGapMaxMs = percentile(receive_gaps, 1.00),
  producerGapP95Ms = percentile(producer_gaps, 0.95),
  producerGapMaxMs = percentile(producer_gaps, 1.00),
  slowEvents = slow_events,
}))
