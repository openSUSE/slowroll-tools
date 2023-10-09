install:
	zypper -n in perl-JSON-XS perl-XML-Bare

daily: fetch select
fetch:
	tools/getrepoviews
	tools/diffdistro

select:
	mkdir -p out/log
	DEBUG=1 tools/selectupdates.pl 2>&1 | tee out/log/select-$$(date -Iseconds)
	#DRYRUN=0 tools/selectupdates.pl

release:
	tools/releasestaging 2>&1 | tee out/log/release-$$(date -Iseconds)

newsnapshot:
	# on pontifex2 run /usr/local/bin/slowroll-snapshot
	FORCE=1 ./collectbuildinfo
