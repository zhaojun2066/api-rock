--
-- Created by IntelliJ IDEA.
-- User: 86186
-- Date: 3/1/2020
-- Time: 上午10:14
-- url 重定向 301 302
-- 应该是一个全局的配置，匹配上就重定向到第一个
-- 会有很多租匹配关系，不应配置很多

local ngx = ngx
local require = require
local rock_core = require "rock.core"
local ngx_re = ngx.re
local pairs = pairs
local table_concat = table.concat



local schema = {
    type = "object",
    properties = {
        uri_reg = {type = "string"},
        to_uri = {type = "string"},
        code = {type = "integer"},
        vars = {type = "object"}
    },
    required = {"uri_reg", "to_uri", "code"}
}
---vars  可以是ngx.var 里的key value
local _M = {
    version = "1,0",
    name = "redirect"
}

local function match_vars(vars)
    local status
    for k,v in pairs(vars) do
        if not ngx.var[k] then
            status = 1
        end
    end
    return status
end
local function check_conf(conf)

    local code = conf.code
    if not code then
        return nil,"router's rewrite param code null"
    end

    local to_uri = conf.to_uri
    if not to_uri then
        return nil,"router's rewrite param to_uri null"
    end
    return true,nil
end

function _M.rewrite(conf)
    local res,err = check_conf(conf)
    if not res then
        return rock_core.response.exit_msg(400,err)
    end

    local uri_reg = conf.uri_reg
    local vars = conf.vars
    local code = conf.code
    local to_uri = conf.to_uri
    local request_uri = ngx.var.uri
    local args = {
        ngx.var.is_args,
        ngx.var.args
    }
    local args_str= table_concat(args,"")
    to_uri = to_uri .. args_str
    if uri_reg and not vars then
        local match_group = ngx_re.match(request_uri,uri_reg)
        if match_group then
            return ngx.redirect(to_uri,code)
        end
    elseif not uri_reg and vars then
        if  match_vars(vars) then
            return ngx.redirect(to_uri,code)
        end
    elseif uri_reg and vars then
        local match_group = ngx_re.match(request_uri,uri_reg)
        if match_vars(vars) and match_group then
            return ngx.redirect(to_uri,code)
        end
    end
end

return _M
