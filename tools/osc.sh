# to be sourced into a shell script:
# refer to osc --debug or https://api.opensuse.org/apidocs/

#dry=echo
: ${apiurl:=https://api.opensuse.org}
: ${accelerate:=0}
: ${verbose:=-s}
curl="curl $verbose -n --cookie $HOME/.local/state/osc/cookiejarcurl --cookie-jar $HOME/.local/state/osc/cookiejarcurl"
if [[ $accelerate = 1 ]] ; then
    sed -i -e 's,TRUE\t/\tTRUE,TRUE\t/\tFALSE,' $HOME/.local/state/osc/cookiejarcurl
    curl+=" --connect-to ::127.0.0.1:40080 -H Connection:Keep-Alive"
    apiurl=http://api.opensuse.org
fi

# Refuse to modify anything outside $sloguard. Unset in production; the test
# suite sets it to the playground prefix. Everything in the toolchain that
# changes state in OBS goes through osc_api, so this one check covers all of it.
function osc_guard
{
    [ -z "$sloguard" ] && return 0
    local path=$1; shift
    case " $* " in
        *" -X POST "*|*" -X PUT "*|*" -X DELETE "*) ;;
        *) return 0 ;; # a read, nothing to guard
    esac
    local prj
    case "$path" in
        *target_project=*)
            # releasemulti posts to /source/openSUSE:Factory/PKG?cmd=release,
            # so judge a release by where it lands rather than where it comes from
            prj=${path##*target_project=}; prj=${prj%%&*}
            ;;
        *)
            prj=${path#/}; prj=${prj#*/} # drop the leading source/ or build/
            prj=${prj%%/*}; prj=${prj%%\?*}
            ;;
    esac
    case "$prj" in
        "$sloguard"|"$sloguard":*) return 0 ;;
    esac
    echo "GUARD: refusing to modify $prj (sloguard=$sloguard): $path" >&2
    return 9
}

# e.g. source/home:rb-checker
function osc_api
{
    local path=$1; shift
    osc_guard "$path" "$@" || return 9
    $dry $curl "$apiurl/$path" "$@"
}

# e.g. source/home:rb-checker:rebuild:xx?force=1
function osc_delete
{
    local path=$1; shift
    osc_api "$path" -X DELETE "$@"
}

function osc_post
{
    local path=$1; shift
    local data=$1; shift
    osc_api "$path" -X POST --data "$data" "$@"
}

function osc_put
{
    local path=$1; shift
    local data=$1; shift
    osc_api "$path" -X PUT --data "$data" "$@"
}

