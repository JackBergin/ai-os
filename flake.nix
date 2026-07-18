{
  description = "ai-os — local-first AI appliance operating system";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Odysseus: self-hosted AI workspace (chat, agents, research, docs, email).
    # Not a flake — we consume the source tree and run its docker compose stack
    # from modules/odysseus.nix. Pinned to `main` (the curated branch).
    odysseus = {
      url = "github:pewdiepie-archdaemon/odysseus/main";
      flake = false;
    };

    # Hermes Agent (Nous Research): autonomous agent with persistent memory,
    # skills, and a messaging gateway. A real flake — exports packages (uv2nix)
    # and nixosModules.default, consumed by modules/hermes.nix. Nix support is
    # upstream Tier 2 (main may break), so pin release tags, not main.
    # Deliberately NOT following our nixpkgs: their package set is built and
    # tested against their own pinned nixos-unstable.
    hermes-agent.url = "github:NousResearch/hermes-agent/v2026.7.7.2";
  };

  outputs = { self, nixpkgs, nixos-generators, ... }@inputs:
  let
    system = "aarch64-linux";

    mkNixos = modules: nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit inputs; };
      inherit modules;
    };

    # OrbStack NixOS guest on the Mac (primary VM target).
    vmConfig = mkNixos [ ./vm/configuration.nix ];
  in
  {
    nixosConfigurations = {
      #   sudo nixos-rebuild switch --flake .#vm
      vm = vmConfig;

      # Transitional alias — prefer .#vm going forward.
      orbstack-dev = vmConfig;

      # Bare-metal / full NixOS appliance (add hardware-configuration.nix first).
      native = mkNixos [ ./native/configuration.nix ];

      # Same modules as the docker image, for `nixos-rebuild` / inspection.
      docker = mkNixos [ ./docker/configuration.nix ];
    };

    packages.${system} = {
      # NixOS-based container image (systemd). Prefer podman:
      #   nix build .#docker && podman load -i result
      docker = nixos-generators.nixosGenerate {
        inherit system;
        specialArgs = { inherit inputs; };
        format = "docker";
        modules = [ ./docker/configuration.nix ];
      };
    };
  };
}
