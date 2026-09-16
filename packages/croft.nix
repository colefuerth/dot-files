{
  pkgs,
  inputs,
  ...
}:
let
  lib = pkgs.lib;
  stdenv = pkgs.stdenv;
  src = inputs.croft;
  cfg = lib.importTOML "${src}/Cargo.toml";
  rustToolchain = pkgs.rust-bin.fromRustupToolchainFile "${src}/rust-toolchain.toml";
  linuxClipboard = lib.optionals stdenv.isLinux [
    pkgs.wl-clipboard
    pkgs.xclip
    pkgs.xsel
  ];
  darwinFrameworks = lib.optionals stdenv.isDarwin (
    with pkgs.darwin.apple_sdk.frameworks;
    [
      AppKit
      Cocoa
      CoreServices
      CoreFoundation
      Security
    ]
  );
  buildInputs = lib.flatten [
    rustToolchain
    linuxClipboard
    darwinFrameworks
  ];
  nativeBuildInputs = [
    pkgs.pkg-config
    pkgs.git
    pkgs.python3
  ];
  customRustPlatform = pkgs.makeRustPlatform {
    cargo = rustToolchain;
    rustc = rustToolchain;
  };
in
customRustPlatform.buildRustPackage {
  pname = cfg.package.name;
  version = cfg.package.version;

  cargoLock.lockFile = "${src}/Cargo.lock";

  inherit src nativeBuildInputs buildInputs;

  preConfigure = ''
    export HOME=$(pwd)
    export PATH=$PWD/bin:$PATH

    substituteInPlace src/widgets/terminal.rs \
      --replace-fail /bin/echo ${pkgs.coreutils}/bin/echo
  '';

  doCheck = false;
}
