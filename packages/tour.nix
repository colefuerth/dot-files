{
  pkgs,
}:
pkgs.buildGoModule rec {
  pname = "tour";
  version = "unstable-2025-03-26";

  src = pkgs.fetchFromGitHub {
    owner = "golang";
    repo = "website";
    rev = "985eb3ee12e5";
    hash = "sha256-fSrY+9zfCRUBRdYFIrtLgi3zCeyI/7qAUrdFP1bN9h0=";
  };

  subPackages = [ "tour" ];

  vendorHash = "sha256-H/p4t8CngX3jendvlxhloUMLR7B7dSvgKGCjZ5ypTWk=";
}
