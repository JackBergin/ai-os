# ai-appliance

A local-first AI appliance OS: plug-in hardware that gives a household or
small business private AI, built as a NixOS configuration. The OS is this
repo — every deployed machine is reproducible from a commit hash.

## Layout

```
flake.nix                     # Pins nixpkgs, declares one config per host
hosts/
  orbstack-dev/               # Dev target: OrbStack NixOS container on the Mac
    configuration.nix         # Host plumbing (users, networking, OrbStack bits)
    incus.nix                 # Copied from OrbStack-generated /etc/nixos
    orbstack.nix              # Copied from OrbStack-generated /etc/nixos
modules/                      # The product. Portable across hosts.
  base.nix                    # Nix settings, operator tooling
  inference.nix               # Ollama runtime (:11434)
  webui.nix                   # Open WebUI (:8080)
```

`modules/` is the IP: a future `hosts/appliance-v1/` targeting real hardware
imports the same modules and differs only in host plumbing.

## Deploying to the OrbStack dev machine

The Mac filesystem is shared into OrbStack machines at the same path, so the
repo is directly visible inside the VM. From the Mac:

```sh
git add -A          # flakes only see git-tracked files!
orb -m nix -w ~/Documents/develop/ai-appliance \
  sudo nixos-rebuild switch --flake .#orbstack-dev
```

Or open a shell in the machine (`orb -m nix`) and run the rebuild from the
repo directory. First build downloads Ollama + Open WebUI; the first Ollama
start also pulls `llama3.2:3b` (declared in `modules/inference.nix`).

Then browse from the Mac: **http://nix.orb.local:8080**

Roll back a bad rebuild with `sudo nixos-rebuild switch --rollback`.

## Notes / constraints

- The OrbStack machine is an LXC container sharing the host kernel: no GPU,
  CPU-only inference. It's for building the product layer, not benchmarking.
- Bootloader / disk-image / A/B-update work doesn't apply in the container;
  that happens later via image builds from this same flake.
- `incus.nix` / `orbstack.nix` are OrbStack-generated. If OrbStack regenerates
  them in the VM, re-copy: `orb -m nix cat /etc/nixos/orbstack.nix > hosts/orbstack-dev/orbstack.nix`
