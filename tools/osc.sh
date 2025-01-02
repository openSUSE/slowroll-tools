# to be sources into a shell script:
# refer to osc --debug or https://api.opensuse.org/apidocs/

#dry=echo
: ${apiurl:=https://api.opensuse.org}
curl="curl -n --cookie $HOME/.local/state/osc/cookiejarcurl --cookie-jar $HOME/.local/state/osc/cookiejarcurl"

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

