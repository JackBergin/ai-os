# Odysseus: self-hosted AI workspace (chat, agents, deep research, documents,
# email, notes, calendar) sitting alongside Open WebUI. Upstream ships a
# docker compose stack (odysseus + chromadb + searxng + ntfy) built from
# source, so rather than repackage every service for NixOS we run that stack
# declaratively via a systemd unit and point it at the host's Ollama.
#
# `inputs.odysseus` is the pinned upstream source tree (see flake.nix).
{ config, pkgs, lib, inputs, ... }:

let
  # Immutable upstream source from the flake input.
  odysseusSrc = inputs.odysseus;

  # Writable working copy + persistent data live here. The Nix store is
  # read-only, but `docker compose build` and the app's SQLite/data dirs need
  # to write, so we rsync the source into a mutable state dir on each start.
  stateDir = "/var/lib/odysseus";

  # LAN-facing port for the Odysseus web UI (mirrors webui.nix on :8080).
  port = 7000;

  # Compose v2 as a standalone binary; exposes the `docker-compose` command.
  compose = "${pkgs.docker-compose}/bin/docker-compose";
in
{
  # Container runtime for the compose stack. Pin docker_29 — the default
  # docker package on this nixpkgs pin (docker_28) is flagged insecure.
  virtualisation.docker.enable = true;
  virtualisation.docker.package = pkgs.docker_29;

  systemd.services.odysseus = {
    description = "Odysseus self-hosted AI workspace (docker compose stack)";

    after = [ "docker.service" "network-online.target" "ollama.service" ];
    requires = [ "docker.service" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    path = with pkgs; [ docker_29 docker-compose rsync coreutils gnugrep ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      # First run builds the Odysseus image and pulls chromadb/searxng/ntfy;
      # give it plenty of headroom.
      TimeoutStartSec = "3600";
    };

    script = ''
      set -euo pipefail

      mkdir -p ${stateDir}/src ${stateDir}/data ${stateDir}/logs

      # Refresh the working copy from the pinned source, but never clobber the
      # generated .env or the persistent data/logs directories.
      rsync -a --delete \
        --exclude='.env' \
        --exclude='data' \
        --exclude='logs' \
        ${odysseusSrc}/ ${stateDir}/src/

      cd ${stateDir}/src

      # Persist a generated admin password across rebuilds.
      if [ ! -s ${stateDir}/admin_password ]; then
        head -c 24 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 24 \
          > ${stateDir}/admin_password
      fi
      ADMIN_PW="$(cat ${stateDir}/admin_password)"

      # Declaratively render the compose env. Odysseus reaches the host's
      # Ollama (modules/inference.nix, :11434) via the host-gateway alias the
      # compose file already wires up as host.docker.internal.
      cat > .env <<EOF
      APP_BIND=0.0.0.0
      APP_PORT=${toString port}
      APP_DATA_DIR=${stateDir}/data
      APP_LOGS_DIR=${stateDir}/logs
      OLLAMA_BASE_URL=http://host.docker.internal:11434
      LLM_HOST=host.docker.internal
      AUTH_ENABLED=true
      ODYSSEUS_ADMIN_USER=admin
      ODYSSEUS_ADMIN_PASSWORD=$ADMIN_PW
      PUID=0
      PGID=0
      EOF

      ${compose} up -d --build --remove-orphans
    '';

    preStop = ''
      cd ${stateDir}/src && ${compose} down
    '';
  };

  networking.firewall.allowedTCPPorts = [ port ];
}
