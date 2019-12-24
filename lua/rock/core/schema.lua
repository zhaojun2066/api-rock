--
-- Created by IntelliJ IDEA.
-- User: 86186
-- Date: 19/12/2019
-- Time: 下午1:58
-- To change this template use File | Settings | File Templates.
--
local require = require
local rapidjson = require('rapidjson')
local schema_models = require("rock.schema.schema_model")
local upstream_schema = schema_models.upstream
local route_schema = schema_models.router
local service_schema = schema_models.service

local function check(data,data_schema)
    local schema = rapidjson.SchemaDocument(data_schema)
    local validator = rapidjson.SchemaValidator(schema)
    local d = rapidjson.Document(data)
    return validator:validate(d)
end

local _M={}
function _M.check_upstream(data)
    return check(data,upstream_schema)
end

function _M.check_route(data)
    return check(data,route_schema)
end

function _M.check_service(data)
    return check(data,service_schema)
end

return _M
