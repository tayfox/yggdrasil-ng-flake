{
  description = "Yggdrasil-ng: package and NixOS-module";

  outputs = { self, nixpkgs }: let
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
  in {
    packages.x86_64-linux.yggdrasil-ng = pkgs.callPackage ./yggdrasil-ng-drv.nix {};

    nixosModules.yggdrasil-ng = ./yggdrasil-ng.nix;

    # алиас, чтобы подключать просто как `yggdrasil-ng.nixosModules.default`
    nixosModules.default = self.nixosModules.yggdrasil-ng;
  };
}