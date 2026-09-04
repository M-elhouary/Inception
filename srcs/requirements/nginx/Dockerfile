FROM debian:bookworm

RUN apt-get update && apt-get install -y \
    nginx \
    openssl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /etc/nginx/ssl

RUN openssl req \
    -x509 \
    -nodes \
    -days 365 \
    -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/inception.key \
    -out /etc/nginx/ssl/inception.crt \
    -subj "/C=MA/ST=Morocco/L=Khouribga/O=42/OU=Inception/CN=localhost"

COPY conf/nginx.conf /etc/nginx/nginx.conf

RUN nginx -t

CMD ["nginx", "-g", "daemon off;"]