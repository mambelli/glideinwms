# BATS wants all messages to &2
# Messages to stdout or stderr could cause strange output and the test to fail

info_stdout () {
    [[ -z "$GLIDEIN_QUIET" ]] && echo "STDOUT - " "$@" >&3
    true
}


info_raw () {
    [[ -z "$GLIDEIN_QUIET" ]] && echo "MK" "$@"  1>&3
    [[ -n "$SCRIPT_LOG" ]] && echo "$@"  >> "$GWMS_SCRIPT_LOG"
    true
}


warn_raw () {
    echo "MK" "$@"  1>&3
    [[ -n "$SCRIPT_LOG" ]] && echo "$@"  >> "$GWMS_SCRIPT_LOG"
    true
}
