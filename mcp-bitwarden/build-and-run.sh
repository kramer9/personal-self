#!/bin/bash

# Build and run the Bitwarden MCP server with Podman

set -e

echo "🔧 Building Bitwarden MCP Server container..."

# Check if .env file exists
if [ ! -f .env ]; then
    echo "❌ .env file not found. Please copy .env.example to .env and fill in your BWS_ACCESS_TOKEN"
    exit 1
fi

# Build the container
podman build -t bitwarden-mcp-server .

echo "✅ Container built successfully!"

# Stop existing container if running
echo "🛑 Stopping existing container if running..."
podman stop bitwarden-mcp-server 2>/dev/null || true
podman rm bitwarden-mcp-server 2>/dev/null || true

# Load environment variables
source .env

# Run the container
echo "🚀 Starting Bitwarden MCP Server..."
podman run -d \
    --name bitwarden-mcp-server \
    -p 8080:8080 \
    -e BWS_ACCESS_TOKEN="$BWS_ACCESS_TOKEN" \
    --restart unless-stopped \
    bitwarden-mcp-server

# Wait a moment for startup
sleep 3

# Test the health endpoint
echo "🏥 Testing health endpoint..."
if curl -f http://localhost:8080/health &>/dev/null; then
    echo "✅ Server is healthy and running!"
    echo ""
    echo "📡 Server is available at: http://localhost:8080"
    echo "📖 API Documentation:"
    echo "   Health Check: GET  http://localhost:8080/health"
    echo "   Get Secret:   GET  http://localhost:8080/secret/{org_id}/{secret_key}"
    echo ""
    echo "🧪 Test with your data:"
    echo "   curl \"http://localhost:8080/secret/a45c69b8-28af-4a12-9c83-b3380121a0c2/test\""
else
    echo "❌ Server health check failed"
    echo "📋 Container logs:"
    podman logs bitwarden-mcp-server
    exit 1
fi