# Firefox pulls in onnxruntime (used for its CPU-side local translation
# feature). Under a host with `nixpkgs.config.cudaSupport = true`, onnxruntime
# builds its CUDA execution provider, which drags in cudnn-frontend — and that
# fails to configure under cmake 4.3's FindCUDAToolkit, taking the whole system
# build down with it. Firefox never wants CUDA here, so force onnxruntime to
# build without it (it falls back to the OpenVINO/CPU execution provider).
#
# Applied to every host via overlays/default.nix. On hosts that don't build
# Firefox (or don't set cudaSupport) this is a harmless no-op, since nothing
# pulls the CUDA onnxruntime in the first place.
final: prev: {
  onnxruntime = prev.onnxruntime.override { cudaSupport = false; };
}
