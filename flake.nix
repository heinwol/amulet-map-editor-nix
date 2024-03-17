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

      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
      perSystem = { config, self', inputs', pkgs, system, ... }:
        let
          poetry2nixLib = (inputs.poetry2nix.lib.mkPoetry2Nix { inherit pkgs; });

          pythonPkgs = pkgs.python311Packages;

          pypkgs-build-requirements = with pkgs; {
            amulet-leveldb = [ "setuptools" "cython" zlib.dev ];
            amulet-nbt = [ "setuptools" "cython" "versioneer" ];
            amulet-map-editor = [ "setuptools" "cython" "versioneer" ];
          };

          p2n-overrides = poetry2nixLib.defaultPoetryOverrides.extend
            (self: super:
              (builtins.mapAttrs
                (package: build-requirements:
                  (builtins.getAttr package super).overridePythonAttrs (old: {
                    buildInputs = (old.buildInputs or [ ]) ++ (
                      builtins.map
                        (pkg:
                          if builtins.isString pkg
                          then builtins.getAttr pkg super
                          else pkg)
                        build-requirements
                    );
                  })
                )
                pypkgs-build-requirements)
              // { inherit (pythonPkgs) wxpython numpy pillow pyopengl; }
            );

          poetryAttrs = {
            projectDir = ./.;
            # python = pkgs.python311;
            overrides = p2n-overrides;
            preferWheels = true; # I don't want to compile all that
          };

          # devEnv = poetry2nixLib.mkPoetryEnv (poetryAttrs // {
          #   # groups = [ "dev" "test" ];
          # });

          app = (poetry2nixLib.mkPoetryApplication poetryAttrs).overrideAttrs
            (oldAttrs: rec {
              nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ])
                ++ (with pkgs; [ wrapGAppsHook libGLU ]);
            });
        in
        {
          packages = {
            default = app;
          };
          devShells = {
            default = app.dependencyEnv;
          };
        };
    };
}
