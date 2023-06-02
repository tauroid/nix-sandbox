{pkgs, tools, portMappings, shellHook, detach ? false}:
let portArgs = builtins.concatStringsSep " " (
      map (mapping: "-p " + (toString mapping.host)
                    + ":" + (toString mapping.container))
        portMappings
    );
    in
(import ./sandboxed-shell.nix) (genericPreface:
  let shellHookFile = pkgs.writeScriptBin "shellHookFile" shellHook;
    preface = pkgs.writeScriptBin "preface" ''
    ${genericPreface}
    setpriv --reuid=$HOST_UID --regid=$HOST_UID \
      --clear-groups --inh-caps=-all \
      bash --init-file ${shellHookFile}/bin/shellHookFile
    exit
  ''; in
  ''
  bindArgs=""
  for path in ''${full_closure[@]}; do
    bindArgs="$bindArgs -v $path:$path:ro"
  done
  IMAGE=$(tar cv --files-from /dev/null | docker import -)
  mkdir -p .home
  docker run -ti ${portArgs} $bindArgs \
    -v ${preface}:${preface}:ro \
    -v ${shellHookFile}:${shellHookFile}:ro \
    -v ${pkgs.bashInteractive}/bin/bash:/bin/bash:ro \
    -v ${pkgs.bashInteractive}/bin/sh:/bin/sh:ro \
    -v ${pkgs.coreutils}/bin/env:/usr/bin/env:ro \
    -v $(pwd):/home/dev/sandbox \
    -v $(pwd)/.home:/home/dev \
    -e HOST_UID=$UID \
    $IMAGE \
    ${pkgs.bashInteractive}/bin/bash \
      --init-file ${preface}/bin/preface
  docker rm -f $(docker ps -a -q --filter="ancestor=$IMAGE")
  docker image rm $IMAGE
'') pkgs tools