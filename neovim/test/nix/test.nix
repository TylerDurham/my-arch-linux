{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.modules.docker;
in
{
  options.modules.docker = {
    enable = mkEnableOption "Docker container runtime (rootless)";

    dataRoot = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Override Docker's data-root (e.g. to move images off /).";
    };

    autoPrune = mkOption {
      type = types.bool;
      default = true;
      description = "Enable weekly automatic pruning of unused images/containers.";
    };
  };

  config = mkIf cfg.enable {
    virtualisation.docker = {
      rootless = {
        enable = true;
        setSocketVariable = true;
      };
      daemon.settings = mkIf (cfg.dataRoot != null) {
        data-root = cfg.dataRoot;
      };
      autoPrune = {
        enable = cfg.autoPrune;
        dates = "weekly";
      };
    };

    # docker compose ships as a CLI plugin with `docker` itself —
    # no separate package needed. This is for standalone tooling only.
    environment.systemPackages = with pkgs; [
      lazydocker
    ];
  };
}
