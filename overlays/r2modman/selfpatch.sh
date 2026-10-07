#!@shell@
# r2modman, with the Linux BepInEx files kept topped up in STRAFTAT profiles.
#
# Thunderstore's BepInExPack for STRAFTAT is Windows-only, so on Linux r2modman
# builds a profile with mods in it but no Unix doorstop and no launcher script,
# and "Start modded" silently launches vanilla. The missing files have to sit
# inside the profile folder, and a profile only exists once it has been created
# or imported -- which happens after r2modman is already running, with no hook to
# observe it. Hence the poll: a find over one directory every two seconds, for as
# long as r2modman is up. It prints only when it actually installs something.
#
# A profile export does not carry the files either: r2modman strips the doorstop
# and launcher, expecting to regenerate them per platform on import, which on
# Linux it does not. So importing a working profile still needs this.
set -eu

@r2modman@ "$@" &
r2modman_pid=$!

while kill -0 "$r2modman_pid" 2>/dev/null; do
    # Never take r2modman down over a failed copy.
    @straftatBepinex@ --all || true
    sleep 2
done

wait "$r2modman_pid"
