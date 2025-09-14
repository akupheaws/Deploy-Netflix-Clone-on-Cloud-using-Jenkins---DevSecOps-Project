# ------------ Build Stage ------------
FROM node:16.17.0-alpine AS builder
WORKDIR /app

# Install dependencies
COPY package.json ./
RUN yarn install --no-lockfile

# Copy source
COPY . .

# Build-time variables
ARG TMDB_V3_API_KEY
ENV VITE_APP_TMDB_V3_API_KEY=${TMDB_V3_API_KEY}
ENV VITE_APP_API_ENDPOINT_URL="https://api.themoviedb.org/3"

# Skip tsc and just build assets with Vite
RUN npx vite build

# ------------ Runtime Stage ------------
FROM nginx:stable-alpine

# Nginx config for SPA
RUN printf '%s\n' \
  'server {' \
  '  listen 80;' \
  '  server_name _;' \
  '  root /usr/share/nginx/html;' \
  '  index index.html;' \
  '  location / { try_files $uri $uri/ /index.html; }' \
  '  location ~* \.(?:js|mjs|css|png|jpg|jpeg|gif|svg|ico|woff2?)$ { add_header Cache-Control "public, max-age=31536000, immutable"; try_files $uri =404; }' \
  '  gzip on;' \
  '  gzip_types text/plain text/css application/json application/javascript application/xml+rss image/svg+xml;' \
  '  gzip_min_length 1024;' \
  '}' > /etc/nginx/conf.d/default.conf

# Copy build artifacts
COPY --from=builder /app/dist /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
