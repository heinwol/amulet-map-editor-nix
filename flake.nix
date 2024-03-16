{
  description = "Description for the project";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    poetry2nix = {
      url = "github:nix-community/poetry2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        # To import a flake module
        # 1. Add foo to inputs
        # 2. Add foo as a parameter to the outputs function
        # 3. Add here: foo.flakeModule

      ];
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
      perSystem = { config, self', inputs', pkgs, system, ... }:
        let
          poetry2nixLib = (inputs.poetry2nix.lib.mkPoetry2Nix { inherit pkgs; });
          p2n-overrides = poetry2nixLib.defaultPoetryOverrides.extend
            (self: super: {
              clipboard = super.clipboard.overridePythonAttrs (
                old: { buildInputs = (old.buildInputs or [ ]) ++ [ super.setuptools ]; }
              );
            });
          poetryAttrs = {
            projectDir = ./.;
            python = pkgs.python311;
            overrides = p2n-overrides;
            preferWheels = true; # I don't want to compile all that
          };
          app = (poetry2nixLib.mkPoetryApplication poetryAttrs).overrideAttrs
            (oldAttrs: rec {
              buildInputs = (oldAttrs.buildInputs or [ ]) (with pkgs; [ ]);
            });

        in
        {
          packages = { };
          apps = {
            default = app;
          };
        };
      flake = { };
    };
}
