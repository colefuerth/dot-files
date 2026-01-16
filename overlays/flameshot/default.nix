inputs: final: prev: {
  flameshot = inputs.flameshot.packages.${prev.system}.default;
}
