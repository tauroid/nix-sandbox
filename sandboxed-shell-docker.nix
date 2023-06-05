{
  pkgs,
  tools,
  portMappings ? [],
  shellHook ? "",
  command ? null,
  extraMountDirs ? []
}:
let portArgs = builtins.concatStringsSep " " (
      map (mapping: "-p " + (toString mapping.host)
                    + ":" + (toString mapping.container))
        portMappings
    );
    extraMountArgs = builtins.concatStringsSep " " (
      map (dir: "-v ${dir}:${dir}") extraMountDirs
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
  docker run -ti ${portArgs} $bindArgs ${extraMountArgs} \
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
      --init-file ${preface}/bin/preface \
      ${if command == null then "" else ''-c "${command}"''}
  docker rm -f $(docker ps -a -q --filter="ancestor=$IMAGE")
  docker image rm $IMAGE
'') pkgs tools
