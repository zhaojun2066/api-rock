--
-- Created by IntelliJ IDEA.
-- User: jufeng
-- Date: 23/12/2019
-- Time: 上午10:37
-- 初始化service
--
local require = require
local rock_core = require('rock.core')
local new_table = require ("table.new")
local ipairs = ipairs
local ngx = ngx
local timer_at = ngx.timer.at

local _M = {}
local service_hash

local function load_service()
    local sql = "select * from service limit 5000"
    local res,err,sqlstate = rock_core.mysql.query(sql)
    ---- todo 如果失败要有重试机制
    if not res then
        rock_core.log.error(err)
    end

    service_hash = new_table(0,#res)

    for _,v  in ipairs(res)  do
        service_hash[v.id] = rock_core.json.decode_json(v.data)
    end
end

function _M.init_http_worker()
    timer_at(0,load_service)
end

function _M.get_service(id)
    return service_hash[id]
end


function _M.reload_service()
    load_service()
end

--- 新增或者更新service
function _M.put(service)
    service_hash[service.id] = service
end

function _M.delete(id)
    service_hash[id] = nil
end

return _M