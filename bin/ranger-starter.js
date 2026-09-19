#!/usr/bin/env node
// SPDX-License-Identifier: MIT
//
// The stable entry point. `bin/StarterMain.js` beside it is COMPILED from
// `src/starter/StarterMain.rgr` and is gitignored; this shim is committed so
// that the path in `package.json`'s `bin` field, in the generated projects'
// scripts, and in anything anybody has typed does not change when the build
// output is renamed.
//
// Build it with `npm run starter:build`; `npm install` does that for you through
// the `prepare` script.
'use strict';
const path = require('path');
const fs = require('fs');

const built = path.join(__dirname, 'StarterMain.js');
if (!fs.existsSync(built)) {
  console.error('ranger-starter: not built yet. Run `npm run starter:build`.');
  process.exit(1);
}
require(built);
