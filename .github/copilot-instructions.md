<!-- Copilot instructions for contributors and AI agents -->
# Repository guidance for AI coding agents

Purpose: Help an AI coding agent become productive quickly in this repository.

High-level summary
- **Repo type:** Collections of HOWTOs, Kubernetes manifests, small sample apps and scripts. Most content is Markdown documentation for Linux, Kubernetes, monitoring and related tooling.
- **Not a single app:** There is a top-level .NET solution (`linux-how-to.sln`) used for small utilities, plus multiple small projects under folders like `09-test-access-to-sites/dotnet/ProxyWebChecker` and `K8_resources/k8_dotnet-web-app`.

Key files & directories (follow these first)
- `linux-how-to.sln` — root .NET solution; used by workspace `build`/`publish` tasks.
- `09-test-access-to-sites/` — contains runnable test utilities: shell scripts, Node.js and a .NET console app (`ProxyWebChecker`). See `09-test-access-to-sites/dotnet/.vscode/tasks.json` for per-project tasks.
- `K8_resources/` — Kubernetes manifests and example microservices. Treat these as configuration artifacts, not executable code.
- `images/` and `08-log-forwarder/images/` — assets referenced from Markdown; keep image paths stable.

Build, run and debug workflows (explicit commands)
- Use the provided VS Code tasks (workspace): `Run Task -> build` runs `dotnet build ${workspaceFolder}/linux-how-to.sln`.
- Per-project commands (example):
  - Build ProxyWebChecker: `dotnet build 09-test-access-to-sites/dotnet/ProxyWebChecker/ProxyWebChecker.csproj`
  - Publish: `dotnet publish 09-test-access-to-sites/dotnet/ProxyWebChecker/ProxyWebChecker.csproj`
  - Watch/run: `dotnet watch run --project 09-test-access-to-sites/dotnet/ProxyWebChecker/ProxyWebChecker.csproj`
- Node sample runner: `09-test-access-to-sites/nodejs/run_me.sh` (read before running; uses `node` and local CSVs).

Project-specific conventions
- File ordering: many Markdown files use numeric prefixes like `01-...`, `02-...` — preserve or update ordering when adding new HOWTOs.
- Documentation-first: most contributions are docs. Avoid large refactors of Markdown formatting unless explicitly requested.
- Small focused changes: prefer minimal diffs that touch only the relevant HOWTO, script, or manifest. Do not reorder unrelated files.

Integration & external dependencies
- The docs reference external systems (Proxmox, Prometheus, Grafana, FreeIPA, HashiCorp Vault, Kubernetes clusters). Do not attempt to run or mock them automatically; instead add clear instructions and prerequisites when adding examples.
- If adding code that depends on external services, include environment variables, version expectations and a minimal local mock where practical.

Patterns to follow when editing code or docs
- When changing code, update the nearest README or the top-level `README.md` with exact commands to build/run the change.
- For .NET projects, preserve SDK target frameworks (examples: `net6.0`, `net8.0` in `*.csproj`). Match the project's `TargetFramework` instead of upgrading without confirmation.
- For Kubernetes manifests, prefer small, idempotent patches (add/modify single resource files). Keep namespace and secret handling out of repo — document how to create them instead of committing credentials.

What to avoid
- Don't alter many HOWTO files in a single PR. The repo is a curated set of guides; changes should be reviewable by topic.
- Avoid adding new toolchain requirements (e.g., databases, message brokers) without documenting install steps.

Where to look for examples
- `09-test-access-to-sites/dotnet/ProxyWebChecker` — small .NET console app and VS Code task examples.
- `K8_resources/k8_dotnet-web-app/MyMicroservice` — example microservice project file (`MyMicroservice.csproj`).
- `09-test-access-to-sites/nodejs` — minimal Node.js script + `run_me.sh` to show how scripts consume CSV test data.

If uncertain, ask before large changes
- For cross-cutting changes (solution-level, major manifest reorganizations), open an issue or ask the repository owner. Include a short rationale and a draft plan.

Feedback loop
- After applying changes, run the small project tasks above (build/publish/watch) when relevant and add brief verification steps to the PR description.

End of file.
