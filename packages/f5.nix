{
  pkgs,
}:
pkgs.buildGoModule rec {
  pname = "f5";
  version = "unstable-2022-07-27";

  src = pkgs.fetchFromGitHub {
    owner = "yukinying";
    repo = "f5";
    rev = "946a179ae255";
    hash = "sha256-SqGjjhz0Hh/gqw29s9b6EnFFh1o2r64/8DrX8KjvwtM=";
  };

  subPackages = [ "f5" ];

  vendorHash = "sha256-ctfFi/YsLMl7fW3h/U3VR/EWueAo9yhTWFjmQxQJTIw=";
}
