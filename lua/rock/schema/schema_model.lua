--
-- Created by IntelliJ IDEA.
-- User: jufeng
-- Date: 18/12/2019
-- Time: 上午11:02
-- To change this template use File | Settings | File Templates.
--

local _M = {}

local plugins_schema = {
    type = "object"
}

local host_def_pat = "^\\*?[0-9a-zA-Z-.]+$"
local host_def = {
    type = "string",
    pattern = host_def_pat,
}
_M.host_def = host_def


local ipv4_def = "[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}"
local ipv6_def = "([a-fA-F0-9]{0,4}:){0,8}(:[a-fA-F0-9]{0,4}){0,8}"
        .. "([a-fA-F0-9]{0,4})?"
local ip_def = {
    {pattern = "^" .. ipv4_def .. "$"},
    {pattern = "^" .. ipv4_def .. "/[0-9]{1,2}$"},
    {pattern = "^" .. ipv6_def .. "$"},
    {pattern = "^" .. ipv6_def .. "/[0-9]{1,3}$"},
}
_M.ip_def = ip_def


_M.global_plugins = {
    type = "object",
    properties = {
        plugins = plugins_schema
    },
    required = {"plugins"},
    additionalProperties = false,
}

local id_schema = {
    anyOf = {
        {
            type = "string", minLength = 1, maxLength = 32,
            pattern = [[^[0-9]+$]]
        },
        {type = "integer", minimum = 1}
    }
}

local remote_addr_def = {
    description = "client IP",
    type = "string",
    anyOf = ip_def,
}

local upstream_schema = {
    type = "object",
    properties = {
        nodes = {
            description = "nodes of upstream",
            type = "object",
            patternProperties = {
                [".*"] = {
                    description = "weight of node",
                    type = "integer",
                    minimum = 0,
                }
            },
            minProperties = 1,
        },
        retries = {
            type = "integer",
            minimum = 1,
        },
        timeout = {
            type = "object",
            properties = {
                connect = {type = "number", minimum = 0},
                send = {type = "number", minimum = 0},
                read = {type = "number", minimum = 0},
            },
            required = {"connect", "send", "read"},
        },
        type = {
            description = "algorithms of load balancing",
            type = "string",
            enum = {"chash", "roundrobin"}
        },
        key = {
            description = "the key of chash for dynamic load balancing",
            type = "string",
            pattern = [[^((uri|server_name|server_addr|request_uri|remote_port]]
                    .. [[|remote_addr|query_string|host|hostname)]]
                    .. [[|arg_[0-9a-zA-z_-]+)$]],
        },
        desc = {type = "string", maxLength = 256},
        id = id_schema
    },
    required = {"nodes", "type"},
    additionalProperties = false,
}


_M.router = {
    type = "object",
    properties = {
        uri = {type = "string", minLength = 1, maxLength = 4096},
        uris = {
            type = "array",
            items = {
                description = "HTTP uri",
                type = "string",
            },
            uniqueItems = true,
        },
        desc = {type = "string", maxLength = 256},

        methods = {
            type = "array",
            items = {
                description = "HTTP method",
                type = "string",
                enum = {"GET", "POST", "PUT", "DELETE", "PATCH", "HEAD",
                    "OPTIONS", "CONNECT", "TRACE"}
            },
            uniqueItems = true,
        },
        host = host_def,
        hosts = {
            type = "array",
            items = host_def,
            uniqueItems = true,
        },
        remote_addr = remote_addr_def,
        remote_addrs = {
            type = "array",
            items = remote_addr_def,
            uniqueItems = true,
        },
        vars = {
            type = "array",
            items = {
                description = "Nginx builtin variable name and value",
                type = "array",
                items = {
                    maxItems = 3,
                    minItems = 2,
                    anyOf = {
                        {type = "string",},
                        {type = "number",},
                    }
                }
            }
        },
        filter_func = {
            type = "string",
            minLength = 10,
            pattern = [[^function]],
        },

        plugins = plugins_schema,
        upstream = upstream_schema,

        service_id = id_schema,
        upstream_id = id_schema,
        service_protocol = {
            enum = {"http"}
        },
        id = id_schema,
    },
    anyOf = {
        {required = {"plugins", "uri"}},
        {required = {"upstream", "uri"}},
        {required = {"upstream_id", "uri"}},
        {required = {"service_id", "uri"}},
        {required = {"upstream", "uris"}},
        {required = {"upstream_id", "uris"}},
        {required = {"service_id", "uris"}},
    },
    additionalProperties = false,
}

_M.service = {
    type = "object",
    properties = {
        id = id_schema,
        plugins = plugins_schema,
        upstream = upstream_schema,
        upstream_id = id_schema,
        desc = {type = "string", maxLength = 256},
    },
    anyOf = {
        {required = {"upstream"}},
        {required = {"upstream_id"}},
        {required = {"plugins"}},
    },
    additionalProperties = false,
}
_M.consumer = {
    type = "object",
    properties = {
        username = {
            type = "string", minLength = 1, maxLength = 32,
            pattern = [[^[a-zA-Z0-9_]+$]]
        },
        plugins = plugins_schema,
        desc = {type = "string", maxLength = 256}
    },
    required = {"username"},
    additionalProperties = false,
}
_M.upstream = upstream_schema

return _M

