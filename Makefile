DATE=$(shell date -I)
install:
	zypper -n in wget perl-JSON-XS perl-XML-Bare jq gnu_parallel time

daily: fetch select
fetch:
	#mkdir -p out/frozenlinks/ ; osc api /source/openSUSE:Slowroll:Next/_project/_frozenlinks?meta=1 > out/frozenlinks/${DATE}
	tools/getrepoviews
	tools/diffdistro
	osc api /build/openSUSE:Slowroll/_result > out/result/slo/${DATE}
	#osc api /build/openSUSE:Slowroll:Staging/_result > out/result/slos/${DATE}
	-osc api /build/${slobuild}/_result > out/result/slos/${DATE}
	#osc api /build/${slobase}/_result > out/result/slob/${DATE}

select:
	mkdir -p out/log
	DEBUG=1 tools/selectupdates.pl 2>&1 | tee out/log/select-$$(date -Iseconds)
	for p in $$(find cache/force-submit/ -type f|sort) ; do FORCE=1 tools/submitpackageupdate $$(basename $$p) ; rm $$p ; done
	#DRYRUN=0 tools/selectupdates.pl

release:
	tools/releasestaging 2>&1 | tee out/log/release-$$(date -Iseconds)

newsnapshot1: # before or on day of TW snapshot (~6d ahead of bump) # source slorc.next
	osc api -X DELETE /source/${slobase}/_project/_frozenlinks\?meta=1 ; sleep 5
	osc api -X POST /source/${slobase}?cmd=freezelink
	# sync prjconf from Factory to Base
	echo "sync meta prjconf from Factory to Slowroll:Base:N"
	osc meta prjconf openSUSE:Factory > cache/meta/factory-prjconf && sed -i 's/distribution-logos-openSUSE-Tumbleweed/distribution-logos-openSUSE-Slowroll/; /excludebuild:installation-images:Slowroll/d' cache/meta/factory-prjconf && osc meta prjconf -F cache/meta/factory-prjconf ${slobase}
	# sync i586 (and not -bootstrap (kept in :Staging)) binaries to ${slobase}
	#using /build/openSUSE:Slowroll:Base:2/standard/i586/_repository?view=binaryversions&withevr=1 and osc release
	##tools/syncslob > cache/slobrsync
	osc ls ${slobase} > cache/basenext.ls
	DELETE=1 DRYRUN=0 tools/obsrsync $$(cat in/missing-dvd-rpms* cache/slobrsync cache/basenext.ls)
	#for p in `grep -v : /dev/shm/slobase` ; do echo $p ; PAGER="wc -l" osc rdiff ${slobase} $p openSUSE:Factory ; done 2>&1 | tee /dev/shm/syncslob3
	find cache -mtime +3 -name factory-i586.xml -delete
	#rm -f buildinfo/*
	FORCE=1 ./collectbuildinfo
	./processbuildinfo
	go run cmd/processbuildinfo.go

	#osc ls -vb ${slobase}|grep "Apr.*debugsource" > /tmp/slob ; tools/obsrsync $(perl -ne 'm/.* (.*)-debugsource.rpm/ && print "$1\n"' < /tmp/slob)
	osc linkpac -f openSUSE:Slowroll:Build:Overlay 000release-packages ${slobuild}
	tools/releasemulti openSUSE:Slowroll:Build:Overlay ${slo}:Base:Next branding-openSUSE
newsnapshot2:
	tools/triggernextsnapshot
	# alternatively on mirror@pontifex run /usr/local/bin/slowroll-snapshot as 'mirror' user or update vm12:/srv/www/slowroll/nextsnapshot
	# TODO keep backup of old /update/slowroll for analysis ; on stage3 /srv/ftp/pub/opensuse-old/
	echo update Release: line in osc meta -e prjconf ${slobuild}
	osc wipebinaries --all ${slobuild}
	#echo 'on slowrollbot@opensusevm: cd ~/code/osc/openSUSE:Slowroll:Build:Overlay/000release-packages && ./update.sh && osc ci --noservice'
	(cd ~/code/osc/openSUSE:Slowroll:Build:Overlay/000release-packages && osc up && ./update.sh && osc ci --noservice -m update)
	#echo "update _link in ${slobuild} 000release-packages with new vrev= to match the TW snapshot on bernhard@adrian:~/code/osc/maint/openSUSE:Slowroll:Build:1/000release-packages or ~/code/osc/${slobuild}/000release-packages with sh ./updatevrev.sh"
	(cd ~/code/osc/${slobuild}/000release-packages && osc up && sh updatevrev.sh)
	tools/cleanuprepo ${slobuild} # with next config
	# tools/releasemulti openSUSE:Slowroll:Build:Overlay ${slo}:Base:Next branding-openSUSE ; tools/releasemulti ${slobuild} ${slo}:Base:Next 000release-packages
	echo 'cd ~/code/osc/openSUSE:Slowroll:Build:iso/000product && ./update.sh && osc ci --noservice -m update'
	echo 'sync skelcd-control-openSUSE-Slowroll yast2-installation-control installation-images' # https://github.com/yast/skelcd-control-openSUSE-Slowroll/pull/6
	cd ~/code/osc/openSUSE:Slowroll:Build:iso/installation-images && sh ./update.sh && osc ci --noservice -m update
	# build+test DVD in openSUSE:Slowroll:Build:iso
newsnapshot2b:
	osc rbl openSUSE:Slowroll:Build:iso/000product:openSUSE-dvd5-dvd-x86_64 images x86_64 | perl -ne 'if(/\[W\]   (\S+) not available for /){print "$$1\n"}' | sort -u >> in/missing-dvd-rpms-${DATE}
	DRYRUN=0 tools/obsrsync `cat in/missing-dvd-rpms-${DATE}`
# on day of version bump:
newsnapshot3: # with old $slobuild
	tools/syncslo-pre
	tools/getrepoviews
	#echo "disabling cron jobs..."
	touch .blockcron
	curl https://downloadcontent.opensuse.org/slowroll/next-full/base-next-full/repo/src-oss/src/.slowroll > cache/slowroll-base.disturls
newsnapshot4: # with new $slobuild
	cp -a ~/.slorc.next ~/.slorc
	echo "review in/never-update-exceptions"
	tools/syncslo-pre
	set -x ; for p in `grep -h -v '#' in/i586bitbuilddeps1 in/kmps|sort -u` ; do FORCE=1 tools/submitpackageupdate "$$p" ; done
	echo "notify https://www.reddit.com/r/openSUSE_Slowroll/ about version bump in progress"
	tools/releasemulti ${slo}:Base:Next ${slo}:Base 000release-packages # for NET iso

	find out/pending/ -mtime +1 -delete
	rm -f cache/changelog/* cache/changelogdiff/* cache/triggeronurlchange/http*
	##echo "enable keepobsolete Flag in https://build.opensuse.org/projects/openSUSE:Slowroll/prjconf" # leave enabled. When publishing is enabled, it does not matter.
	# osc copypac openSUSE:Factory kiwi-templates-Minimal ${slobuild} # for openQA # needs adaptation
	for p in $$(osc ls ${slo}|grep -v :|sort -r) ; do echo "$$p"; tools/syncslo-postbump "$$p" ; done | tee out/log/syncslo-postbump-${DATE}
	tools/switchbase openSUSE:Slowroll # update https://build.opensuse.org/projects/openSUSE:Slowroll/meta Build:N refs
	tools/switchbase # update https://build.opensuse.org/projects/openSUSE:Slowroll:Base/meta Build:N refs
	echo make newsnapshot4b
newsnapshot4b:
	for p in $$(osc ls ${slo}|grep -v :|sort -r) ; do echo "$$p"; dry=' ' tools/syncslo-postbump "$$p" ; done | tee out/log/syncslo-postbump-${DATE}b
newsnapshot8: # on day of bump
	osc release --no-delay openSUSE:Slowroll:Base:Next -r standard
	tools/releasemulti ${slo}:Base:Next ${slo} 000release-packages
	##echo "edit tools/diffdistro and tools/selectupdates.pl with slowroll/next as baseurl; make daily" # does not work: slowroll/next does not exist on stage3 to fetch changelogs
	osc release ${slo}:Build:iso --target-project=${slo} 000product --target-repository=images -r images
	tools/syncslo-post # let it build
	make newsnapshot8b
newsnapshot8b: # on day of bump
	( cd / ; osc r -w --xml ${slobuild} >/dev/null )
	DRYRUN=0 make release
	tools/releasemulti ${slobuild} ${slo}:Base AMF # for Packman
	osc wipebinaries -a x86_64 ${slo}:Base AMF
	echo "wait for Packman to finish building https://pmbs.links2linux.de/project/show/Essentials"
	cd / ; osc -A https://pmbs.links2linux.de r -r openSUSE_Slowroll -w --xml Essentials > /dev/null
newsnapshot9:
	tools/syncslo-post2 # enable publishing of update repo
	echo 'on screen mirror@pontifex: dry=" " /usr/local/bin/slowroll-snapshot-2'
	#https://download.opensuse.org/download/update/slowroll/repo/oss/x86_64/ => "repo" link => "Clear cached info about mirrors" # also mirrorcache-us,br,au ; or find other solution for replaced rpms
	echo "re-scan mirrors login for https://download.opensuse.org/slowroll/repo/oss/ noarch + x86_64"
	##echo "on stage3.o.o : edit /etc/munin/plugins/slowrollstats to update build prj"
	-sleep 60m # wait for repos to be updated
	#echo "enable cron jobs"
	rm -f .blockcron
	echo "switch slowroll-next/slowroll in https://build.opensuse.org/projects/openSUSE:Slowroll:Base:1+2/meta"
	tools/switchbase ${slo}:Base:Next
	tr 12 21 <~/.slorc >~/.slorc.next
	echo "ensure ${slobuild} builds for ${slo} and not just ${slobase}"
	echo "notify reddit of completion"
	tools/newsnapshot9

cache/ring0:
	osc ls openSUSE:Factory:Rings:0-Bootstrap > $@

cache/factory-i586-binaries:
	osc ls -vb --arch i586 openSUSE:Factory > $@
