{
  nix = {
    settings = {
      substituters = [ "https://cuda-maintainers.cachix.org?priority=25" ];
      trusted-public-keys = [
        "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
      ];
    };
  };
}
