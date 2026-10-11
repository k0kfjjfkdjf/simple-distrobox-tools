# simple-distrobox-tools

> **EN, коротко:** small Bash tools on top of [Distrobox](https://github.com/89luca89/distrobox)
> for Arch Linux and Steam Deck. `dbx install vlc` searches the host (pacman, AUR) and every
> container (apt, dnf, pacman, zypper) at once and asks where to install from. Plain `apt`, `dnf`,
> `pacman`, `yay` typed on the host run inside the matching container, and installed GUI apps
> appear in (and disappear from) your desktop menu automatically.

Набор небольших скриптов поверх Distrobox. Сделан для себя на Arch Linux + KDE Plasma,
работает и на **Steam Deck (SteamOS)**, и вообще на любом дистрибутиве с `distrobox`,
`podman` и systemd. Всё ставится в домашний каталог, поэтому подходит и для систем
с корнем только для чтения.

## Зачем

Иногда нужна программа, которая есть только в виде `.deb` или `.rpm`, или только
в репозиториях Ubuntu/Fedora. Distrobox решает это контейнером, но в повседневной
работе мешают мелочи:

- каждый раз заходить в контейнер (`distrobox enter …`), чтобы что-то поставить;
- вручную выносить ярлык в меню (`distrobox-export --app …`) и не забыть убрать его
  после удаления программы;
- путаться, где ты сейчас — на хосте или в контейнере.

Эти скрипты убирают все три пункта.

## Что умеет

### `dbx` — один менеджер поверх всего

```bash
dbx install vlc      # ищет везде сразу и спрашивает, откуда ставить
dbx search vlc       # поиск по всем источникам
dbx remove vlc       # сам находит, где установлен
dbx upgrade          # обновляет систему, flatpak и все контейнеры (-y — без вопросов)
dbx sources          # какие источники сейчас доступны
```

```
«vlc» есть здесь:
   1) Arch — хост (pacman)  vlc  3.0.21-10
   2) ubuntu (apt)          vlc  3.0.20-3build6  [установлен]
   3) fedora (dnf)          vlc  3.0.21-15.fc41
   4) AUR — хост (yay)      ...

Откуда ставить? [1-4, Enter = 1, q = отмена]:
```

Источники определяются сами: pacman хоста (если он живой), AUR (yay/paru хоста или yay
в контейнере `arch`) и каждый контейнер Distrobox со своим apt / dnf / pacman / zypper.
На Steam Deck pacman системы пропускается без ошибок; если контейнера `arch` ещё нет,
Arch и AUR ищутся через их сайты, а контейнер создаётся при установке.

### Привычные команды прямо на хосте

```bash
apt update && apt upgrade        # выполнится в контейнере ubuntu
apt install vlc                  # ярлык VLC сам появится в меню
apt remove vlc                   # …и сам исчезнет
dnf install ./программа.rpm      # в контейнере fedora (создастся при первом вызове)
pacman -S htop                   # Steam Deck: в контейнере arch
yay -S spotify                   # Steam Deck: AUR в контейнере arch (yay поставится сам)

dbx-install ~/Загрузки/app.deb   # сам выберет контейнер по типу файла
dbx-install -c fedora gimp       # по имени пакета в указанный контейнер
dbx-install -r -c ubuntu gimp    # удалить
dbx-install ./пакет.pkg.tar.zst  # пакет Arch → контейнер arch

dbx-sync                         # синхронизировать ярлыки вручную (обычно не нужно)
dbx-sync -n                      # показать, что изменится, ничего не меняя
```

`sudo` писать не нужно: он добавляется внутри контейнера, где пароль не требуется.

## Установка

Одна команда для любой системы — Arch, Steam Deck, Fedora, Ubuntu и др.:

```bash
curl -fsSL https://raw.githubusercontent.com/k0kfjjfkdjf/simple-distrobox-tools/main/get.sh | bash
```

Установщик сам определит систему и при необходимости поставит `distrobox` и `podman`:

| Система | Что делает |
|---|---|
| Arch и производные | `sudo pacman -S distrobox podman` (спросит пароль) |
| SteamOS (Steam Deck) | ничего — всё встроено с SteamOS 3.5; если distrobox нет, кладёт его в `~/.local` |
| Fedora / Debian / Ubuntu / openSUSE | `dnf` / `apt-get` / `zypper` |
| Silverblue, Bazzite (rpm-ostree) | ничего — distrobox обычно встроен |

Дальше всё ставится в домашний каталог, без `sudo`: файлы проекта в
`~/.local/share/simple-distrobox-tools`, команды в `~/.local/bin`, службы в
`~/.config/systemd/user`. `~/.local/bin` сам добавляется в `PATH`. Поэтому всё
переживает обновления SteamOS и других систем с корнем только для чтения.
После установки откройте новый терминал.

**Обновление** — та же команда ещё раз.
**Удаление** — `bash ~/.local/share/simple-distrobox-tools/install.sh --remove`
(контейнеры и уже вынесенные ярлыки не трогаются; контейнер удаляется как обычно — `distrobox rm имя`).

Вручную, без `curl | bash`:

```bash
git clone https://github.com/k0kfjjfkdjf/simple-distrobox-tools.git
cd simple-distrobox-tools && ./install.sh
```

### Steam Deck

Команду выше запускайте в Konsole в режиме рабочего стола. Программы появляются
в меню **режима рабочего стола**; чтобы запускать их из игрового режима, добавьте
ярлык в Steam как стороннюю игру («Добавить стороннюю игру»).

## Как это устроено

| Файл | Что делает |
|---|---|
| `dbx` | Общий менеджер: опрашивает все источники параллельно, показывает таблицу и ставит / удаляет / обновляет там, где выбрали. |
| `dbx-lib` | Общий код: настройки, проверка «жив ли pacman хоста», работа с контейнерами, установка yay в контейнер. |
| `dbx-pm` | Ставится ссылками `apt`, `apt-get`, `dnf` в `~/.local/bin` (а там, где pacman системы недоступен, — ещё `pacman` и `yay`). По имени, под которым его вызвали, выбирает контейнер и выполняет там `sudo <команда> <аргументы>`. Вывод и вопросы `[Y/n]` идут прямо в ваш терминал. Внутри контейнера (где `~/.local/bin` тоже в `PATH`) сразу передаёт управление настоящему `/usr/bin/apt`, чтобы не вызывать сам себя. |
| `dbx-install` | Ставит `.deb`/`.rpm`-файлы или пакеты по имени в подходящий контейнер, создаёт его при необходимости (с собственным `--hostname`). |
| `dbx-sync` | Сравнивает приложения в контейнерах с ярлыками в `~/.local/share/applications`: новые выносит через `distrobox-export`, пропавшие убирает. Помнит, что выносил сам, и не трогает чужие ярлыки. |
| `systemd/dbx-sync.path` | Следит за файлом-триггером. В контейнеры кладутся хуки (apt — `DPkg::Post-Invoke`, pacman — `/etc/pacman.d/hooks`), которые «трогают» этот файл после каждой установки/удаления — меню обновляется через пару секунд. |
| `systemd/dbx-sync.timer` | Раз в 10 минут — для dnf/zypper (у них хука нет) и ручных изменений. Остановленные контейнеры не будит. |

Распознаются ярлыки с `Type=Application`; служебные (`NoDisplay=true`, `Hidden=true`)
пропускаются.

## Настройки

`~/.config/dbx-tools/config` (создайте при необходимости):

```bash
DEB_BOX=ubuntu    DEB_IMAGE=ubuntu:24.04
RPM_BOX=fedora    RPM_IMAGE=fedora:latest
ARCH_BOX=arch     ARCH_IMAGE=docker.io/library/archlinux:latest
DBX_HOST_PACMAN=0 # не трогать pacman хоста (1 — использовать даже на SteamOS)
```

`~/.config/dbx-tools/ignore` — ярлыки, которые не нужно выносить в меню
(шаблоны `контейнер/имя.desktop`, например `ubuntu/debian-uxterm.desktop`).

Разово в другой контейнер: `DBX_BOX=debian apt install htop`.

## Совет: видно, где вы находитесь

По умолчанию приглашение в контейнере и на хосте одинаковое. Добавьте в `~/.bashrc`
(он общий для хоста и контейнеров):

```bash
if [ -n "$CONTAINER_ID" ]; then
  PS1='\[\e[1;35m\][📦 '"$CONTAINER_ID"']\[\e[0m\] \u \W\$ '
fi
```

## Ограничения

- `apt upgrade` обновляет **контейнер**, а не хост. Arch по-прежнему обновляется через `pacman`.
- На хосте нельзя писать `sudo apt …`: sudo не ищет команды в `~/.local/bin`.
  Просто `apt …`. На Steam Deck то же с pacman: `pacman -S …` без `sudo` уйдёт
  в контейнер, а `sudo pacman …` — в «мёртвый» pacman системы.
- Если в системе уже есть настоящий `apt` или `dnf`, `install.sh` не будет его перекрывать.
- После удаления программы её иконка остаётся в `~/.local/share/icons` (безвредно).
- Distrobox — это удобство, а не изоляция: контейнер видит весь домашний каталог.
- Проверено на Arch Linux + KDE Plasma 6, Distrobox 1.8, Podman, контейнер Ubuntu 24.04.
  Поддерживаются и старые Distrobox (без `--yes`/`--hostname` у `create`) и Plasma 5.

## Похожие проекты

- [apx](https://github.com/Vanilla-OS/apx) из Vanilla OS — полноценный менеджер «подсистем»
  в контейнерах, экспорт ярлыков вручную.
- [BoxBuddy](https://github.com/dvlv/boxbuddyrs), DistroShelf — графические оболочки для Distrobox.
- [Bedrock Linux](https://bedrocklinux.org) — смешивание дистрибутивов на уровне всей системы.

Отличие этого набора — ярлыки синхронизируются **сами**, а команды выглядят как обычные
`apt`/`dnf` без префиксов.
