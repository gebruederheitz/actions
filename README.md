# Shared GitHub Actions

Reusable composite actions shared across our projects. Reference them from a
workflow with `uses: gebruederheitz/actions/<action>@<ref>`.

## Actions

### `cached-asdf`

Installs [asdf](https://asdf-vm.com/) and every language listed in your
`.tool-versions`, caching the installed languages between workflow runs. It also
installs PHP build-time dependencies automatically when `.tool-versions` requests
PHP, and can optionally set up [go-task](https://taskfile.dev/).

#### Inputs

| Name                 | Default          | Description                                                                                     |
| -------------------- | ---------------- | ----------------------------------------------------------------------------------------------- |
| `setup-task`         | `"false"`        | Set to `"true"` to install go-task.                                                             |
| `tool-versions-path` | `.tool-versions` | Path to the `.tool-versions` file inspected to decide whether PHP build-time deps are required. |

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
