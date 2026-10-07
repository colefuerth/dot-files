#!/bin/sh
# BepInEx launcher for r2modman on native Linux games.
#
# r2modman's linux_wrapper.sh execs this with the entire Steam launch command
# as arguments, so all we do is put Doorstop in the environment and hand that
# command straight back. Requires UnityDoorstop >= 4.6.0: older builds hook
# dup2/fclose in every process LD_PRELOAD reaches, which breaks the Steam Linux
# Runtime's shell scripts and the game never starts.
#
# https://github.com/NeighTools/UnityDoorstop/issues/88

a="/$0"; a=${a%/*}; a=${a#/}; a=${a:-.}; BASEDIR=$(cd "$a" || exit; pwd -P)

DOORSTOP_LIB="${BASEDIR}/libdoorstop.so"
TARGET_ASSEMBLY="${BASEDIR}/BepInEx/core/BepInEx.Preloader.dll"

if [ ! -r "$DOORSTOP_LIB" ] || [ ! -r "$TARGET_ASSEMBLY" ]; then
    echo "[run_bepinex] missing $DOORSTOP_LIB or $TARGET_ASSEMBLY; launching vanilla" >&2
    exec "$@"
fi

export DOORSTOP_ENABLED=1
export DOORSTOP_TARGET_ASSEMBLY="$TARGET_ASSEMBLY"
export LD_PRELOAD="${DOORSTOP_LIB}${LD_PRELOAD:+:${LD_PRELOAD}}"

exec "$@"
