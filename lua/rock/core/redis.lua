--
-- Created by IntelliJ IDEA.
-- User: 86186
-- Date: 25/12/2019
-- Time: 上午10:37
-- To change this template use File | Settings | File Templates.
--

local require = require
local ngx = ngx
local redis = require "resty.redis"
local rock_core = require "rock.core"
local setmetatable = setmetatable

local _M = {}
local mt = {
    __index = _M
}
function _M.new()
    local red = redis:new()
    red:set_timeouts(1000, 1000, 2000) -- 1 sec red:set_timeouts(connect_timeout, send_timeout, read_timeout)
    local ok, err = red:connect("127.0.0.1", 6379)
    if not ok then
        rock_core.log.error("redis failed to connect: ".. err)
        return nil
    end

    local self = {
        red = red
    }
    return  setmetatable(self,mt)
end

function _M:close()
    local ok ,err = self.red:set_keepalive(30000, 30)
    if not ok then
        rock_core.log.error("redis failed to set_keepalive: ".. err)
        _M.new() -- 重新初始化
    end

end

function _M:subscribe(key)
    local res, err = self.red:subscribe(key)
    if not res then
        rock_core.log.error(" failed to subscribe: ".. err)
    ---subscribe("dog")
    ---  正常返回 ["subscribe","dog",1]
    end
    self:close()
    return res,err
end

function _M:publish(key,value_str)
    local res, err = self.red:publish(key,value_str)
    if not res then
        rock_core.log.error("failed to subscribe: " .. err)
        ---   red2:publish("dog", "Hello")
    end
    self:close()
    return res,err
end

function _M:read_reply()
    local res, err = self.red:read_reply()
    if not res then
        rock_core.log.error(" failed to read reply: " .. err)
        ---  正常返回 ["message","dog","Hello"], 取得时候，取最后一个Hello ，
    end
    self:close()
    return res,err
end


return _M

