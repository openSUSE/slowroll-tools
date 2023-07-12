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
