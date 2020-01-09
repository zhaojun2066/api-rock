### openresty install
    yum安装 【我使用的方式】
    sudo yum install yum-utils
    添加官方仓库
    sudo yum-config-manager --add-repo https://openresty.org/package/centos/openresty.repo
    安装
    sudo yum install openresty
    命令行工具 resty
    sudo yum install openresty-resty
    命令行工具 restydoc
    sudo yum install openresty-doc
    按照opm
    yum install openresty-opm
    
    列出所有 openresty 仓库里头的软件包：然后自行安装
    sudo yum --disablerepo="*" --enablerepo="openresty" list available
    
    二进制安装
    tar -zxvf openresty-1.13.6.2.tar.gz
    cd openresty-1.13.6.2
    yum install -y gcc gcc-c++ readline-devel pcre-devel openssl-devel tcl perl
    ./configure  --prefix=/apps/openresty  --with-luajit
    make
    make install
    
    启动：openresty -p `pwd` -c cong/nginx.conf  其中pwd 是你当前的工作目录
    重启：sudo kill -HUP `cat logs/nginx.pid` 
### luarocks install
    安装：
    $ wget https://luarocks.org/releases/luarocks-2.4.1.tar.gz
    $ tar zxpf luarocks-2.4.1.tar.gz
    $ cd luarocks-2.4.1
    ./configure --prefix=/usr/local/openresty/luajit \
        --with-lua=/usr/local/openresty/luajit/ \
        --lua-suffix=jit \
        --with-lua-include=/usr/local/openresty/luajit/include/luajit-2.1   
         
### schema
    具体看schema_model.lua 定义
    具体api 看rock/admin/*.lua
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
    {
    	"plugins": {
    		"limit-req": {
    			"rate": 10,
    			"burst": 5,
    			"key":"arg_name"
    		}
    	},
    	"upstream": {
    		"nodes": {
    			"10.12.52.23:8665": 1,
    			"10.12.52.23:8666": 1
    		},
    		"type": "roundrobin"
    	},
    	"id": 1
    
    }

##### dep
    luarocks install  rapidjson 0.6.1-1
    luarocks install  lua-resty-ipmatcher
    luarocks install  lua-resty-radixtree
    luarocks install  lua-tinyyaml
    luarocks install  lua-resty-balancer
    luarocks install lua-resty-cookie
    luarocks install lua-resty-jwt
    --todo upsteam service 采用lrucahe ，失效在去db查询，注意回源数据库的时候加锁，防止造成缓存失效的风暴
    
### plugins
    redirect 
    jwt-auth
    basic-auth
    limit-req
    limit-distribution
    ---- 开发中
    stat
    ip-restriction ip white block list
    降级
     ab-test
    
    
        