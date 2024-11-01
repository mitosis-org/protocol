import { readdirSync, rmSync, writeFileSync } from 'fs';
import { globSync } from 'glob';
import { extname, parse } from 'path';

// XXX: THIS CAN BE IMPROVED
const filter = globSync('src/{branch,hub,interfaces,lib,message,twab}/**/*.sol')
  .map(parse)
  .map(({ name }) => name);

const entries = readdirSync('abis');

const contracts = [];
for (const entry of entries) {
  if (extname(entry) !== '.json') continue;

  const name = entry.replace('.abi.json', '');

  const content = require(`../abis/${entry}`);
  rmSync(`abis/${entry}`);

  if (
    !filter.includes(name) ||
    !Array.isArray(content) ||
    content.length === 0
  ) {
    console.log(`Skipping ${entry}`);
    continue;
  }

  contracts.push(name);

  let builder = '';
  builder += `const ${name} = ${JSON.stringify(content, null, 2)} as const;\n\n`;
  builder += `export { ${name} };\n`;

  writeFileSync(`abis/${name}.ts`, builder);
}

let builder = '';
for (const contract of contracts) {
  builder += `export * from './${contract}';\n`;
}

writeFileSync('abis/index.ts', builder);
