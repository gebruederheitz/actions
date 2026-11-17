# Shared GitHub Actions

Reusable composite actions shared across our projects. Reference them from a
workflow with `uses: gebruederheitz/actions/<action>@<ref>`.

## Actions

### Which action sets up my tools?

Use **`setup-tool-versions`**. It installs `php`, `nodejs` and `pnpm` from prebuilt
binaries in about 15 seconds, without a cache and without the Ubuntu apt mirrors,
and every other tool in `.tool-versions` with asdf, cached between runs.

Use **`cached-asdf`** only if you need the exact PHP patch version from
`.tool-versions` (see below). It compiles PHP on every cache miss, which takes
5 to 12 minutes and happens after each PHP or Node.js bump, on the first run on
`main` after a pull request (pull request caches aren't visible there), and whenever
GitHub has evicted the cache (after 7 days without use). `cached-asdf` is meant to be
retired once repositories have moved to `setup-tool-versions`.

### `setup-tool-versions`

Reads `.tool-versions` and installs each tool:

| Tool in `.tool-versions` | Installed with                                                            |
|--------------------------|---------------------------------------------------------------------------|
| `php`                    | [`shivammathur/setup-php`](https://github.com/shivammathur/setup-php)    |
| `nodejs`                 | [`actions/setup-node`](https://github.com/actions/setup-node)            |
| `pnpm`                   | [`pnpm/action-setup`](https://github.com/pnpm/action-setup) (pnpm 11+)   |
| anything else            | [asdf](https://asdf-vm.com/), cached (see below)                         |

`php`, `nodejs` and `pnpm` need exactly one numeric version (`8.4`, `8.4.16`);
anything else for them (`system`, `latest`, `ref:…`, several versions) fails the
action with an error pointing at the line, as does a tool listed twice. It can
optionally set up [go-task](https://taskfile.dev/), as `cached-asdf` does.

Unlike `cached-asdf`, this action **does not check out** the repository: run
`actions/checkout` before it. It never modifies `.tool-versions`.

#### Tools installed with asdf

Every other line of `.tool-versions` (e.g. `python`) is installed with asdf, exactly
as listed, and is skipped entirely (no asdf setup) when there is none:

- **Cache:** `~/.asdf/` is cached under a key made of the runner's OS, architecture
  and **OS release** (e.g. `ubuntu-26.04`) plus a hash of those lines. A change to any
  of them installs everything again; there is deliberately no prefix fallback, so a
  cached shim can never shadow a tool installed from a prebuilt binary. The cache is
  saved right after installing, so a later failing step doesn't discard it. The OS
  release is part of the key because compiled tools link against the system
  libraries: a PHP compiled on Ubuntu 24.04 doesn't start on 26.04.
- **Versions:** the action sets `ASDF_<TOOL>_VERSION` for the rest of the job, so the
  tools work in any directory, whatever `tool-versions-path` is.
- **System packages:** plugins that compile need the build dependencies they
  document; install missing ones with `apt-get` before this action. For example,
  asdf-python compiles Python 3.13 on `ubuntu-latest` in about 1.5 minutes, but
  without the `bz2` and `readline` modules unless `libbz2-dev` and
  `libreadline-dev` are installed first. Prefer adding a prebuilt installer for a
  tool to this action over relying on compiling it.

#### Falling back to asdf (opt-in)

By default a failing prebuilt install of `php`, `nodejs` or `pnpm` fails the action.
With `asdf-fallback: "true"` the tool is installed with asdf instead, with a
warning. For PHP that means compiling it (several minutes) after installing its
build dependencies with apt, so the job then depends on the Ubuntu mirrors again.

#### Inputs

| Name                 | Default          | Description                                                                 |
|----------------------|------------------|-----------------------------------------------------------------------------|
| `tool-versions-path` | `.tool-versions` | Path to the `.tool-versions` file.                                          |
| `php-extensions`     | `""`             | Passed to setup-php as `extensions`, e.g. `"intl, redis"`.                  |
| `php-ini-values`     | `""`             | Passed to setup-php as `ini-values`, e.g. `"memory_limit=1G"`.              |
| `php-coverage`       | `""`             | Passed to setup-php as `coverage`: `xdebug`, `pcov` or `none`.              |
| `asdf-fallback`      | `"false"`        | `"true"`: install `php`/`nodejs`/`pnpm` with asdf when the prebuilt install fails. |
| `asdf-version`       | `latest`         | The asdf version used for tools installed with asdf.                       |
| `setup-task`         | `"false"`        | Set to `"true"` to install go-task.                                         |
| `repo-token`         | `""`             | GitHub token passed to `go-task/setup-task` to avoid rate limiting.        |

#### Outputs

| Name           | Description                                                     |
|----------------|-----------------------------------------------------------------|
| `php-version`  | The installed PHP version, e.g. `8.4.27`.                       |
| `node-version` | The Node.js version from `.tool-versions`.                      |
| `pnpm-version` | The pnpm version from `.tool-versions`.                         |
| `asdf-tools`   | The `.tool-versions` lines installed with asdf, one per line.   |
| `asdf-cache-hit` | `true` when those were restored from the cache for the exact key. |

#### Usage

```yaml
- uses: actions/checkout@v7
- uses: gebruederheitz/actions/setup-tool-versions@v1
  with:
    setup-task: "true"
    repo-token: ${{ github.token }}
```

#### Things to know

- **PHP patch versions are not honoured.** setup-php only uses major.minor and
  installs the newest patch release it has a build for: `php 8.4.16` installs the
  current 8.4.x. The action then emits a warning naming both versions. Node.js and
  pnpm are installed exactly as listed.
- **PHP extensions:** setup-php's prebuilt PHP comes with most common extensions
  already enabled (including `gd`, `intl`, `redis`, `imagick` and Xdebug), so
  `php-extensions` is usually only needed to enable an extension that is missing or
  to disable one (`:xdebug`). Extensions are not read from `composer.json`; a missing
  one makes `composer install` fail with a platform requirement error. Set
  `php-coverage: none` to turn Xdebug off when you don't collect coverage, which
  speeds up tests and static analysis.
- **pnpm and `packageManager`:** if `package.json` also declares
  `"packageManager": "pnpm@…"` with a different version, `pnpm/action-setup` fails
  with "Multiple versions of pnpm specified". The same version is fine.
- **No apt:** on GitHub-hosted Ubuntu runners setup-php downloads a prebuilt PHP
  from GitHub instead of installing packages with apt, so an Ubuntu mirror or PPA
  outage doesn't break the setup. The test workflow checks this with every apt host
  blocked.

#### Migrating from `cached-asdf`

Add `actions/checkout` before the action if the job relied on `cached-asdf`'s
checkout, replace `cached-asdf` with `setup-tool-versions` (inputs `setup-task`,
`repo-token`, `tool-versions-path` and `asdf-version` carry over), and make sure a `packageManager` field in `package.json` names the same pnpm version as
`.tool-versions` (or remove it).

### `cached-asdf`

Installs [asdf](https://asdf-vm.com/) and every language listed in your
`.tool-versions`, caching the installed languages between workflow runs. It also
installs PHP build-time dependencies automatically when `.tool-versions` requests
PHP, and can optionally set up [go-task](https://taskfile.dev/).

The action checks out the repository itself and installs from the `.tool-versions`
in the repository root.

#### Caching

The installed languages (`~/.asdf/`) are cached under a key made of the runner's OS,
architecture and **OS release** (e.g. `Linux-X64-ubuntu-26.04-asdf-`) plus a hash of
all `.tool-versions` files in the repository. The OS release is part of the key
because compiled languages link against the system libraries: when `ubuntu-latest`
moved from 24.04 to 26.04, a cached PHP compiled on 24.04 failed to start with
`libxml2.so.2: cannot open shared object file`. Now the first run on a new release
compiles again. The cache is saved **right after the
languages are installed**, not at the end of the job, so a failing lint or test step
later in the job no longer throws away a fresh PHP compile. Nothing is saved when
the cache was restored for the exact key, or when installing failed.

When no exact entry exists, the most recent entry for the same OS release is restored instead
and asdf installs only what is missing. This is deliberate: after a Node.js bump the
previously compiled PHP is reused.

Keep in mind that GitHub only shares caches downwards: entries saved by a pull
request run are not visible to runs on `main`, and entries unused for 7 days are
evicted.

#### PHP build dependencies

When the cache is not an exact hit and `.tool-versions` requests PHP, the action
installs the Debian/Ubuntu packages needed to compile PHP with `apt-get`. The
package list is vendored in [`cached-asdf/php-build-deps.sh`](cached-asdf/php-build-deps.sh) instead
of downloading and running php-build's script at run time. apt's network waits are
bounded (1 retry and 15 s timeouts, as preset on GitHub's Ubuntu images, plus a
hard limit of 2 minutes for `apt-get update` and 5 minutes for `apt-get install`),
so an unreachable Ubuntu mirror fails the step within about 7 minutes instead of
hanging the job. A healthy run of the step takes well under a minute.

The list is php-build's, plus `libgd-dev`:

- **Source:** the `debian|ubuntu)` branch of
  [`install-dependencies.sh`](https://github.com/php-build/php-build/blob/2fecc9da7425e66307fca0341267a239c4502d25/install-dependencies.sh)
  in php-build/php-build, copied at commit
  `2fecc9da7425e66307fca0341267a239c4502d25` (2026-05-07). The asdf PHP plugin
  compiles PHP with php-build.
- **`libgd-dev`** is our own addition. Up to asdf-php's rewrite onto php-build
  (asdf-community/asdf-php@efb4ccdae2, 2026-11-05) the plugin always configured
  PHP with `--with-external-gd`, which links the GD extension against the system
  libgd and fails without its headers. The rewritten plugin builds GD from PHP's
  bundled copy, so the package is probably no longer needed; it stays until a
  build without it has been verified.

##### Updating the PHP build dependencies

1. Compare upstream's current script with the recorded commit:

   ```bash
   OLD=2fecc9da7425e66307fca0341267a239c4502d25
   NEW=$(gh api 'repos/php-build/php-build/commits?path=install-dependencies.sh&per_page=1' --jq '.[0].sha')
   echo "$NEW"
   diff \
     <(gh api "repos/php-build/php-build/contents/install-dependencies.sh?ref=$OLD" -H 'Accept: application/vnd.github.raw') \
     <(gh api "repos/php-build/php-build/contents/install-dependencies.sh?ref=$NEW" -H 'Accept: application/vnd.github.raw')
   ```

   Without `gh`, fetch both versions with
   `curl -fsSL https://raw.githubusercontent.com/php-build/php-build/<sha>/install-dependencies.sh`.
   No output from `diff` means nothing to do.
2. Copy the package names from the `apt-get install` command in the
   `debian|ubuntu)` branch into the `packages` array in
   `cached-asdf/php-build-deps.sh`. Keep upstream's order and keep
   `libgd-dev` last, under its comment. Changes to the other branches (RHEL, Arch,
   macOS) don't concern us; GitHub's Linux runners are Ubuntu.
3. Replace the recorded SHA (and date) with `$NEW` in the script's comment and in this
   section, in the same commit as the package changes.
4. Open a pull request: the "Test cached-asdf PHP build" workflow
   ([`.github/workflows/test-cached-asdf-php-build.yml`](.github/workflows/test-cached-asdf-php-build.yml))
   compiles every supported PHP minor version with the new list on `ubuntu-latest`.
   When PHP releases a new minor version or drops one, update its matrix too.

#### Inputs

| Name                 | Default          | Description                                                                                     |
|----------------------|------------------|-------------------------------------------------------------------------------------------------|
| `setup-task`         | `"false"`        | Set to `"true"` to install go-task.                                                             |
| `tool-versions-path` | `.tool-versions` | Path to the `.tool-versions` file inspected to decide whether PHP build-time deps are required. |
| `asdf-version`       | `latest `        | The version of asdf to install. Defaults to the latest stable version.                                |

#### Outputs

| Name        | Description                                                                          |
|-------------|--------------------------------------------------------------------------------------|
| `cache-hit` | `true` when the asdf cache was restored for the exact key and nothing was installed. |
| `cache-key` | The asdf cache key, e.g. `Linux-X64-ubuntu-26.04-asdf-<hash>`.                       |

> **Note:** GitHub Actions inputs are always strings, so boolean-like inputs are
> passed and compared as `"true"` / `"false"`.

#### Usage

```yaml
- uses: gebruederheitz/actions/cached-asdf@v1
  with:
    setup-task: "true"
```

### `composer-cache`

Caches Composer packages (the vendor directory and Composer's local cache)
between workflow runs.

#### Inputs

| Name          | Default  | Description                                          |
| ------------- | -------- | ---------------------------------------------------- |
| `vendor_path` | `vendor` | Path to the vendor directory Composer installs into. |

#### Outputs

| Name        | Description                                                     |
| ----------- | -------------------------------------------------------------- |
| `cache-hit` | `true` when the vendor directory was restored from cache.      |

#### Usage

```yaml
- uses: gebruederheitz/actions/composer-cache@v1
  id: composer-cache
- run: composer install
  if: steps.composer-cache.outputs.cache-hit != 'true'
```

## Releasing

Releases are cut locally with [release-it](https://github.com/release-it/release-it)
via [go-task](https://taskfile.dev/). One-time setup:

```bash
npm install
export GITHUB_TOKEN=<a token with repo scope>   # used to publish the GitHub release
```

Then:

```bash
task release
```

This prompts for the next semantic version (based on the current one), creates and
pushes the `vX.Y.Z` tag, publishes a GitHub release, and force-moves the floating
major tag (e.g. `v1`) to the new release so consumers pinned to `@v1` pick it up.

> Consumers pin to the major tag, e.g. `uses: gebruederheitz/actions/cached-asdf@v1`.
> If moving the major tag ever fails after a release, re-run it manually:
> `task major-tag TAG=v1.2.0`.
