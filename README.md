
    /usr/local/openresty/luajit/bin/luarocks install  rapidjson 0.6.1-1
    /usr/local/openresty/luajit/bin/luarocks install  lua-resty-ipmatcher
    /usr/local/openresty/luajit/bin/luarocks install  lua-resty-radixtree
    /usr/local/openresty/luajit/bin/luarocks install  lua-tinyyaml
    /usr/local/openresty/luajit/bin/luarocks install  lua-resty-balancer
    
    --todo upsteam service 采用lrucahe ，失效在去db查询，注意回源数据库的时候加锁，防止造成缓存失效的风暴
    
### plugins
    redirect 
    rewrite
    key-auth
    jwt-auth
    basic-auth
    oauth2
    ab-test
    limit-req
    limit-conn
    limit-count
    limit-distribution
    stat
    ip-restriction ip white block list
    降级
    
    
        