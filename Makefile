install:
	zypper -n in perl-JSON-XS perl-XML-Bare

daily:
	tools/diffdistro
	DRYRUN=0 tools/selectupdates.pl

newsnapshot:
	FORCE=1 ./collectbuildinfo
