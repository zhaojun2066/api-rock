--
-- Created by IntelliJ IDEA.
-- User: jufeng
-- Date: 23/12/2019
-- Time: 上午10:37
-- 初始化service
--
local require = require
local rock_core = require('rock.core')
local new_table = require ("table.new")
local ipairs = ipairs
local ngx = ngx
local timer_at = ngx.timer.at
local timer_every = ngx.timer.every


local _M = {}
local service_hash

local function load()
    local sql = "select * from service limit 5000"
    local res,err,sqlstate = rock_core.mysql.query(sql)
    ---- todo 如果失败要有重试机制
    if not res then
        rock_core.log.error(err)
    end

    service_hash = new_table(0,#res)

    for _,v  in ipairs(res)  do
        service_hash[v.id] = rock_core.json.decode_json(v.data)
    end
end


local reddis = rock_core.redis.new()
local service_key = "rock_service"
local function subscribe_service()
    reddis:subscribe(service_key)
end

local function put(service)
    service_hash[service.id] = service
end

local function recive_service()
    local res ,error =  reddis:read_reply()
    if not res then
        rock_core.log.error("recive_service  err : " ..  error)
    end

    local service_str = res[3]
    local service = rock_core.json.decode_json(service_str)
    put(service)
end


function _M.init_http_worker()
    timer_at(0,load)
    timer_at(0,subscribe_service)
    timer_every(5,recive_service)
end

function _M.get(id)
    return service_hash[id]
end


function _M.reload()
    load()
end

--- 新增或者更新service
_M.put = put

function _M.delete(id)
    service_hash[id] = nil
end

return _M