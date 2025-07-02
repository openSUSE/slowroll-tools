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

# e.g. source/home:rb-checker
function osc_api
{
    local path=$1; shift
    $dry $curl "$apiurl/$path" "$@"
}

# e.g. source/home:rb-checker:rebuild:xx?force=1
function osc_delete
{
    local path=$1; shift
    osc_api "$path" -X DELETE "$@"
}

# untested
function osc_post
{
    local path=$1; shift
    local data=$2; shift
    osc_api "$path" -X POST --data "$data" "$@"
}

function osc_put
{
    local path=$1; shift
    local data=$2; shift
    osc_api "$path" -X PUT --data "$data" "$@"
}

