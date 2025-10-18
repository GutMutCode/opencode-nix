{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.opencode;
in
{
  options.services.opencode = {
    enable = mkEnableOption "OpenCode - AI coding agent";

    package = mkOption {
      type = types.package;
      default = pkgs.opencode;
      defaultText = literalExpression "pkgs.opencode";
      description = "OpenCode package to use";
    };
  };

  config = mkIf cfg.enable {
    # Install package
    home.packages = [ cfg.package ];
  };
}
