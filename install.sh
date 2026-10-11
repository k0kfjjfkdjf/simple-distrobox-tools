#!/usr/bin/env bash
# Установка simple-distrobox-tools для текущего пользователя (без sudo).
#   ./install.sh            установить и включить синхронизацию
#   ./install.sh --remove   удалить (контейнеры и вынесенные ярлыки останутся)
#
# Всё ставится в $HOME, поэтому работает и на системах с read-only корнем
# (SteamOS / Steam Deck, Fedora Silverblue, Bazzite и т.п.) и переживает их обновления.
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"
BIN="$HOME/.local/bin"
UNITS="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/dbx-tools"
BASHRC="$HOME/.bashrc"
MARK_PATH="# simple-distrobox-tools: PATH"
MARK_PS1="# simple-distrobox-tools: prompt"

OS_ID="$( . /etc/os-release 2>/dev/null; echo "${ID:-}" )"

if [ "${1:-}" = "--remove" ]; then
  systemctl --user disable --now dbx-sync.path dbx-sync.timer 2>/dev/null || true
  for l in apt apt-get dnf pacman yay; do
    [ "$(readlink "$BIN/$l" 2>/dev/null)" = dbx-pm ] && rm -f "$BIN/$l"
  done
  rm -f "$BIN"/{dbx,dbx-lib,dbx-install,dbx-sync,dbx-pm} "$UNITS"/dbx-sync.{service,path,timer}
  systemctl --user daemon-reload
  # убрать наши блоки из ~/.bashrc (между маркером и строкой «# end»)
  if [ -f "$BASHRC" ]; then
    sed -i "/^$MARK_PATH\$/,/^# end\$/d; /^$MARK_PS1\$/,/^# end\$/d" "$BASHRC"
  fi
  echo "simple-distrobox-tools удалён. Откройте новый терминал."
  exit 0
fi

if [ -n "${CONTAINER_ID:-}" ] || [ -e /run/.containerenv ]; then
  echo "Запустите install.sh на хосте, а не внутри контейнера «${CONTAINER_ID:-?}»."; exit 1
fi

missing=()
for dep in distrobox flock; do command -v "$dep" >/dev/null || missing+=("$dep"); done
command -v podman >/dev/null || command -v docker >/dev/null || missing+=(podman)
if [ ${#missing[@]} -gt 0 ]; then
  echo "Не найдено: ${missing[*]}"
  case "$OS_ID" in
    steamos) echo "В SteamOS 3.5+ distrobox и podman встроены. Обновите SteamOS или поставите distrobox в домашний каталог:"
             echo "  curl -s https://raw.githubusercontent.com/89luca89/distrobox/main/install | sh -s -- --prefix ~/.local" ;;
    arch|endeavouros|manjaro|cachyos) echo "Установите: sudo pacman -S distrobox podman" ;;
    *) echo "Установите distrobox и podman пакетным менеджером вашей системы." ;;
  esac
  exit 1
fi

mkdir -p "$BIN" "$UNITS" "$STATE"
touch "$STATE/trigger"
install -m755 "$SRC"/{dbx,dbx-install,dbx-sync,dbx-pm} "$BIN/"
install -m644 "$SRC/dbx-lib" "$BIN/"
# shellcheck source=dbx-lib
. "$BIN/dbx-lib"

# apt / apt-get / dnf на хосте → в контейнеры (если в системе нет настоящих с тем же именем)
link() {  # $1 = команда
  if [ "$(readlink "$BIN/$1" 2>/dev/null)" = dbx-pm ] || [ ! -e "$BIN/$1" ]; then ln -sfn dbx-pm "$BIN/$1"; fi
}
for l in apt apt-get dnf; do
  real=""
  for d in /usr/bin /bin /usr/local/bin; do [ -x "$d/$l" ] && real="$d/$l"; done
  if [ -n "$real" ]; then
    echo "Пропускаю «$l»: в системе уже есть $real"
  else
    link "$l"
  fi
done
# pacman / yay → в контейнер arch, только если pacman хоста недоступен (Steam Deck и т.п.)
if host_pacman_ok; then
  for l in pacman yay; do [ "$(readlink "$BIN/$l" 2>/dev/null)" = dbx-pm ] && rm -f "$BIN/$l"; done
else
  link pacman; link yay
  echo "pacman и yay будут работать в контейнере «$ARCH_BOX» (pacman системы недоступен)."
fi
install -m644 "$SRC"/systemd/dbx-sync.{service,path,timer} "$UNITS/"

systemctl --user daemon-reload
systemctl --user enable --now dbx-sync.path dbx-sync.timer

# ~/.local/bin в PATH — дописываем сами (один раз)
touch "$BASHRC"
if ! grep -qxF "$MARK_PATH" "$BASHRC"; then
  cat >> "$BASHRC" <<'EOF'

# simple-distrobox-tools: PATH
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac
# end
EOF
  echo "Добавил ~/.local/bin в PATH (~/.bashrc)."
fi

# Подсветка «[📦 контейнер]» в приглашении — по желанию
if ! grep -qxF "$MARK_PS1" "$BASHRC" && [ -t 0 ]; then
  read -r -p "Показывать в приглашении, что вы внутри контейнера ([📦 ubuntu])? [Y/n] " ans || ans=n
  case "${ans:-y}" in
    [Yy]*|[Дд]*) cat >> "$BASHRC" <<'EOF'

# simple-distrobox-tools: prompt
if [ -n "$CONTAINER_ID" ]; then
  PS1='\[\e[1;35m\][📦 '"$CONTAINER_ID"']\[\e[0m\] \u \W\$ '
fi
# end
EOF
    echo "Готово: внутри контейнера приглашение будет фиолетовым." ;;
  esac
fi

echo "Первая синхронизация:"
"$BIN/dbx-sync"

echo
echo "Готово. Откройте НОВЫЙ терминал (или выполните: source ~/.bashrc), затем:"
echo "  dbx install vlc            (найдёт везде и спросит, откуда ставить)"
echo "  dbx upgrade                (обновит систему и все контейнеры)"
echo "  apt install vlc            (выполнится в контейнере ubuntu)"
echo "  dnf install ./файл.rpm     (выполнится в контейнере fedora)"
echo "  dbx-install ./файл.deb     (сам выберет контейнер по типу файла)"
if [ "$OS_ID" = steamos ]; then
  echo
  echo "Steam Deck: программы появятся в меню режима рабочего стола."
  echo "Чтобы запускать их из игрового режима — добавьте ярлык в Steam как стороннюю игру."
fi
