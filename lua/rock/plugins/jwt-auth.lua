--
-- Created by IntelliJ IDEA.
-- User: jufeng
-- Date: 30/12/2019
-- Time: 下午3:08
-- json web token
--

local ngx = ngx
local require = require
local rock_core = require('rock.core')
local ngx_re   = require("ngx.re")
local ngx_base64 = require("ngx.base64")
local users = require("rock.admin.users")
local resty_cookie = require("resty.cookie")
local jwt = require ("resty.jwt")
local exp_time = 3600*24*30  --- 30天

local _M = {}


local function get_request_token()
    local args = ngx.req.get_uri_args()
    if args and args.jwt then
        return args.jwt
    end

    local headers = ngx.req.get_headers()
    if headers.Authorization then
        return headers.Authorization
    end

    local cookie, err = resty_cookie:new()
    if not cookie then
        return nil, err
    end

    local val, err = cookie:get("jwt")
    return val, err
end

local function get_user()
    local auth_str = ngx.req.get_headers()["Authorization"]
    if not auth_str then
        return nil,"Header Authorization is mising... "
    end
    local auth_arry =ngx_re.split(auth_str," ")
    local auth
    if #auth_arry>1 then
        auth = auth_arry[2]
    end
    local res,err = ngx_base64.decode_base64url(auth)
    if not res then
        return nil, "Header Authorization decode_base64url error"
    end
    local res_array = ngx_re.split(res,":")
    local user
    if #res_array>1 then
        local username = res_array[1]
        local pwd = res_array[2]
        user = users.get_user(username,pwd)
    end
    if not user then
        return nil, "No Authorization"
    end

    return user,nil

end

function _M.generate_token()
    local user,err = get_user()
    if not user then
        return rock_core.response.exit_error_msg(401,err)
    end
    local pwd = user.password
    local username = user.username
    local exp_time = user.expire_time
    ---todo 要不要每次都更新token
    local jwt_token = jwt:sign(
        pwd,
        {
            header={typ="JWT", alg="HS256"},
            payload={
                username=username,
                exp = ngx.time() + exp_time

            }
        }
    )
    return rock_core.response.exit_msg(401,jwt_token)
end

---- check token
function _M.access()
    local jwt,err = get_request_token()
    if not jwt then
        return rock_core.response.exit_error_msg(401,"JWT is not null")
    end

    local jwt_obj = jwt:load_jwt(jwt)
    if not jwt_obj.valid then
        return 401, {message = jwt_obj.reason}
    end
    local username = jwt_obj.payload and jwt_obj.payload.username

    if not username then
        return rock_core.response.exit_error_msg(401,"Jmissing username in JWT token")
    end
    local user = users.get_user(username)
    jwt_obj = jwt:verify_jwt_obj(user.password, jwt_obj)
    if not jwt_obj.verified then
        return rock_core.response.exit_error_msg(401,jwt_obj.reason )
    end

end

return _M