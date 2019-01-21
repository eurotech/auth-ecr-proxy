FROM openresty/openresty:centos

RUN yum -y install \
        python \
        epel-release \
        && \
    yum -y install python-pip && \
    pip install --upgrade pip awscli==1.11.92 && \ 
    opm get bungle/lua-resty-session


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
