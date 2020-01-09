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
local ipairs = ipairs
local pairs = pairs
local pcall = pcall
local pkg_name_prefix = "rock.plugins."

local local_plugins = table_new(20,0) --- router plugin
local local_global_plugins = table_new(10,0)-- global plugin
local plugin_routers = table_new(10,0)
local function sort_plugin(l, r)
    return l.priority > r.priority
end

local function load_plugins()
    table_clear(local_global_plugins)
    table_clear(local_plugins)
    table_clear(plugin_routers)
    local local_config = rock_core.config.local_conf(true) --- 强制刷新
    local plugin_config_array = local_config.plugins
    if not plugin_config_array then
        rock_core.log.error("rock.plugin.load_plugins() faild to load plugins" )
        return
    end
    for _,plugin_cofing in ipairs(plugin_config_array) do

        local abled = plugin_cofing.disabled or false
        if not abled then
            local name = plugin_cofing.name
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
            local api =  plugin.api --- plugin 需要的外部api path ，也是需要注册到routers里
            if api then
                table_insert(plugin_routers,api)
            end

            local scope = plugin_cofing.scope
            if scope and scope == "global" then
                table_insert(local_global_plugins,plugin)
            else
                table_insert(local_plugins,plugin)
            end
            if plugin.init then
                plugin.init()
            end
        end
    end

    if #local_plugins > 1 then
        table_sort(local_plugins, sort_plugin)
    end
    if #local_global_plugins > 1 then
        table_sort(local_global_plugins, sort_plugin)
    end
end

local function run_plugins(phase)
    local plugins = ngx.ctx.plugins
    if not plugins then
        return
    end
    for _,plugin_obj in ipairs(plugins) do
        local plugin = plugin_obj["plugin"]
        if plugin[phase] then
            --rock_core.log.error("filter plugin => " .. rock_core.json.encode_json(plugin_obj["conf"]))
            plugin[phase](plugin_obj["conf"])
        end
    end
end

local function run_global_plugins(phase)
    for _,plugin in ipairs(local_global_plugins) do
        if plugin[phase] then
            plugin[phase]()
        end
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
    for _,plugin in ipairs(local_plugins) do
        local plugin_name = plugin.name
        local conf = filter_plugins_hash[plugin_name]
        if conf then
            local filter_plugin = {}
            filter_plugin["conf"] = conf
            filter_plugin["plugin"] = plugin
            rock_core.log.error("filter plugin => " .. rock_core.json.encode_json(conf))
            table_insert(filter_plugins,filter_plugin)
        end
    end
    if #filter_plugins>0 then
        ngx.ctx.plugins = filter_plugins
    end
end



local _M = {}

_M.init_http_worker = function()
    load_plugins()
end

function _M.get_plugin_routers()
    return plugin_routers
end

_M.run_global_plugins = run_global_plugins
_M.run = run_plugins
_M.filter = filter


return _M

