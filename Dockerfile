FROM centos:centos7
MAINTAINER Mateusz Lerczak mateusz.lerczak@5ki.pl

ENV HAPROXY_MJR_VERSION=1.7
ENV HAPROXY_VERSION=1.7.9
ENV LUA_VERSION 5.3.4
ENV LUA_MJR_VERSION 53
ENV OPENSSL_VERSION="1.1.0f"
ENV CERTS_PATH /etc/haproxy/certs
ENV HAPROXY_CONFIG /etc/haproxy/haproxy.cfg

RUN yum-config-manager --enable rhui-REGION-rhel-server-extras rhui-REGION-rhel-server-optional \
    && yum install -y epel-release \
    && yum update -y \
    && yum install -y inotify-tools wget make gcc perl pcre-devel zlib-devel readline-devel certbot

RUN cd /usr/src \
    && curl -R -O http://www.lua.org/ftp/lua-${LUA_VERSION}.tar.gz \
    && tar -zxf lua-${LUA_VERSION}.tar.gz \
    && rm lua-${LUA_VERSION}.tar.gz \
    && cd lua-${LUA_VERSION} \
    && make linux \
    && make INSTALL_TOP=/opt/lua${LUA_MJR_VERSION} install

RUN wget -O /tmp/openssl.tgz https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz \
    && tar -zxf /tmp/openssl.tgz -C /tmp \
    && cd /tmp/openssl-* \
    && ./config --prefix=/usr \
                --openssldir=/etc/ssl \
                --libdir=lib \
                no-shared zlib-dynamic \
    && make \
    && make install_ssldirs \
    && make install_sw \
    && cd \
    && rm -rf /tmp/openssl*

RUN wget -O /tmp/haproxy.tgz http://www.haproxy.org/download/${HAPROXY_MJR_VERSION}/src/haproxy-${HAPROXY_VERSION}.tar.gz \
    && tar -zxvf /tmp/haproxy.tgz -C /tmp \
    && cd /tmp/haproxy-* \
    && make \
        TARGET=linux2628 USE_LINUX_TPROXY=1 USE_ZLIB=1 USE_REGPARM=1 USE_PCRE=1 USE_PCRE_JIT=1 \
        USE_LUA=yes LUA_LIB=/opt/lua53/lib/ LUA_INC=/opt/lua53/include/ LDFLAGS=-ldl \
        USE_OPENSSL=1 SSL_INC=/usr/include SSL_LIB=/usr/lib ADDLIB=-ldl ADDLIB=-lpthread \
        CFLAGS="-O2 -g -fno-strict-aliasing -DTCP_USER_TIMEOUT=18" \
    && make install \
    && cd \
    && rm -rf /tmp/haproxy*  \
    && mkdir -p /var/lib/haproxy \
    && groupadd haproxy \
    && adduser haproxy -g haproxy \
    && chown -R haproxy:haproxy /var/lib/haproxy

RUN mkdir -p ${CERTS_PATH}
RUN openssl genrsa -out ${CERTS_PATH}/dummy.key 2048 \
    && openssl req -new -key ${CERTS_PATH}/dummy.key -out ${CERTS_PATH}/dummy.csr -subj "/C=GB/L=London/O=Company Ltd/CN=haproxy" \
    && openssl x509 -req -days 3650 -in ${CERTS_PATH}/dummy.csr -signkey ${CERTS_PATH}/dummy.key -out ${CERTS_PATH}/dummy.crt
RUN cat ${CERTS_PATH}/dummy.crt ${CERTS_PATH}/dummy.key > ${CERTS_PATH}/haproxy-dummy.pem
RUN rm ${CERTS_PATH}/dummy.*

RUN yum remove -y wget gcc pcre-devel zlib-devel perl readline-devel \
    && yum clean all

COPY container-files /

EXPOSE 80 443

ENTRYPOINT ["/bootstrap.sh"]
