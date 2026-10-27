#!/usr/bin/env bash
set -euo pipefail
if (( EUID != 0 )); then
  echo "Запусти: sudo bash '$0'" >&2
  exit 1
fi
/usr/bin/python3 - <<'PY'
from pathlib import Path
import os, re, shutil, tempfile

pam = Path('/etc/pam.d')
target = pam / 'sudo'
custom = pam / 'honor-sudo-fingerprint'
text = target.read_text()
if re.search(r'^auth\s+include\s+honor-sudo-fingerprint\s*$', text, re.M):
    print('Отпечаток для sudo уже настроен.')
    raise SystemExit(0)
if not Path('/usr/lib/security/pam_fprintd.so').is_file():
    raise SystemExit('Не найден pam_fprintd.so; изменений нет.')
auth = (pam / 'system-auth').read_text()
if 'pam_fprintd.so' in auth or custom.exists() or target.is_symlink():
    raise SystemExit('Нестандартная конфигурация PAM; нужна проверка. Изменений нет.')
lines = auth.splitlines(keepends=True)
positions = [i for i, line in enumerate(lines)
             if re.match(r'^auth\s+', line) and 'pam_faillock.so' in line and 'preauth' in line]
if len(positions) != 1:
    raise SystemExit('Неожиданный system-auth; изменений нет.')
lines.insert(positions[0] + 1, 'auth sufficient pam_fprintd.so max-tries=3 timeout=10\n')
updated, count = re.subn(r'^(auth\s+include\s+)system-auth(\s*)$',
                         r'\g<1>honor-sudo-fingerprint\g<2>', text, flags=re.M)
if count != 1:
    raise SystemExit('Неожиданный профиль sudo; изменений нет.')
backup = Path(tempfile.mkdtemp(prefix='honor-sudo-backup.', dir='/etc'))
os.chmod(backup, 0o700)
shutil.copy2(target, backup / 'sudo')
restore = backup / 'restore.sh'
restore.write_text(f"#!/bin/bash\nset -euo pipefail\ncp -p -- '{backup / 'sudo'}' '{target}'\nrm -f -- '{custom}'\n")
os.chmod(restore, 0o700)

def atomic_write(path, content):
    fd, name = tempfile.mkstemp(prefix='.honor-sudo.', dir=pam)
    try:
        with os.fdopen(fd, 'w') as stream:
            stream.write(content)
        os.chmod(name, 0o644)
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)

atomic_write(custom, ''.join(lines))
try:
    atomic_write(target, updated)
except Exception:
    custom.unlink()
    raise
print('Для sudo включён отпечаток, после отказа или тайм-аута доступен пароль.')
print(f'Откат: sudo bash {restore}')
PY
