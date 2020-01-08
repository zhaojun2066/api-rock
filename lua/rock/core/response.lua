--
-- Created by IntelliJ IDEA.
-- User: 86186
-- Date: 24/12/2019
-- Time: 上午8:58
-- To change this template use File | Settings | File Templates.
--
local require = require
local ngx = ngx
local rapidjson = require('rapidjson')
local encode_json = rapidjson.encode
local ngx_resp = require "ngx.resp"
local util = require('rock.core.util')
local _M = {}



function _M.exit(code,table_body)
    ngx_resp.add_header("Content-Type","application/json;charset=utf-8")
    if code then
        ngx.status = code
    end
    if table_body then
        --- 要在say之前设置nginx.status
        ngx.say(encode_json(table_body))
    end

    if code then
        return ngx.exit(code)
    end
end

function _M.exit_code(code)
    if code then
        ngx.status = code
    end
    return ngx.exit(code)
end

function _M.exit_error_msg(code,error_msg)
    ngx_resp.add_header("Content-Type","application/json;charset=utf-8")
    if code then
        ngx.status = code
    end
    if error_msg then
        --- 要在say之前设置nginx.status
        ngx.say(encode_json(util.get_error_msg(error_msg)))
    end

    if code then
        return ngx.exit(code)
    end
end

function _M.exit_msg(code,msg)
    ngx_resp.add_header("Content-Type","application/json;charset=utf-8")
    if code then
        ngx.status = code
    end
    if msg then
        --- 要在say之前设置nginx.status
        ngx.say(encode_json(util.get_msg(msg)))
    end

    if code then
        return ngx.exit(code)
    end
end

return _M