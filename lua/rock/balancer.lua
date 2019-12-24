--
-- Created by IntelliJ IDEA.
-- User: jufeng
-- Date: 23/12/2019
-- Time: 上午10:37
--  初始化上游服务 upstream
--
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
local service = require("rock.service")
local lrucache = require ("resty.lrucache")


local _M = {}
local upstream_hash

local upstream_argo_cache

local function load_upstream()
    local sql = "select * from upstream limit 10000"
    local res,err,sqlstate = rock_core.mysql.query(sql)
    ---- todo 如果失败要有重试机制
    if not res then
        rock_core.log.error(err)
        return
    end

    upstream_hash = new_table(0,#res)

    for _,v  in ipairs(res)  do
        upstream_hash[v.id] = rock_core.json.decode_json(v.data)
    end
end

local function init_upstream_cache()
    local c, err = lrucache.new(5000)  -- allow up to 5000 items in the cache
    if not c then
        rock_core.log.error("failed to create the cache: " .. (err or "unknown"))
    end
    upstream_argo_cache = c
end

function _M.init_http_worker()
    timer_at(0,load_upstream)
    init_upstream_cache()
end

function _M.get_upstream(id)
    return upstream_hash[id]
end

--- set upstream
function _M.run()
    local matched_router = ngx.ctx.matched_router
    if not matched_router then
        return rock_core.response.exit_error_msg(404,"router not found")
    end
    --- router.upstream> router.upstream_id > router.service_id> service.upstream> service.upstream_id
    local upstream
    if matched_router.upstream then
        upstream = matched_router.upstream
    elseif  matched_router.upstream_id then

    elseif  matched_router.service_id then
        local matched_service = service.get_service(matched_router.service_id)
        if not matched_service then
            return rock_core.response.exit_error_msg(404,"service not found")
        end
        if  matched_service.upstream then
            upstream = matched_service.upstream
        elseif matched_service.upstream_id then
            upstream = _M.get_upstream(matched_service.upstream_id)
        end
    end
    --- 未找到路由
    if not upstream then
        return rock_core.response.exit_error_msg(404,"upstream not found")
    end

    local nodes = upstream.nodes
    local up_nodes = new_table(0, #upstream.nodes)

    for addr, weight in pairs(nodes) do
        --- local ip, port = rock_core.util.parse_addr(addr)
        --- todo 是否健康 ip port
        up_nodes[addr] = weight
    end

    local type = nodes.type -- "chash", "roundrobin"
    local server
    if type == "roundrobin" then
        local cache_key ="rr_" .. upstream.id
        local get = upstream_argo_cache:get(cache_key)
        if not get then
            local picker_server = function()
                local picker = roundrobin:new(up_nodes)
                return picker:find()
            end
            upstream_argo_cache:set(cache_key,picker_server,300) ---ttl is second
            server = picker_server()
        else
            server = get()
        end
    else
        local cache_key ="ch_" .. upstream.id
        local hash_key = upstream.key
        local get = upstream_argo_cache:get(cache_key)
        if not get then
            local picker_server = function()
                local picker = resty_chash:new(up_nodes)
                --- todo get hash_key
                local id = picker:find(ngx.var[hash_key])
                return up_nodes[id]
            end
            upstream_argo_cache:set(cache_key,picker_server,300) ---ttl is second
            server = picker_server()
        else
            server = get()
        end
    end

    local ip, port ,err= rock_core.util.parse_addr(server)
    if err then
        rock_core.log.error("failed to set server peer: ", err)
        return rock_core.response.exit_error_msg(502,"failed to set server peer: "..err)
    end


    local ok, err = ngx_balancer.set_current_peer( ip, port )
    if not ok then
        rock_core.log.error("failed to set server peer: ", err)
        return rock_core.response.exit_error_msg(502,"failed to set server peer: "..err)
    end

end


function _M.reload_upstream()
    load_upstream()
end

--- 新增或者更新upstream
function _M.put(upstream)
    upstream_hash[upstream.id] = upstream
end


return _M