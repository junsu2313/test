# Advanced Control button compatibility · 2026-07-30

When the landscape Advanced Control/settings layer was open, its full-screen
panel used `pointer-events: auto`. The transparent panel therefore intercepted
pointer input intended for the existing AF, SHOT, LIVE, STOP, KILL, and CLEAN
buttons.

The panel now uses `pointer-events: none`. Only the settings close button,
priority controls, value-cycle buttons, and focus controls opt back into pointer
input. Existing camera buttons remain reachable through unused overlay space.

Updated files:

- `app/remote-ui/0716-landscape-1.1.html`
- `app/remote-ui/0716-landscape.html`

The active Opal file `/www/remote-ui/0716-landscape-1.1.html` was deployed and
verified with SHA-256:

`68a724139f8d344924bf49d8ff1023306c84f0e5ea1c162aa5ec3771c30ce7af`

The previous deployed file is backed up at:

`/root/d810-deploy-backups/20260730-advanced-controls/0716-landscape-1.1.html`
