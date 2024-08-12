BASENEXT:=${slobase}

install:
	zypper -n in wget perl-JSON-XS perl-XML-Bare

daily: fetch select
fetch:
	#mkdir -p out/frozenlinks/ ; osc api /source/openSUSE:Slowroll:Next/_project/_frozenlinks?meta=1 > out/frozenlinks/$$(date -I)
	tools/getrepoviews
	tools/diffdistro
	osc api /build/openSUSE:Slowroll/_result > out/result/slo/$$(date -I)
	#osc api /build/openSUSE:Slowroll:Staging/_result > out/result/slos/$$(date -I)
	-osc api /build/${slobuild}/_result > out/result/slos/$$(date -I)
	#osc api /build/${slobase}/_result > out/result/slob/$$(date -I)

select:
	mkdir -p out/log
	DEBUG=1 tools/selectupdates.pl 2>&1 | tee out/log/select-$$(date -Iseconds)
	#DRYRUN=0 tools/selectupdates.pl

release:
	tools/releasestaging 2>&1 | tee out/log/release-$$(date -Iseconds)

newsnapshot1: # on day of TW snapshot (~6d ahead of bump)
	osc api -X DELETE /source/${BASENEXT}/_project/_frozenlinks\?meta=1
	osc api -X POST /source/${BASENEXT}?cmd=freezelink
	# sync prjconf from Factory to Base
	echo "sync meta prjconf from Factory to Slowroll:Base:N"
	osc meta prjconf openSUSE:Factory > cache/meta/factory-prjconf && sed -i 's/distribution-logos-openSUSE-Tumbleweed/distribution-logos-openSUSE-Slowroll/; /excludebuild:installation-images:Slowroll/d' cache/meta/factory-prjconf && osc meta prjconf -F cache/meta/factory-prjconf ${BASENEXT}
	# sync i586 (and not -bootstrap (kept in :Staging)) binaries to ${BASENEXT}
	#using /build/openSUSE:Slowroll:Base:2/standard/i586/_repository?view=binaryversions&withevr=1 and osc release
	##tools/syncslob > cache/slobrsync
	# tools/obsrsync $(cat in/missing-dvd-rpms* cache/slobrsync)
	#for p in `grep -v : /dev/shm/slobase` ; do echo $p ; PAGER="wc -l" osc rdiff $slobase $p openSUSE:Factory ; done 2>&1 | tee /dev/shm/syncslob3
	find cache -mtime +3 -name factory-i586.xml -delete
	rm -f buildinfo/*
	FORCE=1 ./collectbuildinfo
	./processbuildinfo
	go run cmd/processbuildinfo.go

	##tools/syncslob
	#osc ls -vb $slobase|grep "Apr.*debugsource" > /tmp/slob ; tools/obsrsync $(perl -ne 'm/.* (.*)-debugsource.rpm/ && print "$1\n"' < /tmp/slob)
	osc linkpac openSUSE:Slowroll:Build:Overlay 000release-packages $$slobuild
	echo "update _link in $$slobuild 000release-packages with new vrev= to match the TW snapshot"
	tools/releasemulti openSUSE:Slowroll:Build:Overlay $$slo:Base:Next branding-openSUSE
	#for kmp in $(grep -h -v '#' in/kmps) ; do osc linkpac -f openSUSE:Slowroll $kmp $slobuild ; done
newsnapshot2:
	# on pontifex2 run /usr/local/bin/slowroll-snapshot as 'mirror' user
	# TODO keep backup of old /update/slowroll for analysis ; on stage3 /srv/ftp/pub/opensuse-old/
	echo update Release: line in osc meta -e prjconf $$slobuild
	echo osc wipebinaries --all $$slobuild
	# tools/releasemulti openSUSE:Slowroll:Build:Overlay $slo:Base:Next branding-openSUSE ; tools/releasemulti openSUSE:Slowroll:Build:1 $slo:Base:Next 000release-packages
	# build+test DVD in openSUSE:Slowroll:Build:iso
newsnapshot3: # with old $slobuild
	tools/syncslo-pre
	tools/getrepoviews
	echo "disable cron jobs"
	echo "adapt tools/syncslo-postbump files"
newsnapshot4: # with new $slobuild
	cp -a ~/.slorc.next ~/.slorc
	echo "review in/never-update-exceptions"
	tools/syncslo-pre
	##for p in `cat in/javabuilddeps |grep -v '#'` ; do tools/releasemulti openSUSE:Factory $$slobase "$$p" ; done # replaced by obsrsync
	set -x ; for p in `grep -h -v '#' in/i586bitbuilddeps1 in/kmps` ; do FORCE=1 tools/submitpackageupdate "$$p" ; done
	tools/submitpackageupdate virtualbox ; rm -f out/pending/virtualbox
	echo "notify https://www.reddit.com/r/openSUSE_Slowroll/"
	##tools/cleanuprepo $$slo:Staging
	##tools/cleanuprepo $$slo
	##rm -f out/pending/*
	#for p in $(osc ls $slo|grep -v :|sort -r) ; do echo "$p"; tools/syncslo-postbump "$p" ; done | tee out/log/syncslo-postbump-$(date -I)
	#grep ^osc.rdelete out/log/syncslo-postbump-2024-07-09| time parallel --jobs 20 --pipe --block 4k sh
	##tools/syncslos-postbump
	##for p in `cat in/i586bitbuilddeps` ; do touch out/pending/$p ; done
	##touch out/pending/000release-packages # and update the version numbers in there
	tools/releasemulti $$slobuild $$slo:Base 000release-packages # for NET iso
	touch out/pending/000release-packages

	##echo "adapt and run tools/syncbase | bash -x"
	find out/pending/ -mtime +2 -delete
	rm cache/changelog/* cache/changelogdiff/*
	##echo "enable keepobsolete Flag in https://build.opensuse.org/projects/openSUSE:Slowroll/prjconf" # leave enabled. When publishing is enabled, it does not matter.
	# osc copypac openSUSE:Factory kiwi-templates-Minimal $slobuild # for openQA # needs adaptation
	#for p in $(osc ls $slo) ; do echo "$p"; tools/syncslo-postbump "$p" ; done | tee out/log/syncslo-postbump-$(date -I)
	##for p in $(osc ls $slo:Staging) ; do echo "$p"; tools/syncslos-postbump "$p" ; done | tee out/log/syncslos-postbump-$(date -I)
	#tools/syncslo-postbump2 | tee out/log/syncslo-postbump2-$(date -I)
	#https://download.opensuse.org/download/update/slowroll/repo/oss/x86_64/ => "repo" link => "Clear cached info about mirrors" # also mirrorcache-us,br,au ; or find other solution for replaced rpms
	#ask Andrii to add DVD iso .torrent to tracker.o.o
newsnapshot8: # on day of bump
	echo "update https://build.opensuse.org/projects/openSUSE:Slowroll/meta Build:N refs"
	echo "update https://build.opensuse.org/projects/openSUSE:Slowroll:Base/meta Build:N refs"
	osc release --no-delay openSUSE:Slowroll:Base:Next -r standard
	tools/releasemulti ${slo}:Base:Next ${slo} 000release-packages
	##echo "edit tools/diffdistro and tools/selectupdates.pl with slowroll/next as baseurl; make daily" # does not work: slowroll/next does not exist on stage3 to fetch changelogs
	tools/syncslo-post # let it build
	sleep 40m && DRYRUN=0 make release
	tools/releasemulti ${slobuild} ${slo}:Base AMF # for Packman
	osc wipebinaries -a x86_64 ${slo}:Base AMF
newsnapshot9:
	tools/syncslo-post2 # enable publishing of update repo
	echo 'on mirror@pontifex: dry=" " /usr/local/bin/slowroll-snapshot-2'
	echo "re-scan mirrors login for https://download.opensuse.org/app/folder/3855809"
	echo "on stage3.o.o : edit /etc/munin/plugins/slowrollstats to update build prj"

cache/ring0:
	osc ls openSUSE:Factory:Rings:0-Bootstrap > $@

cache/rbring0:
	osc ls home:bmwiedemann:reproducible:distribution:ring0 | grep -v : > $@

cache/ring1:
	osc ls openSUSE:Factory:Rings:1-MinimalX > $@

cache/slfo.ls:
	osc ls SUSE:SLFO:Main:Build > $@

cache/factory-i586-binaries:
	osc ls -vb --arch i586 openSUSE:Factory > $@

branchrb0: cache/ring0
	for p in $$(grep -v -e : -e '^rpm$$' cache/ring0) ; do \
	  bash -x tools/submitpackageupdate $$p ;\
	done

branchrb1: cache/ring1
	for p in $$(grep -v -e : -e '^rpm$$' cache/ring1) ; do \
	  bash -x tools/submitpackageupdate $$p ;\
	done
