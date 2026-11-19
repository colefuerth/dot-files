{
  pkgs,
  inputs,
}:
let
  inherit (pkgs) lib;
  src = inputs.jfa-go;
  rev = src.shortRev or "unknown";
  cssVersion = lib.head (
    builtins.match ".*web/css/(v[0-9.]+)bundle.css.*" (builtins.readFile "${src}/html/crash.html")
  );
  swag = "swag init --parseDependency --parseInternal -g main.go";
in
pkgs.buildGoModule {
  pname = "jfa-go";
  version = "git-${rev}";
  inherit src;

  vendorHash = "sha256-aGmwHsnKx0S+VDJ48QKg1qlq36nBNLzAwO2dJdQudw8=";

  npmDeps = pkgs.fetchNpmDeps {
    name = "jfa-go-npm-deps";
    inherit src;
    hash = "sha256-kcEVgjQ7romEns9QcstBRvLmf1F4y0J74gI7oCnVEkg=";
  };

  nativeBuildInputs = [
    pkgs.nodejs
    pkgs.npmHooks.npmConfigHook
    pkgs.go-swag
    pkgs.perl
  ];

  overrideModAttrs = old: {
    nativeBuildInputs = lib.remove pkgs.npmHooks.npmConfigHook old.nativeBuildInputs ++ [
      pkgs.go-swag
    ];
    preBuild = "GOFLAGS= ${swag}";
  };

  preBuild = ''
    # SWAGINSTALL= : the Makefile probes with `which`, which the sandbox lacks, then tries `go install swag`.
    make precompile SWAGINSTALL= VERSION=git COMMIT=${rev} CSSVERSION=${cssVersion} BUILDTIME=1
  '';

  subPackages = [ "." ];

  tags = [
    "e2ee"
    "goolm"
  ];
  ldflags = [
    "-s"
    "-w"
    "-X main.version=git"
    "-X main.commit=${rev}"
    "-X main.cssVersion=${cssVersion}"
    "-X main.buildTimeUnix=1"
  ];

  doCheck = false;

  meta = {
    description = "Account management app for Jellyfin";
    homepage = "https://github.com/hrfee/jfa-go";
    license = lib.licenses.mit;
    mainProgram = "jfa-go";
  };
}
