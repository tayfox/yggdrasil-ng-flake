How to use:

```
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    yggdrasil-ng.url = "github:/tayfox/yggdrasil-ng-flake";
  };
  outputs = { self, nixpkgs, yggdrasil-ng }: {
    nixosConfigurations.<hostname> = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        yggdrasil-ng.nixosModules.default
      ];
    };
  };
}
```