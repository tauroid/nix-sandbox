{
  pkgs,
  tools,
  portMappings ? [],
  envVars ? [],
  shellHook ? "",
  command ? null,
  extraMountDirs ? [],
  hostPreface ? ""
}:
let portArgs = builtins.concatStringsSep " " (
      map (mapping: "-p " + (toString mapping.host)
                    + ":" + (toString mapping.container))
        portMappings
    );
    extraMountArgs = builtins.concatStringsSep " " (
      map (dir: "-v ${dir}:${dir}") extraMountDirs
    );
    envVarArgs = builtins.concatStringsSep " " (
      map (envVar: "-e ${envVar.name}=${envVar.value}") envVars
    );
    dockerImage = pkgs.dockerTools.buildLayeredImageWithNixDb {
      name = "nix-sandboxed-shell";
      tag = "latest";
      contents = tools;
    };
in (import ./sandboxed-shell.nix) {
  runInBareRootEnvironment = script: ''

  '';
  pkgs = pkgs;
  tools = tools;
}
