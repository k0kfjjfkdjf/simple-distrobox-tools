# simple-distrobox-tools

> **EN, коротко:** a few small Bash scripts on top of [Distrobox](https://github.com/89luca89/distrobox)
> for Arch Linux. Type `apt install …` or `dnf install …` right on the host — the command runs
> inside an Ubuntu/Fedora container, and installed GUI apps appear in (and disappear from)
> your desktop menu automatically.

Набор небольших скриптов поверх Distrobox. Сделан для себя на Arch Linux + KDE Plasma,
но должен работать на любом дистрибутиве с `distrobox`, `podman` и systemd.

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

```bash
apt update && apt upgrade        # выполнится в контейнере ubuntu
apt install vlc                  # ярлык VLC сам появится в меню
apt remove vlc                   # …и сам исчезнет
dnf install ./программа.rpm      # в контейнере fedora (создастся при первом вызове)

dbx-install ~/Загрузки/app.deb   # сам выберет контейнер по типу файла
dbx-install -c fedora gimp       # по имени пакета в указанный контейнер
dbx-install -r -c ubuntu gimp    # удалить

dbx-sync                         # синхронизировать ярлыки вручную (обычно не нужно)
dbx-sync -n                      # показать, что изменится, ничего не меняя
```

`sudo` писать не нужно: он добавляется внутри контейнера, где пароль не требуется.

## Установка

```bash
sudo pacman -S --needed distrobox podman     # или аналог в вашем дистрибутиве
git clone https://github.com/k0kfjjfkdjf/simple-distrobox-tools.git
cd simple-distrobox-tools
./install.sh
```

Всё ставится в домашний каталог, без `sudo`: скрипты в `~/.local/bin`,
службы в `~/.config/systemd/user`. Если `~/.local/bin` нет в `PATH`, `install.sh` подскажет,
что добавить в `~/.bashrc`.

Удаление: `./install.sh --remove`. Контейнеры и уже вынесенные ярлыки при этом
не трогаются (контейнер удаляется как обычно — `distrobox rm имя`).

## Как это устроено

| Файл | Что делает |
|---|---|
| `dbx-pm` | Ставится ссылками `apt`, `apt-get`, `dnf` в `~/.local/bin`. По имени, под которым его вызвали, выбирает контейнер и выполняет там `sudo <команда> <аргументы>`. Вывод и вопросы `[Y/n]` идут прямо в ваш терминал. Внутри контейнера (где `~/.local/bin` тоже в `PATH`) сразу передаёт управление настоящему `/usr/bin/apt`, чтобы не вызывать сам себя. |
| `dbx-install` | Ставит `.deb`/`.rpm`-файлы или пакеты по имени в подходящий контейнер, создаёт его при необходимости (с собственным `--hostname`). |
| `dbx-sync` | Сравнивает приложения в контейнерах с ярлыками в `~/.local/share/applications`: новые выносит через `distrobox-export`, пропавшие убирает. Помнит, что выносил сам, и не трогает чужие ярлыки. |
| `systemd/dbx-sync.path` | Следит за файлом-триггером. В контейнеры с apt кладётся хук `DPkg::Post-Invoke`, который «трогает» этот файл после каждой установки/удаления — меню обновляется через пару секунд. |
| `systemd/dbx-sync.timer` | Раз в 10 минут — для dnf/zypper (у них хука нет) и ручных изменений. Остановленные контейнеры не будит. |

Распознаются ярлыки с `Type=Application`; служебные (`NoDisplay=true`, `Hidden=true`)
пропускаются.

## Настройки

`~/.config/dbx-tools/config` (создайте при необходимости):

```bash
DEB_BOX=ubuntu    DEB_IMAGE=ubuntu:24.04
RPM_BOX=fedora    RPM_IMAGE=fedora:latest
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
  Просто `apt …`.
- Если в системе уже есть настоящий `apt` или `dnf`, `install.sh` не будет его перекрывать.
- После удаления программы её иконка остаётся в `~/.local/share/icons` (безвредно).
- Distrobox — это удобство, а не изоляция: контейнер видит весь домашний каталог.
- Проверено на Arch Linux + KDE Plasma 6, Distrobox 1.8, Podman, контейнер Ubuntu 24.04.

## Похожие проекты

- [apx](https://github.com/Vanilla-OS/apx) из Vanilla OS — полноценный менеджер «подсистем»
  в контейнерах, экспорт ярлыков вручную.
- [BoxBuddy](https://github.com/dvlv/boxbuddyrs), DistroShelf — графические оболочки для Distrobox.
- [Bedrock Linux](https://bedrocklinux.org) — смешивание дистрибутивов на уровне всей системы.

Отличие этого набора — ярлыки синхронизируются **сами**, а команды выглядят как обычные
`apt`/`dnf` без префиксов.
