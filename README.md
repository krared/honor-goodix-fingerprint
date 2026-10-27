# Goodix 27c6:6f94 на HONOR под CachyOS

Пакет libfprint с поддержкой сканера отпечатков Goodix USB `27c6:6f94`.
Патч добавляет USB ID и число этапов регистрации в существующий драйвер
`goodixmoc`. Это адаптация существующего драйвера, а не новый драйвер с нуля.

## Проверено на устройстве

27 октября 2026 года на HONOR `MRB-XXX` под CachyOS:

- libfprint `1.94.100-1.2`, fprintd `1.94.5-2.1`;
- сборка и установка пакета выполнены;
- регистрация завершилась `enroll-completed`;
- проверка завершилась `verify-match`.

Вход, разблокировка и sudo по отпечатку не проверялись. Скрипт не меняет PAM.
Одинаковый USB ID не гарантирует одинаковый протокол на других моделях.

## Установка

Требуются CachyOS или совместимая система Arch Linux и сканер `27c6:6f94`.
Запускай обычным пользователем; sudo запросит пароль в терминале.

```bash
git clone https://github.com/krared/honor-goodix-fingerprint.git
cd honor-goodix-fingerprint
bash install.sh
fprintd-enroll
fprintd-verify
```

При регистрации прикладывай палец по приглашениям программы.
Исходники закреплены на коммите релиза libfprint 1.94.100, пакет устанавливается
через pacman. Документация отключена: gtk-doc некорректно обрабатывает
пути с пробелами при упаковке. Повторная сборка перенастраивает Meson.

Для одной только сборки после установки зависимостей:

```bash
makepkg --syncdeps
```

## Диагностика и откат

```bash
lsusb -d 27c6:6f94
pacman -Q libfprint fprintd
fprintd-list "$USER"
journalctl -u fprintd -b --no-pager -n 80
```

Чтобы вернуться к пакету из репозитория дистрибутива:

```bash
sudo pacman -S libfprint
sudo systemctl restart fprintd
```

Обновление дистрибутива может заменить локальный патч. Перед повторной
сборкой проверь, не появилась ли поддержка устройства в новой версии libfprint.
Пакет закреплён на старой версии: не используй его для бессрочной блокировки
обновлений библиотеки.

## Источники и лицензия

- [libfprint](https://gitlab.freedesktop.org/libfprint/libfprint), релиз
  1.94.100, коммит `80a4b5ec612892c5c056c48dddaa561452cf37ec`.
- [Патч rs0x29a](https://github.com/rs0x29a/Linux-on-HONOR-MagicBook-14-Pro-2026-AI_ZQC-P_M1010/tree/95631852eeda83b8a32a4913f5431475daad3ca1/patch/fingerprint/zqc-p/M1010).
  Патч перенесён без изменения; PKGBUILD основан на Arch Linux и рецепте
  этого проекта.
- [Альтернативная реализация SDCP для того же USB ID](https://github.com/andreas-fe/goodix-27c6-6f94-linux-driver).
  В этот пакет не включена и на данном ноутбуке не использовалась.

libfprint распространяется под LGPL-2.1-or-later; текст лицензии в `COPYING`.
Исходные права и авторство upstream сохраняются. Новые скрипты и изменения
рецепта в этом репозитории также распространяются под LGPL-2.1-or-later.
