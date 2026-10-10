#!/usr/bin/env bash
# Установка dbx-tools для текущего пользователя (без sudo).
#   ./install.sh            установить и включить синхронизацию
#   ./install.sh --remove   удалить (экспортированные ярлыки останутся)
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"
BIN="$HOME/.local/bin"
UNITS="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/dbx-tools"

if [ "${1:-}" = "--remove" ]; then
  systemctl --user disable --now dbx-sync.path dbx-sync.timer 2>/dev/null || true
  for l in apt apt-get dnf; do
    [ "$(readlink "$BIN/$l" 2>/dev/null)" = dbx-pm ] && rm -f "$BIN/$l"
  done
  rm -f "$BIN/dbx-install" "$BIN/dbx-sync" "$BIN/dbx-pm" "$UNITS"/dbx-sync.{service,path,timer}
  systemctl --user daemon-reload
  echo "dbx-tools удалён."
  exit 0
fi

for dep in distrobox podman flock; do
  command -v "$dep" >/dev/null || { echo "Не найден $dep. Установите: sudo pacman -S distrobox podman"; exit 1; }
done

mkdir -p "$BIN" "$UNITS" "$STATE"
touch "$STATE/trigger"
if [ -n "${CONTAINER_ID:-}" ] || [ -e /run/.containerenv ]; then
  echo "Запустите install.sh на хосте, а не внутри контейнера «${CONTAINER_ID:-?}»."; exit 1
fi
install -m755 "$SRC/dbx-install" "$SRC/dbx-sync" "$SRC/dbx-pm" "$BIN/"

# apt / apt-get / dnf на хосте → в контейнеры (если в Arch нет настоящих с тем же именем)
for l in apt apt-get dnf; do
  real=""
  for d in /usr/bin /bin /usr/local/bin; do [ -x "$d/$l" ] && real="$d/$l"; done
  if [ -n "$real" ]; then
    echo "Пропускаю «$l»: в системе уже есть $real"
  else
    ln -sfn dbx-pm "$BIN/$l"
  fi
done
install -m644 "$SRC"/systemd/dbx-sync.{service,path,timer} "$UNITS/"

systemctl --user daemon-reload
systemctl --user enable --now dbx-sync.path dbx-sync.timer

echo "Первая синхронизация:"
"$BIN/dbx-sync"

case ":$PATH:" in
  *":$BIN:"*) ;;
  *) echo; echo "Внимание: $BIN нет в PATH. Добавьте в ~/.bashrc:"
     echo "  export PATH=\"\$HOME/.local/bin:\$PATH\"" ;;
esac
echo
echo "Готово. Примеры:"
echo "  apt install vlc            (выполнится в контейнере ubuntu)"
echo "  dnf install ./файл.rpm     (выполнится в контейнере fedora)"
echo "  dbx-install ./файл.deb     (сам выберет контейнер по типу файла)"
