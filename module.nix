{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.opencode;

  jsonFormat = pkgs.formats.json { };

  # ── MCP helpers ──────────────────────────────────────────────────────────

  renderEnv = env:
    lib.mapAttrs (_: value:
      if isAttrs value && value ? file then "{file:${value.file}}"
      else value
    ) env;

  toOpencodeShape = s:
    let
      isRemote = s ? url && s.url != null;
      renderedEnv = renderEnv (s.env or { });
    in
    optionalAttrs (s.enabled or null != null) { inherit (s) enabled; }
    // {
      type = if isRemote then "remote" else "local";
    }
    // (
      if isRemote then
        { inherit (s) url; } // optionalAttrs (s.headers or { } != { }) { inherit (s) headers; }
      else
        {
          command = [ s.command ] ++ (s.args or [ ]);
        }
        // optionalAttrs (renderedEnv != { }) { environment = renderedEnv; }
    );

  transformMcpServer =
    {
      server,
      extraTransforms ? [ ],
      exclude ? [ ],
    }:
    let
      hasEnabled = server ? enabled && server.enabled != null;
      hasDisabled = server ? disabled && server.disabled != null;
      resolvedEnabled =
        if hasEnabled then server.enabled
        else if hasDisabled then !server.disabled
        else null;

      normalised = server // {
        enabled = resolvedEnabled;
        url =
          if (server.url or null) != null then server.url
          else server.serverUrl or null;
      };
      transformed = lib.foldl' (acc: transform: transform acc) normalised extraTransforms;
      cleaned = removeAttrs transformed ([ "disabled" "serverUrl" ] ++ exclude);
    in
    filterAttrs (_: value: value != null && value != [ ] && value != { }) cleaned;

  transformedMcpServers =
    if cfg.enableMcpIntegration
      && (config.programs.mcp.enable or false)
      && (config.programs.mcp.servers or { }) != { }
    then
      mapAttrs (
        _: server:
        transformMcpServer {
          inherit server;
          extraTransforms = [ toOpencodeShape ];
          exclude = [ "args" "env" ];
        }
      ) config.programs.mcp.servers
    else
      { };

  # ── Package wrapper ─────────────────────────────────────────────────────

  packageWithExtraPackages =
    if cfg.package != null && cfg.extraPackages != [ ] then
      pkgs.symlinkJoin {
        inherit (cfg.package) meta;
        name = "${getName cfg.package}-wrapped-${getVersion cfg.package}";
        paths = [ cfg.package ];
        preferLocalBuild = true;
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/${cfg.package.meta.mainProgram or "opencode"} \
            --suffix PATH : ${makeBinPath cfg.extraPackages}
        '';
      }
    else
      cfg.package;

  # ── Skill helpers ────────────────────────────────────────────────────────

  isPathLike = x:
    isPath x || (isString x && builtins.match "^(/|\\.(/|$)|/nix/store/).*" x != null);

  normalizeDirectory =
    name: source:
    if isPath source then
      source
    else
      pkgs.runCommandLocal name { } ''
        if [[ ! -d ${escapeShellArg (toString source)} ]]; then
          echo ${escapeShellArg "programs.opencode.skills must be a directory"} >&2
          exit 1
        fi
        ln -s ${escapeShellArg (toString source)} "$out"
      '';

  normalizeSkill =
    source:
    pkgs.runCommandLocal "opencode-skill" { } ''
      source=${escapeShellArg (toString source)}
      if [[ -d "$source" ]]; then
        ln -s "$source" "$out"
      elif [[ -f "$source" ]]; then
        mkdir "$out"
        ln -s "$source" "$out/SKILL.md"
      else
        echo "OpenCode skill source must be a file or directory: $source" >&2
        exit 1
      fi
    '';

  # ── Config file generation ──────────────────────────────────────────────

  mergedMcpServers =
    transformedMcpServers // (cfg.settings.mcp or { }) // cfg.mcpServers;

  mergedSettings =
    cfg.settings
    // optionalAttrs (mergedMcpServers != { }) { mcp = mergedMcpServers; };

in
{
  # ── Deprecated alias ────────────────────────────────────────────────────

  imports = [
    (mkRenamedOptionModule [ "services" "opencode" ] [ "programs" "opencode" ])
  ];

  # ── Options ─────────────────────────────────────────────────────────────

  options.programs.opencode = {

    enable = mkEnableOption "opencode";

    package = mkOption {
      type = types.nullOr types.package;
      default = pkgs.opencode or null;
      defaultText = literalExpression "pkgs.opencode";
      description = "OpenCode package to use.";
    };

    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      example = literalExpression "[ pkgs.uv ]";
      description = "Extra packages available to OpenCode (added to PATH).";
    };

    enableMcpIntegration = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to integrate MCP servers from {option}`programs.mcp.servers`
        into {option}`programs.opencode.settings.mcp`.

        Requires the home-manager {option}`programs.mcp` module to be enabled.
        OpenCode-specific {option}`mcpServers` take precedence over integrated ones.
      '';
    };

    mcpServers = mkOption {
      inherit (jsonFormat) type;
      default = { };
      example = literalExpression ''
        {
          filesystem = {
            type = "local";
            command = [ "npx" "-y" "@modelcontextprotocol/server-filesystem" "/tmp" ];
            enabled = true;
          };
          context7 = {
            type = "remote";
            url = "https://mcp.context7.com/mcp";
            headers = { CONTEXT7_API_KEY = "{env:CONTEXT7_API_KEY}"; };
          };
        }
      '';
      description = ''
        MCP servers configuration written to {file}`$XDG_CONFIG_HOME/opencode/opencode.json`
        under the {var}`mcp` key.

        Each server can be either:
        - A local (stdio) server with {var}`type = "local"` and {var}`command`
        - A remote (HTTP/SSE) server with {var}`type = "remote"` and {var}`url`

        See <https://opencode.ai/docs/mcp-servers/> for the documentation.
      '';
    };

    settings = mkOption {
      inherit (jsonFormat) type;
      default = { };
      example = {
        model = "anthropic/claude-sonnet-4-20250514";
        autoshare = false;
        autoupdate = true;
      };
      description = ''
        Configuration written to {file}`$XDG_CONFIG_HOME/opencode/opencode.json`.
        See <https://opencode.ai/docs/config/> for the documentation.

        Note: {literal}`"$schema": "https://opencode.ai/config.json"` is automatically added.
      '';
    };

    tui = mkOption {
      inherit (jsonFormat) type;
      default = { };
      example = {
        theme = "system";
        keybinds = {
          leader = "alt+b";
        };
      };
      description = ''
        TUI-specific configuration written to {file}`$XDG_CONFIG_HOME/opencode/tui.json`.
        See <https://opencode.ai/docs/tui#configure> for the documentation.

        Note: {literal}`"$schema": "https://opencode.ai/tui.json"` is automatically added.
      '';
    };

    web = {
      enable = mkEnableOption "opencode web service";

      extraArgs = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [
          "--hostname"
          "0.0.0.0"
          "--port"
          "4096"
        ];
        description = "Extra arguments passed to the opencode serve command.";
      };

      environmentFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        example = "/run/secrets/opencode-web";
        description = ''
          Path to an EnvironmentFile for the web service (KEY=VALUE pairs).
          Recommended for setting OPENCODE_SERVER_PASSWORD without exposing it in the Nix store.
        '';
      };
    };

    context = mkOption {
      type = types.either types.lines types.path;
      default = "";
      description = ''
        Global context written to {file}`$XDG_CONFIG_HOME/opencode/AGENTS.md`.
      '';
    };

    commands = mkOption {
      type = types.either (types.attrsOf (types.either types.lines types.path)) types.path;
      default = { };
      description = ''
        Custom commands. Attribute names become filenames (.md).
        Values can be inline strings or paths to files.
        A path value symlinks the entire directory.
      '';
    };

    agents = mkOption {
      type = types.either (types.attrsOf (types.either types.lines types.path)) types.path;
      default = { };
      description = ''
        Custom agents. Attribute names become filenames (.md).
        Values can be inline strings or paths to files.
        A path value symlinks the entire directory.
      '';
    };

    skills = mkOption {
      type = types.either (types.attrsOf (types.oneOf [ types.lines types.path types.str ])) types.path;
      default = { };
      description = ''
        Custom skills. Attribute names become directory names containing SKILL.md.
        Values can be inline strings, paths to files, or paths to directories.
        A path value (non-attrset) symlinks the entire directory.
      '';
    };

    themes = mkOption {
      type = types.either (types.attrsOf (types.either jsonFormat.type types.path)) types.path;
      default = { };
      description = ''
        Custom themes. Attribute names become filenames (.json).
        Values can be attrsets (converted to JSON) or paths to files.
        A path value symlinks the entire directory.
      '';
    };

    tools = mkOption {
      type = types.either (types.attrsOf (types.either types.lines types.path)) types.path;
      default = { };
      description = ''
        Custom tools. Attribute names become filenames (.ts).
        Values can be inline strings or paths to files.
        A path value symlinks the entire directory.
      '';
    };
  };

  # ── Config ──────────────────────────────────────────────────────────────

  config = mkIf cfg.enable {

    assertions = [
      {
        assertion = !isPath cfg.commands || pathIsDirectory cfg.commands;
        message = "`programs.opencode.commands` must be a directory when set to a path";
      }
      {
        assertion = !isPath cfg.agents || pathIsDirectory cfg.agents;
        message = "`programs.opencode.agents` must be a directory when set to a path";
      }
      {
        assertion = !isPath cfg.tools || pathIsDirectory cfg.tools;
        message = "`programs.opencode.tools` must be a directory when set to a path";
      }
      {
        assertion = !isPath cfg.skills || pathIsDirectory cfg.skills;
        message = "`programs.opencode.skills` must be a directory when set to a path";
      }
      {
        assertion = !isPath cfg.themes || pathIsDirectory cfg.themes;
        message = "`programs.opencode.themes` must be a directory when set to a path";
      }
    ];

    home.packages = mkIf (packageWithExtraPackages != null) [ packageWithExtraPackages ];

    xdg.configFile =
      {
        "opencode/opencode.json" = mkIf (mergedSettings != { "$schema" = "https://opencode.ai/config.json"; }) {
          source = jsonFormat.generate "opencode.json" (
            { "$schema" = "https://opencode.ai/config.json"; } // mergedSettings
          );
        };

        "opencode/tui.json" = mkIf (cfg.tui != { }) {
          source = jsonFormat.generate "tui.json" (
            { "$schema" = "https://opencode.ai/tui.json"; } // cfg.tui
          );
        };

        "opencode/AGENTS.md" =
          if isPath cfg.context then
            { source = cfg.context; }
          else
            mkIf (cfg.context != "") { text = cfg.context; };

        "opencode/commands" = mkIf (isPath cfg.commands) {
          source = cfg.commands;
          recursive = true;
        };

        "opencode/agents" = mkIf (isPath cfg.agents) {
          source = cfg.agents;
          recursive = true;
        };

        "opencode/tools" = mkIf (isPath cfg.tools) {
          source = cfg.tools;
          recursive = true;
        };

        "opencode/skills" = mkIf (isPathLike cfg.skills && !isAttrs cfg.skills) {
          source = normalizeDirectory "opencode-skills" cfg.skills;
          recursive = true;
        };

        "opencode/themes" = mkIf (isPath cfg.themes) {
          source = cfg.themes;
          recursive = true;
        };
      }
      // optionalAttrs (isAttrs cfg.commands) (
        mapAttrs' (name: content:
          nameValuePair "opencode/commands/${name}.md" (
            if isPath content then { source = content; } else { text = content; }
          )
        ) cfg.commands
      )
      // optionalAttrs (isAttrs cfg.agents) (
        mapAttrs' (name: content:
          nameValuePair "opencode/agents/${name}.md" (
            if isPath content then { source = content; } else { text = content; }
          )
        ) cfg.agents
      )
      // optionalAttrs (isAttrs cfg.tools) (
        mapAttrs' (name: content:
          nameValuePair "opencode/tools/${name}.ts" (
            if isPath content then { source = content; } else { text = content; }
          )
        ) cfg.tools
      )
      // mapAttrs' (name: content:
        if isPath content && pathIsDirectory content then
          nameValuePair "opencode/skills/${name}" { source = content; recursive = true; }
        else if isPathLike content && !isPath content then
          nameValuePair "opencode/skills/${name}" { source = normalizeSkill content; recursive = true; }
        else
          nameValuePair "opencode/skills/${name}/SKILL.md" (
            if isPathLike content then { source = content; } else { text = content; }
          )
      ) (if isAttrs cfg.skills then cfg.skills else { })
      // optionalAttrs (isAttrs cfg.themes) (
        mapAttrs' (name: content:
          nameValuePair "opencode/themes/${name}.json" (
            if isPath content then
              { source = content; }
            else
              {
                source = jsonFormat.generate "opencode-${name}.json" (
                  { "$schema" = "https://opencode.ai/theme.json"; } // content
                );
              }
          )
        ) cfg.themes
      );

    systemd.user.services = mkIf cfg.web.enable {
      opencode-web = {
        Unit = {
          Description = "OpenCode Web Service";
          After = [ "network.target" ];
        };

        Service = {
          ExecStart = "${lib.getExe packageWithExtraPackages} serve ${escapeShellArgs cfg.web.extraArgs}";
          Restart = "always";
          RestartSec = 5;
        }
        // optionalAttrs (cfg.web.environmentFile != null) {
          EnvironmentFile = cfg.web.environmentFile;
        };

        Install = {
          WantedBy = [ "default.target" ];
        };
      };
    };

    launchd.agents = mkIf cfg.web.enable {
      opencode-web = {
        enable = true;
        config = {
          ProgramArguments =
            let
              programArguments = [ (lib.getExe packageWithExtraPackages) "serve" ] ++ cfg.web.extraArgs;
              opencodeLaunchdWrapper = pkgs.writeShellScriptBin "opencode-launchd-wrapper" ''
                source ${cfg.web.environmentFile}
                ${escapeShellArgs programArguments}
              '';
            in
            if cfg.web.environmentFile == null then programArguments
            else [ (lib.getExe opencodeLaunchdWrapper) ];

          KeepAlive = {
            Crashed = true;
            SuccessfulExit = false;
          };
          ProcessType = "Background";
          RunAtLoad = true;
        };
      };
    };
  };
}
