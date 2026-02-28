final: prev: {
  gh = prev.gh.overrideAttrs (old: {
    # Fix cross-compilation: the Makefile builds a native helper tool (script/build)
    # but in nix's cross environment, CC is the cross-compiler and Go's linker uses it
    # even with CGO_ENABLED=0. Override CC to the build platform's compiler.
    preBuild =
      (old.preBuild or "")
      + ''
        CC=${prev.buildPackages.stdenv.cc}/bin/cc \
          GOOS=$(go env GOHOSTOS) GOARCH=$(go env GOHOSTARCH) \
          CGO_ENABLED=0 \
          go build -o script/build script/build.go
      '';
  });
}
