# Contributing guidelines

- If your change is a fix for an issue, search if it already
  exists at the opened list of issues of the repo (TODO Add issue list from
  your repo).
- If your change is a security issue, please see: [SECURITY.md](SECURITY.md).

---

- Clone repository: `git clone https://github.com/user/repo.git` TODO update URL
- Create a branch: `git checkout -b my-change`
- Add a unit test at `tests/` directory.
- Update code until `make all` pass.
- Commit and push your changes, and create a PR.

## Commit formats

It follow guidelines for [conventional commits](https://www.conventionalcommits.org/en/v1.0.0/)

```raw
<type>: <title>

What is the change and the motivation for the change.

[Co-authored-by: First Lastname <user@example.com>]
Signed-off-by: First Lastname <user@example.com>
```

Every commit should pass the unit tests.

