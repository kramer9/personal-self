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
