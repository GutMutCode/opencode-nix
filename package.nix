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
  version = "0.15.7";

  # SHA256 hashes for npm packages (nix base32 format)
  hashes = {
    x86_64-linux = "0xfiz2ynlb7xadgzv7qfngkxbqv5zdlqi30mnf6s2fmlnzjmdbq4";
    aarch64-linux = "0g433anwr7fqrgf389wy6ip2sdi5n821qpgl8sh234z1056jj3xj";
    x86_64-darwin = "0wwzp5gjsrb957a7hf36gvgdv4xcfadg592473pl990wyrbn7vlk";
    aarch64-darwin = "0rlxdmhrvv1r2y86bira8pycapj61y9nrpkm5rqkvhc0913r66rg";
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
