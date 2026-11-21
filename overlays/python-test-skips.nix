final: prev:
let
  skipChecks = [
    "pylint"
    "libvirt"
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
