# ai-os

A local-first AI appliance OS: plug-in hardware that gives a household or
small business private AI, built as a NixOS configuration. The OS is this
repo — every deployed machine is reproducible from a commit hash.

## Layout

```
flake.nix                     # Pins nixpkgs + app sources, declares one config per host
hosts/
  orbstack-dev/               # Dev target: OrbStack NixOS container on the Mac
    configuration.nix         # Host plumbing (users, networking, OrbStack bits)
    incus.nix                 # Copied from OrbStack-generated /etc/nixos
    orbstack.nix              # Copied from OrbStack-generated /etc/nixos
modules/                      # The product. Portable across hosts.
  base.nix                    # Nix settings, operator tooling
  inference.nix               # Ollama runtime (:11434)
  webui.nix                   # Open WebUI (:8080)
  odysseus.nix                # Odysseus AI workspace, docker compose stack (:7000)
  hermes.nix                  # Hermes Agent gateway + API server (:8642)
```

`modules/` is the IP: a future `hosts/appliance-v1/` targeting real hardware
imports the same modules and differs only in host plumbing.

## Services

| Module         | What it is                                          | Port  |
| -------------- | --------------------------------------------------- | ----- |
| `inference.nix`| Ollama (declaratively pulls `llama3.2:3b`)          | 11434 |
| `webui.nix`    | Open WebUI — simple chat front end for Ollama       | 8080  |
| `odysseus.nix` | Odysseus — self-hosted AI workspace (chat, agents,  | 7000  |
|                | deep research, documents, email, notes, calendar)   |       |
| `hermes.nix`   | Hermes Agent — autonomous agent (memory, skills,    | 8642  |
|                | cron, messaging gateway, OpenAI-compatible API)     |       |

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

Browse from the Mac: **http://nix.orb.local:7000** (log in with `admin` and the
password in `/var/lib/odysseus/admin_password`).

> Note: Odysseus needs a working Docker daemon. Inside the OrbStack LXC dev
> container nested Docker can be finicky; the module is written to be portable
> to real hardware hosts where Docker runs natively.

### Hermes Agent

[Hermes Agent](https://hermes-agent.org) (Nous Research, MIT) is an autonomous
agent with persistent memory, self-authored skills, cron automations, and a
messaging gateway. Upstream ships a proper Nix flake, so `modules/hermes.nix`
consumes its NixOS module (`services.hermes-agent`) directly — no compose
stack:

- The upstream flake is a pinned input (`hermes-agent` in `flake.nix`, pinned
  to a release tag — upstream calls Nix "Tier 2", so `main` may break).
- The gateway runs as a hardened native systemd service (`hermes-agent`);
  state lives in `/var/lib/hermes/.hermes`.
- Chat goes through this box's Ollama (`http://127.0.0.1:11434/v1`, model
  `llama3.2:3b`).
- The gateway's OpenAI-compatible API server listens on :8642. A bearer key is
  generated once into `/var/lib/hermes/api-server-key.env`.
- The `hermes` CLI is on the system PATH and shares state with the gateway
  (`hermes --tui` inside the VM for interactive chat).
- To connect Telegram/Discord/Slack or add provider API keys, put the tokens
  in `/var/lib/hermes/secrets.env` (e.g. `TELEGRAM_BOT_TOKEN=...`) and
  `systemctl restart hermes-agent`.

## Deploying to the OrbStack dev machine

The Mac filesystem is shared into OrbStack machines at the same path, so the
repo is directly visible inside the VM. From the Mac:

```sh
git add -A          # flakes only see git-tracked files!
orb -m nix -w ~/Documents/develop/ai-os \
  sudo nixos-rebuild switch --flake .#orbstack-dev
```

Or open a shell in the machine (`orb -m nix`) and run the rebuild from the
repo directory. First build downloads Ollama + Open WebUI; the first Ollama
start also pulls `llama3.2:3b` (declared in `modules/inference.nix`). The first
rebuild that includes Odysseus also builds its docker compose stack.

Then browse from the Mac: **http://nix.orb.local:8080** (Open WebUI) or
**http://nix.orb.local:7000** (Odysseus).

Roll back a bad rebuild with `sudo nixos-rebuild switch --rollback`.

## Notes / constraints

- The OrbStack machine is an LXC container sharing the host kernel: no GPU,
  CPU-only inference. It's for building the product layer, not benchmarking.
- Bootloader / disk-image / A/B-update work doesn't apply in the container;
  that happens later via image builds from this same flake.
- `incus.nix` / `orbstack.nix` are OrbStack-generated. If OrbStack regenerates
  them in the VM, re-copy: `orb -m nix cat /etc/nixos/orbstack.nix > hosts/orbstack-dev/orbstack.nix`
