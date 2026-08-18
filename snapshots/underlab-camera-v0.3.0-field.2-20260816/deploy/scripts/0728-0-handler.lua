local file = io.open("/www/0728-0.html", "r")
if not file then
  return ngx.exit(404)
end

local body = file:read("*a")
file:close()
ngx.header.content_type = "text/html; charset=utf-8"
ngx.header.cache_control = "private, no-store, no-cache, must-revalidate, proxy-revalidate"
ngx.print(body)
