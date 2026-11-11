final: prev: {
  kdePackages = prev.kdePackages.overrideScope (
    kfinal: kprev: {
      okular = kprev.okular.overrideAttrs (
        old:
        prev.lib.optionalAttrs (prev.lib.versionOlder old.version "26.12") {
          patches = (old.patches or [ ]) ++ [
            /**
              Fix crash when the page changes while a digital signature is pending.
              https://bugs.kde.org/show_bug.cgi?id=519547, fixed upstream in 26.12.
            */
            ./signature-annotation-cast.patch
          ];
        }
      );
    }
  );
}
