{
  description = "AI appliance OS — local-first inference box";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  };

  outputs = { self, nixpkgs, ... }: {
    nixosConfigurations = {
      # Development machine: OrbStack NixOS container on the Mac.
      # Rebuild inside the VM with:
      #   sudo nixos-rebuild switch --flake .#orbstack-dev
      orbstack-dev = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [ ./hosts/orbstack-dev/configuration.nix ];
      };

      # Future targets share the same modules/ with different host plumbing:
      # appliance-v1 = nixpkgs.lib.nixosSystem { ... };
    };
  };
}
