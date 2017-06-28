**Master**
[![Build Status](https://travis-ci.org/mlerczak/haproxy-letsencrypt.svg?branch=master)](https://travis-ci.org/mlerczak/haproxy-letsencrypt)

**Dev**
[![Dev Build Status](https://travis-ci.org/mlerczak/haproxy-letsencrypt.svg?branch=dev)](https://travis-ci.org/mlerczak/haproxy-letsencrypt)



HAProxy docker container based on [million12/haproxy](https://registry.hub.docker.com/u/million12/haproxy/) and [bradjonesllc/docker-haproxy-letsencrypt](https://hub.docker.com/r/bradjonesllc/docker-haproxy-letsencrypt/) 

**Software:**

`HAProxy 1.7.7`
`OpenSSL 1.1.0f`

**Docker compose example:**

```bash
version: "2"
services:
  app:
    image: mlerczak/haproxy-letsencrypt:latest
    volumes:
      - ./haproxy.cfg:/etc/haproxy/haproxy.cfg
    ports:
      - 80:80
      - 443:443
    environment:
      - GENERATE_SSL=1
      - CERTS=5ki.pl,www.5ki.pl
      - EMAIL=mateusz.lerczak@5ki.pl
```

**Docker Swarm example**
```bash
version: "3"
services:
  app:
    image: mlerczak/haproxy-letsencrypt:latest
    volumes:
      - ./haproxy.cfg:/etc/haproxy/haproxy.cfg
    ports:
      - 80:80
      - 443:443
    environment:
      - GENERATE_SSL=1
      - CERTS=5ki.pl,www.5ki.pl
      - EMAIL=mateusz.lerczak@5ki.pl
    deploy:
      mode: global
networks:
    default:
        external:
            name: SWARM_network
```
**SSL Generation**
To generate SSL go into container and run `generateCertsForHAProxy`

```bash
docker exec -it HAPROXY_app.i69nbm4r9yn7mjd391s7tnizs.i81ux4tx4spm97ajx845vwvsb bash

[root@5b5ba38dcd70 ~]# generateCertsForHAProxy 
Saving debug log to /var/log/letsencrypt/letsencrypt.log
Starting new HTTPS connection (1): acme-v01.api.letsencrypt.org
Obtaining a new certificate
Performing the following challenges:
http-01 challenge for 5ki.pl
http-01 challenge for www.5ki.pl
Using the webroot path /var/lib/haproxy for all unmatched domains.
Waiting for verification...
Cleaning up challenges
Unable to clean up challenge directory /var/lib/haproxy/.well-known/acme-challenge

IMPORTANT NOTES:
 - Congratulations! Your certificate and chain have been saved at
   /etc/letsencrypt/live/m2.b-testing.dk/fullchain.pem. Your cert will
   expire on 2017-09-26. To obtain a new or tweaked version of this
   certificate in the future, simply run certbot again. To
   non-interactively renew *all* of your certificates, run "certbot
   renew"
 - Your account credentials have been saved in your Certbot
   configuration directory at /etc/letsencrypt. You should make a
   secure backup of this folder now. This configuration directory will
   also contain certificates and private keys obtained by Certbot so
   making regular backups of this folder is ideal.
 - If you like Certbot, please consider supporting our work by:

   Donating to ISRG / Let's Encrypt:   https://letsencrypt.org/donate
   Donating to EFF:                    https://eff.org/donate-le

[root@5b5ba38dcd70 ~]#
```

HAProxy cfg example

```bash
global
    chroot /var/lib/haproxy
    user haproxy
    group haproxy
    pidfile /var/run/haproxy.pid

    lua-load /etc/haproxy/acme-http01-webroot.lua

    ssl-default-bind-options   no-sslv3 no-tls-tickets force-tlsv12
    ssl-default-bind-ciphers   ECDH+AESGCM:DH+AESGCM:ECDH+AES256:DH+AES256:ECDH+AES128:DH+AES:ECDH+3DES:DH+3DES:RSA+AESGCM:RSA+AES:RSA+3DES:!aNULL:!MD5:!DSS

    spread-checks 4
    tune.maxrewrite 1024
    tune.ssl.default-dh-param 2048

defaults
    mode    http
    balance roundrobin

    option  dontlognull
    option  dontlog-normal
    option  redispatch

    maxconn 5000
    timeout connect 5s
    timeout client  20s
    timeout server  20s
    timeout queue   30s
    timeout http-request 5s
    timeout http-keep-alive 15s

frontend http-in
    bind *:80

    option http-server-close
    option forwardfor

    acl url_acme_http01 path_beg /.well-known/acme-challenge/
    http-request use-service lua.acme-http01 if METH_GET url_acme_http01

    stats enable
    stats refresh 30s
    stats hide-version
    stats realm Strictly\ Private
    stats auth admin:ThisIsSparta
    stats uri /admin?stats

    acl is_www hdr(host) -i www.5ki.pl
    use_backend www if is_www

frontend https-in
    bind *:443 ssl crt /etc/haproxy/certs/ alpn h2c,http/1.1

    option forwardfor

    http-response set-header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload;"
    http-request set-header X-Forwarded-Proto https if  { ssl_fc }
    http-request set-header X-Forwarded-Proto http  if !{ ssl_fc }

#    acl is_www hdr(host) -i www.5ki.pl
#    use_backend www if is_www

frontend https-http2-in
    mode tcp
    bind *:443 ssl crt /etc/haproxy/certs/ alpn h2,http/1.1

    option tcpka

    acl speak_alpn_h2 ssl_fc_alpn -i h2
    acl is_www_ssl ssl_fc_sni_end -i www.5ki.pl
    use_backend www-http2 if speak_alpn_h2 is_www_ssl

backend www
    server www WWW_app:80 cookie check send-proxy

backend www-http2
    mode tcp

    stick-table type binary len 32 size 30k expire 30m
    acl clienthello req_ssl_hello_type 1
    acl serverhello rep_ssl_hello_type 2
    tcp-request inspect-delay 5s
    tcp-request content accept if clienthello
    tcp-response content accept if serverhello
    stick on payload_lv(43,1) if clienthello
    stick store-response payload_lv(43,1) if serverhello

    server www-http2 WWW_app:443 check send-proxy
```