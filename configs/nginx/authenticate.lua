-- basic configuration of the script
 
local db_username = "DBUSER"
local db_password = "DBPASSWORD"
local db_host = "DBHOST"
local db_port = "DBPORT"
local db_name = "DBNAME"
 
-- end configuration

local session = require "resty.session".open()
local remote_password

if ngx.var.http_authorization then
    local tmp = ngx.var.http_authorization
    tmp = tmp:sub(tmp:find(' ')+1)
    tmp = ngx.decode_base64(tmp)
    remote_password = tmp:sub(tmp:find(':')+1)
end
 
function split(inputstr, sep)
    if sep == nil then
            sep = "%s"
    end
    local t={} ; local i=1
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
            t[i] = str
            i = i + 1
    end
    return t
end

function authentication_prompt()
    session.data.valid_user = false
    session.data.user_group = nil
    session:save()
    ngx.header.www_authenticate = 'Basic realm="Restricted"'
    ngx.exit(401)
end
 
function authenticate(user, password, uri)
    local mysql = require "resty.mysql"
    local db, err, errno, sqlstate, res, ok
    
    db = mysql:new()
    if not db then
        ngx.log(ngx.ERR, "Failed to create mysql object")
        ngx.exit(500)
    end
 
    db:set_timeout(2000)
    ok, err, errno, sqlstate = db:connect{
        host = db_host,
        port = db_port,
        database = db_name,
        user = db_username,
        password = db_password
    }
 
    if not ok then
        ngx.log(ngx.ERR, "Unable to connect to database: ", err, ": ", errno, " ", sqlstate)
        ngx.exit(500)
    end
 
    user = ngx.quote_sql_str(user)
    password = ngx.quote_sql_str(password)

    if  uri == "/v2/" then
        uri = ngx.quote_sql_str(uri)
        query = "select 1 from users us INNER JOIN groups_users_ref gr_us on us.id_us = gr_us.id_us INNER JOIN groups gr on gr_us.id_gr = gr.id_gr INNER JOIN groups_uri_ref gr_ur on gr.id_gr = gr_ur.id_gr INNER JOIN uri ur on gr_ur.id_ur = ur.id_ur WHERE username = %s and password = MD5(%s) and uri = %s;"
    elseif string.find(uri, "charts") then
        splituri = split(uri, "/")
        image = splituri[4]
        tag = splituri[6]
        uri = "\'%" .. image .. "%" .. tag .. "%\'"
        query = "select 1 from users us INNER JOIN groups_users_ref gr_us on us.id_us = gr_us.id_us INNER JOIN groups gr on gr_us.id_gr = gr.id_gr INNER JOIN groups_uri_ref gr_ur on gr.id_gr = gr_ur.id_gr INNER JOIN uri ur on gr_ur.id_ur = ur.id_ur WHERE username = %s and password = MD5(%s) and uri like %s;"
    else
        splituri = split(uri, "/")
        image = splituri[3]
        tag = splituri[5]
        uri = "\'%" .. image .. "%" .. tag .. "%\'"
        query = "select 1 from users us INNER JOIN groups_users_ref gr_us on us.id_us = gr_us.id_us INNER JOIN groups gr on gr_us.id_gr = gr.id_gr INNER JOIN groups_uri_ref gr_ur on gr.id_gr = gr_ur.id_gr INNER JOIN uri ur on gr_ur.id_ur = ur.id_ur WHERE username = %s and password = MD5(%s) and uri like %s;"
    end

    query = string.format(query, user, password, uri);
    res, err, errno, sqlstate = db:query(query)
 
    if res and res[1] then
        session.data.valid_user = true
        session:open()
    elseif string.find(uri, "sha256") then
        session.data.valid_user = true
        session:open()
    else
        authentication_prompt()
    end
end

function log_access(user, uri)
    local mysql = require "resty.mysql"
    local db, err, errno, sqlstate, res, ok
    local tf = os.date('%Y-%m-%d %H:%M:%S.',os.time())

    db = mysql:new()
    if not db then
        ngx.log(ngx.ERR, "Failed to create mysql object")
        ngx.exit(500)
    end

    db:set_timeout(2000)
    ok, err, errno, sqlstate = db:connect{
        host = db_host,
        port = db_port,
        database = db_name,
        user = db_username,
        password = db_password
    }

    if not ok then
        ngx.log(ngx.ERR, "Unable to connect to database: ", err, ": ", errno, " ", sqlstate)
        ngx.exit(500)
    end

    user = ngx.quote_sql_str(user)
    uri = ngx.quote_sql_str(uri)
    local query = "insert into log_proxy (username,uri,timestamp) values (%s, %s, '%s');"
    query = string.format(query, user, uri, tf);
    res, err, errno, sqlstate = db:query(query)
end
 
if session.present and (session.data.valid_user) then
    return
elseif ngx.var.remote_user and remote_password then
    authenticate(ngx.var.remote_user, remote_password, ngx.var.request_uri)
    if ( not string.find(ngx.var.request_uri, "blobs") ) then
    log_access(ngx.var.remote_user, ngx.var.request_uri)
    end
else
    authentication_prompt()
end
