--
-- Created by IntelliJ IDEA.
-- User: jufeng
-- Date: 19/12/2019
-- Time: 上午10:15
--  service crud
--
local require = require
local rock_core = require('rock.core')
local ngx = ngx
local quote_sql_str = ngx.quote_sql_str --- 防止sql注入
local rapidjson = require('rapidjson')
local encode_json = rapidjson.encode

local _M ={}

--- 添加service
--- id  route id
--- data route json
--- args

local function check(data)
    if not data then
        return nil, {error_msg = " route is not null"}
    end
    local check_status = rock_core.schema.check_service(data)
    if not check_status or check_status == false then
        return nil ,{error_msg = "schema error"}
    end
    return true ,nil
end
--- add new router
function _M.put(service)
    ---check data
    local ok ,err = check(service)
    if not ok then
        return 400,err
    end
    local service_value = quote_sql_str(encode_json(service))
    local sql = "insert into service (`data`,created,updated) values("..service_value..",now(),now())"
    local res,err = rock_core.mysql.query(sql)
    if not res then
        return 500,{error_msg = err}
    end
    service.id = res.insert_id
    return 200, service
end

function _M.get(id)
    if not id then
        return 400,{error_msg = "id is not null"}
    end
    local id_value = quote_sql_str(id)
    local sql = "select * from service where id = ".. id_value
    local res,err = rock_core.mysql.query(sql)
    if not res then
        return 500,{error_msg = err}
    end
    local service = res[1].data
    service.id = id
    return 200, service
end

function _M.delete(id)
    if not id then
        return 400,{error_msg = "id is not null"}
    end
    local id_value = quote_sql_str(id)
    local sql = "delete from service where id = ".. id_value
    local res,err = rock_core.mysql.query(sql)
    if not res then
        return 500,{error_msg = err}
    end
    return 200, res
end

function _M.patch(service)
    local ok ,err = check(service)
    if not ok then
        return 400,err
    end
    local id = service.id
    if not id then
        return 400,{error_msg = "id is not null"}
    end
    local id_value = quote_sql_str(id)
    local service_value = quote_sql_str(service)
    local sql = "update upstream set `data` = "..service_value.." where id = ".. id_value
    local res,err = rock_core.mysql.query(sql)
    if not res then
        return 500,{error_msg = err}
    end
    return 200, service
end

return _M

