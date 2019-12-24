--
-- Created by IntelliJ IDEA.
-- User: 86186
-- Date: 23/12/2019
-- Time: 上午11:25
-- To change this template use File | Settings | File Templates.
--

local logger = ngx.log                                                 --- function ngx log
local ERR = ngx.ERR

local _M = {}

function _M.error(msg)
    logger(ERR,msg)
end

return _M

