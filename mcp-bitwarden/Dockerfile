# Build stage: use official Rust Alpine image
FROM rust:alpine AS builder

# Install musl dev, openssl-dev, build-base, pkgconfig for building native libs
RUN apk add --no-cache musl-dev openssl-dev build-base pkgconf

WORKDIR /usr/src/app

# Add musl target (rustup is part of the rust:alpine image)
RUN rustup target add x86_64-unknown-linux-musl

# Copy Cargo files and create dummy main.rs for dependencies caching
COPY Cargo.toml Cargo.lock ./
RUN mkdir -p src && echo "fn main() {}" > src/main.rs
RUN cargo build --release
# Multi-stage build for efficient container
FROM rust:1.75 AS builder

# Create app directory
WORKDIR /app

# Copy manifests
COPY Cargo.toml Cargo.lock ./

# Copy source code
COPY src ./src

# Build for release
RUN cargo build --release

# Runtime stage - use Ubuntu for bws CLI compatibility
FROM ubuntu:22.04

# Install required packages
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Install bws CLI
RUN curl -L "https://github.com/bitwarden/sdk/releases/latest/download/bws-x86_64-unknown-linux-gnu.zip" -o bws.zip \
    && unzip bws.zip \
    && chmod +x bws \
    && mv bws /usr/local/bin/ \
    && rm bws.zip

# Copy the built binary from builder stage
COPY --from=builder /app/target/release/bitwarden-mcp-server /usr/local/bin/bitwarden-mcp-server

# Create non-root user for security
RUN useradd -r -s /bin/false -m bitwarden

# Switch to non-root user
USER bitwarden

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Set default environment variables
ENV RUST_LOG=info

# Run the server
CMD ["bitwarden-mcp-server"]
# Copy source code
COPY . .

# Build static binary for musl target
RUN cargo build --release --target x86_64-unknown-linux-musl

# Runtime stage: minimal Debian image with certificates for HTTPS
FROM debian:bullseye-slim

RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/src/app/target/x86_64-unknown-linux-musl/release/mcp-bitwarden /usr/local/bin/mcp-bitwarden

EXPOSE 8080

ENTRYPOINT ["mcp-bitwarden"]
