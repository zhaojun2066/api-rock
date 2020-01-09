--
-- Created by IntelliJ IDEA.
-- User: jufeng
-- Date: 23/12/2019
-- Time: 上午10:37
--  初始化上游服务 upstream
--
----todo  更新完upstream 应该删除关联的router 的cache
local require = require
local roundrobin  = require("resty.roundrobin")
local resty_chash = require("resty.chash")
local ngx_balancer    = require("ngx.balancer")
local rock_core = require('rock.core')
local new_table = require ("table.new")
local ipairs = ipairs
local pairs = pairs
local ngx = ngx
local timer_at = ngx.timer.at
local timer_every = ngx.timer.every
local service = require("rock.service")
local lrucache = require ("resty.lrucache")
local upstream_key = "rock_upstream"
local string_char = string.char
local string_gsub = string.gsub
local tonumber = tonumber

local _M = {}
local upstream_hash

local upstream_argo_cache

local function load_upstream()
    local sql = "select * from upstream limit 10000"
    local res,err = rock_core.mysql.query(sql)
    ---- todo 如果失败要有重试机制
    ---rock_core.log.error("init  upstream_hash res=> " .. rock_core.json.encode_json(res))
    if not res then
        rock_core.log.error(err)
        return
    end

    upstream_hash = new_table(0,#res)

    for _,v  in ipairs(res)  do
        local data = rock_core.json.decode_json(v.data)
        local id = tonumber(v.id)
        data.id = id
        upstream_hash[id] = data
        --rock_core.log.error("init  upstream_hash[id]=> " .. rock_core.json.encode_json(upstream_hash[id]))
    end
end

local function init_upstream_argo_cache()
    local c, err = lrucache.new(5000)  -- allow up to 5000 items in the cache
    if not c then
        rock_core.log.error("failed to create the cache: " .. (err or "unknown"))
        return
    end
    upstream_argo_cache = c
end

local function get_redis()
    return rock_core.redis.new()
   --- rock_core.log.error("rock.balancer.init_redis reddis=> " .. reddis)
end

local function subscribe_upstream(reddis)
    reddis:subscribe(upstream_key)
end

local function put(upstream)
    upstream_hash[upstream.id] = upstream
    rock_core.log.error("rock.balancer.recive_upstream=> " .. rock_core.json.encode_json(upstream))
end

local function delete(id)
    upstream_hash[id] = nil
end

local function delete_router_upstream(router_id)
    upstream_argo_cache:delete("rr_"..router_id)
    upstream_argo_cache:delete("ch_"..router_id)
end



local function recive_upstream(reddis)
    local res ,error =  reddis:read_reply()
    if not res then
        ----rock_core.log.error("recive_upstream  err : " ..  error)
        return
    end

    rock_core.log.error("rock.balancer.recive_upstream=> " .. rock_core.json.encode_json(res))

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

local function subscribe_recive()
    local reddis = get_redis()
    subscribe_upstream(reddis)
    recive_upstream(reddis)
end

function _M.init_http_worker()
    timer_at(0,load_upstream)
    init_upstream_argo_cache()
    timer_every(3,subscribe_recive)
end



local function get(id)
    return upstream_hash[id]
end


_M.get= get



--- set upstream
function _M.run()
    local matched_router = ngx.ctx.matched_router
    if not matched_router then
        rock_core.log.error("matched_router not found ")
        return rock_core.response.exit_code(404)
    end
    --- router.upstream> router.upstream_id > router.service_id> service.upstream> service.upstream_id
    local upstream
    --rock_core.log.error("matched_router=> " .. rock_core.json.encode_json(matched_router))
    --rock_core.log.error("upstream_hash=> " .. rock_core.json.encode_json(upstream_hash))
    --rock_core.log.error("matched_router.upstream_id=> " .. matched_router.upstream_id)
    if matched_router.upstream then
        upstream = matched_router.upstream
    elseif  matched_router.upstream_id then
        upstream = get(matched_router.upstream_id)
    elseif  matched_router.service_id then
        local matched_service = service.get(matched_router.service_id)
        if not matched_service then
            rock_core.log.error("matched_service not found ")
            return rock_core.response.exit_code(404)
        end
        if  matched_service.upstream then
            upstream = matched_service.upstream
        elseif matched_service.upstream_id then
            upstream = get(matched_service.upstream_id)
        end
    end
    --- 未找到路由
    if not upstream then
        rock_core.log.error("upstream not found ")
        return rock_core.response.exit_code(404)
    end

    local up_nodes = upstream.nodes
    local type = upstream.type -- "chash", "roundrobin"
    local server
    local router_id = matched_router.id
    rock_core.log.error("upstream.type=> " .. upstream.type)
    if type == "roundrobin" then
        rock_core.log.error("roundrobin")
        local cache_key ="rr_" .. router_id
        local picker = upstream_argo_cache:get(cache_key)
        if not picker then
            rock_core.log.error("roundrobin:new")
            picker = roundrobin:new(up_nodes)
            upstream_argo_cache:set(cache_key,picker,300) ---ttl is second
        end
        server = picker:find()
    else
        local str_null = string_char(0)
        local servers, nodes = {}, {}
        for serv, weight in pairs(up_nodes) do
            --- local ip, port = rock_core.util.parse_addr(addr)
            --- todo 是否健康 ip port
            local id = string_gsub(serv, ":", str_null)
            servers[id] = serv
            nodes[id] = weight
        end
        local cache_key ="ch_" .. router_id
        local hash_key = upstream.key
        if not hash_key then
            rock_core.log.error("hash_key is not config ")
            return rock_core.response.exit_code(502,"hash_key is not config ")
        end

        local picker = upstream_argo_cache:get(cache_key)
        if not picker then
            picker = resty_chash:new(nodes)
            upstream_argo_cache:set(cache_key,picker,300) ---ttl is second
        end
        local id = picker:find(ngx.var[hash_key])
        server = servers[id]
    end

    local ip, port ,err= rock_core.util.parse_addr(server)
    if err then
        rock_core.log.error("failed to set server peer: ", err)
        return rock_core.response.exit_code(502)
    end

    rock_core.log.error("set_current_peer: ", ip,":",port)
    local ok, err = ngx_balancer.set_current_peer( ip, port )
    if not ok then
        rock_core.log.error("failed to set server peer: ", err)
        return rock_core.response.exit_code(502)
    end

end


function _M.reload_upstream()
    load_upstream()
end

---- 删除路由对应up_stream 的轮询策略
function _M.delete_router_upstream(router_id)
        delete_router_upstream(router_id)
end


_M.delete = delete

--- 新增或者更新upstream
_M.put = put


return _M