# Multi-stage build for optimized image size
FROM node:18-alpine AS builder

# Application version - Change this to update the version
ARG APP_VERSION=2.0.1

# Set working directory
WORKDIR /app

# Clone the node-hostname application
RUN apk add --no-cache git && \
    git clone https://github.com/cristiklein/node-hostname.git . && \
    npm ci --only=production && \
    apk del git

# Production stage
FROM node:18-alpine

# Application version - Must match builder stage
ARG APP_VERSION=2.0.1

# Add metadata
LABEL maintainer="vagner.samm@gmail.com"
LABEL description="Node Hostname - Container testing application"
LABEL version="${APP_VERSION}"

# Environment variables
ENV APP_VERSION=${APP_VERSION}
ENV npm_package_version=${APP_VERSION}
ENV PORT=8080

# Create non-root user for security
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

WORKDIR /app

# Copy application from builder
COPY --from=builder --chown=nodejs:nodejs /app /app

# Switch to non-root user
USER nodejs

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD node -e "require('http').get('http://localhost:8080', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Start application
CMD ["node", "./bin/www"]
