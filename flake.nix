{
  description = "Personal infrastructure repo for an Ubuntu 24.04 VPS managed with Nix-built artifacts";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    wgdashboard-src = {
      url = "github:WGDashboard/WGDashboard?ref=v4.3.2";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      wgdashboard-src,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        hostSpec = import ./hosts/theau-vps;
        wgdashboard = pkgs.callPackage ./packages/wgdashboard {
          src = wgdashboard-src;
        };
        theauVpsBundle = pkgs.callPackage ./packages/bundle {
          inherit hostSpec wgdashboard;
        };
        mkHostTarball =
          hostName:
          let
            hostSystem = self.nixosConfigurations.${hostName}.config.system.build.toplevel;
          in
          pkgs.runCommand "${hostName}-system.tar.gz" { } ''
            mkdir -p root
            ln -s ${hostSystem} root/system
            cat > root/README <<'EOF'
            This tarball contains a symlink to the evaluated ${hostName} NixOS
            system closure. It is a build artifact for validating the host
            configuration, not an installer image.
            EOF
            tar -czf "$out" -C root .
          '';
        jellyfinKotTarball = mkHostTarball "jellyfin-kot";
        seedboxKotTarball = mkHostTarball "seedbox-kot";
        jellyseerrKotTarball = mkHostTarball "jellyseerr-kot";
        kotMediaStackTarball = pkgs.runCommand "kot-media-stack.tar.gz" { } ''
          mkdir -p root
          ln -s ${jellyfinKotTarball} root/jellyfin-kot-system.tar.gz
          ln -s ${seedboxKotTarball} root/seedbox-kot-system.tar.gz
          ln -s ${jellyseerrKotTarball} root/jellyseerr-kot-system.tar.gz
          cat > root/README <<'EOF'
          This tarball groups the split Kot media service build artifacts:
          jellyfin-kot, seedbox-kot, and jellyseerr-kot.
          EOF
          tar -czf "$out" -C root .
        '';
      in
      {
        formatter = pkgs.nixfmt-rfc-style;

        packages = {
          inherit wgdashboard;
          theau-vps-bundle = theauVpsBundle;
          jellyfin-kot = jellyfinKotTarball;
          seedbox-kot = seedboxKotTarball;
          jellyseerr-kot = jellyseerrKotTarball;
          kot-media-stack = kotMediaStackTarball;
          default = theauVpsBundle;
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            age
            git
            jq
            nixfmt-rfc-style
            openssh
            python3
            rsync
            sops
            ssh-to-age
            yq-go
          ];
        };
      }
    )
    // {
      nixosConfigurations.jellyfin-kot = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./hosts/jellyfin-kot
        ];
      };
      nixosConfigurations.seedbox-kot = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./hosts/seedbox-kot
        ];
      };
      nixosConfigurations.jellyseerr-kot = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./hosts/jellyseerr-kot
        ];
      };
    };
}
