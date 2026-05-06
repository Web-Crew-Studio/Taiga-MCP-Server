# WebCrewStudio Taiga MCP

Production-ready Docker setup for running a Taiga MCP server for AI coding agents such as Codex, Claude Code, Cursor and other MCP-compatible tools.

## Features

- Dockerized deployment
- Taiga API integration
- MCP-compatible server
- Reverse proxy support
- HTTPS-ready
- Lightweight VPS deployment
- Compatible with Codex and Claude Code workflows

## Stack

- Docker
- Docker Compose
- Taiga API
- MCP Server
- Nginx (optional)

---

## Quick Start

### Clone repository

```bash
git clone https://github.com/WebCrewStudio/webcrewstudio-taiga-mcp.git

cd webcrewstudio-taiga-mcp
```

---

## Repository Structure

```text
.
├── docker-compose.yml
├── Dockerfile
├── .env.example
├── .gitignore
├── README.md
├── LICENSE
├── docker/
│   └── patch_upstream.py
├── nginx/
│   └── taiga-mcp.conf
└── docs/
    └── codex-example-config.md
```

---

# VPS Deployment Guide

## Requirements

Recommended VPS stack:

- Ubuntu 22.04 LTS
- 1 vCPU
- 1 GB RAM
- Docker
- Docker Compose
- Optional domain name
- Optional Nginx reverse proxy

---

# Step 1 — Install Docker

Update packages:

```bash
sudo apt update
sudo apt upgrade -y
```

Install Docker:

```bash
curl -fsSL https://get.docker.com | sh
```

Add current user to docker group:

```bash
sudo usermod -aG docker $USER
```

Reconnect SSH session after this step.

---

# Step 2 — Install Docker Compose

Check if Docker Compose is already available:

```bash
docker compose version
```

If missing:

```bash
sudo apt install docker-compose-plugin -y
```

---

# Step 3 — Taiga Authentication

This setup uses the standard Taiga cloud authentication flow described in the official Taiga API documentation.

Taiga cloud has two relevant hosts:

```text
https://tree.taiga.io  - Taiga web UI
https://api.taiga.io   - Taiga API
```

Use `https://tree.taiga.io` in your browser. Configure the MCP server with the API host, `https://api.taiga.io`; the Python client calls `/api/v1/...` paths internally.

For Taiga cloud, Taiga does not provide permanent API keys or application tokens.

Instead, the MCP server authenticates using your Taiga username and password and internally obtains an auth token.

Official documentation:

```text
https://docs.taiga.io/api.html#_authentication
```

NOTE:
Application token authentication is only available for self-hosted Taiga instances and is not supported on `tree.taiga.io`.

---

# Step 4 — Configure Environment

Create environment file:

```bash
cp .env.example .env
```

Edit `.env`:

```env
TAIGA_API_URL=https://api.taiga.io
TAIGA_USERNAME=your_email@example.com
TAIGA_PASSWORD=your_taiga_password

MCP_PUBLIC_HOST=taiga-mcp.example.com
MCP_PUBLIC_ORIGIN=https://taiga-mcp.example.com
```

`TAIGA_TOKEN` is not used for Taiga cloud. Application token authentication is only relevant for self-hosted Taiga instances that explicitly support it.

Do not commit real domains or credentials. Use placeholders in the repository:

```env
MCP_PUBLIC_HOST=taiga-mcp.example.com
MCP_PUBLIC_ORIGIN=https://taiga-mcp.example.com
```

On your VPS, put the real values only in `.env`:

```env
MCP_PUBLIC_HOST=your-real-subdomain.example.com
MCP_PUBLIC_ORIGIN=https://your-real-subdomain.example.com
```

`MCP_PUBLIC_HOST` and `MCP_PUBLIC_ORIGIN` are added to FastMCP's DNS rebinding allowlist. Without matching values, FastMCP can reject external requests with `421 Invalid Host header`.

---

# Step 5 — Start MCP Server

This repository builds a WebCrewStudio-owned Docker image from the upstream Taiga MCP image and applies a small runtime patch:

- starts FastMCP with `streamable-http` transport instead of stdio
- binds the MCP app to `0.0.0.0:8080` inside the container
- adds `MCP_PUBLIC_HOST` and `MCP_PUBLIC_ORIGIN` to FastMCP DNS rebinding protection
- preserves the environment-authenticated default Taiga session across streamable HTTP transport cleanup

Build the image:

```bash
docker compose build
```

On Apple Silicon, build the amd64 image explicitly:

```bash
DOCKER_DEFAULT_PLATFORM=linux/amd64 docker compose build
```

Start the server:

```bash
docker compose up -d
```

Check running containers:

```bash
docker ps
```

Check logs:

```bash
docker logs -f taiga-mcp
```

Successful username/password auto-authentication includes log lines similar to:

```text
Login successful. Auth token acquired.
Auto-authentication successful. Default session created: 'default'
```

---

# Optional — Publish Docker Image

After testing, publish the owned image to GHCR:

```bash
docker login ghcr.io
docker compose build
docker push ghcr.io/webcrewstudio/taiga-mcp:latest
```

On the VPS you can then deploy either by building from this repository or by pulling the published image. If you want pull-only deployment, remove the `build` block from `docker-compose.yml` on the server and keep:

```yaml
image: ghcr.io/webcrewstudio/taiga-mcp:latest
```

---

# Step 6 — Verify Server

The Docker Compose service starts FastMCP with streamable HTTP transport. The MCP endpoint is `/mcp`.

In production, Docker binds only to localhost:

```text
127.0.0.1:8087:8080
```

Expose HTTPS through Nginx:

```text
https://your-real-subdomain.example.com/mcp
  ->
http://127.0.0.1:8087/mcp
```

Test the local upstream endpoint on the VPS with a minimal MCP initialize request:

```bash
curl -i -X POST http://localhost:8087/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"curl","version":"0.0.1"}}}'
```

A successful response returns `200 OK` with a JSON-RPC initialize result. A plain `curl http://localhost:8087`, a GET without an MCP session, or a request without MCP headers can return `404 Not Found`, `400 Bad Request`, or `406 Not Acceptable` depending on the request.

---

# Optional — Configure Nginx Reverse Proxy

Install Nginx:

```bash
sudo apt install nginx -y
```

Copy config:

```bash
sudo cp nginx/taiga-mcp.conf /etc/nginx/sites-available/taiga-mcp
```

Enable site:

```bash
sudo ln -s /etc/nginx/sites-available/taiga-mcp /etc/nginx/sites-enabled/
```

Test config:

```bash
sudo nginx -t
```

Restart Nginx:

```bash
sudo systemctl restart nginx
```

---

# Optional — Enable HTTPS

Install Certbot:

```bash
sudo apt install certbot python3-certbot-nginx -y
```

Generate SSL certificate:

```bash
sudo certbot --nginx
```

---

# Firewall Example

Recommended UFW configuration:

```bash
sudo ufw allow 80
sudo ufw allow 443
sudo ufw deny 8087
```

---

# Codex MCP Configuration Example

```json
{
  "mcpServers": {
    "taiga": {
      "url": "https://taiga-mcp.example.com/mcp"
    }
  }
}
```

---

# Example Workflow

Once connected, Codex can:

- Read sprint tasks
- Read task descriptions
- Read acceptance criteria
- Update task statuses
- Add comments
- Create subtasks

Example prompt:

```text
Implement TASK-007 from current sprint backlog.
```

---

# Security Notes

- Never commit `.env`
- Never expose real Taiga credentials
- Never commit real production domains
- Prefer HTTPS reverse proxy
- Restrict public access where possible
- Keep FastMCP DNS rebinding protection enabled and configure `MCP_PUBLIC_HOST` / `MCP_PUBLIC_ORIGIN` for the public hostname clients use

---

# Authentication Notes

This repository is currently designed for Taiga cloud authentication using the standard username/password login flow.

Authentication flow:

```text
username/password -> auth token -> MCP requests
```

For self-hosted Taiga installations you may additionally configure application-token-based authentication if supported by your instance.

---

# License

MIT
