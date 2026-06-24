# Freeside Wintermute packaging agent orchestrations
set dotenv-load := false
set working-directory := ".."

# Run wintermute interactive command line interface (or with optional query)
run query="":
    cd wintermute && uv run adk run app {{ if query == "" { "" } else { quote(query) } }} \
        --session_service_uri "wintersession://" \
        --artifact_service_uri "winterartifact://"

# Start the local ADK Web UI
web:
    cd wintermute && uv run adk web app \
        --session_service_uri "wintersession://" \
        --artifact_service_uri "winterartifact://" \
        2>&1 | tee .adk/server.log

# Run wintermute tests
tests:
    cd wintermute && uv run pytest
