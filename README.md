# Shared GitHub Actions

Reusable composite actions shared across our projects. Reference them from a
workflow with `uses: <owner>/<repo>/<action>@<ref>`.

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
- uses: <owner>/<repo>/cached-asdf@v1
  with:
    setup-task: "true"
```
