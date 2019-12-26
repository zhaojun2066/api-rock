--
-- Created by IntelliJ IDEA.
-- User: jufeng
-- Date: 23/12/2019
-- Time: 下午2:38
-- 进行router 相关的操作
--

local require = require
local rock_core = require('rock.core')
local new_table = require ("table.new")
local ipairs = ipairs
local pairs  = pairs
local ngx = ngx
local timer_at = ngx.timer.at
local radix = require("resty.radixtree")
local table_insert = table.insert
local get_method = ngx.req.get_method
---local resty_lock = require ("resty.lock") -- 更新router需要加锁，work级别
local timer_every = ngx.timer.every
local router_key = "rock_router"


local _M = {}
local router_hash
local routers


local function load_routers()
    local sql = "select * from router limit 10000"
    local res,err,sqlstate = rock_core.mysql.query(sql)
    ---- todo 如果失败要有重试机制
    if not res then
        rock_core.log.error(err)
        return
    end

    router_hash = new_table(0,#res)
    local router_array  = new_table(#res,0)

    for _,v  in ipairs(res)  do
        local router_data = rock_core.json.decode_json(v.data)
        router_hash[v.id] = router_data
        table_insert(router_array,{
            paths = router_data.uris or router_data.uri,
            methods = router_data.methods,
            hosts = router_data.hosts or router_data.host,
            remote_addrs = router_data.remote_addrs
                    or router_data.remote_addr,
            vars = router_data.vars,
            filter_fun = router_data.filter_fun or function() end,
            handler = function ()
                ngx.ctx.matched_router = router_data
            end
        })
    end

    routers = radix.new(router_array)
end

local function reload_routers()

   --[[ local lock, err = resty_lock:new("router_locks")
    if not lock then
        rock_core.log.error("failed to create lock: " .. err)
        return
    end]]

    local router_array  = new_table(#router_hash,0)
    for _,router_data  in pairs(router_hash) do
        if  router_data then
            table_insert(router_array,{
                paths = router_data.uris or router_data.uri,
                methods = router_data.methods,
                hosts = router_data.hosts or router_data.host,
                remote_addrs = router_data.remote_addrs
                        or router_data.remote_addr,
                vars = router_data.vars,
                filter_fun = router_data.filter_fun or function() end,
                handler = function ()
                    ngx.ctx.matched_router = router_data
                end
            })
        end
    end

    routers = radix.new(router_array)

   --[[ local ok, err = lock:unlock()
    if not ok then
        rock_core.log.error("failed unlock: " .. err)
    end]]

end

function _M.get_router()
    return router
end




local function put(router)
    router_hash[router.id] = router
    reload_routers()
    rock_core.log.error("rock.router.put().recive_router=> " .. rock_core.json.encode_json(router))
end

local function delete(id)
    router_hash[id] = nil
    reload_routers()
end


local function recive_router(reddis)
    local res ,error =  reddis:read_reply()
    if not res then
        ---rock_core.log.error("rock.router.recive_router()  err : " ..  error)
        return
    end

    rock_core.log.error("rock.router.recive_router().recive_router=> " .. rock_core.json.encode_json(res))

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

local function get_redis ()
   return rock_core.redis.new()
end

local function subscribe_router(reddis)
    reddis:subscribe(router_key)
end

local function subscribe_recive_router()
    local reddis = get_redis()
    subscribe_router(reddis)
    recive_router(reddis)
end

function _M.init_http_worker()
    timer_at(0,load_routers)
    timer_every(3,subscribe_recive_router)
end

function _M.get(id)
    return router_hash[id]
end

--- 新增或者更新router
_M.put  = put

_M.delete = delete


function _M.match()
    local  match_opts = new_table(4,0)
    match_opts.method = get_method()
    match_opts.host = ngx.var.host
    match_opts.remote_addr = rock_core.util.get_ip()
    match_opts.vars = ngx.var

    local ok = routers:dispatch(ngx.var.uri, match_opts)
    if not ok then
        rock_core.log.error("not find any matched route")
        return ngx.exit(404)
    end

    return true
end

return _M

