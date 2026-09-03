# third_party

This directory holds vendored third-party packages pulled in via
`dependency_overrides` path dependencies (for example `usb_serial`, added in
commit f2eb730).

Code here is excluded from our formatting and analysis tooling
(`melos run format`, `melos run analyze`, and the CI `check` job) and from
`tool/dep_lint.dart`. It is not our code, so we do not reformat it, lint it
against our own rules, or hold it to our own conventions — doing so would
create needless diffs against upstream and make future updates harder to
review. Treat vendored packages as read-only unless patching upstream
directly is unavoidable.
