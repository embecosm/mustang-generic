# SPDX-FileCopyrightText: Copyright (c) 2023 by Rivos Inc.
# SPDX-License-Identifier: MIT
{
  config,
  pkgs,
  lib,
  modulesPath,
  workloadPkgs,
  ...
}: let
  inherit (builtins) all elem map attrNames;
  inherit (lib) mkOption splitString types;
  inherit (lib.lists) flatten forEach unique;

  cpuCfgGenerator = import ./generator.nix;
  cpuCfgTxt = cpuCfgGenerator {inherit config lib workloadPkgs;};

  benchsets = import ../../lib/cpu2017/benchsets.nix;

  runlistEnum =
    benchsets.cpu2017.cpu
    ++ [
      "intrate"
      "fprate"
      "specrate"
      "specrate_no_fortran"
      "intspeed"
      "fpspeed"
      "specspeed"
    ];

  # Expand a benchmark set into its constituent benchmarks.
  expandRunlist = name: benchsets.cpu2017."${name}" or name;

  # Turn a runlist, potentially with benchmark sets, into a list of individual
  # benchmarks.
  normalizeRunlist = runlist: unique (flatten (map expandRunlist runlist));

  # Call the packages to do runsetup for each benchmark. This uses the normalized runlist
  # so we know that each package is setting up only a single benchmark.
  runsetupPkgs = builtins.listToAttrs (forEach config.cpu2017.normalizedRunlist (
    benchname: {
      name = benchname;
      value = workloadPkgs.callPackage ../../lib/runsetup.nix {
        inherit benchname;
        specConfig = pkgs.writeTextFile {
          name = "cpu2017-${benchname}.cfg";
          text = cpuCfgTxt;
        };
        stdenv = config.workloads.modifiedStdenv;
      };
    }
  ));
  runsetupDerivation = pkgs.linkFarmFromDrvs "cpu2017-runsetup" (builtins.attrValues runsetupPkgs);

  # Same for runscripts.
  runscriptPkgs = builtins.listToAttrs (forEach config.cpu2017.normalizedRunlist (
    benchname: {
      name = benchname;
      value = pkgs.callPackage ../../lib/runscript.nix {
        inherit benchname workloadPkgs;
        qemuWrapperCfg = config.qemu-wrapper;
        workloadsCfg = config.workloads;
        runsetup = runsetupPkgs."${benchname}";
      };
    }
  ));

  cfgOpts = (import ./cpu2017-options.nix) {
    inherit config lib;
  };
in {
  options = {
    cpu2017 = {
      pkg = mkOption {
        type = types.package;
        default = workloadPkgs.buildPackages.cpu2017;
        description = ''
          CPU2017 package.
        '';
      };
      runlist = mkOption {
        type = types.listOf (types.enum runlistEnum);
        description = ''
          List of benchmarks to run. Benchmarks may be enumerated by name, or
          benchmark sets intrate, fprate, or specrate.
        '';
      };

      normalizedRunlist = mkOption {
        type = types.listOf (types.enum benchsets.cpu2017.cpu);
        readOnly = true;
        description = ''
          Normalized list of benchmarks to run. Benchsets have been replaced
          with individual benchmarks, and duplicates removed.
        '';
      };

      tune = mkOption {
        default = "base";
        type = types.enum ["base" "peak"];
        description = ''
          Tuning for benchmark builds. See SPEC CPU 2017 documentation for details.
        '';
      };

      cfg = mkOption {
        type = types.lines;
        description = ''
          Rendered spec config.
        '';
      };

      cfgFile = mkOption {
        type = types.package;
        description = ''
          Rendered spec config file.
        '';
      };

      runsetupPkgs = mkOption {
        type = types.attrsOf types.package;
        readOnly = true;
        description = ''
          Runsetup packages for cpu2017 benchmarks in the runlist.
        '';
      };

      runscriptPkgs = mkOption {
        type = types.attrsOf types.package;
        description = ''
          Scripts to run SPEC with this configuration.
        '';
      };

      patches = mkOption {
        type = types.attrsOf (types.listOf types.path);
        default = {};
        description = ''
          Patches to apply to specific benchmarks.
        '';
      };

      cfgSections = mkOption {
        type = types.attrsOf (types.attrsOf (types.submodule cfgOpts));
        default = {};
        description = ''
          Organized in a hierarchy similar to the runcpu config, with the omission of labels.
          The top-level attributes can consist of
            default
            a benchset (e.g. fprate)
            a benchmark name (e.g. 525.x264_r)
          or a comma separated list of the above (minus default).
          Second level attributes must be tuning: default, base, peak, or a comma separated list of base and peak..
          Third level attributes may be runcpu config options
          https://www.spec.org/cpu2017/Docs/config.html#Dtoc_II
          or specmake options.
          https://www.spec.org/cpu2017/Docs/makevars.html
        '';
      };

      baseOptimizeFlags = mkOption {
        type = types.listOf types.str;
        description = ''
          Base optimization flags for benchmarks.
        '';
      };
    };
  };

  config = {
    assertions = let
      isValidBenchSectionSpecifier = name:
        if name == "default"
        then true
        else all (component: elem component runlistEnum) (splitString "," name);
    in [
      {
        assertion = all (name: isValidBenchSectionSpecifier name) (attrNames config.cpu2017.cfgSections);
        message = "Config section names must follow the description at https://www.spec.org/cpu2017/Docs/config.html#sectionI.D.7";
      }
    ];
    cpu2017 = rec {
      cfg = cpuCfgTxt;

      cfgFile = pkgs.writeTextFile {
        name = "default.cfg";
        text = config.cpu2017.cfg;
      };

      normalizedRunlist = normalizeRunlist config.cpu2017.runlist;

      inherit runsetupPkgs runscriptPkgs;
    };
    build.runsetup = runsetupDerivation;
  };
}
