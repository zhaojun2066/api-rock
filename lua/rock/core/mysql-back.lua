--
-- Created by IntelliJ IDEA.
-- User: jufeng
-- Date: 19/12/2019
-- Time: 下午3:38
-- To change this template use File | Settings | File Templates.
--
local local_config = require('rock.core.config')
local config = local_config.local_conf(false)
local mysql = require("resty.mysql")
local _M ={}
local mt = {
    __index = _M
}

local function get_connection(db_config)
    local client, errmsg = mysql:new()
    if not client then
        return nil, {error_msg = "mysql.socket_failed: " .. (errmsg or "nil")}
    end
    local options = {
        host = db_config.host,
        port = db_config.port,
        user = db_config.user,
        password = db_config.password,
        database = db_config.database,
        charset = db_config.charset
    }
    local result, errmsg, errno, sqlstate = client:connect(options)
    if not result then
        return nil, {error_msg = "mysql.cant_connect: " .. (errmsg or "nil") .. ", errno:" .. (errno or "nil") ..
                ", sql_state:" .. (sqlstate or "nil")}
    end
    client:set_timeout(db_config.timeout) -- ms
    return client,nil
end
function _M.new()
    local db_config = config.mysql;
    local connection,err = get_connection(db_config)
    if not connection then
        return nil, err
    end
    local self = {
        connection = connection,
        db_config = db_config
    }
    return  setmetatable(self,mt),nil
end


function _M:close()
    local connection = self.connection
    local db_config = self.db_config
    local ok, err =  connection:set_keepalive(db_config.max_idle_timeout,db_config.pool_size)
    if not ok then
        connection:close()
        self.new(self.db_config)
    end
end

function _M:query(sql)
    local connection =self.connection
    local result, errmsg, errno, sqlstate = connection:query(sql)
    while errmsg == "again" do
        result, errmsg, errno, sqlstate = connection:read_result()
    end
    self:close()
    if not result then
        errmsg = "mysql.query_failed:" .. (errno or "nil") .. (errmsg or "nil")
        return nil, {error_msg = errmsg}, sqlstate
    end

    return  result,nil, sqlstate
end

return _M


