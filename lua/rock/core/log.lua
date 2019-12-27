--
-- Created by IntelliJ IDEA.
-- User: 86186
-- Date: 23/12/2019
-- Time: 上午11:25
-- To change this template use File | Settings | File Templates.
--

local logger = ngx.log                                                 --- function ngx log
local ERR = ngx.ERR
local WARN = ngx.WARN

local _M = {}

function _M.error(...)
    logger(ERR,...)
end

function _M.warn(msg)
    logger(WARN,msg)
end

return _M

