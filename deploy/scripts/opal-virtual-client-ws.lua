#!/usr/bin/lua

local ok_nixio, nixio = pcall(require, "nixio")
if not ok_nixio then
  io.stderr:write("nixio unavailable\n")
  os.exit(2)
end

local source_ip = arg[1] or "192.168.8.250"
local host = arg[2] or "192.168.8.1"
local port = tonumber(arg[3] or "8191")
local output_path = arg[4] or "/tmp/d810-test-frame.jpg"

local function method(obj, names)
  for _, name in ipairs(names) do
    if type(obj[name]) == "function" then return obj[name] end
  end
end

local function send_all(sock, data)
  local send = method(sock, { "send", "write" })
  local sent = 0
  while sent < #data do
    local wrote, err = send(sock, data:sub(sent + 1))
    if not wrote or wrote <= 0 then return nil, err or "send failed" end
    sent = sent + wrote
  end
  return true
end

local function read_exact(sock, length)
  local recv = method(sock, { "recv", "receive", "read" })
  local parts, total = {}, 0
  while total < length do
    local chunk, err, partial = recv(sock, length - total)
    chunk = chunk or partial
    if not chunk or #chunk == 0 then return nil, err or "closed" end
    parts[#parts + 1] = chunk
    total = total + #chunk
  end
  return table.concat(parts)
end

local function read_line(sock)
  local parts = {}
  while true do
    local byte, err = read_exact(sock, 1)
    if not byte then return nil, err end
    if byte == "\n" then return table.concat(parts):gsub("\r$", "") end
    parts[#parts + 1] = byte
  end
end

local function read_frame(sock)
  local header, err = read_exact(sock, 2)
  if not header then return nil, nil, err end
  local first, second = header:byte(1, 2)
  local opcode = first % 16
  local masked = second >= 128
  local length = second % 128
  if length == 126 then
    local ext = assert(read_exact(sock, 2))
    length = ext:byte(1) * 256 + ext:byte(2)
  elseif length == 127 then
    local ext = assert(read_exact(sock, 8))
    length = 0
    for i = 1, 8 do length = length * 256 + ext:byte(i) end
  end
  if length < 0 or length > 8 * 1024 * 1024 then return nil, nil, "invalid frame length" end
  local mask
  if masked then mask = assert(read_exact(sock, 4)) end
  local payload = assert(read_exact(sock, length))
  if mask then
    local out = {}
    for i = 1, #payload do
      local b = payload:byte(i)
      local m = mask:byte(((i - 1) % 4) + 1)
      out[i] = string.char(nixio.bit.bxor(b, m))
    end
    payload = table.concat(out)
  end
  return opcode, payload
end

local sock = assert(nixio.socket("inet", "stream"))
assert(sock:bind(source_ip, 0))
assert(sock:connect(host, port))
sock:setblocking(true)

local key = "ZDE4MTAtYXV0b3Rlc3Q="
assert(send_all(sock, table.concat({
  "GET / HTTP/1.1\r\n",
  "Host: ", host, ":", tostring(port), "\r\n",
  "Upgrade: websocket\r\n",
  "Connection: Upgrade\r\n",
  "Sec-WebSocket-Key: ", key, "\r\n",
  "Sec-WebSocket-Version: 13\r\n",
  "X-D810-Client: flutter-camera\r\n\r\n",
})))

local status = assert(read_line(sock))
if not status:match("^HTTP/1%.1 101") then error("websocket handshake failed: " .. status) end
while true do
  local line = assert(read_line(sock))
  if line == "" then break end
end

for _ = 1, 20 do
  local opcode, payload, err = read_frame(sock)
  if not opcode then error(err or "websocket frame unavailable") end
  if opcode == 0x2 and #payload > 1024 and payload:sub(1, 2) == "\255\216" and payload:sub(-2) == "\255\217" then
    local out = assert(io.open(output_path, "wb"))
    out:write(payload)
    out:close()
    io.stdout:write(string.format("WS_FRAME_OK bytes=%d\n", #payload))
    sock:close()
    os.exit(0)
  end
  if opcode == 0x8 then error("websocket closed before JPEG") end
end

error("JPEG frame not received")
