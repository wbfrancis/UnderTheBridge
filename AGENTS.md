# Windows OptMem invocation

On this Windows machine, `C:\Users\wbfra\.optmem\memo` is an extensionless
Python script. Never execute it directly: doing so opens Windows' app chooser.

Use the global `optmem` launcher for every OptMem command:

```powershell
optmem <command>
```

In particular, the mandatory startup command is:

```powershell
optmem wake
```

Do not invoke OptMem through Codex's bundled Python runtime.

Follow the rest of the OptMem instructions supplied by the parent `AGENTS.md`.

## Agent skills

### Issue tracker

Issues and specs live in GitHub Issues for `wbfrancis/UnderTheBridge`. See `docs/agents/issue-tracker.md`.

### Triage labels

Use the five standard triage labels. See `docs/agents/triage-labels.md`.

### Domain docs

This is a single-context project. Read the root `CONTEXT.md` and relevant decisions under `docs/adr/`. See `docs/agents/domain.md`.
