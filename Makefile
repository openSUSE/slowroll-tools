install:
	zypper -n in perl-JSON-XS perl-XML-Bare

daily: fetch select
fetch:
	mkdir -p out/frozenlinks/ ; osc api /source/openSUSE:ALP:Experimental:Slowroll:Next/_project/_frozenlinks?meta=1 > out/frozenlinks/$$(date -I)
	tools/getrepoviews
	tools/diffdistro

select:
	mkdir -p out/log
	DEBUG=1 tools/selectupdates.pl 2>&1 | tee out/log/select-$$(date -Iseconds)
	#DRYRUN=0 tools/selectupdates.pl

release:
	tools/releasestaging 2>&1 | tee out/log/release-$$(date -Iseconds)

newsnapshot:
	osc api -X POST /source/openSUSE:ALP:Experimental:Slowroll:Next?cmd=freezelink
	# on pontifex2 run /usr/local/bin/slowroll-snapshot
	tools/cleanuprepo $$slo:Staging
	tools/cleanuprepo $$slo
	FORCE=1 ./collectbuildinfo
	rm -f out/pending/*
	touch out/pending/000release-packages # and update the version numbers in there
