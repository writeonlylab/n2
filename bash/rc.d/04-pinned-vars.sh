__N2_PINNED_VARS=

function n2_define_pinned {
    local var_name var_value v
    var_name="$1"
    var_value="${2:-}"
    eval "$var_name='$var_value'"

    local IFS=:
    for v in $__N2_PINNED_VARS; do
        [ "$v" = "$var_name" ] && return
    done
    __N2_PINNED_VARS="$__N2_PINNED_VARS:$var_name"
}

function n2_update_pinned {
    __N2_PINNED_VARS=
    if [ -z "${N2_PS1_LABEL:-}" ]; then
        return
    fi

    local hook="n2_hook_label_${N2_PS1_LABEL:-}"
    [ "$(type -t "$hook")" = function ] && "$hook" "${N2_PS1_LABEL:-}"
}

