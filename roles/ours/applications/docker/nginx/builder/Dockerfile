# First stage: Generate the certificate
FROM nginx:latest AS builder

RUN openssl req -x509 -nodes -days 3650 -subj "/CN=*.statox.fr" -newkey rsa:2048 -keyout /nginx-selfsigned.key -out /nginx-selfsigned.crt

# Second stage: Copy the certificate to the final image
FROM nginx:latest

COPY --from=builder /nginx-selfsigned.crt /etc/nginx/ssl/nginx-selfsigned.crt
COPY --from=builder /nginx-selfsigned.key /etc/nginx/ssl/nginx-selfsigned.key
