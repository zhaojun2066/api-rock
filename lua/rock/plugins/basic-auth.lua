--
-- Created by IntelliJ IDEA.
-- User: 86186
-- Date: 30/12/2019
-- Time: 上午10:01
-- Basic Auth
-- “用户名:密码”格式的字符串经过的Base64编码

local ngx = ngx
local require = require
local rock_core = require('rock.core')
local ngx_re   = require("ngx.re")
local ngx_base64 = require("ngx.base64")
local users = require("rock.admin.users")


local _M = {
    version = 0.1,
    priority = 1000  --- 权重，越大越靠前
}

function _M.access(conf)
   local auth_str = ngx.req.get_headers()["Authorization"]
   if not auth_str then
       return rock_core.response.exit_error_msg(401,"Header Authorization is mising... ")
   end
   local auth_arry =ngx_re.split(auth_str," ")
   local auth
   if #auth_arry>1 then
       auth = auth_arry[2]
   end
   local res,err = ngx_base64.decode_base64url(auth)
   if not res then
       return rock_core.response.exit_error_msg(401,"Header Authorization decode_base64url error")
   end
   local res_array = ngx_re.split(res,":")
   local user
   if #res_array>1 then
       local username = res_array[1]
       local pwd = res_array[2]
        user = users.get_user(username,pwd)
   end
   if not user then
       return rock_core.response.exit_error_msg(401,"No Authorization")
   end

    ---生成token
    local res,err= rock_core.token.create(user)
    if not res then
        return rock_core.response.exit_error_msg(500,"Authorization server error")
    end
    return rock_core.response.exit(200,res)
end

return _M