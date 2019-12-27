--
-- Created by IntelliJ IDEA.
-- User: jufeng
-- Date: 19/12/2019
-- Time: 上午10:15
--  service crud
--
local require = require
local rock_core = require('rock.core')
local service_cache = require('rock.service')
local ngx = ngx
local quote_sql_str = ngx.quote_sql_str --- 防止sql注入
local service_key = "rock_service"
local tonumber = tonumber

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


local function puslish(action,data)
    local msg = {
        worker_id = ngx.worker.id(),
        action = action,
        data = data
    }
    local redis =  rock_core.redis.new()
    redis:publish(service_key,rock_core.json.encode_json(msg))
end


local function action_cache(action,data)
    if action == "put" then
        service_cache.put(data) --- 添加or更新cache
    elseif action == "delete" then
        service_cache.delete(data) -- 删除
    end
end

--- add new router
function _M.post(service)
    ---check data
    local ok ,err = check(service)
    if not ok then
        return 400,err
    end
    local service_value = quote_sql_str(rock_core.json.encode_json(service))
    local sql = "insert into service (`data`,created,updated) values("..service_value..",now(),now())"
    local res,err = rock_core.mysql.query(sql)
    if not res then
        return 500,{error_msg = err}
    end
    service.id = res.insert_id
    action_cache("put",service)
    puslish("put",service)
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
    local service
    if #res >=1 then
        service = res[1].data
    end
    if not service then
        return 200,{}
    end
    service = rock_core.json.decode_json(service)
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
    action_cache("delete",id)
    puslish("delete",id)
    return 200, res
end


--- update service
function _M.put(service)
    local ok ,err = check(service)
    if not ok then
        return 400,err
    end
    local id = service.id
    if not id then
        return 400,{error_msg = "id is not null"}
    end
    local id_value = quote_sql_str(id)
    local service_value = quote_sql_str(rock_core.json.encode_json(service))
    local sql = "update service set `data` = "..service_value.." where id = ".. id_value
    local res,err = rock_core.mysql.query(sql)
    if not res then
        return 500,{error_msg = err}
    end
    if res.affected_rows and res.affected_rows>0 then
        action_cache("put",service)
        puslish("put",service)
        return 200, service
    end
    return 500,{error_msg = "the service not found for id= " ..id_value}
end


function _M.list()
    local sql = "select * from service limit 10000"
    local res,err = rock_core.mysql.query(sql)
    if not res then
        return 500,{error_msg = err}
    end
    return 200, res
end

return _M

