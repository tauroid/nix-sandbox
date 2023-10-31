{
  pkgs,
  tools,
  defineClosure ? false,
  runInBareRootEnvironment,
  rootPreface ? "",
  shellHook,
  command
}:
let toolpaths = map (tool: "${tool}")
      (tools ++ [
        pkgs.bashInteractive
        pkgs.coreutils
        pkgs.util-linux
        pkgs.gnugrep
      ]);
    path = builtins.concatStringsSep ":" (
             map (toolpath: "${toolpath}/bin") toolpaths);
    shellHookFile = pkgs.writeScriptBin "shellHookFile" shellHook;
    # expects /home/dev/sandbox to already exist and belong to
    # HOST_UID (which is also expected to be defined)
    enterNormalUserShellScript = pkgs.writeScriptBin "enterNormalUserShellScript" ''
      export PATH="${pkgs.bashInteractive}/bin:${path}"
      export HOME=/home/dev
      export TERM=xterm-256color
      mkdir -p /root
      ROOT_LINE="root:x:0:0::/root:/bin/bash"
      DEV_LINE="dev:x:$HOST_UID:$HOST_GID::/home/dev:/bin/bash"
      if ! grep -Fxq "root:x:" /etc/passwd; then
          echo "$ROOT_LINE" >> /etc/passwd
      fi
      if ! grep -Fxq "dev:x:" /etc/passwd; then
          echo "$DEV_LINE" >> /etc/passwd
      fi
      if ! grep -Fxq "dev:x:" /etc/group; then
          echo "dev:x:$HOST_GID" >> /etc/group
      fi
      ulimit -n 32186
      mkdir -p /tmp
      chmod 777 /tmp
      ${rootPreface}
      cd /home/dev/sandbox
      setpriv --reuid=$HOST_UID --regid=$HOST_GID \
        --clear-groups --inh-caps=-all \
        bash --init-file ${shellHookFile}/bin/shellHookFile \
        ${if command == null then "" else ''-c "${command}"''}
    '';
    scriptpaths = map (script: "${script}")
      [shellHookFile enterNormalUserShellScript];
in pkgs.mkShell {
  shellHook = ''
    set -e
  '' + (if defineClosure then ''
    full_closure=()
    for path in ${builtins.concatStringsSep " " toolpaths}; do
        readarray -t closure < <(nix path-info -r "$path")
        full_closure+=("''${closure[@]}")
    done
    for path in ${builtins.concatStringsSep " " scriptpaths}; do
        readarray -t closure < <(nix path-info -r "$path")
        full_closure+=("''${closure[@]}")
    done
    readarray -t full_closure < <(printf "%s\n" "''${full_closure[@]}" | sort -u)
  '' else ''
  '') + ''
    ${runInBareRootEnvironment enterNormalUserShellScript}
    exit
  '';
}
