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
