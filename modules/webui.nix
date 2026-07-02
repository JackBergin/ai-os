# User-facing web interface: Open WebUI in front of Ollama.
# v0 of the appliance UX — eventually replaced by our own admin/chat plane.
{ config, pkgs, lib, ... }:

{
  # Open WebUI moved to a source-available license; allow just this package.
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "open-webui"
  ];

  services.open-webui = {
    enable = true;
    host = "0.0.0.0";
    port = 8080;
    environment = {
      OLLAMA_BASE_URL = "http://127.0.0.1:11434";
      # No login wall while developing on a private LAN. Flip to "True"
      # (and re-onboard) before this faces anyone but you.
      WEBUI_AUTH = "False";
    };
  };

  networking.firewall.allowedTCPPorts = [ 8080 ];
}
