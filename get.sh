#!/usr/bin/env bash
# Установка и обновление simple-distrobox-tools одной командой:
#
#   curl -fsSL https://raw.githubusercontent.com/k0kfjjfkdjf/simple-distrobox-tools/main/get.sh | bash
#
# Сам определяет систему и ставит недостающее (distrobox, podman) подходящим способом:
#   Arch и производные     → pacman
#   SteamOS (Steam Deck)    → ничего, всё встроено (при необходимости distrobox → ~/.local)
#   Fedora / Debian / Ubuntu / openSUSE → dnf / apt-get / zypper
#   Silverblue, Bazzite и др. (rpm-ostree) → ничего, distrobox обычно встроен
# Повторный запуск = обновление до последней версии.
#
# Переменные: SDT_DIR (куда положить файлы), SDT_REF (ветка/тег, по умолчанию main).

# Всё внутри main(): при «curl | bash» bash читает скрипт из stdin по кусочкам,
# и любая команда, читающая stdin, «съела» бы остаток скрипта.
main() {
  set -euo pipefail
  local REPO="k0kfjjfkdjf/simple-distrobox-tools"
  local REF="${SDT_REF:-main}"
  local DIR="${SDT_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/simple-distrobox-tools}"
  local TTY=/dev/null
  { : </dev/tty; } 2>/dev/null && TTY=/dev/tty   # вопросы и пароли — с клавиатуры, не из трубы

  say()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
  warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
  die()  { printf '\033[1;31mОшибка:\033[0m %s\n' "$*" >&2; exit 1; }

  [ "$(id -u)" -ne 0 ] || die "запускайте от обычного пользователя, не через sudo"
  if [ -n "${CONTAINER_ID:-}" ] || [ -e /run/.containerenv ]; then
    die "вы внутри контейнера «${CONTAINER_ID:-?}». Выйдите (exit) и запустите на хосте."
  fi
  command -v curl >/dev/null || die "нужен curl"

  # --- какая система ---
  local ID="" ID_LIKE=""
  # shellcheck disable=SC1091
  [ -r /etc/os-release ] && { ID="$(. /etc/os-release; echo "${ID:-}")"; ID_LIKE="$(. /etc/os-release; echo "${ID_LIKE:-}")"; }
  local family="unknown"
  case " $ID $ID_LIKE " in
    *" steamos "*)                     family=steamos ;;
    *" arch "*)                        family=arch ;;
    *" fedora "*|*" rhel "*)           family=fedora ;;
    *" debian "*|*" ubuntu "*)         family=debian ;;
    *" suse "*|*" opensuse "*)         family=suse ;;
  esac
  command -v rpm-ostree >/dev/null && [ "$family" != steamos ] && family=ostree
  say "Система: ${ID:-неизвестна} (${family})"

  # --- зависимости ---
  local need=()
  command -v distrobox >/dev/null || need+=(distrobox)
  command -v podman >/dev/null || command -v docker >/dev/null || need+=(podman)

  if [ ${#need[@]} -gt 0 ]; then
    say "Не хватает: ${need[*]}"
    case "$family" in
      arch)   sudo pacman -S --needed "${need[@]}" <"$TTY" ;;
      fedora) sudo dnf install "${need[@]}" <"$TTY" ;;
      debian) sudo apt-get install "${need[@]}" <"$TTY" ;;
      suse)   sudo zypper install "${need[@]}" <"$TTY" ;;
      steamos|ostree)
        # корень только для чтения — distrobox можно поставить в домашний каталог
        if [[ " ${need[*]} " == *" distrobox "* ]]; then
          say "Ставлю distrobox в ~/.local (системный раздел только для чтения)"
          curl -fsSL https://raw.githubusercontent.com/89luca89/distrobox/main/install | sh -s -- --prefix "$HOME/.local"
          export PATH="$HOME/.local/bin:$PATH"
        fi
        command -v podman >/dev/null || command -v docker >/dev/null ||
          die "podman не найден. На SteamOS он встроен с версии 3.5 — обновите систему."
        ;;
      *) die "не знаю, как поставить ${need[*]} в этой системе. Установите вручную и запустите снова." ;;
    esac
  fi

  # --- rootless podman: диапазоны UID ---
  if command -v podman >/dev/null && ! grep -q "^$(id -un):" /etc/subuid 2>/dev/null; then
    warn "Для $(id -un) нет диапазона в /etc/subuid — rootless podman может не работать."
    warn "Исправить: sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 $(id -un)"
  fi

  # --- скачать / обновить файлы (без git: он есть не везде) ---
  local tmp; tmp="$(mktemp -d)"
  # shellcheck disable=SC2064  # путь подставляем сразу: после выхода из main() переменной уже нет
  trap "rm -rf '$tmp'" EXIT
  if [ -n "${SDT_LOCAL_SRC:-}" ]; then          # для тестов
    cp -r "$SDT_LOCAL_SRC" "$tmp/src"
  else
    say "Скачиваю $REPO ($REF)"
    curl -fsSL "https://codeload.github.com/$REPO/tar.gz/$REF" | tar -xz -C "$tmp"
    mv "$tmp"/simple-distrobox-tools-* "$tmp/src"
  fi
  rm -rf "$DIR"
  mkdir -p "$(dirname "$DIR")"
  mv "$tmp/src" "$DIR"

  # --- установка ---
  say "Устанавливаю"
  bash "$DIR/install.sh" <"$TTY"

  # PATH в текущем терминале не обновится сам — подскажем
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) echo; say "Выполните «source ~/.bashrc» или откройте новый терминал." ;;
  esac
  echo
  say "Обновление — та же команда ещё раз. Удаление: bash $DIR/install.sh --remove"
}

main "$@"
