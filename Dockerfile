# Build stage
FROM alpine:3.21 AS builder

# Install Hugo extended from GitHub releases (newer than Alpine package)
ARG HUGO_VERSION=0.146.0
RUN apk add --no-cache git curl && \
    curl -L "https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_linux-amd64.tar.gz" | tar -xz -C /usr/local/bin hugo

WORKDIR /src

# Copy the entire site
COPY . .

# Clone the theme since git submodules aren't copied
RUN rm -rf themes/PaperMod && \
    git clone --depth 1 https://github.com/adityatelange/hugo-PaperMod.git themes/PaperMod

# Build the Hugo site
RUN hugo --gc --minify

# Production stage
FROM nginx:1.27-alpine

# Copy the built site from builder
COPY --from=builder /src/public /usr/share/nginx/html

# Nginx config
COPY <<EOF /etc/nginx/conf.d/default.conf
server {
    listen 80;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1000;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json image/svg+xml;

    # Cache static assets
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|woff|woff2|ttf|svg|webp)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Cache HTML with revalidation
    location ~* \.html$ {
        expires 1h;
        add_header Cache-Control "public, must-revalidate";
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
}
EOF

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
