# ------------ Build Stage ------------
FROM node:16.17.0-alpine AS builder
WORKDIR /app

# Copy only manifest first for better layer caching
COPY package.json ./

# Install deps without requiring a yarn.lock
# (If you later add yarn.lock, switch to: `COPY package.json yarn.lock ./` then `RUN yarn install --frozen-lockfile`)
RUN yarn install --no-lockfile

# Copy the rest of the source code
COPY . .

# Build-time vars for Vite (baked into bundle)
ARG TMDB_V3_API_KEY
ENV VITE_APP_TMDB_V3_API_KEY=${TMDB_V3_API_KEY}
ENV VITE_APP_API_ENDPOINT_URL="https://api.themoviedb.org/3"

# Build production bundle
RUN yarn build

# ------------ Runtime Stage ------------
FROM nginx:stable-alpine

# Minimal, SPA-friendly nginx config with caching for static assets
RUN printf '%s\n' \
  'server {' \
  '  listen 80;' \
  '  server_name _;' \
  '  root /usr/share/nginx/html;' \
  '  index index.html;' \
  '' \
  '  # Try direct file; fallback to index.html (SPA routing)' \
  '  location / {' \
  '    try_files $uri $uri/ /index.html;' \
  '  }' \
  '' \
  '  # Cache static assets aggressively (adjust as needed)' \
  '  location ~* \.(?:js|mjs|css|png|jpg|jpeg|gif|svg|ico|woff2?)$ {' \
  '    add_header Cache-Control "public, max-age=31536000, immutable";' \
  '    try_files $uri =404;' \
  '  }' \
  '' \
  '  # Basic gzip (nginx:alpine has gzip module by default)' \
  '  gzip on;' \
  '  gzip_types text/plain text/css application/json application/javascript application/xml+rss image/svg+xml;' \
  '  gzip_min_length 1024;' \
  '}' > /etc/nginx/conf.d/default.conf

# Copy built assets
COPY --from=builder /app/dist /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
