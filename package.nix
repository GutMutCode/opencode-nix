{ lib
, stdenv
, fetchurl
, patchelf
, glibc
}:

let
  # Platform and architecture detection for npm package names
  arch =
    if stdenv.hostPlatform.isAarch64 then "arm64"
    else if stdenv.hostPlatform.isx86_64 then "x64"
    else throw "Unsupported architecture for opencode";

  platform =
    if stdenv.hostPlatform.isLinux then "linux"
    else if stdenv.hostPlatform.isDarwin then "darwin"
    else throw "Unsupported OS for opencode";

  # Latest version
  version = "0.15.13";

  # SHA256 hashes for npm packages (nix base32 format)
  hashes = {
    x86_64-linux = "1iissg5lr51w5y1awqavwgrhrh1n41mdn6w3dzjyzqjzzmbdd5ms";
    aarch64-linux = "1zh00v8m3d3vid2dfwr56mjj7a2qpxsfngp2pf1ma9sw55q8j98k";
    x86_64-darwin = "1dq72ixz42acrddkjmdxnx1w0b9x75ffi6f7sn0xsl4viczi0fh5";
    aarch64-darwin = "0kzk1g191zkqgrpx2khq21bm81i3vwj09nmhcl1p3kiqh4mml09d";
  };

  # Fetch the platform-specific npm package
  src = fetchurl {
    url = "https://registry.npmjs.org/opencode-${platform}-${arch}/-/opencode-${platform}-${arch}-${version}.tgz";
    sha256 = hashes.${stdenv.hostPlatform.system};
  };
in
stdenv.mkDerivation {
  pname = "opencode";
  inherit version;
  inherit src;

  # Do NOT use autoPatchelfHook - it corrupts the Bun-based binary
  nativeBuildInputs = [ patchelf ];

  # npm tarballs have a 'package' directory
  sourceRoot = "package";

  # Disable all default fixup phases that might corrupt the binary
  dontStrip = true;
  dontPatchELF = true;
  dontPatchShebangs = true;

  installPhase = ''
    runHook preInstall

    # Install binary
    install -Dm755 bin/opencode $out/bin/opencode

    # Only patch the interpreter, nothing else
    patchelf --set-interpreter ${glibc}/lib/ld-linux-x86-64.so.2 $out/bin/opencode

    runHook postInstall
  '';

  meta = with lib; {
    description = "AI coding agent built for the terminal (latest version from npm)";
    homepage = "https://opencode.ai";
    license = licenses.mit;
    platforms = platforms.linux ++ platforms.darwin;
    maintainers = [ ];
    mainProgram = "opencode";
  };
}
