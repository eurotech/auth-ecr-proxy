FROM openresty/openresty:1.27.1.2-bookworm

RUN apt update && \
    apt -y install python3-pip awscli openresty-opm && \
    opm get bungle/lua-resty-session && \
    apt-get clean && rm -rf /var/lib/apt/lists/*


COPY configs/nginx/nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
COPY configs/nginx/default.conf /etc/nginx/conf.d/default.conf
COPY configs/nginx/authenticate.lua /etc/nginx/authenticate.lua

ADD configs/entrypoint.sh /entrypoint.sh
ADD configs/auth_update.sh /auth_update.sh
ADD configs/renew_token.sh /renew_token.sh 

EXPOSE 80

ENTRYPOINT ["/entrypoint.sh"]

CMD ["/usr/local/openresty/bin/openresty", "-g", "daemon off;"]

STOPSIGNAL SIGQUIT
