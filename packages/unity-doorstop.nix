# UnityDoorstop, the .NET preloader BepInEx uses to get into a Unity game.
#
# Pinned past the 4.5.0 release on purpose: 4.5.0 and earlier install dup2/fclose
# hooks into every process LD_PRELOAD reaches, which suppresses stdout/stderr
# redirection and so breaks `$(...)` in the Steam Linux Runtime's entry-point
# scripts -- the game then never launches. Fixed by NeighTools/UnityDoorstop#120,
# merged after 4.5.0 was tagged, so there is no release to use yet.
{
  pkgs,
}:
pkgs.stdenv.mkDerivation {
  pname = "unity-doorstop";
  version = "4.6.0-unstable-2026-09-26";

  src = pkgs.fetchFromGitHub {
    owner = "NeighTools";
    repo = "UnityDoorstop";
    rev = "3035af7ae73ed071200c995886264d62ceb3488b";
    hash = "sha256-c+esaD43thbXTKanJGmsQOq4Ow1znNGwKcPn5PoppjM=";
  };

  # Upstream builds with xmake, which wants to fetch its own toolchain at build
  # time. The Unix target is nine translation units and libdl, so compile it
  # directly instead of packaging a build system to do it.
  buildPhase = ''
    runHook preBuild

    $CC -shared -fPIC -Os -Wall -o libdoorstop.so \
      src/bootstrap.c \
      src/config/common.c \
      src/runtimes/globals.c \
      src/util/paths.c \
      src/nix/config.c \
      src/nix/entrypoint.c \
      src/nix/jit_memcpy.c \
      src/nix/util.c \
      src/nix/plthook/plthook_elf.c \
      -ldl

    runHook postBuild
  '';

  # The whole reason for pinning a commit instead of the release: confirm the
  # shell fix is actually in this build. Broken builds print "[]".
  doCheck = true;
  checkPhase = ''
    runHook preCheck

    got=$(LD_PRELOAD=$PWD/libdoorstop.so DOORSTOP_ENABLED=1 \
      DOORSTOP_TARGET_ASSEMBLY=/dev/null \
      sh -c 'x="$(echo hi)"; echo "[$x]"')
    if [ "$got" != "[hi]" ]; then
      echo "doorstop broke command substitution: expected [hi], got $got" >&2
      exit 1
    fi

    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall

    install -Dm644 libdoorstop.so $out/lib/libdoorstop.so
    # Version marker r2modman reads to decide whether to refresh its files.
    printf '4.6.0' > $out/lib/.doorstop_version

    runHook postInstall
  '';

  meta = {
    description = "Unity .NET preloader used by BepInEx (Linux build, with the LD_PRELOAD stdio fix)";
    homepage = "https://github.com/NeighTools/UnityDoorstop";
    license = pkgs.lib.licenses.cc0;
    platforms = pkgs.lib.platforms.linux;
  };
}
