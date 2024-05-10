BASENEXT:=${slobase}

install:
	zypper -n in perl-JSON-XS perl-XML-Bare

daily: fetch select
fetch:
	#mkdir -p out/frozenlinks/ ; osc api /source/openSUSE:Slowroll:Next/_project/_frozenlinks?meta=1 > out/frozenlinks/$$(date -I)
	tools/getrepoviews
	tools/diffdistro
	osc api /build/openSUSE:Slowroll/_result > out/result/slo/$$(date -I)
	#osc api /build/openSUSE:Slowroll:Staging/_result > out/result/slos/$$(date -I)
	-osc api /build/${slobuild}/_result > out/result/slos/$$(date -I)
	osc api /build/openSUSE:Slowroll:Base/_result > out/result/slob/$$(date -I)

select:
	mkdir -p out/log
	DEBUG=1 tools/selectupdates.pl 2>&1 | tee out/log/select-$$(date -Iseconds)
	#DRYRUN=0 tools/selectupdates.pl

release:
	tools/releasestaging 2>&1 | tee out/log/release-$$(date -Iseconds)

newsnapshot1:
	osc api -X DELETE /source/${BASENEXT}/_project/_frozenlinks\?meta=1
	osc api -X POST /source/${BASENEXT}?cmd=freezelink
	# sync prjconf from Factory to Base
	osc meta prjconf openSUSE:Factory > cache/meta/factory-prjconf && osc meta prjconf -F cache/meta/factory-prjconf ${BASENEXT}
	# sync i586 (and not -bootstrap (kept in :Staging)) binaries to ${BASENEXT}
	#using /build/openSUSE:Slowroll:Base:2/standard/i586/_repository?view=binaryversions&withevr=1 and osc release
	find cache -mtime +3 -name factory-i586.xml -delete
	FORCE=1 ./collectbuildinfo
	./processbuildinfo
	go run cmd/processbuildinfo.go

	tools/syncslob
newsnapshot2:
	# on pontifex2 run /usr/local/bin/slowroll-snapshot as 'mirror' user
	# TODO keep backup of old /update/slowroll for analysis ; on stage3?
	for p in `cat in/javabuilddeps ; cat in/i586bitbuilddeps1` ; do osc copypac openSUSE:Factory "$$p" $$slobuild ; done
newsnapshot3:
	echo "review in/never-update-exceptions"
	tools/syncslo-pre
	echo "disable cron jobs"
	#tools/cleanuprepo $$slo:Staging
	#tools/cleanuprepo $$slo
	#rm -f out/pending/*
	#for p in $(osc ls $slo | grep -v :) ; do echo "$p"; tools/syncslo-postbump "$p" ; done | tee out/log/syncslo-postbump-$(date -I)
	#tools/syncslos-postbump
	#for p in `cat in/i586bitbuilddeps` ; do touch out/pending/$p ; done
	#touch out/pending/000release-packages # and update the version numbers in there
	osc release $s:Build:Overlay --target-project $s 000release-packages --target-repository=standard -r standard
	echo "re-scan mirrors login for https://download.opensuse.org/app/folder/3855809"
	tools/releasemulti $$slobuild $$slobase 000release-packages # for NET iso

	echo "adapt and run tools/syncbase | bash -x"
	echo "sync meta prjconf from Factory to Slowroll:Base"
	find out/pending/ -mtime +2 -delete
	rm cache/changelog/* cache/changelogdiff/*
	#for p in $(osc ls $slo) ; do echo "$p"; tools/syncslo-postbump "$p" ; done | tee out/log/syncslo-postbump-$(date -I)
	#for p in $(osc ls $slo:Staging) ; do echo "$p"; tools/syncslos-postbump "$p" ; done | tee out/log/syncslos-postbump-$(date -I)
	#tools/syncslo-postbump2 | tee out/log/syncslo-postbump2-$(date -I)
	#https://download.opensuse.org/download/update/slowroll/repo/oss/x86_64/ => "repo" link => "Clear cached info about mirrors" # also mirrorcache-us,br,au ; or find other solution for replaced rpms
	#ask Andrii to add DVD iso .torrent to tracker.o.o
newsnapshot9:
	echo "update https://build.opensuse.org/projects/openSUSE:Slowroll/meta Build:N refs"
	tools/syncslo-post

cache/ring0:
	osc ls openSUSE:Factory:Rings:0-Bootstrap > $@

cache/factory-i586-binaries:
	osc ls -vb --arch i586 openSUSE:Factory > $@
