# GitHub setup recommendations — multi-agent Shinobi Rush

## Repository files now provided
- Root `AGENTS.md` for shared onboarding.
- Per-agent orders and post-job reports.
- Camera/art direction for Codex.
- Local reusable skills in `skills/`.

## GitHub Settings to configure/verify (NOT automatically enabled)
1. Protect `main`: require PRs, at least one review where practical, require passing checks, block force pushes/deletions, and resolve conversations. Configure via repository Settings → Rules → Rulesets / branch protection. Avoid a deadlock where no reviewer is available.
2. Enable automated Godot 4 project import/build validation and Web export in GitHub Actions, **after confirming actual project root, Godot version, export templates, and export preset**. Avoid guessing paths or adding a workflow that always fails.
3. Configure a dedicated live-test deployment workflow (GitHub Pages or the actual existing host) triggered on successful integration to main; grant minimum necessary permissions. Preserve existing deployment before changing anything.
4. Configure environment deployment status and checks. Require CI before merge once checks are actually working.
5. Use `CODEOWNERS` when real GitHub accounts/teams are known; the agent nicknames Aki, Orcha, Kiro, Codex are not necessarily valid GitHub usernames.
6. Set up Dependabot for GitHub Actions if workflows are present, pin trusted actions, review permissions, and never commit credentials or tokens.
7. Add PR template requiring order link, files affected, tests run, report link, screenshots where visual, live URL/build evidence, and outstanding questions.
8. Consider Git LFS only if large binary source-art files exceed sensible Git limits; avoid imposing LFS on small PNG sprite sheets without need.
9. Add automated validation for skill frontmatter, report presence, sprite PNG alpha/dimensions, animation manifests, and broken internal links once repository structure stabilizes.

**Do not assume these GitHub Settings or deployment jobs are active just because documented here.** Someone with repository administration and actual pipeline access must enable/verify them.
