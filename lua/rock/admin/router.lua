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
local quote_sql_str = ngx.quote_sql_str --- 防止sql注入
local rapidjson = require('rapidjson')
local encode_json = rapidjson.encode

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
--- add new router
function _M.put(router)
    ---check data
    local ok ,err = check(router)
    if not ok then
        return 400,err
    end
    local router_value = quote_sql_str(encode_json(router))
    local sql = "insert into router (`data`,created,updated) values("..router_value..",now(),now())"
    local res,err = rock_core.mysql.query(sql)
    if not res then
        return 500,{error_msg = err}
    end
    ---logger(ERR,"req_body:" ..res)
    router.id = res.insert_id
    return 200, router
end

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
    local router = res[1].data
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
    return 200, res
end

function _M.patch(router)
    local ok ,err = check(router)
    if not ok then
        return 400,err
    end
    local id = router.id
    if not id then
        return 400,{error_msg = "id is not null"}
    end
    local id_value = quote_sql_str(id)
    local router_value = quote_sql_str(router)
    local sql = "update router set `data` = "..router_value.." where id = ".. id_value
    local res,err = rock_core.mysql.query(sql)
    if not res then
        return 500,{error_msg = err}
    end
    return 200, router
end

return _M

