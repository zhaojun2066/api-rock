--
-- Created by IntelliJ IDEA.
-- User: jufeng(zhaojun)
-- Date: 18/12/2019
-- Time: 上午10:14
-- To change this template use File | Settings | File Templates.
--
local require = require
local ngx = ngx
local ngx_exit = ngx.exit
local get_mothed = ngx.req.get_method
local rock_core = require('rock.core')
local admin_init = require('rock.admin.init')
local balancer = require("rock.balancer")
local service = require("rock.service")
local router = require("rock.router")
local plugin = require("rock.plugin")

local _M = {}

--- 用于同步各个woker 间 router 、upstream、service 数据
--[[local function init_worker_events()
    local we = require("resty.worker.events")
    local ok, err = we.configure({shm = "worker-events", interval = 0.1})
    if not ok then
        rock_core.log.error("failed to init worker event: " .. err)
    end

end]]

function _M.http_init()
    require("resty.core") -- 开启resty.core
end

function _M.http_init_worker()
    --init_worker_events()
    local config = rock_core.config.local_conf() --- load cofig.yaml
    if config.rock.enable_admin then
        admin_init.init_http_work() --- init admin
    end
    balancer.init_http_worker()
    service.init_http_worker()
    plugin.init_http_worker() --- 在router 之前
    router.init_http_worker()  --- router  可能会加载plugin 的api router

end

function _M.http_rewrite_phase() end


function _M.http_access_phase()
    plugin.run_global_plugins("rewrite")
    plugin.run_global_plugins("access")
    ---todo  执行全局的plugins
    router.match()
    --- 过滤匹配router 的所有过滤器
    plugin.filter()
    plugin.run("rewrite")
    plugin.run("access")
end


function _M.http_balancer_phase()
    plugin.run_global_plugins("balancer")
    plugin.run("balancer")
    balancer.run()
end


function _M.http_body_filter_phase()
    plugin.run_global_plugins("body_filter")
    plugin.run("body_filter")
end


function _M.http_header_filter_phase()
    plugin.run_global_plugins("header_filter")
    plugin.run("header_filter")
end

function _M.http_log_phase()
    plugin.run_global_plugins("log")
    plugin.run("log")
end


local admin_router

function _M.http_admin()
    if not admin_router then
        admin_router = admin_init.get()
    end

    local ok = admin_router:dispatch(ngx.var.uri, {method = get_mothed()})
    if not ok then
        ngx_exit(404)
    end
end
return _M