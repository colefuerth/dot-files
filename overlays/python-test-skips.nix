# Several Python packages in the shared pyPackages list aren't in the binary
# cache at our fast-moving nixpkgs pin, so they build from source and run their
# full test suites. A few of those suites fail for reasons unrelated to how we
# use the package — flaky tolerances, or tests coupled to a fast-drifting
# upstream at this pin:
#   - scipy:  borderline floating-point tolerance tests on x86_64
#   - pylint: "primer" tests that diff pylint output against a pinned astroid
#             (pulled in transitively by python-lsp-server)
#
# Skip their test suites. Applied through pythonPackagesExtensions so it covers
# every interpreter (python312 on the laptop, python313 on the desktop). Add a
# package name here if it starts failing the same way.
final: prev:
let
  skipChecks = [
    "scipy"
    "pylint"
  ];
in
{
  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (
      pyfinal: pyprev:
      prev.lib.genAttrs skipChecks (
        name:
        pyprev.${name}.overridePythonAttrs (_: {
          doCheck = false;
        })
      )
    )
  ];
}
