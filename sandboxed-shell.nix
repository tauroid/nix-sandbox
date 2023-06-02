specificScript: pkgs: tools:
let toolpaths = map (tool: "${tool}")
      (tools ++ [pkgs.bashInteractive pkgs.coreutils pkgs.util-linux]);
    path = builtins.concatStringsSep ":" (
             map (toolpath: "${toolpath}/bin") toolpaths);
    genericPreface = ''
      export PATH="${pkgs.bashInteractive}/bin:${path}"
      export HOME=/home/dev
      export TERM=xterm-256color
      mkdir /root
      echo "root:x:0:0::/root:/bin/bash" > /etc/passwd
      echo "dev:x:$HOST_UID:$HOST_UID::/home/dev:/bin/bash" >> /etc/passwd
      ulimit -n 32186
      mkdir /tmp
      chmod 777 /tmp
      chown -R dev /home/dev
      cd /home/dev/sandbox
    '';
in pkgs.mkShell {
  shellHook = ''
    set -e
    full_closure=()
    for path in ${builtins.concatStringsSep " " toolpaths}; do
        readarray -t closure < <(nix path-info -r "$path")
        full_closure+=("''${closure[@]}")
    done
    readarray -t full_closure < <(printf "%s\n" "''${full_closure[@]}" | sort -u)
    ${specificScript genericPreface}
    exit
  '';
}
