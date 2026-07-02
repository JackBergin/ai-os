# Shared appliance baseline: nix settings and operator tooling.
{ config, pkgs, ... }:

{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  environment.systemPackages = with pkgs; [
    git
    htop
    curl
  ];
}
