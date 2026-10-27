#!/usr/bin/env bash
set -euo pipefail
if (( EUID != 0 )) && [[ "${1:-}" != --check ]]; then
  echo "Запусти: sudo bash '$0'" >&2
  exit 1
fi
/usr/bin/python3 - "${1:-}" <<'PY'
from pathlib import Path
import os
import re
import shutil
import tempfile
import sys

pam = Path('/etc/pam.d')
vendor = Path('/usr/lib/pam.d')
if not Path('/usr/lib/security/pam_fprintd.so').is_file():
    raise SystemExit('Не найден pam_fprintd.so')

def read_service(name):
    path = pam / name
    return (path if path.exists() else vendor / name).read_text()

def replace_auth(text, old, new):
    pattern = rf'^(auth\s+include\s+){re.escape(old)}(\s*)$'
    result, count = re.subn(pattern, rf'\g<1>{new}\g<2>', text, flags=re.M)
    if count != 1:
        raise SystemExit(f'Неожиданный PAM-профиль: ожидалась одна строка auth include {old}. Изменений нет.')
    return result

auth = read_service('system-auth')
if 'pam_fprintd.so' in auth:
    raise SystemExit('В system-auth уже есть pam_fprintd; нужна ручная проверка, изменений нет.')
# Keep the existing faillock preauth check before fingerprint authentication.
lines = auth.splitlines(keepends=True)
positions = [i for i, line in enumerate(lines)
             if re.match(r'^auth\s+', line) and 'pam_faillock.so' in line and 'preauth' in line]
if len(positions) != 1:
    raise SystemExit('Не найден однозначный pam_faillock preauth; изменений нет.')
lines.insert(positions[0] + 1, 'auth sufficient pam_fprintd.so max-tries=3 timeout=10\n')
outputs = {'honor-fingerprint-auth': ''.join(lines)}
outputs['honor-fingerprint-login'] = replace_auth(read_service('system-login'), 'system-auth', 'honor-fingerprint-auth')
for service in ('sudo', 'polkit-1'):
    text = read_service(service)
    # Replace the earlier optional Polkit-only setup if it has been applied.
    if service == 'polkit-1':
        text = re.sub(r'^auth sufficient pam_fprintd\.so max-tries=3 timeout=10\n', '', text, flags=re.M)
    if 'pam_fprintd.so' in text:
        raise SystemExit(f'{service}: уже есть другая настройка отпечатка; изменений нет.')
    outputs[service] = replace_auth(text, 'system-auth', 'honor-fingerprint-auth')
outputs['plasmalogin'] = replace_auth(read_service('plasmalogin'), 'system-login', 'honor-fingerprint-login')

if sys.argv[1] == '--check':
    print('Профили проверены; подготовлены: ' + ', '.join(outputs))
    print('system-auth: pam_faillock preauth сохранён перед pam_fprintd.')
    print('Проверка без записи файлов завершена.')
    raise SystemExit(0)

backup = Path(tempfile.mkdtemp(prefix='honor-pam-backup.', dir='/etc'))
os.chmod(backup, 0o700)
rollback = ['#!/bin/bash', 'set -euo pipefail']
for name in outputs:
    target = pam / name
    if target.is_symlink():
        raise SystemExit(f'{target}: символическая ссылка; изменений нет.')
    if target.exists():
        shutil.copy2(target, backup / name)
        rollback.append(f"cp -p -- '{backup / name}' '{target}'")
    else:
        rollback.append(f"rm -f -- '{target}'")
(backup / 'restore.sh').write_text('\n'.join(rollback) + '\n')
os.chmod(backup / 'restore.sh', 0o700)
try:
    for name, content in outputs.items():
        fd, temporary = tempfile.mkstemp(prefix='.honor-pam.', dir=pam)
        try:
            with os.fdopen(fd, 'w') as stream:
                stream.write(content)
            os.chmod(temporary, 0o644)
            os.replace(temporary, pam / name)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)
except Exception:
    import subprocess
    subprocess.run(['/bin/bash', str(backup / 'restore.sh')], check=True)
    raise
print('Настроены sudo, Polkit (включая KeePassXC) и Plasma Login.')
print('Пароль остаётся доступен после отказа отпечатка или тайм-аута 10 секунд.')
print('Исходный system-auth и настройки SSH не изменены.')
print(f'Откат: sudo bash {backup / "restore.sh"}')
PY
