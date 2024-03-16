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

          pythonPkgs = pkgs.python311Packages;

          pypkgs-build-requirements = with pkgs; {
            amulet-leveldb = [ "setuptools" "cython" zlib.dev ]; # "zlib-ng"
            amulet-nbt = [ "setuptools" "cython" "versioneer" ];
            amulet-map-editor = [ "setuptools" "cython" "versioneer" ];
            # wxpython = [ "setuptools" "sip" ];
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
              // { inherit (pythonPkgs) wxpython numpy pillow; }
              # )
              //
              {
                # wxpython = super.wxpython.overrideAttrs (oldAttrs: {
                #   # autoPatchelfIgnoreMissingDeps = true;
                #   # postFixup = ''
                #   #   rm -r $out/${self.python.sitePackages}/nvidia/{__pycache__,__init__.py}
                #   # '';
                #   propagatedBuildInputs = (oldAttrs.propagatedBuildInputs or [ ]) ++ [
                #     super.sip
                #     super.six
                #   ];
                #   nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [
                #     super.sip
                #     super.six
                #   ];
                #   propagatedBuildInputs = (oldAttrs.propagatedBuildInputs or [ ]) ++ [
                #     super.sip
                #     super.six
                #   ];
                # });
                # wxpython = super.wxpython.overridePythonAttrs (old:
                #   let
                #     localPython = self.python.withPackages (ps: with ps; [
                #       setuptools
                #       numpy
                #       six
                #       sip
                #     ]);
                #   in
                #   {
                #     DOXYGEN = "${pkgs.doxygen}/bin/doxygen";

                #     nativeBuildInputs = with pkgs; [
                #       which
                #       doxygen
                #       gtk3
                #       pkg-config
                #       autoPatchelfHook
                #     ] ++ (old.nativeBuildInputs or [ ]);

                #     buildInputs = with pkgs; [
                #       gtk3
                #       webkitgtk
                #       ncurses
                #       SDL2
                #       xorg.libXinerama
                #       xorg.libSM
                #       xorg.libXxf86vm
                #       xorg.libXtst
                #       xorg.xorgproto
                #       gst_all_1.gstreamer
                #       gst_all_1.gst-plugins-base
                #       libGLU
                #       libGL
                #       libglvnd
                #       mesa
                #     ] ++ (old.buildInputs or [ ]);

                #     buildPhase = ''
                #       ${localPython.interpreter} build.py -v build_wx
                #       ${localPython.interpreter} build.py -v dox etg --nodoc sip
                #       ${localPython.interpreter} build.py -v build_py
                #     '';

                #     installPhase = ''
                #       ${localPython.interpreter} setup.py install --skip-build --prefix=$out
                #     '';
                #   });
              }

            );

          poetryAttrs = {
            projectDir = ./.;
            # python = pkgs.python311;
            overrides = p2n-overrides;
            preferWheels = true; # I don't want to compile all that
          };

          devEnv = poetry2nixLib.mkPoetryEnv (poetryAttrs // {
            # groups = [ "dev" "test" ];
          });

          app = (poetry2nixLib.mkPoetryApplication poetryAttrs).overrideAttrs
            (oldAttrs: rec {
              buildInputs = (oldAttrs.buildInputs or [ ]) ++ (with pkgs; [ ]);
            });
          # devEnvPopulated =
          #   (devEnv.env.overrideAttrs (oldAttrs: rec {
          #     name = "py";
          #     buildInputs = with pkgs;
          #       (oldAttrs.buildInputs or [ ])
          #       # ++ buildInputs-base
          #       ++ [

          #       ];
          #     # shellHook = ''
          #     #   export MYPYPATH=$PWD/sponge_networks/
          #     # '';
          #   }));

        in
        {
          packages = {
            default = app;
          };
          devShells = {
            # default = devEnvPopulated;
          };

          # apps = {
          #   default = app;
          # };
        };
      flake = { };
    };
}
