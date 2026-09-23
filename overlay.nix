final: prev:
{
  # OpenCode from npm platform-specific package (latest version 1.18.21)
  # Fetches the binary directly from npm registry
  # See: docs/custom-package-troubleshooting.md for details on Bun binary packaging
  opencode = prev.callPackage ./package.nix { };
}
