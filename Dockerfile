# Build stage
FROM alpine:latest AS builder

# Install Hugo extended
RUN apk add --no-cache \
    hugo \
    git

WORKDIR /src

# Copy the entire site
COPY . .

# Clone the theme since git submodules aren't copied
# Remove the empty submodule directory first
RUN rm -rf themes/PaperMod && \
    git clone --depth 1 https://github.com/adityatelange/hugo-PaperMod.git themes/PaperMod

# Build the Hugo site
RUN hugo --gc --minify

# Production stage
FROM nginx:alpine

# Copy the built site from builder
COPY --from=builder /src/public /usr/share/nginx/html

# Copy custom nginx config if needed
COPY <<EOF /etc/nginx/conf.d/default.conf
server {
    listen 80;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    # Enable gzip compression
    gzip on;
    gzip_vary on;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;

    # Cache static assets
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|woff|woff2|ttf|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
