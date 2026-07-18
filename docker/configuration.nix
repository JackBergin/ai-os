# Host: NixOS-based Docker/Podman image (built via nixos-generators).
# Product code lives in ../modules and is shared with vm/native hosts.
#
# Nested Docker (Odysseus) has the same caveats as OrbStack — prefer podman
# with --systemd=always when running this image.

{ config, pkgs, lib, modulesPath, ... }:

{
  imports = [
    ../modules/base.nix
    ../modules/inference.nix
    ../modules/webui.nix
    ../modules/odysseus.nix
    ../modules/hermes.nix
  ];

  networking.hostName = "ai-os";

  # Container image: no bootloader / EFI.
  boot.isContainer = true;

  # Reachable over published ports; DHCP is not needed inside the image.
  networking.useDHCP = lib.mkDefault false;
  networking.firewall.enable = true;

  time.timeZone = "America/New_York";

  # Minimal login for debugging the image.
  users.users.root.password = "ai-os";
  services.getty.autologinUser = lib.mkDefault "root";

  system.stateVersion = "25.11";
}
