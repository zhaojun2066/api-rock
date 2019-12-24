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

local _M = {}
local router_hash
local router


local function load_router()
    local sql = "select * from router limit 5000"
    local res,err,sqlstate = rock_core.mysql.query(sql)
    ---- todo 如果失败要有重试机制
    if not res then
        rock_core.log.error(err)
        return
    end

    router_hash = new_table(0,#res)
    local router_array  = new_table(#res,0)

    for _,v  in ipairs(res)  do
        local router_data = v.data
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

    router = radix.new(router_array)
end

function _M.get_router()
    return router
end

function _M.init_http_worker()
    timer_at(0,load_router)
end

function _M.get_router(id)
    return router_hash[id]
end


local function reload_router()
    local router_array  = new_table(#res,0)
    for k,router_data  in pairs(router_hash) do
        router_hash[k] = router_data
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
    router = radix.new(router_array)
end
--- 新增或者更新upstream
function _M.put(router)
    router_hash[router.id] = router
    reload_router()
end



function _M.match()
    local  match_opts = new_table(4,0)
    match_opts.method = get_method()
    match_opts.host = ngx.var.host
    match_opts.remote_addr = rock_core.util.get_ip()
    match_opts.vars = ngx.var

    local ok = router:dispatch(ngx.var.uri, match_opts)
    if not ok then
        rock_core.log.error("not find any matched route")
        return ngx.exit(404)
    end

    return true
end



return _M

