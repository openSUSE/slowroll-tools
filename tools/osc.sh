# to be sources into a shell script:
# refer to osc --debug or https://api.opensuse.org/apidocs/

#dry=echo
: ${apiurl:=https://api.opensuse.org}
cookie=$(perl -ne 'm/(openSUSE_session=[0-9a-f]+);.*domain=..opensuse.org/ && print $1' ~/.local/state/osc/cookiejar)
curl="curl"
if [ -n "$cookie" ] ; then
    curl="$curl --header Cookie:$cookie"
else
    curl="$curl -n" # use user:password auth
fi


function osc_api
{
    local path=$1; shift
    $dry $curl "$apiurl/$path" "$@"
}

function osc_delete
{
    local path=$1; shift
    osc_api "$path" -X DELETE "$@"
}

# untested
function osc_put
{
    local path=$1; shift
    local data=$2; shift
    osc_api "$path" -X PUT --data "$data" "$@"
}

