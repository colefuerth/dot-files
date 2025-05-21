final: prev: {
  openssh = prev.openssh.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      /**
        Disable "bad permission" checking in openssh.
      */
      ./no-check-permission.patch
    ];
    doCheck = false;
  });
}
