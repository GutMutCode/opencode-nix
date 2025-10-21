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
  version = "0.15.10";

  # SHA256 hashes for npm packages (nix base32 format)
  hashes = {
    x86_64-linux = "18psblmcbna2xhy9f77h0k53am8dpp456c0a8nqq9rvp7yn5skgi";
    aarch64-linux = "0mmcyfp3pjn4hi3h0nlmp6myyr0nmh60rai2pkvgkcqpsmcnhcpm";
    x86_64-darwin = "1xicgawqndqhjfh9jvv8bd3si49mdy7b28ai3zjxcxrnlhcxx90k";
    aarch64-darwin = "1pz66lf37hkz5clpsyrk0zn8x1ahvh5djk833h23iir8x9y8yz63";
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
