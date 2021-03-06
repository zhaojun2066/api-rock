--
-- Created by IntelliJ IDEA.
-- User: jufeng
-- Date: 19/12/2019
-- Time: 上午10:15
--  router crud
--
local require = require
local ngx = ngx
local rock_core = require('rock.core')
local router_cache = require('rock.router')
local quote_sql_str = ngx.quote_sql_str --- 防止sql注入

local router_key = "rock_router"
local _M ={}

--- 添加路由
--- id  route id
--- data route json
--- args

local function check(data)
    if not data then
        return nil, {error_msg = " route is not null"}
    end
    local check_status,err = rock_core.schema.check_route(data)
    if not check_status  then
        return nil ,{error_msg = err}
    end
    --- todo check upstream_id,service_id,如果都传递，要保证之前的库里有对应的upstream和service
    --- todo check plugins 检查是否在配置存在，不在也要返回错误信息
    --- todo check filter function 是否包含过滤器函数，然后是否定义了
    return true ,nil
end

local function action_cache(action,data)
    rock_core.log.error("rock.admin.roouters.action_cache ok")
    if action == "put" then
        router_cache.put(data) --- 添加or更新cache
    elseif action == "delete" then
        router_cache.delete(data) -- 删除
    end
end

local function puslish(action,data)
    local msg = {
        worker_id = ngx.worker.id(),
        action = action,
        data = data
    }
    rock_core.log.error("rock.admin.roouters.puslish start")
    local redis =  rock_core.redis.new()
    local res ,err = redis:publish(router_key,rock_core.json.encode_json(msg))
    ---todo 失败要有重试机制
    if not res then
        rock_core.log.error("rock.admin.roouters.puslish: " .. err)
    end

end

--- add router
function _M.post(router)
    ---check data
    local ok ,err = check(router)
    if not ok then
        return 400,err
    end
    local router_str = rock_core.json.encode_json(router)
    local router_value = quote_sql_str(router_str)
    local sql = "insert into router (`data`,created,updated) values("..router_value..",now(),now())"
    local res,err = rock_core.mysql.query(sql)
    if not res then
        return 500,{error_msg = err}
    end
    router.id = res.insert_id
    action_cache("put",router)
    puslish("put",router)
    return 200, router
end

--- get a router
function _M.get(id)
    if not id then
        return 400,{error_msg = "id is not null"}
    end
    local id_value = quote_sql_str(id)
    local sql = "select * from router where id = ".. id_value
    local res,err =  rock_core.mysql.query(sql)
    if not res then
        return 500,{error_msg = err}
    end
    local router
    if #res >=1 then
        router = res[1].data
    end
    if not router then
        return 200,{}
    end
    router = rock_core.json.decode_json(router)
    router.id = id
    return 200, router
end


function _M.delete(id)
    if not id then
        return 400,{error_msg = "id is not null"}
    end
    local id_value = quote_sql_str(id)
    local sql = "delete from router where id = ".. id_value
    local res,err = rock_core.mysql.query(sql)
    if not res then
        return 500,{error_msg = err}
    end
    action_cache("delete",id)
    puslish("delete",id)
    return 200, res
end

--- update router
function _M.put(router)
    local ok ,err = check(router)
    if not ok then
        return 400,err
    end
    local id = router.id
    if not id then
        return 400,{error_msg = "id is not null"}
    end
    local id_value = quote_sql_str(id)
    local router_value = quote_sql_str(rock_core.json.encode_json(router))
    local sql = "update router set `data` = "..router_value.." where id = ".. id_value
    local res,err = rock_core.mysql.query(sql)
    if not res then
        return 500,{error_msg = err}
    end
    if res.affected_rows and res.affected_rows>0 then
        action_cache("put",router)
        puslish("put",router)
        return 200, router
    end
    return 500,{error_msg = "the router not found for id= " ..id_value}
end


function _M.list()
    rock_core.log.error("rock.admin.roouters.list start")
    local sql = "select * from router limit 10000"
    local res,err = rock_core.mysql.query(sql)
    if not res then
        return 500,{error_msg = err}
    end
    return 200, res
end

return _M

