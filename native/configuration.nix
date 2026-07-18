# Host: bare-metal / full NixOS appliance.
# Before deploying: replace the tmpfs root below with hardware-configuration.nix
# from nixos-generate-config, and enable a bootloader.
# Product code lives in ../modules and is shared with vm/docker hosts.

{ config, pkgs, lib, ... }:

{
  imports = [
    # TODO: ./hardware-configuration.nix
    # TODO: boot.loader (systemd-boot or grub)

    ../modules/base.nix
    ../modules/inference.nix
    ../modules/webui.nix
    ../modules/odysseus.nix
    ../modules/hermes.nix
  ];

  networking.hostName = "ai-os";

  # Placeholder root so the config evaluates before real hardware is added.
  # Replace with nixos-generate-config output before installing.
  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
    options = [ "defaults" "mode=755" ];
  };

  time.timeZone = "America/New_York";

  # Placeholder operator account — replace before real deploy.
  users.users.operator = {
    isNormalUser = true;
    extraGroups = [ "wheel" "hermes" "docker" ];
  };
  security.sudo.wheelNeedsPassword = true;

  services.openssh.enable = true;

  system.stateVersion = "25.11";
}
