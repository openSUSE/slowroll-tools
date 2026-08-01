# slowroll-tools test suite

A disposable copy of the release pipeline under `home:bmwiedemannai:Slowroll`,
so changes to the tools can be exercised somewhere that is not the distribution
people are running.

## Prerequisites

- An `osc` config for `api.opensuse.org` (`~/.config/osc/oscrc`), for the direct
  `osc` calls.
- **A `~/.netrc` entry for `api.opensuse.org`.** `tools/osc.sh` authenticates
  with `curl -n`, not through `osc`, so an osc config on its own is not enough:
  without a netrc, curl exits 26 and every REST helper returns nothing. That is
  quiet enough to look like an empty API response - `tools/submitpackageupdate`
  simply fails to resolve `latest` to a revision - so check this first if a run
  behaves oddly.

  ```
  machine api.opensuse.org login YOURUSER password YOURPASS
  ```

## Running it

```sh
set -a ; . test/slorc.test ; set +a   # NOT ~/.slorc
test/assertions --offline             # no OBS, a few seconds
test/runcycle                         # the full thing, ~15 min
```

`test/runcycle` does setup, seeds the packages, waits for the builds, runs a
real `releasestaging` with the installcheck gate enforcing, waits for the
update repo to publish, and then checks the result.

Between runs use `test/resetplayground` (seconds) rather than
`test/teardownplayground` (throws away the build config and every binary).

## Safety

Four independent layers, because the tools contain calls that delete from
production by name:

1. **OBS permissions.** `bmwiedemannai` holds no role in any
   `openSUSE:Slowroll*` project, so those calls get a 403 regardless.
2. **`test/guard.sh`**, sourced first by every script here: refuses to run
   unless every `$slo*` variable points inside `home:bmwiedemannai:Slowroll`,
   refuses if neither `SILENT` nor `MAILER` is set, and touches `.blockcron`.
3. **`osc_guard` in `tools/osc.sh`**: blocks any mutating REST call outside
   `$sloguard`. Everything in the toolchain that changes OBS state goes through
   `osc_api`, so this one check covers all of it. A `cmd=release` is judged by
   its `target_project`, since `releasemulti` legitimately posts to
   `/source/openSUSE:Factory/PKG?cmd=release`.
4. **`test/bin/osc`**, first on `$PATH`: refuses a mutating `osc` subcommand
   that names a production Slowroll project, catching the direct `osc branch`,
   `linkpac`, `rdelete` and friends that never reach `tools/osc.sh`.

Run from a separate clone, so `out/pending/` and `cache/view/` cannot be
confused with a production bot's state. Never run a `make newsnapshot*` target
here - test the individual tools it calls instead.

## What it cannot cover

- **`tools/selectupdates.pl`'s delay heuristics.** They read changelogs from
  the CGI on stage3, which is a partial mirror carrying neither
  `/repositories/` nor `/debug`, so it returns an empty body for a home
  project. Test those offline by pre-populating `cache/changelog*/` instead.
- **The mirror half**: `pontifex/slowroll-snapshot*`,
  `tools/triggernextsnapshot`, `tools/newsnapshot9` - all ssh to a specific
  host, and there is no playground equivalent of a published `/slowroll/` tree.
- **Product and ISO**: `000product`, `000release-packages`,
  `installation-images`, `:Build:Overlay`, `:Build:iso`. Half an hour per build
  and a complete base.
- **Packman coupling** and openQA.

## Layout

| path | what |
|---|---|
| `slorc.test` | the environment; source this instead of `~/.slorc` |
| `guard.sh` | the refusal checks, sourced by every script |
| `meta/*.xml` | one project meta per file, applied in filename order so paths and links exist before they are referenced |
| `meta/build-prjconf` | build-project config template, `@BUILDPRJ@` substituted at setup |
| `packages` | which packages get seeded, and what each is here to exercise |
| `pkg/slowroll-canary.spec` | a package that can never be installable, so the gate has something deterministic to reject |
| `bin/osc`, `bin/mailmock` | the `$PATH` shims |
