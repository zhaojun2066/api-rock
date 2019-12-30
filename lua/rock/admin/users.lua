--
-- Created by IntelliJ IDEA.
-- User: 86186
-- Date: 30/12/2019
-- Time: 上午10:46
-- To change this template use File | Settings | File Templates.
--


local require = require
local ngx = ngx
local rock_core = require('rock.core')
local quote_sql_str = ngx.quote_sql_str --- 防止sql注入


local _M = {}

function _M.get_user(username,pwd)
    if not username then
        return nil,{error_msg = "username is not null"}
    end
    if not pwd then
        return nil,{error_msg = "pwd is not null"}
    end
    username = quote_sql_str(username)
    pwd = quote_sql_str(pwd)
    local sql = "select * from user where username = ".. username .. " and password = " .. pwd
    local res,err = rock_core.mysql.query(sql)
    if not res then
        return nil,{error_msg = err}
    end
    local user
    if #res >=1 then
        user = res[1].data
    end
    return user, nil
end
return _M

