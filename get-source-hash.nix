(import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz") { }).fetchhg
  {
    url = "https://hg.mozilla.org/mozilla-central";
    rev = "279b57ef4bf0";
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  }
