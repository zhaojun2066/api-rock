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
local mq = require("rock.mq")
local _M = {}

--- 用于同步各个woker 间 router 、upstream、service 数据
local function init_worker_events()
    local we = require("resty.worker.events")
    local ok, err = we.configure({shm = "worker-events", interval = 0.1})
    if not ok then
        rock_core.log.error("failed to init worker event: " .. err)
    end

end

function _M.http_init()
    require("resty.core") -- 开启resty.core
end

function _M.http_init_worker()
    init_worker_events()
    local config = rock_core.config.local_conf() --- load cofig.yaml
    if config.rock.enable_admin then
        admin_init.init_http_work() --- init admin
    end
    rock_core.redis.init_http_worker()
    balancer.init_http_worker()
    service.init_http_worker()
    router.init_http_worker()
    mq.init_http_worker()
    --- todo 初始化所有的plugin,pcall 加载

end

function _M.http_rewrite_phase() end


function _M.http_access_phase()
    --- todo run access plugins  第一步 执行 acces 阶段的pluain access 方法
    --- 根据参数匹配router，然后返回可用的upstream,设置ngx.ctx 中，然后在balancer 阶段 取出，然后设置
    router.match()



end


function _M.http_balancer_phase()
    ---  set  upstream
    balancer.run()
end


function _M.http_body_filter_phase()
    --- todo run all body filter
end


function _M.http_header_filter_phase()
    --- todo run all header filter
end

function _M.http_log_phase()
    --- todo run log filter
end


local admin_router

function _M.http_admin()
    if not admin_router then
        admin_router = admin_init.get()
    end

    -- core.log.info("uri: ", get_var("uri"), " method: ", get_method())
    local ok = admin_router:dispatch(ngx.var.uri, {method = get_mothed()})
    if not ok then
        ngx_exit(404)
    end
end
return _M