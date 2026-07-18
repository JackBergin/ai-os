# ai-os

A local-first AI appliance OS: plug-in hardware that gives a household or
small business private AI, built as a NixOS configuration. The OS is this
repo — every deployed machine is reproducible from a commit hash.

## Layout

```
flake.nix                     # Pins nixpkgs + app sources; NixOS + docker image outputs
modules/                      # The product. Portable across NixOS hosts.
  base.nix                    # Nix settings, operator tooling
  inference.nix               # Ollama runtime (:11434)
  webui.nix                   # Open WebUI (:8080)
  odysseus.nix                # Odysseus AI workspace, docker compose stack (:7000)
  hermes.nix                  # Hermes Agent gateway + API server (:8642)
local/                        # Ubuntu / macOS + Docker only (no Nix)
  docker-compose.yml
  .env.example
  up.sh
vm/                           # OrbStack NixOS guest (dev VM)
native/                       # Bare-metal / full NixOS appliance stub
docker/                       # NixOS-in-Docker image host module
```

`modules/` is the IP for NixOS targets (`vm`, `native`, `docker`). `local/`
mirrors the same services with plain Docker Compose on a general-purpose OS.

## Services

| Module         | What it is                                          | Port  |
| -------------- | --------------------------------------------------- | ----- |
| `inference.nix`| Ollama (declaratively pulls `llama3.2:3b`)          | 11434 |
| `webui.nix`    | Open WebUI — simple chat front end for Ollama       | 8080  |
| `odysseus.nix` | Odysseus — self-hosted AI workspace (chat, agents,  | 7000  |
|                | deep research, documents, email, notes, calendar)   |       |
| `hermes.nix`   | Hermes Agent — autonomous agent (memory, skills,    | 8642  |
|                | cron, messaging gateway, OpenAI-compatible API)     |       |

| Target   | Requires Nix? | How to run |
| -------- | ------------- | ---------- |
| `local`  | No            | `cd local && ./up.sh` on Ubuntu or macOS |
| `vm`     | Yes (OrbStack)| `sudo nixos-rebuild switch --flake .#vm` |
| `native` | Yes           | Install / rebuild on real NixOS hardware |
| `docker` | Yes (to build)| `nix build .#docker` then load the image |

### Odysseus

[Odysseus](https://github.com/pewdiepie-archdaemon/odysseus) ships as a docker
compose stack (the app plus `chromadb`, `searxng`, and `ntfy`) built from
source. Rather than repackage each service, `modules/odysseus.nix` runs that
stack declaratively via a systemd unit:

- The upstream source is a pinned flake input (`odysseus` in `flake.nix`).
- On start, the unit rsyncs the source into `/var/lib/odysseus/src`, renders a
  `.env`, and runs `docker compose up -d --build`. First build is slow (it
  builds the Odysseus image and pulls the sidecars).
- It talks to this box's Ollama at `http://host.docker.internal:11434`.
- Auth is enabled. A random admin password is generated once and stored at
  `/var/lib/odysseus/admin_password`; the user is `admin`.
- Persistent data/logs live under `/var/lib/odysseus/{data,logs}`.

> Note: Odysseus needs a working Docker daemon. Inside the OrbStack LXC or a
> NixOS-in-Docker image, nested Docker can be finicky; the module is written to
> be portable to real hardware hosts where Docker runs natively.

### Hermes Agent

[Hermes Agent](https://hermes-agent.org) (Nous Research, MIT) is an autonomous
agent with persistent memory, self-authored skills, cron automations, and a
messaging gateway. Upstream ships a proper Nix flake, so `modules/hermes.nix`
consumes its NixOS module (`services.hermes-agent`) directly — no compose
stack. Hermes is available on `vm` / `native` / `docker` NixOS targets; it is
not part of the `local/` Compose stack yet.

- The upstream flake is a pinned input (`hermes-agent` in `flake.nix`, pinned
  to a release tag — upstream calls Nix "Tier 2", so `main` may break).
- The gateway runs as a hardened native systemd service (`hermes-agent`);
  state lives in `/var/lib/hermes/.hermes`.
- Chat goes through this box's Ollama (`http://127.0.0.1:11434/v1`, model
  `llama3.2:3b`).
- The gateway's OpenAI-compatible API server listens on :8642. A bearer key is
  generated once into `/var/lib/hermes/api-server-key.env`.
- The `hermes` CLI is on the system PATH and shares state with the gateway.
- To connect Telegram/Discord/Slack or add provider API keys, put the tokens
  in `/var/lib/hermes/secrets.env` (e.g. `TELEGRAM_BOT_TOKEN=...`) and
  `systemctl restart hermes-agent`.

## local — Ubuntu / macOS (Docker only)

No Nix required. Needs Docker Engine or Docker Desktop with Compose v2.

```sh
cd local
./up.sh          # clones pinned Odysseus, then docker compose up -d --build
./up.sh logs     # follow logs
./up.sh down     # stop
```

First run copies `.env.example` → `.env`. Change `ODYSSEUS_ADMIN_PASSWORD`.
Odysseus is cloned into `local/odysseus` at the commit pinned in `flake.lock`
(override with `ODYSSEUS_REV=...`).

Browse:

- Open WebUI: http://localhost:8080
- Odysseus: http://localhost:7000
- Ollama: http://localhost:11434

`host.docker.internal` is not required for Odysseus→Ollama here; both share
the Compose network (`OLLAMA_BASE_URL=http://ollama:11434`).

## vm — OrbStack (Mac)

The Mac filesystem is shared into OrbStack machines at the same path, so the
repo is directly visible inside the VM. From the Mac:

```sh
git add -A          # flakes only see git-tracked files!
orb -m nix -w ~/Documents/develop/ai-os \
  sudo nixos-rebuild switch --flake .#vm
```

The old attribute `.#orbstack-dev` still works as an alias for `.#vm`.

Or open a shell in the machine (`orb -m nix`) and run the rebuild from the
repo directory. First build downloads Ollama + Open WebUI; the first Ollama
start also pulls `llama3.2:3b`. The first rebuild that includes Odysseus also
builds its docker compose stack.

Then browse from the Mac: **http://nix.orb.local:8080** (Open WebUI) or
**http://nix.orb.local:7000** (Odysseus).

Roll back a bad rebuild with `sudo nixos-rebuild switch --rollback`.

If OrbStack regenerates guest nix files, re-copy:

```sh
orb -m nix cat /etc/nixos/orbstack.nix > vm/orbstack.nix
orb -m nix cat /etc/nixos/incus.nix > vm/incus.nix
```

## native — bare-metal NixOS

[`native/configuration.nix`](native/configuration.nix) imports the same
modules. Before installing:

1. Run `nixos-generate-config` and import `hardware-configuration.nix`.
2. Replace the placeholder tmpfs root and enable a bootloader.
3. Rebuild: `sudo nixos-rebuild switch --flake .#native`.

## docker — NixOS container image

Builds a systemd-based NixOS image from the same modules (via nixos-generators).
Prefer Podman for systemd-in-container:

```sh
nix build .#docker
podman load -i result
podman run --systemd=always -p 8080:8080 -p 7000:7000 -p 11434:11434 -p 8642:8642 <image>
```

Nested Docker for Odysseus inside this image has the same caveats as OrbStack.

## Notes / constraints

- The OrbStack machine is an LXC container sharing the host kernel: no GPU,
  CPU-only inference. It's for building the product layer, not benchmarking.
- Bootloader / disk-image / A/B-update work belongs on `native` (and later
  image builds from this same flake), not in the OrbStack guest.
- `vm/incus.nix` / `vm/orbstack.nix` are OrbStack-generated. Refresh them if
  OrbStack regenerates them in the guest.
