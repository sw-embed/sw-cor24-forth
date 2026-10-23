# Forth on COR24 — presentation

`build.js` generates `forth-on-cor24.pptx` with pptxgenjs; `forth-on-cor24.odp`
is the LibreOffice conversion of it.

```bash
cd docs/presentation
npm install pptxgenjs            # once
NODE_PATH=$PWD/node_modules node build.js
soffice --headless --convert-to odp forth-on-cor24.pptx
```

`build.js` requires the pptx skill's `apply_theme.js` by absolute path; adjust
that line if the skill lives elsewhere. Content sources: this repo's docs and
`forth-*/docs/`, `web-sw-cor24-forth/docs/`, and the ISA crate.
