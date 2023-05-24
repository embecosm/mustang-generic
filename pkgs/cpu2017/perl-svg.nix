# SPDX-FileCopyrightText: Copyright (c) 2022 by Rivos Inc.
# Licensed under the MIT License; see LICENSE for details.
# SPDX-License-Identifier: MIT
{
  perlPackages,
  lib,
  fetchurl,
}:
with lib;
  perlPackages.buildPerlPackage {
    pname = "SVG";
    version = "2.86";
    src = fetchurl {
      url = "mirror://cpan/authors/id/M/MA/MANWAR/SVG-2.86.tar.gz";
      sha256 = "72c6eb6f86bb2c330280f9f3d342bb2673ad5da22d1f44fba3e04cfb5d30a67b";
    };
    meta = {
      description = "Perl extension for generating Scalable Vector Graphics (SVG) documents";
      license = with lib.licenses; [artistic1 gpl1Plus];
    };
  }
