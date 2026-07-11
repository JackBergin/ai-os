# Hermes Agent (Nous Research): autonomous AI agent with persistent memory,
# self-authored skills, cron automations, and a multi-platform messaging
# gateway (Telegram/Discord/Slack/...). Upstream ships a first-class Nix flake
# with a NixOS module (services.hermes-agent), so unlike Odysseus we consume
# that directly instead of wrapping a compose stack.
#
# `inputs.hermes-agent` is the pinned upstream flake (see flake.nix).
#
# What this module wires up:
#   - the gateway as a hardened native systemd service (state in /var/lib/hermes)
#   - chat via this box's Ollama (modules/inference.nix, :11434)
#   - Hermes' OpenAI-compatible API server on :8642 for LAN clients
#   - the `hermes` CLI on the system PATH, sharing state with the gateway
#
# Messaging platforms activate when their tokens appear in the env — drop
# e.g. TELEGRAM_BOT_TOKEN=... into /var/lib/hermes/secrets.env and
# `systemctl restart hermes-agent`.
{ config, pkgs, lib, inputs, ... }:

let
  # LAN-facing port for the OpenAI-compatible API server (mirrors webui.nix
  # :8080 and odysseus.nix :7000). 8642 is the Hermes upstream default.
  apiPort = 8642;

  # Upstream module default; gateway state lives in $stateDir/.hermes.
  stateDir = "/var/lib/hermes";
in
{
  imports = [ inputs.hermes-agent.nixosModules.default ];

  services.hermes-agent = {
    enable = true;

    # The flake's `default` package pre-builds every optional integration
    # (~700 MB closure). `messaging` is the minimal core plus the
    # Discord/Telegram/Slack libraries (~33 MB extra) — the right size for
    # this appliance until we need voice/TTS/etc.
    package = inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.messaging;

    # Rendered declaratively into $HERMES_HOME/config.yaml. Nix-set keys win;
    # keys added at runtime (by the agent or manual edits) are preserved.
    settings = {
      model = {
        # "ollama" is an upstream alias for "custom": any OpenAI-compatible
        # endpoint. Ollama serves one at /v1 and ignores the API key, but the
        # client requires a non-empty value.
        provider = "ollama";
        base_url = "http://127.0.0.1:11434/v1";
        api_key = "ollama";
        default = "llama3.2:3b";
      };
      terminal = { backend = "local"; timeout = 180; };
      memory = { memory_enabled = true; user_profile_enabled = true; };
    };

    # Non-secret env, merged into $HERMES_HOME/.env at activation. Enables the
    # gateway's api_server platform (OpenAI-compatible /v1 endpoint) so the
    # gateway has a LAN-facing surface even with no messaging tokens yet.
    environment = {
      API_SERVER_ENABLED = "true";
      API_SERVER_HOST = "0.0.0.0";
      API_SERVER_PORT = toString apiPort;
    };

    # Puts `hermes` on the system PATH and exports HERMES_HOME so interactive
    # CLI use shares sessions/skills/memory with the gateway service.
    addToSystemPackages = true;

    # Extra tools on the agent's PATH (upstream already provides bash,
    # coreutils, git).
    extraPackages = with pkgs; [ curl jq ripgrep ];
  };

  systemd.services.hermes-agent = {
    # The default model lives on this box's Ollama.
    after = [ "ollama.service" ];
    wants = [ "ollama.service" ];

    # The api_server platform refuses to start without a strong
    # API_SERVER_KEY. Generate one once and persist it across rebuilds
    # (same pattern as odysseus.nix's admin password). LAN clients
    # authenticate with `Authorization: Bearer <key>`.
    preStart = ''
      if [ ! -s ${stateDir}/api-server-key.env ]; then
        umask 077
        printf 'API_SERVER_KEY=%s\n' \
          "$(head -c 48 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 48)" \
          > ${stateDir}/api-server-key.env
      fi
    '';

    # systemd reads EnvironmentFile right before spawning each Exec* process,
    # so the key generated in preStart is visible to the main process on the
    # very first start. secrets.env is the operator's drop-box for messaging
    # tokens and provider keys ("-" = optional).
    serviceConfig.EnvironmentFile = [
      "-${stateDir}/api-server-key.env"
      "-${stateDir}/secrets.env"
    ];
  };

  networking.firewall.allowedTCPPorts = [ apiPort ];
}
