#!/usr/bin/env bash
set -euo pipefail
if (( EUID != 0 )); then
  echo "Запусти: sudo bash '$0'" >&2
  exit 1
fi
SOURCE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SOURCE="$SOURCE_DIR/90-honor-fprintd-resume"
TARGET=/usr/lib/systemd/system-sleep/90-honor-fprintd-resume
[[ -f "$SOURCE" ]] || { echo 'Не найден исходник обработчика.' >&2; exit 1; }
if [[ -e "$TARGET" ]] && ! cmp -s -- "$SOURCE" "$TARGET"; then
  BACKUP="${TARGET}.backup-$(date +%Y%m%d-%H%M%S-%N)"
  cp -a -- "$TARGET" "$BACKUP"
  printf 'Предыдущий обработчик сохранен: %s\n' "$BACKUP"
fi
install -D -o root -g root -m 755 -- "$SOURCE" "$TARGET"
systemctl restart fprintd.service
echo 'Обработчик пробуждения установлен; fprintd перезапущен.'
echo 'Проверь отпечаток сейчас и после сна командой fprintd-verify.'
