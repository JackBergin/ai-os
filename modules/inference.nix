# Inference runtime: Ollama serving an OpenAI-compatible-ish API on :11434.
{ config, pkgs, ... }:

{
  services.ollama = {
    enable = true;
    host = "0.0.0.0";

    # Declaratively pulled at service start. Sized for CPU-only inference
    # in the OrbStack container; real hardware targets can override.
    loadModels = [ "llama3.2:3b" ];
  };

  networking.firewall.allowedTCPPorts = [ 11434 ];
}
