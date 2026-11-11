final: prev: {
  # cargo-setup-hook now exports RUSTONIG_SYSTEM_LIBONIG=1, so onig_sys needs oniguruma
  # from pkg-config. Drop once https://github.com/NixOS/nixpkgs/pull/585026 lands.
  fresh-editor = prev.fresh-editor.overrideAttrs (old: {
    buildInputs = old.buildInputs ++ [ prev.oniguruma ];
    checkFlags = old.checkFlags ++ [
      # flaky: https://github.com/NixOS/nixpkgs/pull/585026#issuecomment-6741147524
      "--skip=services::release_checker::tests::test_update_checker"
    ];
  });
}
