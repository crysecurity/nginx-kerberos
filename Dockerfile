FROM alpine as base
LABEL Description="Nginx docker image with kerberos support" \
      BaseImageOS="alpine" \
      Maintainer="cr4sec"
FROM base as build

ARG NGINX_VERSION=1.17.6

RUN set -ex \
  && apk add --no-cache \
    krb5 \
    krb5-dev \
    ca-certificates \
    libressl \
    pcre \
    zlib \
  && apk add --no-cache --virtual .build-deps \
    build-base \
    linux-headers \
    libressl-dev \
    pcre-dev \
    wget \
    zlib-dev

RUN mkdir -p /tmp/nginx && cd /tmp/nginx \
	&& wget https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz -O nginx.tar.gz \
	&& tar -xzf nginx.tar.gz --strip-components=1

COPY images/spnego-http-auth-nginx-module/ /tmp/nginx/spnego-http-auth-nginx-module/

RUN cd /tmp/nginx && ./configure \
        --prefix=/etc/nginx \
        --sbin-path=/usr/sbin/nginx \
        --conf-path=/etc/nginx/nginx.conf \
        --error-log-path=/var/log/nginx/error.log \
        --pid-path=/var/run/nginx.pid \
        --lock-path=/var/run/nginx.lock \
        --user=nginx \
        --group=nginx \
        --with-threads \
        --with-file-aio \
        --with-http_ssl_module \
        --with-http_v2_module \
        --with-http_realip_module \
        --with-http_addition_module \
        --with-http_sub_module \
        --with-http_dav_module \
        --with-http_flv_module \
        --with-http_mp4_module \
        --with-http_gunzip_module \
        --with-http_gzip_static_module \
        --with-http_auth_request_module \
        --with-http_random_index_module \
        --with-http_secure_link_module \
        --with-http_slice_module \
        --with-http_stub_status_module \
        --http-log-path=/var/log/nginx/access.log \
        --http-client-body-temp-path=/var/cache/nginx/client_temp \
        --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
        --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
        --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
        --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
        --with-mail \
        --with-mail_ssl_module \
        --with-stream \
        --with-stream_ssl_module \
        --with-stream_realip_module \
#        --with-debug \
        --add-module=spnego-http-auth-nginx-module \
      && make -j$(getconf _NPROCESSORS_ONLN) \
      && make install

FROM base as runtime

COPY --from=build /etc/nginx /etc/nginx
COPY --from=build /usr/sbin/nginx /usr/sbin/nginx
COPY --from=build /var/log/nginx /var/log/nginx

RUN set -ex \
  && apk add --no-cache \
    krb5 \
    krb5-dev \
    ca-certificates \
    libressl \
    pcre \
    zlib

RUN adduser -D nginx \
  && mkdir -p /var/cache/nginx \
  && rm -rf /tmp/nginx

CMD ["nginx", "-g", "daemon off;"]
