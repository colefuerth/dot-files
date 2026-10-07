# Installs the Linux half of a BepInEx setup into an r2modman profile.
#
# Thunderstore's BepInExPack for STRAFTAT is Windows-only -- it ships winhttp.dll
# and no .so or .sh at all -- so on Linux r2modman produces a profile with mods in
# it but nothing to load them, and the game starts vanilla. This drops in the
# Unix doorstop and the launcher script r2modman's linux_wrapper.sh looks for.
#
# An r2modman profile export does not carry these files -- it strips the doorstop
# and launcher and expects to regenerate them per platform on import, which on
# Linux it does not -- so importing someone's working profile still needs this.
#
# The same two files work for any native Linux Unity game managed by r2modman;
# only the paths below are STRAFTAT-specific.
{
  pkgs,
  unity-doorstop,
}:
pkgs.writeShellApplication {
  name = "straftat-bepinex";

  runtimeInputs = [ pkgs.coreutils ];

  meta = {
    description = "Install BepInEx Linux support into an r2modman STRAFTAT profile";
    mainProgram = "straftat-bepinex";
  };

  text = ''
    profiles_dir="$HOME/.config/r2modmanPlus-local/STRAFTAT/profiles"

    # Copied rather than symlinked: the game runs inside the Steam Linux Runtime
    # container, which does not necessarily have /nix/store bind-mounted.
    install_into() {
      install -Dm644 ${unity-doorstop}/lib/libdoorstop.so "$1/libdoorstop.so"
      install -Dm644 ${unity-doorstop}/lib/.doorstop_version "$1/.doorstop_version"
      install -Dm755 ${./run_bepinex.sh} "$1/run_bepinex.sh"
    }

    has_bepinex() {
      [ -f "$1/BepInEx/core/BepInEx.Preloader.dll" ]
    }

    # Already correct? Then say nothing, so --all can run on a timer.
    up_to_date() {
      cmp -s ${./run_bepinex.sh} "$1/run_bepinex.sh" &&
        cmp -s ${unity-doorstop}/lib/libdoorstop.so "$1/libdoorstop.so"
    }

    # --all: every profile that has BepInEx, quietly, skipping the rest. Used by
    # the r2modman-straftat wrapper, which cannot know when a profile appears.
    if [ "''${1-}" = --all ]; then
      [ -d "$profiles_dir" ] || exit 0
      while IFS= read -r profile; do
        if has_bepinex "$profile" && ! up_to_date "$profile"; then
          install_into "$profile"
          echo "straftat-bepinex: installed into $profile"
        fi
      done <<EOF
    $(find "$profiles_dir" -mindepth 1 -maxdepth 1 -type d)
    EOF
      exit 0
    fi

    if [ ! -d "$profiles_dir" ]; then
      echo "No r2modman STRAFTAT profiles found at $profiles_dir" >&2
      echo "Install BepInExPack and your mods in r2modman first." >&2
      exit 1
    fi

    # One profile: just use it. Several: make the user name the one they mean.
    if [ $# -ge 1 ]; then
      profile="$profiles_dir/$1"
    else
      count=$(find "$profiles_dir" -mindepth 1 -maxdepth 1 -type d | wc -l)
      if [ "$count" -ne 1 ]; then
        echo "Name the profile to install into. Available:" >&2
        find "$profiles_dir" -mindepth 1 -maxdepth 1 -type d -printf '  %f\n' >&2
        exit 1
      fi
      profile=$(find "$profiles_dir" -mindepth 1 -maxdepth 1 -type d)
    fi

    if [ ! -d "$profile" ]; then
      echo "No such profile: $profile" >&2
      exit 1
    fi

    if ! has_bepinex "$profile"; then
      echo "$profile has no BepInEx/core/BepInEx.Preloader.dll" >&2
      echo "Install BepInExPack in r2modman for this profile first." >&2
      exit 1
    fi

    install_into "$profile"

    echo "Installed into $profile"
    echo
    echo "Launch from r2modman with \"Start modded\", then check:"
    echo "  $profile/BepInEx/LogOutput.log"
    echo "It should be freshly modified and end with \"Chainloader startup complete\"."
  '';
}
