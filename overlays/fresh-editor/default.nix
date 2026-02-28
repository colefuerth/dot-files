final: prev: {
  fresh-editor = prev.fresh-editor.overrideAttrs (old: {
    nativeBuildInputs = old.nativeBuildInputs ++ [ prev.rustPlatform.bindgenHook ];
  });
}
