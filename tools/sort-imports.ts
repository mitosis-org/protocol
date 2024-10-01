import chalk from 'chalk';
import { exec } from 'child_process';
import { Command } from 'commander';
import { promises as fs } from 'fs';
import { readFile, writeFile } from 'fs/promises';
import { glob } from 'glob';
import path from 'path';
import toml from 'toml';
import { promisify } from 'util';

import {
  getFileChecksum,
  hrtime,
  loadCache,
  saveCache,
  timeDiff,
} from './utils';

// Types and constants
type ImportObject = {
  full: string;
  path: string;
};

const IMPORT_ALL_REGEX =
  /^(import\s+(?:(?:[^;'"]+from\s+)?['"])([^'"]+)['"];?\s*)$/gm;
const IMPORT_LINE_REGEX =
  /^import\s+(?:(?:[^;'"]+from\s+)?['"])([^'"]+)['"];?\s*$/;
const LINE_BREAK_REGEX = /(?:\r\n|\r|\n)/g;

// Core logic functions
function trimLineBreak(s: string): string {
  return s.replaceAll(LINE_BREAK_REGEX, '');
}

function toSorted(v: ImportObject[]): string[] {
  const sorted = v
    .sort(({ path: a }, { path: b }) => a.localeCompare(b))
    .map(({ full }) => full);
  return sorted;
}

function sortImports(
  rawImports: string[],
  remappings: string[],
  debug: boolean,
): { sortedImports: string[][]; update: boolean } {
  const src: ImportObject[] = rawImports.map((i) => {
    const m = i.match(IMPORT_LINE_REGEX);
    if (!m) throw new Error(`Invalid import statement: ${i}`);
    return { full: i, path: m[1] };
  });

  const srcGroups = src
    .reduce(
      (acc, i) => {
        acc[acc.length - 1].push(trimLineBreak(i.full));
        if (i.full.endsWith('\n')) acc.push([]);

        return acc;
      },
      [[]] as string[][],
    )
    .filter((g) => g.length > 0);

  const grouped = new Map<string, ImportObject[]>();
  const ungrouped: ImportObject[] = [];

  src.forEach((i) => {
    i.full = trimLineBreak(i.full);

    const remapping = remappings.find((r) => i.path.startsWith(r));
    if (!remapping) {
      ungrouped.push(i);
      return;
    }

    if (!grouped.has(remapping)) grouped.set(remapping, []);
    grouped.get(remapping)!.push(i);
  });

  const dstGroups = [
    ...Array.from(grouped.values()).map(toSorted),
    toSorted(ungrouped),
  ].filter((g) => g.length > 0);

  const update = JSON.stringify(dstGroups) !== JSON.stringify(srcGroups);
  if (debug) {
    console.log(src);
    console.log('=====================================');
    console.log(srcGroups);
    console.log('=====================================');
    console.log(dstGroups);
  }

  return { sortedImports: dstGroups, update };
}

async function processContract({
  filePath,
  remappings,
  cache,
  options,
}: {
  filePath: string;
  remappings: string[];
  cache: Record<string, string> | null;
  options: { check: boolean; debug: boolean };
}): Promise<void> {
  try {
    const t = hrtime();

    const contract = await readFile(filePath, 'utf-8');
    const checksum = getFileChecksum(contract);
    if (cache && cache[filePath] === checksum) {
      console.log(chalk.gray(filePath), `${timeDiff(t)}ms`, '✨');
      return;
    }

    const rawImports = [...contract.matchAll(IMPORT_ALL_REGEX)].map(
      (m) => m[1],
    );

    const { sortedImports, update } = sortImports(
      rawImports,
      remappings,
      options.debug,
    );

    const output = sortedImports.map((g) => g.join('\n')).join('\n\n');

    if (options.check) {
      if (update) throw new Error(`${filePath}'s imports are not sorted`);
      console.log(chalk.gray(filePath), `${timeDiff(t)}ms`, '✅');
      return;
    }

    if (!update) {
      console.log(chalk.gray(filePath), `${timeDiff(t)}ms`, '🍻');
      return;
    }

    const lines = contract.replaceAll(IMPORT_ALL_REGEX, '').split('\n');
    const pragmaIndex = lines.findIndex((l) => l.startsWith('pragma'));

    await writeFile(
      filePath,
      lines.toSpliced(pragmaIndex + 1, 0, output).join('\n'),
    );

    console.log(filePath, `${timeDiff(t)}ms`, '🛠️');
  } catch (err) {
    console.error(`[ERROR] Error processing ${filePath}:`, err);
    if (err instanceof Error) {
      throw new Error(`Failed to process ${filePath}: ${err.message}`);
    } else {
      throw new Error(`Failed to process ${filePath}: Unknown error`);
    }
  }
}

// Main execution logic
async function executeCommand(options: {
  input: string;
  check: boolean;
  debug: boolean;
}): Promise<void> {
  const t = hrtime();
  const cache = await loadCache('sort-imports');
  const files = await glob(options.input);

  const targetFiles = files.filter((file) => path.extname(file) === '.sol');
  if (targetFiles.length === 0) {
    throw new Error('No target files found in the matched files.');
  }

  try {
    const foundryConfig = await readFile('foundry.toml', 'utf-8');
    const {
      profile: {
        default: { remappings: remappingsList },
      },
    } = toml.parse(foundryConfig) as {
      profile: { default: { remappings: string[] } };
    };

    const remappings = remappingsList.map((l) => l.split('=')[0]);

    await promisify(exec)('forge fmt');

    await Promise.all(
      targetFiles.map(
        (filePath) =>
          new Promise<void>((resolve, reject) =>
            processContract({ filePath, remappings, cache, options })
              .then(resolve)
              .catch(reject),
          ),
      ),
    );
  } catch (err) {
    console.error('An error occurred:', err);
    process.exit(1);
  } finally {
    await promisify(exec)('forge fmt');

    await saveCache(
      'sort-imports',
      Object.fromEntries(
        await Promise.all(
          targetFiles.map(async (filePath) => {
            const file = await fs.readFile(filePath, 'utf-8');
            const checksum = getFileChecksum(file);
            return [filePath, checksum];
          }),
        ),
      ),
    );
    console.log(`✨ Job Done. Total time: ${timeDiff(t)}ms`);
  }
}

// Command setup
new Command()
  .name('sort-imports')
  .description('CLI tool to sort import statements in Solidity files')
  .requiredOption('-i, --input <pattern>', 'Glob pattern for files to process')
  .option(
    '-c, --check',
    'check for import statement sorting issues without modifying',
    false,
  )
  .option(
    '-d --debug',
    'enable debug mode to print debug information like raw imports',
    false,
  )
  .action(async (options) => {
    try {
      await executeCommand(options);
    } catch (err) {
      console.error(`[ERROR] ${err instanceof Error ? err.message : err}`);
      process.exit(1);
    }
  })
  .parseAsync(process.argv)
  .catch((err) => {
    console.error('[ERROR] Command parsing error:', err);
    process.exit(1);
  });
