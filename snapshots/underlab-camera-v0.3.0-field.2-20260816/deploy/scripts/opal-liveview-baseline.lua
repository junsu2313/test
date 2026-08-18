#!/usr/bin/lua

local ok_nixio, nixio = pcall(require, "nixio")
if not ok_nixio then
  error("nixio is required")
end

local ok_cjson, cjson = pcall(require, "cjson")
if not ok_cjson then
  error("cjson is required")
end

local label = arg[1] or "sample"
local duration_s = tonumber(arg[2] or "60") or 60
local sample_ms = tonumber(arg[3] or "50") or 50
local meta_path = arg[4] or "/tmp/d810-live-v21.meta"

local function now_ms()
  local sec, usec = nixio.gettimeofday()
  return (tonumber(sec) or 0) * 1000 + math.floor((tonumber(usec) or 0) / 1000)
end

local function sleep_ms(ms)
  local sec = math.floor(ms / 1000)
  nixio.nanosleep(sec, (ms - sec * 1000) * 1000000)
end

local function read_file(path)
  local handle = io.open(path, "rb")
  if not handle then return nil end
  local data = handle:read("*a")
  handle:close()
  return data
end

local function read_proc_stat()
  local raw = read_file("/proc/stat") or ""
  local cpu_line = raw:match("cpu%s+([^\n]+)") or ""
  local ticks = {}
  for value in cpu_line:gmatch("%d+") do
    ticks[#ticks + 1] = tonumber(value) or 0
  end
  local total = 0
  for _, value in ipairs(ticks) do total = total + value end
  local idle = (ticks[4] or 0) + (ticks[5] or 0)
  return {
    total = total,
    idle = idle,
    forks = tonumber(raw:match("\nprocesses%s+(%d+)")) or 0,
    ctxt = tonumber(raw:match("\nctxt%s+(%d+)")) or 0,
  }
end

local function read_meta()
  local raw = read_file(meta_path)
  if not raw then return nil end
  local meta = {}
  for line in raw:gmatch("[^\r\n]+") do
    local key, value = line:match("^([^=]+)=(.*)$")
    if key then meta[key] = tonumber(value) or value end
  end
  return meta
end

local process_pidfiles = {
  bridge = "/tmp/d810-bridge-v21.pid",
  websocket = "/tmp/d810-ws-v21.pid",
  frame_refresh = "/tmp/d810-live-v21-refresh.pid",
}

local function read_process_stat(pidfile)
  local pid = tonumber((read_file(pidfile) or ""):match("%d+"))
  if not pid then return nil end
  local stat = read_file("/proc/" .. pid .. "/stat")
  if not stat then return nil end
  local tail = stat:match("^%d+ %b() (.+)$")
  if not tail then return nil end
  local fields = {}
  for value in tail:gmatch("%S+") do fields[#fields + 1] = value end
  local io_raw = read_file("/proc/" .. pid .. "/io") or ""
  return {
    pid = pid,
    cpu_ticks = (tonumber(fields[12]) or 0) + (tonumber(fields[13]) or 0),
    rchar = tonumber(io_raw:match("rchar:%s+(%d+)")) or 0,
    wchar = tonumber(io_raw:match("wchar:%s+(%d+)")) or 0,
    syscr = tonumber(io_raw:match("syscr:%s+(%d+)")) or 0,
    syscw = tonumber(io_raw:match("syscw:%s+(%d+)")) or 0,
  }
end

local function read_processes()
  local result = {}
  for name, pidfile in pairs(process_pidfiles) do
    result[name] = read_process_stat(pidfile)
  end
  return result
end

local function percentile(values, ratio)
  if #values == 0 then return nil end
  table.sort(values)
  local index = math.max(1, math.min(#values, math.ceil(#values * ratio)))
  return values[index]
end

local function average(values)
  if #values == 0 then return nil end
  local total = 0
  for _, value in ipairs(values) do total = total + value end
  return total / #values
end

local started_at = now_ms()
local deadline = started_at + duration_s * 1000
local proc_start = read_proc_stat()
local processes_start = read_processes()
local first_frame_id
local last_frame_id
local last_capture_done
local capture_ms = {}
local total_ms = {}
local cache_ms = {}
local wire_total_us = {}
local first_packet_us = {}
local parse_us = {}
local transport_packets = {}
local frame_gap_ms = {}
local request_gap_ms = {}
local frame_bytes = {}

while now_ms() < deadline do
  local meta = read_meta()
  local frame_id = meta and tonumber(meta.frameId)
  if frame_id and frame_id ~= last_frame_id then
    first_frame_id = first_frame_id or frame_id
    last_frame_id = frame_id
    capture_ms[#capture_ms + 1] = tonumber(meta.captureMs) or 0
    total_ms[#total_ms + 1] = tonumber(meta.totalMs) or 0
    cache_ms[#cache_ms + 1] = tonumber(meta.cacheMs) or 0
    wire_total_us[#wire_total_us + 1] = tonumber(meta.wireTotalUs) or 0
    first_packet_us[#first_packet_us + 1] = tonumber(meta.firstPacketUs) or 0
    parse_us[#parse_us + 1] = tonumber(meta.parseUs) or 0
    transport_packets[#transport_packets + 1] = tonumber(meta.transportPackets) or 0
    request_gap_ms[#request_gap_ms + 1] = tonumber(meta.requestGapMs) or 0
    frame_bytes[#frame_bytes + 1] = tonumber(meta.bytes) or 0
    local capture_done = tonumber(meta.captureDoneAt)
    if capture_done and last_capture_done then
      frame_gap_ms[#frame_gap_ms + 1] = capture_done - last_capture_done
    end
    last_capture_done = capture_done or last_capture_done
  end
  sleep_ms(sample_ms)
end

local ended_at = now_ms()
local proc_end = read_proc_stat()
local processes_end = read_processes()
local total_delta = proc_end.total - proc_start.total
local idle_delta = proc_end.idle - proc_start.idle
local frame_count = #capture_ms
local elapsed_s = (ended_at - started_at) / 1000
local produced_frames = first_frame_id and last_frame_id and math.max(0, last_frame_id - first_frame_id + 1) or 0
local process_deltas = {}
for name, start_value in pairs(processes_start) do
  local end_value = processes_end[name]
  if start_value and end_value and start_value.pid == end_value.pid then
    process_deltas[name] = {
      pid = start_value.pid,
      cpu_ticks = end_value.cpu_ticks - start_value.cpu_ticks,
      cpu_pct = total_delta > 0 and ((end_value.cpu_ticks - start_value.cpu_ticks) * 100 / total_delta) or 0,
      rchar = end_value.rchar - start_value.rchar,
      wchar = end_value.wchar - start_value.wchar,
      syscr = end_value.syscr - start_value.syscr,
      syscw = end_value.syscw - start_value.syscw,
    }
  end
end

io.write(cjson.encode({
  label = label,
  elapsed_s = elapsed_s,
  sample_ms = sample_ms,
  cpu_busy_pct = total_delta > 0 and ((total_delta - idle_delta) * 100 / total_delta) or 0,
  forks = proc_end.forks - proc_start.forks,
  context_switches = proc_end.ctxt - proc_start.ctxt,
  frames = frame_count,
  fps = elapsed_s > 0 and frame_count / elapsed_s or 0,
  produced_frames = produced_frames,
  production_fps = elapsed_s > 0 and produced_frames / elapsed_s or 0,
  first_frame_id = first_frame_id,
  last_frame_id = last_frame_id,
  capture_avg_ms = average(capture_ms),
  capture_p95_ms = percentile(capture_ms, 0.95),
  total_avg_ms = average(total_ms),
  total_p95_ms = percentile(total_ms, 0.95),
  cache_avg_ms = average(cache_ms),
  cache_p95_ms = percentile(cache_ms, 0.95),
  wire_total_avg_us = average(wire_total_us),
  wire_total_p95_us = percentile(wire_total_us, 0.95),
  first_packet_avg_us = average(first_packet_us),
  first_packet_p95_us = percentile(first_packet_us, 0.95),
  parse_avg_us = average(parse_us),
  parse_p95_us = percentile(parse_us, 0.95),
  transport_packets_avg = average(transport_packets),
  frame_gap_avg_ms = average(frame_gap_ms),
  frame_gap_p95_ms = percentile(frame_gap_ms, 0.95),
  request_gap_avg_ms = average(request_gap_ms),
  request_gap_p95_ms = percentile(request_gap_ms, 0.95),
  frame_bytes_avg = average(frame_bytes),
  processes = process_deltas,
}) .. "\n")
