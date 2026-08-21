{ lib
, stdenv
, fetchurl
, patchelf ? null
, glibc ? null
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
  version = "1.18.21";

  # SHA256 hashes for npm packages (nix base32 format)
  hashes = {
    x86_64-linux = "0mr9q4zywqwx0bnm67zysyqwkpbnbp0d4hjf16q004bgw96zzncj";
    aarch64-linux = "0clahc4sv84g1993byg7za8vwz76q37f9v40vzpp6qfs7551wfs4";
    x86_64-darwin = "11k816frml44p1s9s26hw624idc0qcfkqs8jprxxbp2ms3p62xk3";
    aarch64-darwin = "0px8vfs3h7n81m8cxlgk8zbmhkz3k6pn50js9m47szd6w2r9p7yj";
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
  nativeBuildInputs = lib.optional stdenv.hostPlatform.isLinux patchelf;

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

    ${lib.optionalString stdenv.hostPlatform.isLinux ''
    # Only patch the interpreter on Linux, nothing else
    patchelf --set-interpreter ${glibc}/lib/ld-linux-x86-64.so.2 $out/bin/opencode
    ''}

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
