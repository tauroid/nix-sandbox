pkgs: tools: shellHook:
(import ./sandboxed-shell.nix) (genericPreface:
  let preface = pkgs.writeScriptBin "preface" ''
    HOST_UID=$UID
    ${genericPreface}
    ${shellHook}
  '';
  in ''
  bindArgs=""
  for path in ''${full_closure[@]}; do
    bindArgs="$bindArgs --ro-bind $path $path"
  done
  # TODO experiments in network isolation
  #      doesn't work, permissions aren't there for setns or newuidmap
  #rm -f pid
  #mkfifo pid
  #exec 3<> pid
  #(read -r json <& 3
  # echo $json
  # PID=$(${pkgs.jq}/bin/jq '."child-pid"' <(echo $json))
  # echo $PID
  # echo $UID
  # # requires perms in /etc/subuid
  # newuidmap $PID 0 $UID 1
  # ${pkgs.slirp4netns}/bin/slirp4netns --configure #--mtu=65520 --netns-type=path #--userns-path=/proc/$PID/ns/user /proc/$PID/ns/net tap0
  #) &
  ${pkgs.bubblewrap}/bin/bwrap \
    --unshare-all --clearenv --die-with-parent --share-net \
  `# TODO see above` \
  `#  --json-status-fd 3` \
    --proc /proc --dev /dev \
    $bindArgs \
    --ro-bind /etc/resolv.conf /etc/resolv.conf \
    --ro-bind /etc/nsswitch.conf /etc/nsswitch.conf \
    --ro-bind ${pkgs.bashInteractive}/bin/bash /bin/bash \
    --ro-bind ${pkgs.bashInteractive}/bin/sh /bin/sh \
    --ro-bind ${pkgs.coreutils}/bin/env /usr/bin/env \
    --ro-bind ${preface} ${preface} \
    --bind $(pwd) /home/dev/sandbox \
    -- ${pkgs.bashInteractive}/bin/bash --init-file ${preface}/bin/preface
  # TODO see above
  # rm -f pid
'') pkgs tools
