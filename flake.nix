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
      in
      {
        formatter = pkgs.nixfmt-rfc-style;

        packages = {
          inherit wgdashboard;
          theau-vps-bundle = theauVpsBundle;
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
    );
}
