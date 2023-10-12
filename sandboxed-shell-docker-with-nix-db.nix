{
  nixDockerImage,
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
in (import ./sandboxed-shell.nix) {
  runInBareRootEnvironment = script:
    let dockerImage = pkgs.dockerTools.buildLayeredImageWithNixDb {
          name = "nix-sandboxed-shell";
          tag = "latest";
          fromImage = nixDockerImage + "/image.tar.gz";
          maxLayers = 102;
          contents = tools;
          config = {
            Entrypoint = ["/root/.nix-profile/bin/bash" "-c" "${script}/bin/enterNormalUserShellScript"];
          };
        };
    in ''
      docker load -i ${dockerImage}
      mkdir -p .home
      ${hostPreface}
      docker run -ti ${portArgs} ${extraMountArgs} \
        -v ${script}:${script}:ro \
        -v $(pwd):/home/dev/sandbox \
        -v $(pwd)/.home:/home/dev \
        -e HOST_UID=$UID \
        -e HOST_GID=$UID \
        ${envVarArgs} \
        nix-sandboxed-shell:latest
    '';
  rootPreface = ''
    chown -R $HOST_UID /nix || true
    # > /dev/null 2>&1 || true
  '';
  shellHook = shellHook;
  command = command;
  pkgs = pkgs;
  tools = tools ++ [pkgs.firejail];
}
