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
local log = require "rock.core.log"
local setmetatable = setmetatable
local config = require("rock.core.config")

local _M = {}
local mt = {
    __index = _M
}
function _M.new()
    local config =  config.local_conf()
    local redis_config = config.redis
    local red = redis:new()
    red:set_timeout(redis_config.timeout) -- 1 sec red:set_timeouts(connect_timeout, send_timeout, read_timeout)
    local ok, err = red:connect(redis_config.host, redis_config.port)
    if not ok then
        log.error("rock.core.redis.new() failed to connect: ".. err)
        return nil
    end

    local self = {
        red = red,
        redis_config = redis_config
    }
    --red:set("dog", "an animal")
    return  setmetatable(self,mt)
end

function _M:close()
    local ok ,err = self.red:set_keepalive(self.redis_config.max_idle_timeout, self.redis_config.pool_size)
    if not ok then
        log.error("redis failed to set_keepalive: ".. err)
        return _M.new() -- 重新初始化
    end
    return nil
end

function _M:subscribe(key)
    local res, err = self.red:subscribe(key)
    if not res then
        log.error(" failed to subscribe: ".. err)
    ---subscribe("dog")
    ---  正常返回 ["subscribe","dog",1]
    end
   --- self:close(),subscribe  状态 不能够进行 set_keepalive
    return res,err
end


function _M:evel(...)
    local res = self.red: evel(...)
    if res then
        self:close()
    end
    return res
end

function _M:publish(key,value_str)
    local res, err = self.red:publish(key,value_str)
    if not res then
        log.error("failed to subscribe: " .. err)
        ---   red2:publish("dog", "Hello")
        return nil,err
    end
    --- 成功之后在放入连接池中
    self:close()

    return res,err
end

function _M:read_reply()
    local res, err = self.red:read_reply()
    if not res then
        return nil,err
        ---log.error(" failed to read reply: " .. err)
        ---  正常返回 ["message","dog","Hello"], 取得时候，取最后一个Hello ，
    end
    --self:close()
    return res,err
end


return _M

