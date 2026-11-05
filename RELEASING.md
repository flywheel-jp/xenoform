note: This document is for maintainers of xenoform.

# How to release a new version

1. Ensure you are currently on `main` branch.
1. Update `version` field in `Cargo.toml` file.
1. Create a PR with the version bump (`Cargo.toml` and `Cargo.lock`) and merge it. You can't push directly to `main`.
1. `git switch main && git pull`
1. `git tag "v$(yq -er '.package.version' Cargo.toml)"`
1. `git push --tags`
1. GitHub Actions workflow should make a new release in <https://github.com/flywheel-jp/xenoform/releases>.
1. Edit description of the new release based on the changes since the last release.
