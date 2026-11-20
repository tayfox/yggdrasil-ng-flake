{ stdenv, fetchgit, fetchurl, lib }:

stdenv.mkDerivation rec {
  pname = "yggdrasil-ng";
  version = "v0.3.2";

src = fetchurl {
  url = "https://github.com/Revertron/Yggdrasil-ng/releases/download/${version}/yggdrasil-amd64";
  sha256 = "sha256-e2wm4AVJEngsSezXqj+1NprVp4Uu79xNne7nA1+g9CY=";
};

dontUnpack = true;

installPhase = ''
  mkdir -p $out/bin
  install -Dm755 $src $out/bin/yggdrasil-ng
'';

  meta = {
    description = "Prebuilt yggdrasil-ng binary";
    platforms = [ "x86_64-linux" ];
  };
}