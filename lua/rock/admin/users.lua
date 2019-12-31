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
local lrucache = require ("resty.lrucache")
local resty_lock = require ("resty.lock")
local user_cache ,err = lrucache.new(1000)
local user_locks = resty_lock:new("user_locks")
local _M = {}

function _M.get_user(username,pwd)
    local sql =  "select * from user where 1=1  "
    if username then
        username = quote_sql_str(username)
        sql = sql .. " and username = ".. username
    end
    if pwd then
        pwd = quote_sql_str(pwd)
        sql = sql .. " and password = ".. pwd
    end
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

function _M.get_user_from_cache(username,pwd)
    local user = user_cache:get(username)
    if user then
        if pwd then
            local password = user.password
            if password == pwd then
                return user
            else
                return nil,"password error"
            end
        end
        return user,nil
    end

    ---- 防止大流量回源数据库
    local elapsed,err = user_locks:lock(username)
    if not elapsed then
        return nil," get lock error : " .. err
    end
    --- 缓存中可能已经有了
    user = user_cache:get(username)
    if user then
        if pwd then
            local password = user.password
            if password == pwd then
                user_locks:unlock()
                return user
            else
                user_locks:unlock()
                return nil,"password error"
            end
        end
        user_locks:unlock()
        return user,nil
    end
    --- from db
    user = _M.get_user(username,pwd)
    if user then
        user_cache:set(username,user,36000) --- 10 hour
    end
    user_locks:unlock()
    if not user then
        return nil," no such user "
    end
    return user,nil

end

return _M

