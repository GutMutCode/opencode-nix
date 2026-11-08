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
  version = "1.19.5";

  # SHA256 hashes for npm packages (nix base32 format)
  hashes = {
    x86_64-linux = "1q6m3p0153zwb9a86xg5xasy4g5hb3i1pzr2vfycpipc7lqgqz1d";
    aarch64-linux = "16jjini4hqf6ji4rcdxawwfnxnkyzsm5075c1fh6grcgbk7g855s";
    x86_64-darwin = "035a6qjmil9li418z1v0ll6cf1a5n094pwdix6gxh3hc6wrmgvp6";
    aarch64-darwin = "1x4anyy1wkrlg4j7piw3d91hlhvyxwwwxk95yghcyx8578qx9r20";
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
