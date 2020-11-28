local cjson  = require 'cjson'
-- local hmac = require "openssl.hmac"
local str = require "nginx.string"

local user = ngx.var.cookie_SSOwAuthUser

if (user == nil or user == "") then
  return
end

local user_email = user .. "@" .. ngx.var.host

local function b64_encode(input)
  local result = ngx.encode_base64(input, true)
  return result:gsub("+", "-"):gsub("/", "_"):gsub("=", "")
end

local function hmac_sign (alg, message)
  local key = "__SECRET_KEY__"
  local pipe = io.popen("echo -n '" ..message:gsub("'", "'\\''").. "' | openssl " ..alg.. " -hmac '" ..key:gsub("'", "'\\''").. "' --binary | base64")
  local hash = pipe:read():gsub("+", "-"):gsub("/", "_"):gsub("=", "")
  pipe:close()
  return hash
end

local function gen_jwt_token (sub)
  local segments = {
    b64_encode(cjson.encode({ typ = "JWT", alg = "HS256" })),
    b64_encode(cjson.encode({ sub = sub, exp = os.time() + (24*60*60) }))
  }

  local signing_input = table.concat(segments, ".", 1, 2)

  -- local signature = str.to_hex(hmac.new(key, "sha256"):update(signing_input):final())
  -- segments[3] = b64_encode(signature)
  local signature = hmac_sign("sha256", signing_input)
  segments[3] = signature

  return table.concat(segments, ".", 1, 3)
end -- gen_jwt_token

local token = gen_jwt_token(user_email)
local cookie_content = "token=" .. token .. "; Path=__PATH_URL__/; Domain=__DOMAIN__; Secure; HttpOnly; SameSite=Lax"
ngx.req.set_header('Cookie', cookie_content)
ngx.header['X-Copanier-Token'] = token

return
