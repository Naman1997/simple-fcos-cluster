FROM lnl7/nix:latest
WORKDIR /tmp
ENV NIXPKGS_ALLOW_INSECURE=1
RUN nix-env -iA nixpkgs.nixops nixpkgs.bash
CMD /bin/bash