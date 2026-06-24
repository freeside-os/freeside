# Freeside Wintermute packaging agent orchestrations
set dotenv-load := false
set working-directory := ".."

# Run wintermute interactive command line interface (or with optional query)
run query="":
    cd wintermute && mkdir -p .adk && uv run adk run app {{ if query == "" { "" } else { quote(query) } }} \
        --session_service_uri "sqlite:///$(pwd)/.adk/session.db" \
        --artifact_service_uri "file:///$(pwd)/.adk/artifacts"

# Start the local ADK Web UI
web:
    cd wintermute && mkdir -p .adk && uv run adk web app \
        --session_service_uri "sqlite:///$(pwd)/.adk/session.db" \
        --artifact_service_uri "file:///$(pwd)/.adk/artifacts" \
        2>&1 | tee .adk/server.log

# Run wintermute tests
tests:
    cd wintermute && uv run pytest
