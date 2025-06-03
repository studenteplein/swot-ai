# MCP Executables Setup Guide

This guide documents the setup and troubleshooting of MCP (Model Context Protocol) server executables in Docker containers, based on our experience with the elasticsearch-cloud MCP server.

## Overview

MCP servers are external executables that extend LibreChat's capabilities. They run as separate processes and communicate via stdio (standard input/output) protocol.

## Architecture Requirements

### Critical: Binary Architecture Must Match Container Architecture

**Container Architecture**: `linux/amd64` (x86_64)
**Required Binary**: ELF 64-bit LSB executable, x86-64

### ❌ Common Mistake
```bash
# This will FAIL with "Unknown system error -8"
file elastic-mcp
# Output: Mach-O 64-bit executable arm64 (Apple Silicon binary)
```

### ✅ Correct Setup
```bash
# This will WORK
file elastic-mcp  
# Output: ELF 64-bit LSB executable, x86-64, version 1 (SYSV), dynamically linked
```

## File Structure

```
/app/
├── custom_mcp_servers/
│   └── elastic-mcp          # Your MCP executable (must be AMD64)
├── librechat.yaml           # Configuration file
└── api/                     # Application working directory
```

## Configuration

### 1. librechat.yaml Configuration

```yaml
mcpServers:
  elasticsearch-cloud:
    type: stdio
    command: /app/custom_mcp_servers/elastic-mcp  # Use ABSOLUTE path
    args:
      - "--host"
      - "0.0.0.0"
      - "--port" 
      - "3000"
    env:
      ELSER_MODEL: ".elser_model_2"
      ELASTIC_CLOUD_ID: "your-cloud-id"
      ELASTIC_API_KEY: "your-api-key"
      JWT_SECRET: "your-jwt-secret"
      MCP_API_KEY: "your-mcp-api-key"
```

**Important**: Use absolute paths (`/app/custom_mcp_servers/elastic-mcp`) not relative paths (`./custom_mcp_servers/elastic-mcp`) to avoid path resolution issues when the working directory is `/app/api`.

### 2. Dockerfile Configuration

```dockerfile
# Copy MCP servers to container
COPY custom_mcp_servers ./custom_mcp_servers

# Set executable permissions and ownership
RUN addgroup -g 1001 -S nodejs && adduser -S nextjs -u 1001 && \
    mkdir -p /app/api/logs && \
    chmod +x /app/custom_mcp_servers/elastic-mcp && \
    chown -R nextjs:nodejs /app
```

### 3. .dockerignore Configuration

```bash
# Make sure custom_mcp_servers is NOT excluded
# custom_mcp_servers/  # Comment out this line to include MCP servers
```

## Troubleshooting

### Error: `spawn ./custom_mcp_servers/elastic-mcp ENOENT`

**Cause**: File not found
**Solutions**:
1. Check `.dockerignore` - ensure `custom_mcp_servers/` is not excluded
2. Verify `COPY custom_mcp_servers ./custom_mcp_servers` is in Dockerfile
3. Use absolute path in `librechat.yaml`: `/app/custom_mcp_servers/elastic-mcp`

### Error: `spawn Unknown system error -8`

**Cause**: Architecture mismatch (ARM64 binary in AMD64 container)
**Solution**: Replace with AMD64 binary

```bash
# Check binary architecture
file custom_mcp_servers/elastic-mcp

# Should output:
# ELF 64-bit LSB executable, x86-64 ✅
# NOT: Mach-O 64-bit executable arm64 ❌
```

### Error: Permission denied

**Cause**: Executable permissions not set
**Solution**: 
```bash
# In Dockerfile
RUN chmod +x /app/custom_mcp_servers/elastic-mcp

# Or locally before building
chmod +x custom_mcp_servers/elastic-mcp
```

## Verification Steps

### 1. Check Binary Locally
```bash
file custom_mcp_servers/elastic-mcp
ls -la custom_mcp_servers/elastic-mcp
```

### 2. Verify in Container
```bash
# Check if file exists in container
docker run --rm your-image:tag ls -la /app/custom_mcp_servers/

# Check if executable
docker run --rm your-image:tag file /app/custom_mcp_servers/elastic-mcp
```

### 3. Test MCP Server Startup
Look for these log messages:
```
✅ Success:
[MCP] Initialized 1/1 app-level server(s)
[MCP][elasticsearch-cloud] ✓ Connected

❌ Failure:
[MCP][elasticsearch-cloud] Connection failed: spawn ...
[MCP] Initialized 0/1 app-level server(s)
```

## Build Process

### Development Build (with cache)
```bash
docker buildx build --platform linux/amd64 -f Dockerfile.multi -t your-image:tag --target production --load .
```

### Force Rebuild (when MCP server changes)
```bash
docker buildx build --platform linux/amd64 -f Dockerfile.multi -t your-image:tag --target production --load --no-cache .
```

### Quick Layer Invalidation (faster than --no-cache)
Change a comment in the Dockerfile near the COPY command:
```dockerfile
# Copy application code and built assets - Updated for MCP v2
COPY custom_mcp_servers ./custom_mcp_servers
```

## Best Practices

1. **Always use absolute paths** in `librechat.yaml` configuration
2. **Verify binary architecture** before building Docker image
3. **Set executable permissions** in Dockerfile
4. **Use proper ownership** (`chown -R nextjs:nodejs /app`)
5. **Test locally first** before deploying to production
6. **Keep MCP executables in version control** or document where to obtain them

## Environment Variables

MCP servers can access environment variables defined in the `env` section:

```yaml
env:
  ELSER_MODEL: ".elser_model_2"
  ELASTIC_CLOUD_ID: "${ELASTIC_CLOUD_ID}"  # Can reference Docker env vars
  ELASTIC_API_KEY: "${ELASTIC_API_KEY}"
```

## Security Notes

- MCP executables run with the same permissions as the main application
- Ensure executables are from trusted sources
- Consider using checksums to verify binary integrity
- Review environment variables for sensitive data

## Common MCP Server Types

- **Elasticsearch**: Search and indexing capabilities
- **Filesystem**: File system access and manipulation  
- **Puppeteer**: Web scraping and browser automation
- **Database**: Direct database query capabilities
- **Custom**: Application-specific business logic

---

*This guide was created based on real-world troubleshooting experience with SwotAI MCP server deployment.*