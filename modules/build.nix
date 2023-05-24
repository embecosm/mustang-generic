# SPDX-FileCopyrightText: Copyright (c) 2023 by Rivos Inc.
# SPDX-License-Identifier: MIT
{lib, ...}: let
  inherit (lib) mkOption types;
in {
  options = {
    build = mkOption {
      default = {};
      description = ''
        Attribute set of derivations used to run analyses.
      '';
      type = types.submoduleWith {
        modules = [
          {
            freeformType = with types; lazyAttrsOf (uniq unspecified);
          }
        ];
      };
    };
  };
}
