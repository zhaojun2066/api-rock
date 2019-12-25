--
-- Created by IntelliJ IDEA.
-- User: 86186
-- Date: 25/12/2019
-- Time: 上午11:11
-- To change this template use File | Settings | File Templates.
--
local require = require
local rock_core = require('rock.core')
local ngx = ngx
local timer_at = ngx.timer.at

local router_key = "rock_router"
local upstream_key = "rock_upstream"
local service_key = "rock_service"

local _M = {}

local function subscribe_router()
    rock_core.redis.subscribe(router_key)
end


local function subscribe_upstream()
    rock_core.redis.subscribe(upstream_key)
end

local function subscribe_service()
    rock_core.redis.subscribe(service_key)
end

local function subscribe_all()
    subscribe_upstream()
    subscribe_router()
    subscribe_service()
end

function _M.init_http_worker()
    timer_at(0,subscribe_all)
end


return _M

