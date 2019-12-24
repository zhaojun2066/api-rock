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
    router = require("rock.admin.router"),
    service = require("rock.admin.service"),
    upstream = require("rock.admin.upstream")
}

local function run()
    --- /rock/admin/router/1
    local uri = ngx.var.uri
    local res ,err = ngx_re.split(uri,"/")
    local model_name = res[4] --- get model name
    local model = models[model_name]
    if not model then
        return rock_core.response.exit(404)
    end
    local method = str_lower(get_method())
    if not model[method] then
        return rock_core.response.exit(404)
    end
    ngx.req.read_body()
    local req_body = ngx.req.get_body_data()
    if method ~= 'get' and method ~= 'delete' and req_body then
        --  其他请求必须要有body
        if  req_body then
            req_body ,err= rock_core.json.decode_json(req_body)
            if not req_body then
                return rock_core.response.exit(400, {error_msg = "invalid request body, "..err,
                    req_body = req_body})
            end
        else
            return rock_core.response.exit(400, {error_msg = "invalid request body",
                req_body = req_body})
        end
    end
    --logger(ERR,"req_body:" ..req_body.uri)
    if method == 'get' or method=='delete' then
        req_body = res[5] -- 说明就是id
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