# SPDX-FileCopyrightText: Copyright (c) 2023 by Rivos Inc.
# SPDX-License-Identifier: MIT
{
  lib,
  self,
  inputs,
  ...
}: let
  nixosModules = inputs.nixpkgs + "/nixos/modules/";
in {
  perSystem = {system, ...}: let
    evaluateCfg = {specRunCfg}: let
      requiredOverlays = [
        inputs.qemu.overlays.default
      ];
      cfg = lib.evalModules {
        modules = [
          {
            key = "nixpkgs";
            config = {
              _module.args = {nixpkgs = import inputs.nixpkgs;};
              nixpkgs = {
                localSystem = lib.mkDefault {inherit system;};
                config.allowUnfree = true;
                overlays = requiredOverlays;
              };
            };
          }
          (nixosModules + "/misc/nixpkgs.nix")
          ./modules/build.nix
          ./modules/icount.nix
          ./modules/workloads.nix
          ./modules/qemu-wrapper.nix
          specRunCfg
        ];
        # Pass gcc flake args along with module paths.
        # Remove nixpkgs since that argument will be set by the nixpkgs module.
        specialArgs =
          {
            nixosModulesPath = builtins.toString nixosModules;
            modulesPath = builtins.toString ./modules;
          }
          // (lib.filterAttrs (n: v: n != "nixpkgs") inputs)
          // {inherit (inputs.crosspkgs.inputs) gcc;};
      };
    in rec {
      config = cfg.config;

      icount = config.build.icount;
      runsetup = config.build.runsetup;
    };
  in {
    legacyPackages.specrate_gcc = evaluateCfg {
      specRunCfg = ./configs/cpu2017/specrate_gcc.nix;
    };
    legacyPackages.specrate_rvv_gcc = evaluateCfg {
      specRunCfg = ./configs/cpu2017/specrate_rvv_gcc.nix;
    };
  };
}
