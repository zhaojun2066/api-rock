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

local function delete(id)
    service_hash[id] = nil
end


local function recive_service()
    local res ,error =  reddis:read_reply()
    if not res then
        rock_core.log.error("recive_service  err : " ..  error)
        return
    end

    local msg_str = res[3]
    local msg = rock_core.json.decode_json(msg_str)
    local worker_id = msg.worker_id
    --- 如果是自己就不更新说明已经更新了
    if worker_id ~= ngx.worker.id() then
        local action = msg.action
        local data = msg.data
        if action and data then
            if action == "put" then
                put(data)
            elseif action == "delete" then
                delete(data)
            end
        end
    end
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

_M.delete = delete

return _M