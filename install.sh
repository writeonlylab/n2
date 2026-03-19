#!/usr/bin/env bash

set -euo pipefail

if [ ${BASH_VERSINFO[0]} -lt 4 ]; then
    echo "Your bash version ($BASH_VERSION) is too low."
    echo "Requires at least 4.x."
    exit 1
fi

N2_DIR=$(cd "$(dirname "$0")"; pwd)
INSTALLED_FILES="$N2_DIR/volatile/INSTALLED_FILES"

AUTO_CONFIRM=${AUTO_CONFIRM:-no}
PLAYGROUND=${PLAYGROUND:-no}

ASSIGNED_HOME="$HOME"
[ "$PLAYGROUND" == yes ] && ASSIGNED_HOME=$(mktemp -d)

BASHRC_PATH="$ASSIGNED_HOME/.bashrc"
BASH_PROFILE_PATH="$ASSIGNED_HOME/.bash_profile"
VIMRC_PATH="$ASSIGNED_HOME/.vimrc"
TMUX_CONF_PATH="$ASSIGNED_HOME/.tmux.conf"
GIT_CONFIG_PATH="$ASSIGNED_HOME/.gitconfig"

N2_ENTRANCE_BEGIN="=== N2 ENTRANCE BEGIN ==="
N2_ENTRANCE_END="=== N2 ENTRANCE END ==="

read -r -d '' BASHRC_SNIP << EOM || true
# $N2_ENTRANCE_BEGIN
source $N2_DIR/bash/rc
# $N2_ENTRANCE_END
EOM

read -r -d '' BASH_PROFILE_SNIP << EOM || true
# $N2_ENTRANCE_BEGIN
source $N2_DIR/bash/profile
# $N2_ENTRANCE_END
EOM

read -r -d '' VIMRC_SNIP << EOM || true
" $N2_ENTRANCE_BEGIN
execute "source" "$N2_DIR/vim/rc"
" $N2_ENTRANCE_END
EOM

read -r -d '' TMUX_CONF_SNIP << EOM || true
# $N2_ENTRANCE_BEGIN
source-file $N2_DIR/tmux/conf
# $N2_ENTRANCE_END
EOM

read -r -d '' GIT_CONFIG_SNIP << EOM || true
# $N2_ENTRANCE_BEGIN
[include]
    path = $N2_DIR/git/config
    path = $N2_DIR/volatile/git/link0
    path = $N2_DIR/volatile/git/link1
    path = $N2_DIR/volatile/git/link2
    path = $N2_DIR/volatile/git/link3
# $N2_ENTRANCE_END
EOM

declare -A SNIPPETS=(
    ["$BASHRC_PATH"]="$BASHRC_SNIP"
    ["$BASH_PROFILE_PATH"]="$BASH_PROFILE_SNIP"
    ["$VIMRC_PATH"]="$VIMRC_SNIP"
    ["$TMUX_CONF_PATH"]="$TMUX_CONF_SNIP"
    ["$GIT_CONFIG_PATH"]="$GIT_CONFIG_SNIP"
)

function indent {
    local line p
    p="$1"
    while read -r line; do
        echo "$p$line"
    done
}

function fmt {
    local line p
    p="$1"
    while read -r line; do
        echo -e "\033[${p}m$line\033[0m"
    done
}

print_diff() {
    local path snippet
    path="$1"
    snippet="$2"

    echo
    echo "Will apply diff to file $(fmt 1 <<< $path):"

    [ -e "$path" ] || path=/dev/null
    (diff -C5 "$path" <(cat "$path" <(echo "$snippet")) || true) | fmt 33 | indent '  '
}

is_installed() {
    [ "$PLAYGROUND" = yes ] && return 1
    local path line
    path="$1"
    [ -e $INSTALLED_FILES ] || return 1
    while read -r line; do
        [ "$line" = "$path" ] && return 0
    done < "$INSTALLED_FILES"
    return 1
}

mark_installed() {
    local path
    path="$1"
    echo "$path" >> "$INSTALLED_FILES"
}

confirm() {
    local default_reply path
    path="$1"

    if [ "$AUTO_CONFIRM" = yes ]; then
        return 0
    fi

    if is_installed "$path"; then
        default_reply=N
    else
        default_reply=Y
    fi

    echo "Looks good?"
    while :; do
        echo "  $(fmt 1 <<< Y) to continue;"
        echo "  $(fmt 1 <<< A) to continue and auto-confirm all the following installations;"
        echo "  $(fmt 1 <<< N) to skip installing this one;"
        echo "  $(fmt 1 <<< Q) to abort installation:"
        read -re -p "> " -i "$default_reply"
        case "$REPLY" in
            Y | y )
                return 0
                ;;
            A | a)
                AUTO_CONFIRM=yes
                return 0
                ;;
            N | n)
                return 1
                ;;
            Q | q)
                exit
                ;;
            *)
                echo "Invalid option."
                continue
        esac
    done
}

install() {
    local path snippet
    path="$1"
    snippet="$2"
    echo "${snippet}" >> "$path"
    echo "Wrote to file $(fmt 1 <<< "$path")." | fmt 33
    mark_installed "$path"
}

banner() {
    local key
    key="$1"
    case "$key" in
        welcome)
            echo
            echo "-------------------------------------------------------"
            echo "-- Welcome to N2 --- the next geration of N.I.D.U.S. --"
            echo "-------------------------------------------------------"
            echo
            [ "$PLAYGROUND" == no ] && return 0
            echo "Installing to playground dir: $ASSIGNED_HOME"
            echo
            ;;
        jobdone)
            if [ "$PLAYGROUND" == yes ]; then
                echo
                echo "-------------------------------------------------"
                echo "-- N2 installation complete. (playground mode) --"
                echo "-------------------------------------------------"
                echo
                echo "Installed to playground dir: $ASSIGNED_HOME"
                echo
                echo "To try this installation:"
                echo "    HOME='$ASSIGNED_HOME' bash --login"
                echo
                echo "To remove the playground:"
                echo "    rm -rf '$ASSIGNED_HOME'"
                echo
            else
                echo
                echo "---------------------------------------------------------"
                echo "-- N2 installation complete. Please logout then login. --"
                echo "---------------------------------------------------------"
                echo
            fi
            ;;
        *)
            return 1
    esac
}

main() {
    local path snippet
    banner welcome
    for path in ${!SNIPPETS[@]}; do
        snippet="${SNIPPETS["$path"]}"
        print_diff "$path" "$snippet"
        confirm "$path" || continue
        install "$path" "$snippet"
    done
    banner jobdone
}

main

