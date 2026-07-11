{
  description = "ai-os — local-first AI appliance operating system";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

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

  outputs = { self, nixpkgs, ... }@inputs: {
    nixosConfigurations = {
      # Development machine: OrbStack NixOS container on the Mac.
      # Rebuild inside the VM with:
      #   sudo nixos-rebuild switch --flake .#orbstack-dev
      orbstack-dev = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        # Pass flake inputs (e.g. odysseus source) down to modules.
        specialArgs = { inherit inputs; };
        modules = [ ./hosts/orbstack-dev/configuration.nix ];
      };

      # Future targets share the same modules/ with different host plumbing:
      # appliance-v1 = nixpkgs.lib.nixosSystem { ... };
    };
  };
}
