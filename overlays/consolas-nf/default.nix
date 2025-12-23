final: prev: {
  consolas-nf = prev.stdenvNoCC.mkDerivation rec {
    pname = "consolas-nf";
    version = "unstable-2024-12-11";

    src = prev.fetchFromGitHub {
      owner = "ongyx";
      repo = "consolas-nf";
      rev = "dab203dc904c6d2f828ba1a3d8e2cd7e5a9f5dfc";
      hash = "sha256-o8WoqUNyw4/xbDGlJQ0mLuHZ0fCMkJ5OA5xvTnL80oc=";
    };

    installPhase = ''
      runHook preInstall

      install -Dm644 *.ttf -t $out/share/fonts/truetype

      runHook postInstall
    '';

    meta = with prev.lib; {
      description = "Consolas font patched with Nerd Fonts glyphs";
      homepage = "https://github.com/ongyx/consolas-nf";
      license = licenses.unfree; # Consolas is a Microsoft font
      platforms = platforms.all;
      maintainers = [ ];
    };
  };
}
