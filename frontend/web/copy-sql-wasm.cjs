const fs = require('fs');
const path = require('path');

const dist = path.join(__dirname, 'node_modules', 'sql.js', 'dist');
for (const file of ['sql-wasm.js', 'sql-wasm.wasm']) {
  fs.copyFileSync(path.join(dist, file), path.join(__dirname, file));
  console.log('copied', file);
}
