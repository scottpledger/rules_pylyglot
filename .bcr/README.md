# Bazel Central Registry

When the ruleset is released, we want it to be published to the
Bazel Central Registry automatically:
<https://registry.bazel.build>

This folder contains configuration files to automate the publish step.
See <https://github.com/bazel-contrib/publish-to-bcr/blob/main/templates/README.md>
for authoritative documentation about these files.

## Repository setup

Publication uses the following repository resources:

- BCR fork: <https://github.com/scottpledger/bazel-central-registry>
- Actions secret: `BCR_PUBLISH_TOKEN`
- Release workflow: `.github/workflows/release.yaml`
- Manual publication retry: `.github/workflows/publish.yaml`

`BCR_PUBLISH_TOKEN` must be a classic GitHub personal access token owned by a
user who can push to the fork. It needs the `repo` and `workflow` scopes because
the publish workflow pushes a branch to the fork and opens a pull request
against `bazelbuild/bazel-central-registry`.

## Publishing a release

1. Merge the release contents to `main`.
2. Run the **Tag a Release** workflow, or push a semantic tag such as `v0.1.0`.
3. The release workflow creates the source archive and API documentation,
   publishes a draft GitHub release, and invokes the BCR workflow.
4. The BCR workflow opens a draft pull request because this module is maintained
   under a personal GitHub account.
5. Review the generated entry and mark the BCR pull request ready for review.
6. After BCR publication succeeds, the release workflow publishes the draft
   GitHub release.

If publication must be retried without rebuilding a release, manually run
**Publish to BCR** with the existing tag name.
