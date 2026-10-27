# Based on Arch Linux libfprint packaging and rs0x29a's Goodix ID patch.
pkgname=libfprint
pkgver=1.94.100
pkgrel=1.2
pkgdesc='Fingerprint reader library with Goodix 27c6:6f94 support'
arch=(x86_64)
url='https://fprint.freedesktop.org/'
license=(LGPL-2.1-or-later)
depends=(libgcc glib2 glibc libgudev libgusb openssl pixman)
makedepends=(git glib2-devel gobject-introspection meson python-cairo python-gobject systemd)
provides=(libfprint-2.so)
groups=(fprint)
source=('git+https://gitlab.freedesktop.org/libfprint/libfprint.git#commit=80a4b5ec612892c5c056c48dddaa561452cf37ec'
        '0001-goodixmoc-add-27c6-6f94.patch')
# Git source is pinned to the full upstream v1.94.100 commit.
sha256sums=('SKIP' '09e8df5b3c00463afe2a51ac88e0cca83d7a81ef7b75baf558ce936d6e049361')

prepare() {
  cd "$srcdir/libfprint"
  patch --fuzz=0 -p1 < "$srcdir/0001-goodixmoc-add-27c6-6f94.patch"
}

build() {
  local setup_options=()
  if [[ -f build/meson-private/coredata.dat ]]; then
    setup_options+=(--reconfigure)
  fi
  # gtk-doc splits source paths containing spaces during installation.
  arch-meson "${setup_options[@]}" libfprint build -Ddrivers=all -Dinstalled-tests=false -Ddoc=false
  meson compile -C build
}

package() {
  meson install -C build --destdir "$pkgdir"
}
