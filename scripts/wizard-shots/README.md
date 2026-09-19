# Regenerating the wizard screenshots

The pictures in [`docs/WIZARD.md`](../../docs/WIZARD.md) are generated from the
wizard, not captured by hand. Two steps:

```bash
npm run starter:build
npm run wizard:shots
```

`drive.py` runs `ranger-starter configure` inside a real pty — the wizard is a
raw-mode keypress loop and refuses a pipe — sends the key script in
`script.json`, and writes the last screenful after each step to `docs/wizard/*.txt`.
`render.py` puts a terminal window around each frame and screenshots it with the
Chromium that Playwright installs, cropping to the content.

The same key scripts are asserted in `src/starter/StarterTest.rgr`
(`testWizardWalk` and the tests after it), so a screenshot that goes stale is a
test that fails.

Requirements: `python3`, `Pillow`, and Chromium at the path `render.py` names.
Neither script is needed to build or use the starter; they only rebuild the
documentation.
