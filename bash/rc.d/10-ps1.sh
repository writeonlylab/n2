__N2_COMMAND_SNO=0
__N2_COMMAND_ERRNO=0
__N2_COMMAND_UNIX_MILLIS=0

function __n2_unix_millis {
    if [ "$(uname -s)" = Linux ]; then
        date +%s%03N
    else
        date +%s000
    fi
}

function __n2_pretty_date {
    date +"%H:%M:%S %b %d"
}

function __n2_pretty_duration {
    local seconds sec min hr
    seconds=$(("$1" / 1000))

    local hr=$((seconds / 3600))
    local min=$((seconds % 3600 / 60))
    local sec=$((seconds % 60))

    if [[ "$hr" > 0 ]]; then
        echo "${hr}h${min}m"
    elif [[ "$min" > 0 ]]; then
        echo "${min}m${sec}s"
    else
        echo "${sec}s"
    fi
}

function __n2_prefix_line_if_labeled {
    local label=${N2_PS1_LABEL:-}
    local prefix="$1"
    if [ -n "$label" ]; then
      sed -e "s/^/$(__n2_fmt ps1_label zero_width)$prefix$(__n2_reset_fmt zero_width)/g"
    else
      cat
    fi
}

function __n2_inline_echo {
    builtin echo -n "$@"
}

function  __n2_cursor_xpos {
    local saved_state xpos dummy
    saved_state="$(stty -g)"
    stty -echo
    echo -n $'\033[6n' > /dev/tty; read -s -d ';' dummy; read -s -dR xpos
    echo "$xpos"
    stty "$saved_state" 2>/dev/null
}

function __n2_force_newline {
    if ! [ "${N2_ENABLE_EXPLICIT_EOF:-no}" = yes ]; then
        return
    fi

    if [ "$(__n2_cursor_xpos)" != 1 ]; then
        __n2_reset_fmt
        __n2_fmt force_newline
        __n2_inline_echo ":no_eol:"
        __n2_reset_fmt

        if [ "$(__n2_cursor_xpos)" != 1 ]; then
            builtin echo
        fi
    fi
}

function __n2_short_hostname {
    if [ -z "${N2_PS1_HOSTNAME:-}" ]; then
        local node_name="$(uname -n)"
        __n2_inline_echo "${node_name%%.*}"
    else
        __n2_inline_echo "${N2_PS1_HOSTNAME:-}"
    fi
}

function __n2_ps1_nice {
    # Only enables on Linux OS. BSD version nice doesn't print the nice value.
    [ "$(uname -s)" != Linux ] && return 1

    __n2_has nice || return 1
    local n
    n=$(nice)
    [ "$n" = 0 ] && return 1
    __n2_fmt "ps1_priority_$(((n+20)/4))" zero_width
    __n2_inline_echo "n($n)"
    __n2_reset_fmt zero_width
    return 0
}

function __n2_ps1_user_host {
    __n2_ps1_username

    __n2_fmt ps1_userhost_punct zero_width
    __n2_inline_echo "@"
    __n2_reset_fmt zero_width

    __n2_ps1_hostname
    return 0
}

function __n2_ps1_username {
    __n2_fmt ps1_username zero_width
    __n2_inline_echo "$(whoami)"
    __n2_reset_fmt zero_width
}

function __n2_ps1_hostname {
    __n2_fmt ps1_hostname zero_width
    __n2_inline_echo "$(__n2_short_hostname)"
    __n2_reset_fmt zero_width
    return 0
}

function __n2_ps1_chroot {
    if [ -n "${debian_chroot:-}" ]; then
        __n2_fmt ps1_chroot zero_width
        __n2_inline_echo "($debian_chroot)"
        __n2_reset_fmt zero_width
        return 0
    else
        return 1
    fi
}

function __n2_ps1_bg_indicator {
    local njobs="$1"
    if [ "$njobs" -gt 0 ]; then
        __n2_fmt ps1_bg_indicator zero_width
        __n2_inline_echo "&$njobs"
        __n2_reset_fmt zero_width
        return 0
    fi
    return 1
}

function __n2_ps1_shlvl_indicator {
    if [ "$SHLVL" -gt 1 ]; then
        __n2_fmt ps1_shlvl_indicator zero_width
        __n2_inline_echo "^$(expr "$SHLVL" - 1)"
        __n2_reset_fmt zero_width
        return 0
    fi
    return 1
}

function __n2_ps1_screen_indicator {
    local session="${STY:-}"
    if [ -n "${session:-}" ]; then
        __n2_fmt ps1_screen_indicator zero_width
        __n2_inline_echo "*${session#*.}*"
        __n2_reset_fmt zero_width
        return 0
    fi
    return 1
}

function __n2_ps1_git_indicator {

    if type git &>/dev/null; then
        gbr="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
        if [ -n "$gbr" ]; then
            if [ "$gbr" = HEAD ]; then
                gbr="$(git rev-parse HEAD 2>/dev/null | head -c8)"
            fi
            groot="$(basename ///"$(git rev-parse --show-toplevel 2>/dev/null)")"

            if [ "${#groot}" -gt 12 ]; then
                groot="${groot: 0:8}\`${groot: -3:3}"
            fi
            __n2_fmt ps1_git_indicator zero_width
            if [ "$groot" = / ]; then
                __n2_inline_echo "(.git)"
            else
                __n2_inline_echo "$groot[$gbr]"
            fi
            __n2_reset_fmt zero_width
            return 0
        fi
    fi
    return 1
}

function __n2_ps1_permission {

    local r w x display=no
    if test -r .; then
        r="$(__n2_fmt ps1_perm_good)r$(__n2_reset_fmt)"
    else
        r="$(__n2_fmt ps1_perm_bad)-$(__n2_reset_fmt)"
        display=yes
    fi
    if test -w .; then
        w="$(__n2_fmt ps1_perm_good)w$(__n2_reset_fmt)"
    else
        w="$(__n2_fmt ps1_perm_bad)-$(__n2_reset_fmt)"
        display=yes
    fi
    if test -x .; then
        x="$(__n2_fmt ps1_perm_good)x$(__n2_reset_fmt)"
    else
        x="$(__n2_fmt ps1_perm_bad)-$(__n2_reset_fmt)"
    fi

    if [ "$display" = yes ]; then
        __n2_inline_echo "$r$w$x"
        __n2_reset_fmt zero_width
        return 0
    fi
    return 1
}

function __n2_ps1_cwd {
    local hook=n2_hook_ps1_cwd

    __n2_fmt ps1_cwd zero_width
    if [ "$(type -t "$hook")" = function ]; then
        __n2_inline_echo "$($hook "$1")"
    else
        __n2_inline_echo "$1"
    fi
    __n2_reset_fmt zero_width
    return 0
}

function __n2_ps1_non_default_ifs {
    if [[ "${#IFS}" == 3 && "$IFS" == *" "* && "$IFS" == *$'\t'* && "$IFS" == *$'\n'* ]]; then
        return 1
    fi

    __n2_fmt ps1_ifs zero_width
    __n2_inline_echo "(IFS="
    __n2_reset_fmt zero_width

    __n2_fmt ps1_ifs_value zero_width
    printf "%q" "$IFS"
    __n2_reset_fmt zero_width

    __n2_fmt ps1_ifs zero_width
    __n2_inline_echo ")"
    __n2_reset_fmt zero_width

    return 0
}

function __n2_ps1_physical_cwd {
    local physical_cwd="$(pwd -P)"
    if [ "$physical_cwd" != "$(pwd)" ]; then
        __n2_fmt ps1_physical_cwd zero_width
        __n2_inline_echo "(Physical: $physical_cwd)"
        __n2_reset_fmt zero_width
        return 0
    fi
    return 1
}

function __n2_ps1_label {
  local label=${N2_PS1_LABEL:-}
  if [ -n "$label" ]; then
      __n2_fmt ps1_label zero_width
      __n2_inline_echo ":${label}:"
      __n2_reset_fmt zero_width
      return 0
  fi
  return 1
}

function __n2_ps1_dollar_hash {
    __n2_fmt ps1_dollar_hash zero_width
    __n2_inline_echo "$1"
    __n2_reset_fmt zero_width
}

function __n2_ps1_space {
    __n2_inline_echo ' '
}

function __n2_ps1_newline {
    builtin echo
}

function __n2_ps1_pinned_vars {
    local var_name
    local IFS=:
    for var_name in $__N2_PINNED_VARS; do
        [ -z "$var_name" ] && continue
        __n2_fmt pinned_key
        __n2_inline_echo "$var_name"
        __n2_reset_fmt

        __n2_fmt pinned_punct
        __n2_inline_echo "='"
        __n2_reset_fmt

        __n2_fmt pinned_value
        eval "__n2_inline_echo \"\$${var_name}\""
        __n2_reset_fmt

        __n2_fmt pinned_punct
        __n2_inline_echo "'"
        __n2_reset_fmt

        __n2_ps1_newline
    done
}

PS1='$(
    (
        __n2_ps1_user_host         && __n2_ps1_space
        __n2_ps1_chroot            && __n2_ps1_space
        __n2_ps1_bg_indicator "\j" && __n2_ps1_space
        __n2_ps1_shlvl_indicator   && __n2_ps1_space
        __n2_ps1_screen_indicator  && __n2_ps1_space
        __n2_ps1_nice              && __n2_ps1_space
        __n2_ps1_git_indicator     && __n2_ps1_space
        __n2_ps1_permission        && __n2_ps1_space
        __n2_ps1_cwd "\w"
        __n2_ps1_newline
    ) | (
        __n2_prefix_line_if_labeled "$N2_FMT_PS1_HEAD_PREFIX"
    )
    (
        __n2_ps1_pinned_vars
        __n2_ps1_physical_cwd && __n2_ps1_newline
    ) | (
        __n2_prefix_line_if_labeled "$N2_FMT_PS1_MID_PREFIX"
    )
    (
        __n2_ps1_label            && __n2_ps1_space
        __n2_ps1_dollar_hash "\$" && __n2_ps1_space
        __n2_ps1_non_default_ifs  && __n2_ps1_space
    ) | (
        __n2_prefix_line_if_labeled "$N2_FMT_PS1_TAIL_PREFIX"
    )
)'

function __n2_do_before_command {

    # This assignment must be done first
    __N2_COMMAND_ERRNO="${PIPESTATUS[@]}"

    if [ "$BASH_COMMAND" = __n2_do_after_command ]; then
        return
    fi

    if [ "$__N2_COMMAND_SNO" = 0 ]; then
        __N2_COMMAND_UNIX_MILLIS=$(__n2_unix_millis)
    fi

    let '__N2_COMMAND_SNO += 1'

    if [ "${N2_ENABLE_CMD_EXPANSION:-yes}" = no ]; then
        return
    fi

    read -r -a cmd_tokens <<< "$BASH_COMMAND"
    case "$(type -t "${cmd_tokens[0]}")" in
        file|alias)
            # even we got alias here, it has already been resolved
            cmd_tokens[0]=$(type -P "${cmd_tokens[0]}")
            ;;
        builtin)
            cmd_tokens[0]="builtin ${cmd_tokens[0]}"
            ;;
        function)
            cmd_tokens[0]="function ${cmd_tokens[0]}"
            ;;
        keyword)
            cmd_tokens[0]="keyword ${cmd_tokens[0]}"
            ;;
        *)
            ;;
    esac

    local sink=${N2_CMD_EXPANSION_SINK:-&2}
    local proxy_fd=${N2_CMD_EXPANSION_SINK_PROXY_FD:-99}
    local stat_str="[$__N2_COMMAND_SNO] -> ${cmd_tokens[@]} ($(__n2_pretty_date))"
    local safe_stat_str="$(cat -v <<< "$stat_str")"

    if [ -w "$sink" ]; then
        eval "exec $proxy_fd>>$sink"
    else
        eval "exec $proxy_fd>$sink"
    fi

    __n2_force_newline

    [ -t "$proxy_fd" ] && eval "__n2_fmt cmd_expansions >&$proxy_fd"
    eval '__n2_inline_echo "$safe_stat_str" '" >&$proxy_fd"
    [ -t "$proxy_fd" ] && eval "__n2_reset_fmt >&$proxy_fd"
    eval "__n2_ps1_newline >&$proxy_fd"

    eval "exec $proxy_fd>&-"

    # Many bash command completion scripts use unbound variables, i.e.,
    # dereference an undefined variable and use its fallback substution, which
    # is an empty string. Turning on this option (-u) is therefore going to be
    # break these scripts, which are in fact stable, fortunately.
    if [ "$__N2_COMMAND_SNO" = 1 ] && [ "${N2_REPORT_UNBOUND_VARIABLE:-no}" = yes ]; then
        set -u
    fi
}

function __n2_do_after_command {

    # At this point, since bash completion scripts are so widely used, it is
    # safe of assume that user leaves this option (-u) off by default, so that
    # command completion can work. Given this, the option is switched on/off
    # siliently, providing safer interactive variable substitution, in a not-
    # so-annoying way, hopefully.
    if [ "${N2_REPORT_UNBOUND_VARIABLE:-no}" = yes ]; then
        set +u
    fi

    local eno ts wall status
    local ret=OK

    __n2_force_newline

    if [ "$__N2_COMMAND_SNO" -gt 0 ]; then
        __N2_COMMAND_SNO=0

        if [ "${N2_ENABLE_STATUS_LINE:-yes}" = no ]; then
            return
        fi

        ts=$(__n2_pretty_date)
        for eno in $__N2_COMMAND_ERRNO; do
            if [ $eno -ne 0 ]; then
                ret=ERR
                break
            fi
        done

        __n2_reset_fmt
        [ "${N2_THICK_SEPARATOR:-no}" = yes ] || __n2_fmt underline
        if [ $ret = OK ]; then
            __n2_fmt status_ok
        else
            __n2_fmt status_error
        fi

        wall=$(__n2_pretty_duration $(($(__n2_unix_millis) - $__N2_COMMAND_UNIX_MILLIS)))

        if [ $ret = OK ]; then
            status="Status OK"
        else
            status="Error $__N2_COMMAND_ERRNO"
        fi

        printf "%${COLUMNS}s\n" "$ts | $wall | $status"

        if [ "${N2_THICK_SEPARATOR:-no}" = yes ]; then
            printf "%${COLUMNS}s\n" "" | tr " " "${N2_THICK_SEPARATOR_CHAR:-~}"
        fi
        __n2_reset_fmt
    fi
}

# vim: set ft=bash:
