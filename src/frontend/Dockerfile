FROM node:24-alpine AS build

ARG NPM_CONFIG_REGISTRY=https://registry.npmjs.org

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build

FROM nginx:1.29-alpine

COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf.template /etc/nginx/support-desk.conf.template
COPY docker-entrypoint.sh /docker-entrypoint.d/40-support-desk.sh

RUN apk add --no-cache ca-certificates \
    && chmod +x /docker-entrypoint.d/40-support-desk.sh

EXPOSE 80
