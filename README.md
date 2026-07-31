# About

This repo contains tools that assist with maintenance of the openSUSE Slowroll distribution

# Why

To enable as much automation as we can for the openSUSE Slowroll distribution
we need to collect data to asses risk of updates

e.g. the core-ness of a package increases risk of breaking other parts that depend on it.
We can try to express that as a single float between 0 (leaf - nothing depends on it) and 1 (core - everything depends on it - e.g. systemd/glibc)

# How

we collect buildinfo of 16k Factory packages that contain details on which dependencies are used during build and which subpackages are created.
After collection, this data is post-processed into local JSON files.

https://www.zq1.de/~bernhard/linux/opensuse/slowroll/ has zstd-compressed data dumps that avoid a slow fetch via `collectbuildinfo`.

# Usage

    ./collectbuildinfo
    go run cmd/processbuildinfo.go
    DEBUG=1 DRYRUN=0 make daily
    DEBUG=1 make release # later after builds finished and QA succeeded

Before promoting a release, `tools/releasestaging` runs `tools/installcheckrelease`,
which uses `installcheck` from `libsolv-tools` to detect staged packages that would
not be installable for our users - e.g. because a needed newer runtime dependency
was not submitted along with them.

`INSTALLCHECK=warn` (the default) only logs such packages as
`XX installcheck rejected <pkg>`. `INSTALLCHECK=enforce` additionally drops them from
`$sloreleasing` and puts them back into `out/pending/` to be retried once the missing
dependency has landed. `INSTALLCHECK=off` skips the check. Packages that should never
be withheld go into `in/installcheck-exceptions`.
