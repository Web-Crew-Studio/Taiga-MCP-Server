from pathlib import Path


SERVER_PATH = Path("/app/src/server.py")


def replace_once(source: str, old: str, new: str) -> str:
    if old not in source:
        raise RuntimeError(f"Expected source block not found:\n{old}")
    return source.replace(old, new, 1)


source = SERVER_PATH.read_text()

source = replace_once(
    source,
    "import logging.config\n",
    "import logging.config\nimport os\n",
)

source = replace_once(
    source,
    """    finally:
        # Cleanup on shutdown
        logger.info("Server shutting down. Cleaning up sessions...")
        active_sessions.clear()
""",
    """    finally:
        # Streamable HTTP creates and tears down MCP transports independently of the
        # container process. Keep the environment-authenticated default session alive
        # so later tool calls can continue to use it.
        logger.info("Server transport shutting down. Cleaning up non-default sessions...")
        default_session = active_sessions.get(DEFAULT_SESSION_ID)
        active_sessions.clear()
        if default_session is not None:
            active_sessions[DEFAULT_SESSION_ID] = default_session
""",
)

source = replace_once(
    source,
    """# --- Run the server ---
if __name__ == "__main__":
    mcp.run()
""",
    """# --- Run the server ---
if __name__ == "__main__":
    public_host = os.environ.get("MCP_PUBLIC_HOST", "localhost")
    public_origin = os.environ.get("MCP_PUBLIC_ORIGIN", "http://localhost")

    mcp.settings.host = os.environ.get("MCP_HOST", "0.0.0.0")
    mcp.settings.port = int(os.environ.get("MCP_PORT", "8080"))

    if public_host:
        mcp.settings.transport_security.allowed_hosts += [
            public_host,
            public_host + ":443",
            public_host + ":*",
        ]
    if public_origin:
        mcp.settings.transport_security.allowed_origins += [public_origin]

    mcp.run(transport=os.environ.get("MCP_TRANSPORT", "streamable-http"))
""",
)

SERVER_PATH.write_text(source)
