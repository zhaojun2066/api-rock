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
    local res,err = rock_core.mysql.query(sql)
    ---- todo 如果失败要有重试机制
    if not res then
        rock_core.log.error(err)
    end

    service_hash = new_table(0,#res)

    for _,v  in ipairs(res)  do
        local data = rock_core.json.decode_json(v.data)
        data.id = v.id
        service_hash[v.id] = data
    end
end


local function get_redis()
   return rock_core.redis.new()
end

local service_key = "rock_service"
local function subscribe_service(reddis)
    reddis:subscribe(service_key)
end

local function put(service)
    service_hash[service.id] = service
    rock_core.log.error("recive_upstream=> " .. rock_core.json.encode_json(service))
end


local function delete(id)
    service_hash[id] = nil
end


local function recive_service(reddis)
    local res ,error =  reddis:read_reply()
    if not res then
       --- rock_core.log.error("recive_service  err : " ..  error)
        return
    end

    rock_core.log.error("recive_service=> " .. rock_core.json.encode_json(res))

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

local function subscribe_recive_revice()
    local reddis = get_redis()
    subscribe_service(reddis)
    recive_service(reddis)
end

function _M.init_http_worker()
    timer_at(0,load)
    timer_every(3,subscribe_recive_revice)
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