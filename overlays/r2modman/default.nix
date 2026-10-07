# r2modman that installs its own Linux BepInEx support for STRAFTAT.
#
# See ./selfpatch.sh for why this is a wrapper with a poll loop rather than a
# one-shot copy. The desktop entry uses `Exec=r2modman`, resolved on PATH, so
# launching from the app menu gets the wrapper too.
final: prev:
let
  unity-doorstop = import ../../packages/unity-doorstop.nix { pkgs = prev; };
  straftat-bepinex = import ../../packages/straftat-bepinex {
    pkgs = prev;
    inherit unity-doorstop;
  };
in
{
  # Linux-only: the whole point is a Unix doorstop, and leaving it unguarded makes
  # pkgs.r2modman refuse to evaluate on darwin via unity-doorstop's platforms.
  r2modman =
    if !prev.stdenv.hostPlatform.isLinux then
      prev.r2modman
    else
      prev.symlinkJoin {
        name = "r2modman-${prev.r2modman.version}";
        paths = [ prev.r2modman ];
        postBuild = ''
          rm $out/bin/r2modman
          substitute ${./selfpatch.sh} $out/bin/r2modman \
            --replace-fail '@shell@' ${prev.runtimeShell} \
            --replace-fail '@r2modman@' ${prev.r2modman}/bin/r2modman \
            --replace-fail '@straftatBepinex@' ${straftat-bepinex}/bin/straftat-bepinex
          chmod +x $out/bin/r2modman
        '';
        inherit (prev.r2modman) meta;
      };
}
