final: prev: {
  firefoxpwa = prev.firefoxpwa.overrideAttrs (old: rec {
    version = "2.14.1";
    src = prev.pkgs.fetchFromGitHub {
      owner = "filips123";
      repo = "PWAsForFirefox";
      rev = "v${version}";
      hash = "sha256-yYvQxz+lAxKXpAWeLiBnepGuwYfNLyIhu4vQ8NdH3pc=";
    };

    sourceRoot = "${src.name}/native";

    useFetchCargoVendor = true;
    cargoHash = "";

    preConfigure = ''
      sed -i 's;version = "0.0.0";version = "${version}";' Cargo.toml
      sed -zi 's;name = "firefoxpwa"\nversion = "0.0.0";name = "firefoxpwa"\nversion = "${version}";' Cargo.lock
      sed -i $'s;DISTRIBUTION_VERSION = \'0.0.0\';DISTRIBUTION_VERSION = \'${version}\';' userchrome/profile/chrome/pwa/chrome.jsm
    '';

    postInstall = ''
      # Runtime
      mkdir -p $out/share/firefoxpwa
      cp -Lr ${prev.firefox-unwrapped}/lib/firefox $out/share/firefoxpwa/runtime
      chmod -R +w $out/share/firefoxpwa

      # UserChrome
      cp -r userchrome $out/share/firefoxpwa

      # Runtime patching
      FFPWA_USERDATA=$out/share/firefoxpwa $out/bin/firefoxpwa runtime patch

      # Manifest
      sed -i "s!/usr/libexec!$out/bin!" manifests/linux.json
      install -Dm644 manifests/linux.json $out/lib/mozilla/native-messaging-hosts/firefoxpwa.json

      installShellCompletion --cmd firefoxpwa \
        --bash $completions/firefoxpwa.bash \
        --fish $completions/firefoxpwa.fish \
        --zsh $completions/_firefoxpwa

      # AppStream Metadata
      install -Dm644 packages/appstream/si.filips.FirefoxPWA.metainfo.xml $out/share/metainfo/si.filips.FirefoxPWA.metainfo.xml
      install -Dm644 packages/appstream/si.filips.FirefoxPWA.svg $out/share/icons/hicolor/scalable/apps/si.filips.FirefoxPWA.svg

      wrapProgram $out/bin/firefoxpwa \
        --prefix FFPWA_SYSDATA : "$out/share/firefoxpwa" \
        --prefix LD_LIBRARY_PATH : "$libs" \
        --suffix-each GTK_PATH : "$gtk_modules"

      wrapProgram $out/bin/firefoxpwa-connector \
        --prefix FFPWA_SYSDATA : "$out/share/firefoxpwa" \
        --prefix LD_LIBRARY_PATH : "$libs" \
        --suffix-each GTK_PATH : "$gtk_modules"
    '';

    meta.changelog = "https://github.com/filips123/PWAsForFirefox/releases/tag/v${version}";
  });
}
