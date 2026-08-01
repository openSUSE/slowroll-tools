# Sourced first by every test script. Refuses to run unless the environment
# unmistakably points at the playground.
#
# This is the second of four layers. The others: the osc user holds no role in
# any openSUSE:Slowroll* project so OBS itself returns 403; osc_guard in
# tools/osc.sh blocks mutating REST calls outside $sloguard; and test/bin/osc
# blocks mutating osc subcommands that name a production project.

if [ ! -e tools/osc.sh ] ; then
    echo "REFUSING: run me from the top of a slowroll-tools checkout" >&2
    exit 9
fi

test_guard_prefix=home:bmwiedemannai:Slowroll

for v in slo slou slobase slobuild sloreleasing sloguard ; do
    eval "val=\$$v"
    case "$val" in
        "$test_guard_prefix"|"$test_guard_prefix":*) ;;
        "") echo "REFUSING: \$$v is not set - did you source test/slorc.test?" >&2 ; exit 9 ;;
        *)  echo "REFUSING: \$$v='$val' is not a playground project" >&2 ; exit 9 ;;
    esac
done

# releasestaging mails the factory list when this is unset
if [ -z "$SILENT" ] && [ -z "$MAILER" ] ; then
    echo "REFUSING: neither SILENT nor MAILER is set - a run could send real mail" >&2
    exit 9
fi

# never let a cron tick run production work from a tree we are experimenting in
[ -e .blockcron ] || touch .blockcron

# our osc shim goes first, so mutating subcommands naming a production project
# are refused even though they never reach tools/osc.sh
case ":$PATH:" in
    *":$PWD/test/bin:"*) ;;
    *) PATH="$PWD/test/bin:$PATH" ; export PATH ;;
esac
