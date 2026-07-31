# scipy 1.18.0 isn't in the binary cache at our nixpkgs pin (Hydra hit a test
# failure), so every host that includes scipy — it's in the shared pyPackages
# list — builds it from source and runs its lengthy test suite. That suite is
# flaky on x86_64 (borderline floating-point tolerances, e.g.
# `test_support_moments_sample`) and blocks the whole system build.
#
# Skip scipy's test suite outright. Applied through pythonPackagesExtensions so
# it covers every interpreter (the laptop's python312, the desktop's python313).
final: prev: {
  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (pyfinal: pyprev: {
      scipy = pyprev.scipy.overridePythonAttrs (_: {
        doCheck = false;
      });
    })
  ];
}
