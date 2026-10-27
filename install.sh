#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
if (( EUID == 0 )); then
  echo 'Запускай этот скрипт обычным пользователем, без sudo.' >&2
  exit 1
fi
if ! lsusb -d 27c6:6f94 | head -n 1 | grep -q '27c6:6f94'; then
  echo 'Сканер Goodix 27c6:6f94 не обнаружен; установка остановлена.' >&2
  exit 1
fi
sudo pacman -S --needed base-devel git glib2-devel gobject-introspection meson python-cairo python-gobject fprintd
makepkg --syncdeps --install
sudo udevadm control --reload-rules
sudo systemctl restart fprintd
fprintd-list "$(id -un)"
echo 'Если устройство появилось: запусти fprintd-enroll, затем fprintd-verify.'
