--
-- Created by IntelliJ IDEA.
-- User: jufeng
-- Date: 19/12/2019
-- Time: 下午3:38
-- To change this template use File | Settings | File Templates.
--
local require = require
local mysql = require("resty.mysql")
local config = require("rock.core.config")
local logger = ngx.log                                                 --- function ngx log
local ERR = ngx.ERR
local _M ={}
local client
local function get_connection()
    local client, errmsg = mysql:new()
    if not client then
        return nil, {error_msg = "mysql.socket_failed: " .. (errmsg or "nil")}
    end
    local config =  config.local_conf()
    local db_config = config.mysql
    local options = {
        host = db_config.host,
        port = db_config.port,
        user = db_config.user,
        password = db_config.password,
        database = db_config.database,
    }
    local result, errmsg, errno, sqlstate = client:connect(options)
    if not result then
        logger(ERR,"get_connection error:" ..errmsg)
        return nil, {error_msg = "mysql.cant_connect: " .. (errmsg or "nil") .. ", errno:" .. (errno or "nil") ..
                ", sql_state:" .. (sqlstate or "nil")}
    end
    client:set_timeout(db_config.timeout) -- ms
    return client,nil
end

local function close(connection)
    local config =  config.local_conf()
    local db_config = config.mysql
    local ok, err =  connection:set_keepalive(db_config.max_idle_timeout,db_config.pool_size)
    if not ok then
        connection:close()
    end
end

function _M.query(sql)
    local connection,err = get_connection()
    if not connection then
        return nil,err
    end
    local result, errmsg, errno, sqlstate = connection:query(sql)
    while errmsg == "again" do
        result, errmsg, errno, sqlstate = connection:read_result()
    end
    close(connection)
    if not result then
        errmsg = "mysql.query_failed:" .. (errno or "nil") .. (errmsg or "nil")
        logger(ERR,"query error:" ..errmsg)
        return nil, {error_msg = errmsg}
    end
    return  result,nil
end

return _M


