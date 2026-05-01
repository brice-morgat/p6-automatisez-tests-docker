const image = "application-angular";
const appPath = "G-rez-l-int-gration-et-la-livraison-continue-Application-Angular";
const scope = "angular";
const publishImage = [
  'owner="$(echo "$GITHUB_REPOSITORY_OWNER" | tr \'[:upper:]\' \'[:lower:]\')"',
  'short_sha="$(printf %.7s "$GITHUB_SHA")"',
  `docker buildx imagetools create -t "ghcr.io/$owner/${image}:\${nextRelease.version}" "ghcr.io/$owner/${image}:$short_sha"`
].join(" && ");

module.exports = {
  branches: ["main"],
  tagFormat: "angular-v${version}",
  plugins: [
    [
      "@semantic-release/commit-analyzer",
      {
        preset: "conventionalcommits",
        releaseRules: [
          { breaking: true, scope: "angular", release: "major" },
          { type: "feat", scope: "angular", release: "minor" },
          { type: "fix", scope: "angular", release: "patch" },
          { type: "perf", scope: "angular", release: "patch" },
          { breaking: true, release: false },
          { type: "feat", release: false },
          { type: "fix", release: false },
          { type: "perf", release: false }
        ]
      }
    ],
    [
      "@semantic-release/release-notes-generator",
      {
        preset: "conventionalcommits",
        presetConfig: {
          types: [
            { type: "feat", section: "Features" },
            { type: "fix", section: "Bug Fixes" },
            { type: "perf", section: "Performance" }
          ]
        },
        writerOpts: {
          transform: (commit, context) => {
            if (commit.scope !== scope) {
              return false;
            }
            return commit;
          }
        }
      }
    ],
    [
      "@semantic-release/changelog",
      {
        changelogFile: `${appPath}/CHANGELOG.md`,
        changelogTitle: "# Angular Application Changelog"
      }
    ],
    [
      "@semantic-release/exec",
      {
        prepareCmd: "node scripts/sync-release-version.cjs angular ${nextRelease.version}",
        publishCmd: publishImage
      }
    ],
    [
      "@semantic-release/git",
      {
        assets: [
          `${appPath}/package.json`,
          `${appPath}/package-lock.json`,
          `${appPath}/CHANGELOG.md`
        ],
        message: "chore(release): angular ${nextRelease.version} [skip ci]"
      }
    ],
    "@semantic-release/github"
  ]
};
