--
-- Created by IntelliJ IDEA.
-- User: jufeng
-- Date: 24/12/2019
-- Time: 上午11:26
--  plugin operations
--

local require = require
local ngx = ngx
local rock_core = require('rock.core')
local service = require('rock.service')
local pkg_loaded    = package.loaded
local table_clear = table.clear
local table_insert = table.insert
local table_sort = table.sort
local table_new = table.new
local table_nkeys = table.nkeys
local ipairs = ipairs
local pairs = pairs
local pcall = pcall
local pkg_name_prefix = "rock.plugins."

local local_plugins = table_new(20,0)

local function sort_plugin(l, r)
    return l.priority > r.priority
end

local function load_plugins()
    table_clear(local_plugins)
    local local_config = rock_core.config.local_conf(true) --- 强制刷新
    local plugin_name_array = local_config.plugins
    if not plugin_name_array then
        rock_core.log.error("rock.plugin.load_plugins() faild to load plugins" )
        return
    end
    for _,name in ipairs(plugin_name_array) do
        local pkg_name = pkg_name_prefix .. name
        --- 装载之前先卸载
        pkg_loaded[pkg_name] = nil
        local ok, plugin = pcall(require, pkg_name)
        if not ok then
            rock_core.log.error("rock.plugin.load_plugins() failed to load plugin [", name, "] err: ", plugin)
            return
        end
        if not plugin.priority then
            rock_core.log.error("rock.plugin.load_plugins() invalid plugin [", name,
                "], missing field: priority")
            return
        end
        plugin.name = name
        table_insert(local_plugins,plugin)
        if plugin.init then
            plugin.init()
        end
    end

    if #local_plugins > 1 then
        table_sort(local_plugins, sort_plugin)
    end
end


local function filter()
    ----合并plugin
    --- 拿到匹配的router，过滤出该router 需要执行 plugin
    local matched_router = ngx.ctx.matched_router

    local filter_plugins_hash = table_new(0,32)

    local service_id = matched_router.service_id
    local service_plugins
    if service_id then
        local service = service.get(service_id)
        if service then
            service_plugins = service.plugins
        end
    end

    if service_plugins then
        for name,param_obj in pairs(service_plugins) do
            filter_plugins_hash[name] = param_obj
        end
    end

    local router_plugins = matched_router.plugins
    if router_plugins then
        for name,param_obj in pairs(router_plugins) do
            filter_plugins_hash[name] = param_obj
        end
    end

    ---  相当于按照之前的排序
    local filter_plugins = table_new(32,0)
    for _,plugin in ipairs(load_plugins) do
        local plugin_name = plugin.name
        local p = filter_plugins_hash[plugin_name]
        if p then
            plugin.conf_paramms = p
            table_insert(filter_plugins,plugin)
        end
    end
    if #filter>0 then
        ngx.ctx.plugins = filter_plugins
    end
end

local _M = {}

_M.init_http_worker = function()
    load_plugins()
end

_M.filer = filter

return _M

