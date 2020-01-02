--
-- Created by IntelliJ IDEA.
-- User: 86186
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

local _M = {
    version = 1.0
}
local function limiting(limit,conf)
    local key = ngx.var[conf.key]
    local delay , err = limit:incoming(key,true)
    if not delay then
        if err == "rejected" then
            return rock_core.response.exit_error_msg(503, err)
        end
        return ngx.exit(500,err)
    end
    if delay>0.001 then
        --- 说明当前求情延迟了，要放入桶内了
    end
end
local function get_limit(conf)
    local matched_router = ngx.ctx.matched_router
    if not matched_router then
        return
    end
    local router_id = matched_router.id
    local limit = limit_cache:get(router_id)
    if limit then
        limiting(limit)
        return
    end

    local elapsed,err = limit_req_limit_locks:lock(router_id)
    if not elapsed then
        return nil," get lock error : " .. err
    end
    limit = limit_cache:get(router_id)
    if limit then
        limiting(limit)
        limit_req_limit_locks:unlock()
        return
    end

    limit,err  = limit_req.new("limit_req_store",conf.rate,conf.burst)
    if not limit then
        limit_req_limit_locks:unlock()
        return
    end
    if limit then
        limit_cache:set(router_id,limit)
        limit_req_limit_locks:unlock()
    end
end

function _M.access(conf)
    get_limit(conf)
end

function _M.init()
    limit_cache = lrucache.new(3000)
end




return _M

