# Stage 1: Build the Node.js application
FROM node:18-alpine as build
WORKDIR /app
RUN apk add --no-cache openssh git


COPY package*.json ./

RUN npm install


COPY . .


RUN npm run build

RUN npm prune --production


# Stage 2: Build the oauth2-proxy
FROM golang:latest as go
RUN go install -v github.com/oauth2-proxy/oauth2-proxy/v7@latest


# Stage 3: Create the final, small production image
FROM node:18-alpine
# https://stackoverflow.com/questions/66963068/docker-alpine-executable-binary-not-found-even-if-in-path
RUN apk add --no-cache libc6-compat curl
ARG BUILD_VERSION
ARG LOG_LEVEL=info
ARG LOG_LABEL=bull-monitor
ARG ALTERNATE_PORT=8081
ARG PORT=3000
ARG OAUTH2_PROXY_SKIP_AUTH_ROUTES='/metrics,/health,/docs'
WORKDIR /app

# Copy the oauth2-proxy binary from the 'go' stage
COPY --from=go /go/bin/oauth2-proxy ./

# Copy the entire built application (node_modules + dist folder) from the 'build' stage
COPY --from=build /app ./

# Copy the entrypoint script
COPY docker-entrypoint.sh .

ENV NODE_ENV="production" \
    ALTERNATE_PORT=$ALTERNATE_PORT \
    PORT=$PORT \
    LOG_LEVEL=$LOG_LEVEL \
    LOG_LABEL=$LOG_LABEL \
    OAUTH2_PROXY_SKIP_AUTH_ROUTES=$OAUTH2_PROXY_SKIP_AUTH_ROUTES \
    VERSION=$BUILD_VERSION

EXPOSE 3000
HEALTHCHECK --interval=15s --timeout=30s --start-period=5s --retries=3 CMD curl --fail http://localhost:3000/health || exit 1
ENTRYPOINT ["sh", "docker-entrypoint.sh"]