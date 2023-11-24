{
  pkgs,
  tools,
  portMappings ? [],
  envVars ? [],
  shellHook ? "",
  command ? null,
  extraMountDirs ? [],
  extraDockerArgs ? [],
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
  defineClosure = true;
  runInBareRootEnvironment = script: ''
    bindArgs=""
    for path in ''${full_closure[@]}; do
      bindArgs="$bindArgs -v $path:$path:ro"
    done
    IMAGE=$(tar cv --files-from /dev/null | docker import -)
    mkdir -p .home
    ${hostPreface}
    docker run -ti ${portArgs} $bindArgs ${extraMountArgs} \
      -v ${pkgs.bashInteractive}/bin/bash:/bin/bash:ro \
      -v ${pkgs.bashInteractive}/bin/sh:/bin/sh:ro \
      -v ${pkgs.coreutils}/bin/env:/usr/bin/env:ro \
      -v $(pwd):/home/dev/sandbox \
      -v $(pwd)/.home:/home/dev \
      -v ${script}/bin/enterNormalUserShellScript:/.bashrc \
      -e HOST_UID=$UID \
      -e HOST_GID=$UID \
      ${envVarArgs} \
      --add-host=host.docker.internal:host-gateway \
      ${builtins.concatStringsSep " " extraDockerArgs} \
      $IMAGE \
      ${pkgs.bashInteractive}/bin/bash
    docker rm -f $(docker ps -a -q --filter="ancestor=$IMAGE")
    docker image rm $IMAGE
  '';
  shellHook = shellHook;
  command = command;
  pkgs = pkgs;
  tools = tools;
}
