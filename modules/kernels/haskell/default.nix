{
  self,
  system,
  config,
  lib,
  mkKernel,
  ...
}: let
  inherit (lib) types;

  kernelName = "haskell";
  kernelOptions = {
    config,
    name,
    ...
  }: let
    requiredRuntimePackages = [
      config.nixpkgs.haskell.compiler.${config.haskellCompiler}
    ];
    args = {inherit self system lib config name kernelName requiredRuntimePackages;};
    kernelModule = import ./../../kernel.nix args;
    kernelFunc = {
      self,
      system,
      pkgs ? self.inputs.nixpkgs.legacyPackages.${system},
      name ? "haskell",
      displayName ? "Haskell",
      requiredRuntimePackages ? [pkgs.haskell.compiler.${haskellCompiler}],
      runtimePackages ? [],
      haskellKernelPkg ? import "${self.inputs.ihaskell}/release.nix",
      haskellCompiler ? "ghc902",
      extraHaskellFlags ? "-M3g -N2",
      extraHaskellPackages ? (_: []),
    }: let
      allRuntimePackages = requiredRuntimePackages ++ runtimePackages;

      env = haskellKernelPkg {
        compiler = haskellCompiler;
        nixpkgs = pkgs;
        packages = extraHaskellPackages;
      };

      kernelspec = let
        ihaskellGhcLib = env.ihaskellGhcLibFunc env.ihaskellExe env.ihaskellEnv;
        wrappedEnv =
          pkgs.runCommand "wrapper-${ihaskellGhcLib.name}"
          {nativeBuildInputs = [pkgs.makeWrapper];}
          ''
            mkdir -p $out/bin
            for i in ${ihaskellGhcLib}/bin/*; do
              filename=$(basename $i)
              ln -s ${ihaskellGhcLib}/bin/$filename $out/bin/$filename
              wrapProgram $out/bin/$filename \
                --set PATH "${pkgs.lib.makeSearchPath "bin" allRuntimePackages}"
            done
          '';
      in
        env.ihaskellKernelFileFunc
        wrappedEnv
        extraHaskellFlags;
    in {
      inherit name displayName;
      language = "haskell";
      # See https://github.com/IHaskell/IHaskell/pull/1191
      argv = kernelspec.argv ++ ["--codemirror" "Haskell"];
      codemirrorMode = "Haskell";
      logo64 = ./logo-64x64.png;
    };
  in {
    options =
      {
        ihaskell = lib.mkOption {
          type = types.path;
          default = self.inputs.ihaskell;
          defaultText = lib.literalExpression "self.inputs.ihaskell";
          example = lib.literalExpression "self.inputs.ihaskell";
          description = lib.mdDoc ''
            ihaskell flake input to be used for this ${kernelName} kernel.
          '';
        };

        haskellCompiler = lib.mkOption {
          type = types.str;
          default = "ghc902";
          example = "ghc943";
          description = lib.mdDoc ''
            haskell compiler
          '';
        };

        extraHaskellFlags = lib.mkOption {
          type = types.str;
          default = "-M3g -N2";
          example = "-M3g -N2";
          description = lib.mdDoc ''
            haskell compiler flags
          '';
        };

        extraHaskellPackages = lib.mkOption {
          type = types.functionTo (types.listOf types.package);
          default = _: [];
          defaultText = lib.literalExpression "ps: []";
          example = lib.literalExpression "ps: [ps.lens ps.vector]";
          description = lib.mdDoc ''
            extra haskell packages
          '';
        };
      }
      // kernelModule.options;

    config = lib.mkIf config.enable {
      build = mkKernel (kernelFunc config.kernelArgs);
      kernelArgs =
        {
          inherit (config) extraHaskellFlags extraHaskellPackages;
          haskellKernelPkg = import "${config.ihaskell}/release.nix";
        }
        // kernelModule.kernelArgs;
    };
  };
in {
  options.kernel.${kernelName} = lib.mkOption {
    type = types.attrsOf (types.submodule kernelOptions);
    default = {};
    example = lib.literalExpression ''
      {
        kernel.${kernelName}."example".enable = true;
      }
    '';
    description = lib.mdDoc ''
      A ${kernelName} kernel for IPython.
    '';
  };
}
