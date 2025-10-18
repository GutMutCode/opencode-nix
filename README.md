# OpenCode for Nix/NixOS

OpenCode - AI coding agent built for the terminal, packaged for NixOS and Nix users.

## About

This flake provides OpenCode v0.15.7 from npm platform-specific packages.

- **Version**: 0.15.7
- **Source**: npm registry (opencode-linux-x64, etc.)
- **License**: MIT
- **Homepage**: https://opencode.ai

## Important Notes

⚠️ **Special Packaging Requirements**

This package uses a Bun-based binary that requires special handling:
- `autoPatchelfHook` and `strip` are **disabled** to prevent binary corruption
- Only the ELF interpreter is manually patched using `patchelf`
- See `docs/custom-package-troubleshooting.md` for details

## Usage

### With Flakes

Add to your `flake.nix`:

```nix
{
  inputs = {
    opencode.url = "github:GutMutCode/opencode-nix";
  };

  outputs = { self, nixpkgs, opencode, ... }: {
    nixosConfigurations.your-host = nixpkgs.lib.nixosSystem {
      modules = [
        {
          nixpkgs.overlays = [ opencode.overlays.default ];
          home-manager.users.your-user = {
            home.packages = [ pkgs.opencode ];
          };
        }
      ];
    };
  };
}
```

### Direct Installation

```bash
nix profile install github:GutMutCode/opencode-nix
```

### Run Without Installing

```bash
nix run github:GutMutCode/opencode-nix
```

## Verification

```bash
# Check version
opencode --version  # Should show: 0.15.7

# List available models
opencode models

# Run help
opencode --help
```

## Building from Source

```bash
git clone https://github.com/GutMutCode/opencode-nix
cd opencode-nix
nix build
./result/bin/opencode --version
```

## Troubleshooting

If you see Bun help instead of OpenCode help, the binary may have been corrupted by build hooks. This package is specifically configured to avoid this issue. See the inline comments in `package.nix` for details.

## Updating

To update to a newer version:

1. Check latest version: `npm view opencode-ai version`
2. Update `version` in `package.nix`
3. Update SHA256 hashes:
   ```bash
   nix-prefetch-url --type sha256 https://registry.npmjs.org/opencode-linux-x64/-/opencode-linux-x64-VERSION.tgz
   # Repeat for other platforms
   ```
4. Update version in README

## License

MIT (for both the packaging code and OpenCode itself)
