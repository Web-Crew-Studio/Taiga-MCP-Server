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
├── .env.example
├── .gitignore
├── README.md
├── LICENSE
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

For:

```text
https://tree.taiga.io
```

Taiga does not provide permanent API keys or application tokens.

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
TAIGA_URL=https://tree.taiga.io
TAIGA_USERNAME=your_email@example.com
TAIGA_PASSWORD=your_taiga_password
```

---

# Step 5 — Start MCP Server

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

---

# Step 6 — Verify Server

Test local endpoint:

```bash
curl http://localhost:8087
```

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
      "url": "https://taiga-mcp.yourdomain.com"
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
- Prefer HTTPS reverse proxy
- Restrict public access where possible
- Use API token authentication instead of username/password

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