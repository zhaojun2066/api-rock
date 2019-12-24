--
-- Created by IntelliJ IDEA.
-- User: jufeng
-- Date: 19/12/2019
-- Time: 上午10:13
-- To change this template use File | Settings | File Templates.
--

local require = require
local ngx = ngx
local radix = require("resty.radixtree") --- store router
local ngx_re   = require("ngx.re")
local str_lower = string.lower
local router
local get_method = ngx.req.get_method
local rock_core = require('rock.core')

local models = {
    routers = require("rock.admin.routers"),
    services = require("rock.admin.services"),
    upstreams = require("rock.admin.upstreams")
}

local function run()
    ---- example path start --------------
    --- /rock/admin/routers  GET  list
    --- /rock/admin/routers/1 GET get one
    --- /rock/admin/routers/1 DELETE delete one
    --- /rock/admin/routers/1 PUT update one
    --- /rock/admin/routers POST  add one
    ---- example path end --------------

    local uri = ngx.var.uri
    local segs ,err = ngx_re.split(uri,"/")
    if not segs then
        return rock_core.response.exit(404)
    end

    local id = segs[5]
    local method = str_lower(get_method());
    local req_body
    --- 如果没有id ，说明是get 或者是post ，在判断如果是get 就是 list 方法了
    if not id then
        if method == "get" then
            method = "list"
        end
    end
    --- 检查admin下的模块
    local model_name = segs[4] --- get model name
    local model = models[model_name]
    if not model then
        return rock_core.response.exit(404)
    end
    --- 检查该模块是否有该方法
    if not model[method] then
        return rock_core.response.exit(404)
    end
    ngx.req.read_body()
    local req_body = ngx.req.get_body_data()
    if  req_body then
        req_body ,err= rock_core.json.decode_json(req_body)
    end

    if req_body and id then
        req_body.id = id
    elseif id then
        req_body = id
    end

    local code, data = model[method]( req_body)
    return rock_core.response.exit(code, data)

end

--- 注入admin的router
local uri_route = {
    {
        paths = {[[/rock/admin/*]]},
        methods = {"GET", "PUT", "POST", "DELETE", "PATCH"},
        handler = run,
    }
}

local _M = {}

function _M.init_http_work()
    router = radix.new(uri_route)
end

function _M.get()
    return router
end


return _M