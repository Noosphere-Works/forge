## Summary

Each GitHub release title is the piece tag (`<piece>-vX.Y.Z`, or `vX.Y.Z`
outside a workspace).

## Changes

- `release-piece.yml` passes `--title "$TAG"` to `gh release create`. With no
  title, GitHub leaves `name` empty and the release list shows the tagged
  commit subject.

## Validation

- The publish step is `gh release create "$TAG" --title "$TAG"`.

## Previous Release

v0.1.3
