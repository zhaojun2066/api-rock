--
-- Created by IntelliJ IDEA.
-- User: jufeng
-- Date: 2/1/2020
-- Time: 上午10:35
-- 限流请求数
--
local ngx = ngx
local require = require
local rock_core = require "rock.core"
local limit_req = require "resty.limit.req"
local lrucache = require ("resty.lrucache")
local resty_lock = require ("resty.lock")
local limit_req_limit_locks = resty_lock:new("limit_req_limit_locks")
local limit_cache

local schema = {
    type = "object",
    properties = {
        rate = {type = "number", minimum = 0},
        burst = {type = "number",  minimum = 0},
        key = {type = "string",
            enum = {"remote_addr", "server_addr", "http_x_real_ip",
                "http_x_forwarded_for"},
        },
        rejected_code = {type = "integer", minimum = 200},
    },
    required = {"rate", "burst", "key", "rejected_code"}
}


local _M = {
    version = 1.0,
    name = "limit-req"
}
local function limiting(limit,conf)
    local key = ngx.var[conf.key]
    local delay , err = limit:incoming(key,true)
    if not delay then
        if err == "rejected" then
            return rock_core.response.exit_error_msg(503, err)
        end
        return rock_core.response.exit_error_msg(500,err)
    end
    -- 此方法返回，当前请求需要delay秒后才会被处理，和他前面对请求数
    -- 所以此处对桶中请求进行延时处理，让其排队等待，就是应用了漏桶算法
    -- 此处也是与令牌桶的主要区别既,不延迟，就是令牌，可以应对突发
    if delay>0.001 then
        --- 说明当前求情延迟了，要放入桶内了
    end
end
local function get_limit(conf)
    local matched_router = ngx.ctx.matched_router
    if not matched_router then
        return nil,"not router"
    end
    local router_id = matched_router.id
    local limit = limit_cache:get(router_id)
    if limit then
        return limit
    end

    local elapsed,err = limit_req_limit_locks:lock(router_id)
    if not elapsed then
        return nil," get lock error : " .. err
    end
    limit = limit_cache:get(router_id)
    if limit then
        limit_req_limit_locks:unlock()
        return limit
    end

    limit,err  = limit_req.new("limit_req_store",conf.rate,conf.burst)
    if not limit then
        limit_req_limit_locks:unlock()
        return nil," create limit error"
    end
    if limit then
        limit_cache:set(router_id,limit)
        limit_req_limit_locks:unlock()
        return limit
    end
end

function _M.access(conf)
    local limit ,err = get_limit(conf)
    if not limit then
        return rock_core.response.exit_error_msg(500,err)
    end
    limiting(limit)
end

function _M.init()
    limit_cache = lrucache.new(3000)
end

return _M

