# SPDX-FileCopyrightText: Copyright (c) 2022 by Rivos Inc.
# SPDX-License-Identifier: MIT
{
  stdenv,
  lib,
  callPackage,
  requireFile,
  makeWrapper,
  ncurses,
  xorriso,
  coreutils,
  gnumake,
  gnutar,
  perl,
  perlPackages,
  rxp,
  xz,
}: let
  SVG = callPackage ./perl-svg.nix {};
  disable-runcpu-test-patch = ./disable-runcpu-test.patch;
  perlModules = [
    perlPackages.ExporterTiny
    perlPackages.FileNFSLock
    perlPackages.FontAFM
    perlPackages.FontTTF
    perlPackages.IOString
    perlPackages.IOStringy
    perlPackages.ListMoreUtils
    perlPackages.MailTools
    perlPackages.MIMETools
    perlPackages.PDFAPI2
    perlPackages.StringShellQuote
    SVG
    perlPackages.TestDeep
    perlPackages.TextCSV
    perlPackages.TimeDate
    perlPackages.URI
    perlPackages.XMLNamespaceSupport
    perlPackages.XMLSAX
    perlPackages.XMLSAXBase
    perlPackages.XMLSAXExpat
    # XSLoader is part of perl as of 5.26.
  ];
in
  stdenv.mkDerivation rec {
    pname = "cpu2017";
    version = "1.1.9";

    src = requireFile {
      name = "cpu2017-${version}.iso";
      url = "file:///opt/cpu2017-1.1.9.iso";
      sha256 = "02fys6772zxwy3rxpw49gjwaxi9wrcd4zvm441jvjjgpgkvvsrwv";
    };

    unpackPhase = ''
      xorriso -osirrox on -indev "${src}" -extract / .
      chmod u+w tools
      tar xf ./install_archives/tools-src.tar
    '';

    patchPhase = ''
      patch -p1 < ${disable-runcpu-test-patch}
      patchShebangs --build tools/src
    '';

    dontConfigure = true;

    disallowedReferences = [stdenv.cc];

    buildPhase = ''
      mkdir -p tools/output/bin
      pushd tools/output/bin
      ln -s ${gnumake}/bin/make make
      ln -s ${gnutar}/bin/tar tar
      ln -s ${xz}/bin/xz xz
      for f in ${perl}/bin/*; do
        ln -s "$f" "$(basename "$f")"
      done
      ln -s ${rxp}/bin/rxp rxp
      popd
      mkdir -p tools/output/lib/perl5

      SKIPTOOLSINTRO=1 \
      SKIPCLEAN=1      \
      SKIPSTRIP=1      \
      SKIPMAKE=1       \
      SKIPXZ=1         \
      SKIPTAR=1        \
      SKIPPERL=1       \
      SKIPPERL2=1      \
      SKIPRXP=1        \
        ./tools/src/buildtools

      # shrc checks that the config dir exists and is writable
      mkdir -p config
      . shrc
      # The packaged tools will end up under tools/bin.
      chmod u+w tools/bin
      packagetools nix-x86_64
    '';

    # TODO: support other arches
    installPhase = ''
      PERL5LIB_TEST="$PERL5LIB" \
        ./install.sh -d "$out" -f -u nix-x86_64
    '';

    postFixup = ''
      wrapProgram $out/bin/specperl \
        --prefix PERL5LIB : "${perlPackages.makePerlPath perlModules}"
    '';

    outputs = ["out"];

    buildInputs =
      [
        gnumake
        gnutar
        perl
        rxp
        xz
      ]
      ++ perlModules;

    nativeBuildInputs = [
      makeWrapper
      ncurses
      xorriso
    ];

    meta = {
      homepage = "https://www.spec.org/cpu2017/";
      description = "The SPEC CPU 2017 benchmark suite";
      license = lib.licenses.unfree;
      platforms = [
        "aarch64-linux"
        "x86_64-linux"
      ];
    };

    passthru = {
      inherit perlModules;
    };
  }
