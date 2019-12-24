--
-- Created by IntelliJ IDEA.
-- User: 86186
-- Date: 23/12/2019
-- Time: 下午3:45
-- To change this template use File | Settings | File Templates.
--

local ngx = ngx
local sub_str  = string.sub
local str_byte = string.byte
local tonumber = tonumber
local _M = {}

function _M.get_ip()
    local ip = ngx.req.get_headers()["X-Real-IP"]
    if not ip then
        local ips = ngx.req.get_headers()["X-Forwarded-For"]
        if ips then
            ip = ips[0]
        end

    end
    if not ip then
        ip = ngx.var.remote_addr
    end
    return ip
end

function _M.get_error_msg( msg)
    return {error_msg=msg}
end

function _M.get_msg( msg)
    return {msg=msg}
end


local function rfind_char(s, ch, idx)
    local b = str_byte(ch)
    for i = idx or #s, 1, -1 do
        if str_byte(s, i, i) == b then
            return i
        end
    end
    return nil
end

-- parse_addr parses 'addr' into the host and the port parts. If the 'addr'
-- doesn't have a port, 80 is used to return. For malformed 'addr', the entire
-- 'addr' is returned as the host part. For IPv6 literal host, like [::1],
-- the square brackets will be kept.
function _M.parse_addr(addr)
    local default_port = 80
    if str_byte(addr, 1) == str_byte("[") then
        -- IPv6 format
        local right_bracket = str_byte("]")
        local len = #addr
        if str_byte(addr, len) == right_bracket then
            -- addr in [ip:v6] format
            return addr, default_port
        else
            local pos = rfind_char(addr, ":", #addr - 1)
            if not pos or str_byte(addr, pos - 1) ~= right_bracket then
                -- malformed addr
                return addr, default_port
            end

            -- addr in [ip:v6]:port format
            local host = sub_str(addr, 1, pos - 1)
            local port = sub_str(addr, pos + 1)
            return host, tonumber(port)
        end

    else
        -- IPv4 format
        local pos = rfind_char(addr, ":", #addr - 1)
        if not pos then
            return addr, default_port
        end

        local host = sub_str(addr, 1, pos - 1)
        local port = sub_str(addr, pos + 1)
        return host, tonumber(port)
    end
end

return _M