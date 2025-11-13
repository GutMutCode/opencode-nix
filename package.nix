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
  version = "1.0.62";

  # SHA256 hashes for npm packages (nix base32 format)
  hashes = {
    x86_64-linux = "1kvld2asdhfv9whdzyx4sma7nv61w8wr484iik5vsq5vl1j73iym";
    aarch64-linux = "0mz6yl3jzkjz1w13pw1k2isrcml69ynzb94lglg298mbqvx8v23l";
    x86_64-darwin = "1sy1a2s6imwy177m3dj23vr4racgz307pi3fk16ci8dknvn19cy1";
    aarch64-darwin = "13gd9grkngqbkx3iqchsrsma3b2n9svdn00xzik7cx30jpyf049x";
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
