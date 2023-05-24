# SPDX-FileCopyrightText: Copyright (c) 2022 by Rivos Inc.
# SPDX-License-Identifier: MIT
# Module for configuring workloads.
{
  nixpkgs,
  lib,
  config,
  ...
}: let
  inherit (lib) optional types mkDefault mkOption mkOptionType;

  cfg = config.workloads;

  # From nixos/modules/misc/nixpkgs.nix
  overlayType = mkOptionType {
    name = "nixpkgs-overlay";
    description = "nixpkgs overlay";
    check = lib.isFunction;
    merge = lib.mergeOneOption;
  };

  workloadPkgs = nixpkgs {
    config.allowUnfree = true;

    localSystem = config.nixpkgs.localSystem;
    crossSystem = cfg.system;
    overlays =
      config.nixpkgs.overlays
      ++ cfg.overlays;
    # If we want to embed debug info, make sure the entire cross-environment
    # is built with it and not stripped.
    crossOverlays =
      cfg.crossOverlays
      ++ optional cfg.embedDebugInfo (final: prev: {
        stdenv = prev.rivosAdapters.embedDebugInfo prev.stdenv;
      });
  };
  stdenvMods =
    (optional (cfg.ccToolchain != null) ((lib.flip workloadPkgs.stdenvAdapters.overrideCC) cfg.ccToolchain))
    ++ (optional cfg.disableHardening workloadPkgs.rivosAdapters.disableHardening)
    ++ (optional cfg.embedDebugInfo workloadPkgs.rivosAdapters.embedDebugInfo)
    ++ (optional cfg.staticBinaries workloadPkgs.rivosAdapters.makeStatic);
  modifiedStdenv = workloadPkgs.rivosAdapters.modifyStdenv workloadPkgs.stdenv stdenvMods;
in {
  options.workloads = {
    system = mkOption {
      type = types.attrs;
      description = ''
        A system definition suitable for use as crossSystem in nixpkgs.
        Used to build workloads.
      '';
    };
    overlays = mkOption {
      type = types.listOf overlayType;
      default = [];
      description = ''
        Additional overlays for build deps of workloads only.
      '';
    };
    crossOverlays = mkOption {
      type = types.listOf overlayType;
      default = [];
      description = ''
        Additional overlays for runtime deps of workloads only.
      '';
    };
    embedDebugInfo = mkOption {
      type = types.bool;
      default = true;
      description = ''
        When true, extensive debugging information is turned on and built directly into binaries/libraries.
      '';
    };

    staticBinaries = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether or not to build binaries statically.
      '';
    };

    disableHardening = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Disable all hardening that nix forcibly enables by default.
      '';
    };

    ccToolchain = mkOption {
      type = types.nullOr types.package;
      description = ''
        Toolchain to use for building C and C++ workloads.
      '';
    };

    modifiedStdenv = mkOption {
      type = types.package;
      description = ''
        stdenv modified for workloads.
      '';
    };
  };

  config._module.args = rec {
    inherit workloadPkgs;
  };
  config.workloads = {
    ccToolchain = mkDefault workloadPkgs.buildPackages.gcc;
    modifiedStdenv = mkDefault modifiedStdenv;
  };
}
