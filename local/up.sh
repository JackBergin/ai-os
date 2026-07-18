#!/usr/bin/env bash
# Start the ai-os local stack on Ubuntu or macOS (Docker only — no Nix).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

# Keep in sync with flake.lock → nodes.odysseus.locked.rev
ODYSSEUS_REPO="${ODYSSEUS_REPO:-https://github.com/pewdiepie-archdaemon/odysseus.git}"
ODYSSEUS_REV="${ODYSSEUS_REV:-dc3530b8fa817dfc87f5e32920b0bfcfb27ea017}"

if ! command -v docker >/dev/null 2>&1; then
  echo "error: docker not found. Install Docker Engine (Ubuntu) or Docker Desktop (macOS)." >&2
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "error: 'docker compose' unavailable. Install Docker Compose v2." >&2
  exit 1
fi

if [ ! -f .env ]; then
  cp .env.example .env
  echo "created .env from .env.example — edit ODYSSEUS_ADMIN_PASSWORD before production use."
fi

if [ ! -d odysseus/.git ]; then
  echo "cloning Odysseus @ ${ODYSSEUS_REV}..."
  rm -rf odysseus
  git clone --filter=blob:none "$ODYSSEUS_REPO" odysseus
  git -C odysseus checkout "$ODYSSEUS_REV"
elif [ "$(git -C odysseus rev-parse HEAD)" != "$ODYSSEUS_REV" ]; then
  echo "updating Odysseus to ${ODYSSEUS_REV}..."
  git -C odysseus fetch --depth 1 origin "$ODYSSEUS_REV"
  git -C odysseus checkout "$ODYSSEUS_REV"
fi

mkdir -p odysseus-data odysseus-logs

# Merge upstream Odysseus compose with our ollama/open-webui + searxng remap.
# --project-directory keeps .env paths (APP_DATA_DIR, etc.) relative to local/.
compose=(
  docker compose
  --project-directory "$ROOT"
  --env-file "$ROOT/.env"
  -p ai-os
  -f "$ROOT/odysseus/docker-compose.yml"
  -f "$ROOT/docker-compose.yml"
)

cmd="${1:-up}"
shift || true

case "$cmd" in
  up)
    exec "${compose[@]}" up -d --build "$@"
    ;;
  down)
    exec "${compose[@]}" down "$@"
    ;;
  logs)
    exec "${compose[@]}" logs -f "$@"
    ;;
  pull)
    exec "${compose[@]}" pull "$@"
    ;;
  *)
    exec "${compose[@]}" "$cmd" "$@"
    ;;
esac
