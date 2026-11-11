# Shared GitHub Actions

Reusable composite actions shared across our projects. Reference them from a
workflow with `uses: gebruederheitz/actions/<action>@<ref>`.

## Actions

### Which action sets up my tools?

Use **`setup-tool-versions`** for repositories whose `.tool-versions` lists only
`php`, `nodejs` and `pnpm`. It installs prebuilt binaries in about 15 seconds, needs
no cache and doesn't depend on the Ubuntu apt mirrors.

Use **`cached-asdf`** only if you need a tool `setup-tool-versions` doesn't support,
or the exact PHP patch version from `.tool-versions` (see below). It compiles PHP on
every cache miss, which takes about 12 minutes and happens after each PHP or
Node.js bump, on the first run on `main` after a pull request (pull request caches
aren't visible there), and whenever GitHub has evicted the cache (after 7 days
without use). `cached-asdf` is meant to be retired once repositories have moved to
`setup-tool-versions`.

### `setup-tool-versions`

Reads `.tool-versions` and installs each tool from a prebuilt binary, without asdf
and without compiling:

| Tool in `.tool-versions` | Installed with                                                            |
|--------------------------|---------------------------------------------------------------------------|
| `php`                    | [`shivammathur/setup-php`](https://github.com/shivammathur/setup-php)    |
| `nodejs`                 | [`actions/setup-node`](https://github.com/actions/setup-node)            |
| `pnpm`                   | [`pnpm/action-setup`](https://github.com/pnpm/action-setup) (pnpm 11+)   |

Any other tool, more than one version per tool, or a non-numeric version (`system`,
`latest`, `ref:…`, `path:…`) fails the action with an error pointing at the line.
It can optionally set up [go-task](https://taskfile.dev/), as `cached-asdf` does.

Unlike `cached-asdf`, this action **does not check out** the repository: run
`actions/checkout` before it.

#### Inputs

| Name                 | Default          | Description                                                                 |
|----------------------|------------------|-----------------------------------------------------------------------------|
| `tool-versions-path` | `.tool-versions` | Path to the `.tool-versions` file.                                          |
| `php-extensions`     | `""`             | Passed to setup-php as `extensions`, e.g. `"intl, redis"`.                  |
| `php-ini-values`     | `""`             | Passed to setup-php as `ini-values`, e.g. `"memory_limit=1G"`.              |
| `php-coverage`       | `""`             | Passed to setup-php as `coverage`: `xdebug`, `pcov` or `none`.              |
| `setup-task`         | `"false"`        | Set to `"true"` to install go-task.                                         |
| `repo-token`         | `""`             | GitHub token passed to `go-task/setup-task` to avoid rate limiting.        |

#### Outputs

| Name           | Description                                                     |
|----------------|-----------------------------------------------------------------|
| `php-version`  | The installed PHP version, e.g. `8.4.27`.                       |
| `node-version` | The Node.js version from `.tool-versions`.                      |
| `pnpm-version` | The pnpm version from `.tool-versions`.                         |

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
checkout, replace `cached-asdf` with `setup-tool-versions`, drop `asdf-version`, and
make sure a `packageManager` field in `package.json` names the same pnpm version as
`.tool-versions` (or remove it).

### `cached-asdf`

Installs [asdf](https://asdf-vm.com/) and every language listed in your
`.tool-versions`, caching the installed languages between workflow runs. It also
installs PHP build-time dependencies automatically when `.tool-versions` requests
PHP, and can optionally set up [go-task](https://taskfile.dev/).

#### Inputs

| Name                 | Default          | Description                                                                                     |
|----------------------|------------------|-------------------------------------------------------------------------------------------------|
| `setup-task`         | `"false"`        | Set to `"true"` to install go-task.                                                             |
| `tool-versions-path` | `.tool-versions` | Path to the `.tool-versions` file inspected to decide whether PHP build-time deps are required. |
| `asdf-version`       | `latest `        | The version of asdf to install. Defaults to the latest stable version.                                |

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
