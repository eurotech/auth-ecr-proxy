-- basic configuration of the script
 
local db_username = "DBUSER"
local db_password = "DBPASSWORD"
local db_host = "DBHOST"
local db_port = "DBPORT"
local db_name = "DBNAME"
 
-- end configuration

local session = require "resty.session".open()

-- read the content of /etc/nginx/aws_token.txt
local f = io.open("/etc/nginx/aws_token.txt", "r")
if f == nil then
    ngx.log(ngx.ERR, "Unable to open /etc/nginx/aws_token.txt")
    ngx.exit(500)
end
local aws_token = f:read("*all")
f:close()
-- Remove any trailing whitespace/newlines from the token
aws_token = aws_token:gsub("%s+$", "")
ngx.log(ngx.INFO, "AWS token loaded successfully")

 
local function split(inputstr, sep)
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

local function authentication_prompt()
    ngx.log(ngx.DEBUG, "Authentication required for ", ngx.var.remote_user)
    session.data.valid_user = false
    session.data.user_group = nil
    session:save()
    ngx.header.www_authenticate = 'Basic realm="Restricted"'
    ngx.exit(401)
end
 
local function authenticate(user, password, uri)
    local mysql = require "resty.mysql"
    local db, err, errno, sqlstate, res, ok
    
    ngx.log(ngx.DEBUG, "Attempting to authenticate user: ", user, " for URI: ", uri)
    
    db = mysql:new()
    if not db then
        ngx.log(ngx.ERR, "Failed to create mysql object")
        session.data.valid_user = false
        return
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
        session.data.valid_user = false
        return
    end
    
    ngx.log(ngx.DEBUG, "Successfully connected to database")
 
    user = ngx.quote_sql_str(user)
    password = ngx.quote_sql_str(password)

    local query
    if  uri == "/v2/" then
        uri = ngx.quote_sql_str(uri)
        query = "select 1 from users us INNER JOIN groups_users_ref gr_us on us.id_us = gr_us.id_us INNER JOIN groups gr on gr_us.id_gr = gr.id_gr INNER JOIN groups_uri_ref gr_ur on gr.id_gr = gr_ur.id_gr INNER JOIN uri ur on gr_ur.id_ur = ur.id_ur WHERE username = %s and password = MD5(%s) and uri = %s;"
    elseif string.find(uri, "charts") then
        local splituri = split(uri, "/")
        local image = splituri[4]
        local tag = splituri[6]
        uri = "\'%" .. image .. "%" .. tag .. "%\'"
        query = "select 1 from users us INNER JOIN groups_users_ref gr_us on us.id_us = gr_us.id_us INNER JOIN groups gr on gr_us.id_gr = gr.id_gr INNER JOIN groups_uri_ref gr_ur on gr.id_gr = gr_ur.id_gr INNER JOIN uri ur on gr_ur.id_ur = ur.id_ur WHERE username = %s and password = MD5(%s) and uri like %s;"
    else
        local splituri = split(uri, "/")
        local image = splituri[3]
        local tag = splituri[5]
        uri = "\'%" .. image .. "%" .. tag .. "%\'"
        query = "select 1 from users us INNER JOIN groups_users_ref gr_us on us.id_us = gr_us.id_us INNER JOIN groups gr on gr_us.id_gr = gr.id_gr INNER JOIN groups_uri_ref gr_ur on gr.id_gr = gr_ur.id_gr INNER JOIN uri ur on gr_ur.id_ur = ur.id_ur WHERE username = %s and password = MD5(%s) and uri like %s;"
    end

    query = string.format(query, user, password, uri);
    ngx.log(ngx.DEBUG, "Executing query: ", query)
    
    res, err, errno, sqlstate = db:query(query)
    
    if not res then
        ngx.log(ngx.ERR, "Database query failed: ", err, ": ", errno, " ", sqlstate)
        session.data.valid_user = false
        return
    end
 
    if res and res[1] then
        ngx.log(ngx.INFO, "User authentication successful")
        session.data.valid_user = true
        session:save()
    elseif string.find(uri, "sha256") then
        ngx.log(ngx.INFO, "Allowing sha256 request without strict auth")
        session.data.valid_user = true
        session:save()
    else
        ngx.log(ngx.INFO, "User authentication failed - no matching records")
        session.data.valid_user = false
    end
    
    -- Close database connection
    db:close()
end

local function log_access(user, uri)
    local mysql = require "resty.mysql"
    local db, err, errno, sqlstate, res, ok
    local tf = os.date('%Y-%m-%d %H:%M:%S.',os.time())

    ngx.log(ngx.DEBUG, "Attempting to log access for user: ", user)

    db = mysql:new()
    if not db then
        ngx.log(ngx.ERR, "Failed to create mysql object for logging")
        return  -- Don't exit, just skip logging
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
        ngx.log(ngx.WARN, "Unable to connect to database for logging (possibly read replica): ", err, ": ", errno, " ", sqlstate)
        return  -- Don't exit, just skip logging
    end

    user = ngx.quote_sql_str(user)
    uri = ngx.quote_sql_str(uri)
    local query = "insert into log_proxy (username,uri,timestamp) values (%s, %s, '%s');"
    query = string.format(query, user, uri, tf);
    res, err, errno, sqlstate = db:query(query)
    
    if not res then
        ngx.log(ngx.WARN, "Failed to insert log record (possibly read replica): ", err)
    else
        ngx.log(ngx.DEBUG, "Successfully logged access")
    end
    
    db:close()
end
 
-- Parse the Authorization header to extract username and password
local function parse_auth_header()
    local auth_header = ngx.var.http_authorization
    if not auth_header then
        ngx.log(ngx.INFO, "No Authorization header found")
        return nil, nil
    end
    
    if not auth_header:match("^Basic ") then
        ngx.log(ngx.INFO, "Authorization header is not Basic auth")
        return nil, nil
    end
    
    local base64_creds = auth_header:sub(7)  -- Remove "Basic "
    local decoded = ngx.decode_base64(base64_creds)
    if not decoded then
        ngx.log(ngx.ERR, "Failed to decode Base64 credentials")
        return nil, nil
    end
    
    local username, password = decoded:match("([^:]+):(.+)")
    if not username or not password then
        ngx.log(ngx.ERR, "Failed to parse username:password from credentials")
        return nil, nil
    end
    
    ngx.log(ngx.DEBUG, "Parsed credentials for user: ", username)
    return username, password
end

-- Main authentication flow
local username, password = parse_auth_header()

if not username or not password then
    ngx.log(ngx.INFO, "Missing or invalid credentials, prompting for authentication")
    authentication_prompt()
    return
end

-- Check if user has valid session
if session.present and session.data.valid_user and session.data.username == username then
    ngx.log(ngx.DEBUG, "User ", username, " has valid session, setting AWS token")
    -- User is authenticated, set AWS token for ECR access
    ngx.req.set_header("Authorization", "Basic " .. aws_token)
    return
end

-- Authenticate the user against database
ngx.log(ngx.DEBUG, "Authenticating user ", username, " against database")
authenticate(username, password, ngx.var.request_uri)

-- Check if authentication was successful
if session.data and session.data.valid_user then
    ngx.log(ngx.DEBUG, "Authentication successful for user ", username)
    session.data.username = username
    session:save()
    -- Set AWS token for ECR access
    ngx.req.set_header("Authorization", "Basic " .. aws_token)
    
    -- Log access (but not for blob requests to reduce log noise)
    -- Skip logging if database is read-only
    if not string.find(ngx.var.request_uri, "blobs") then
        -- Wrap in pcall to handle read replica errors gracefully
        local ok, err = pcall(log_access, username, ngx.var.request_uri)
        if not ok then
            ngx.log(ngx.WARN, "Failed to log access (likely read replica): ", err)
        end
    end
else
    ngx.log(ngx.INFO, "Authentication failed for user ", username)
    authentication_prompt()
end
