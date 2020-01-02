--
-- Created by IntelliJ IDEA.
-- User: jufeng
-- Date: 2/1/2020
-- Time: 下午3:08
-- 基于redis 的分布式限流
--
local ngx = ngx
local require = require
local rock_core = require "rock.core"

local script = "local key = 'rate:limit:' .. KEY[1]  "..
               "local rate = tonumber(ARG[1]) " ..
               "local current = tonumber(redis.call('get', key) or '0')"..
                "if current+1 > rate then" ..
                "  return 0 "..
                "else "..
                    "redis.call('INCRBY', key,'1')"..
                    "redis.call('expire', key,'2')"..   --- 两秒后过期，多加一秒，执行命令可能会耗时
                    "return current + 1"..
                "end"


local _M = {
    veriosn = "1.0",
    name = "limit-distribution"
}


function _M.access(conf)
    local rate = conf.rate
    if not rate then
        return
    end
    local matched_router = ngx.ctx.matched_router
    if not matched_router then
        return rock_core.response.exit(500,"no router")
    end
    local router_id = matched_router.id
    local key =  router_id .. (conf.key or "")
    local redis = rock_core.redis.new()

    local c = redis:evel(script,1,key,rate)
    if not c or c==0 then
        return rock_core.response.exit(503,"limited")
    end

end


return _M

