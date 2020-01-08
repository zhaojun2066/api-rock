
### schema
##### router
    {
    	"id":37,
    	"methods": ["GET"],
    	"uri": "/hello",
    	"upstream": {
    		"nodes": {
    			"10.12.52.23:8666": 1,
    			"10.12.52.23:8665": 1
    		},
    		"type": "chash", ----- "chash", "roundrobin"
    		"key": "arg_name"--- ngx.var[key]
    	}
    }

##### upstream
          {
        		"nodes": {
        			"10.12.52.23:8666": 1,
        			"10.12.52.23:8665": 1
        		},
        		"type": "chash", ----- "chash", "roundrobin"
        		"key": "arg_name"  --- ngx.var[key]
        	}
##### service


##### dep
    /usr/local/openresty/luajit/bin/luarocks install  rapidjson 0.6.1-1
    /usr/local/openresty/luajit/bin/luarocks install  lua-resty-ipmatcher
    /usr/local/openresty/luajit/bin/luarocks install  lua-resty-radixtree
    /usr/local/openresty/luajit/bin/luarocks install  lua-tinyyaml
    /usr/local/openresty/luajit/bin/luarocks install  lua-resty-balancer
                                    luarocks install lua-resty-cookie
                                    luarocks install lua-resty-jwt
    --todo upsteam service 采用lrucahe ，失效在去db查询，注意回源数据库的时候加锁，防止造成缓存失效的风暴
    
### plugins
    redirect 
    jwt-auth
    basic-auth
    ab-test
    limit-req
    limit-distribution
    stat
    ip-restriction ip white block list
    降级
    
    
        