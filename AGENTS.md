# Repository Guidelines

## Project Structure & Module Organisation
- Core sources live at the root: `dwl.c`, `util.c`, headers `client.h`, `util.h`.
- Configuration is via `config.h` (copy `config.def.h` to `config.h`).
- Build files: `Makefile`, `config.mk`; Wayland XMLs in `protocols/`.
- Documentation and assets: `README.md`, `dwl.1`, `dwl.desktop`, `CHANGELOG.md`.

## Build, Run, and Install
- Build: `make` (generates protocol headers with `wayland-scanner` and produces `./dwl`).
- Clean: `make clean`; Dist tarball: `make dist`.
- Install: `make install DESTDIR=/path` (also installs man page and desktop entry). Uninstall: `make uninstall`.
- XWayland: enable by uncommenting `XWAYLAND`/`XLIBS` in `config.mk`.
- Custom wlroots: set `WLR_INCS` and `WLR_LIBS` in `config.mk` as documented there.
- Run locally for nested testing: `./dwl` within an existing X11/Wayland session.

## Coding Style & Naming Conventions
- Language: C with wlroots headers (C11 unions). Compiler `cc`; keep builds warning-clean under default `DWLDEVCFLAGS`.
- Indentation with tabs; K&R braces; keep lines succinct; no trailing whitespace.
- Naming: macros UPPER_CASE; types CamelCase (e.g., `Monitor`); functions/variables lower_snake_case.
- Keep dependencies minimal; prefer small, focused changes and static helpers.

## Testing Guidelines
- No automated test suite. Validate by: building successfully, launching `./dwl` nested, exercising keybindings, opening clients, and checking multi-monitor, fullscreen, and urgency behaviours.
- When changing interfaces or defaults, update `dwl.1`, `README.md`, and `config.def.h` accordingly.

## Commit & Pull Request Guidelines
- Commits: short, imperative subject lines; keep scope clear (e.g., "fix:", "docs:"). Include rationale in the body when non-trivial and reference issues/MRs when relevant.
- PRs: include a concise description, motivation, summary of changes, manual testing steps, and any configuration toggles (e.g., `config.mk`/`config.h`). Add screenshots or logs for user-visible behaviour.

## Agent Notes
- Do not introduce new build tools or dependencies.
- Prefer changes gated via `config.h`/`config.mk`.
- Preserve strict compilation flags and address all warnings.
