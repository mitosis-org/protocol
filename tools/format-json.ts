import chalk from 'chalk';
import { Command } from 'commander';
import { promises as fs } from 'fs';
import { glob } from 'glob';
import * as path from 'path';
import { getAddress } from 'viem';

import {
  getFileChecksum,
  hrtime,
  loadCache,
  saveCache,
  timeDiff,
} from './utils';

const ethereumAddressRegex = /^0x[a-fA-F0-9]{40}$/;

// Address handling
function convertToChecksum(address: string): string {
  return getAddress(address);
}

function processJsonValue(filePath: string, check: boolean, value: any): any {
  if (typeof value === 'string' && ethereumAddressRegex.test(value)) {
    const checksummed = convertToChecksum(value);
    const hasChanged = checksummed !== value;
    if (hasChanged && check)
      throw new Error(
        `${filePath} contains non-checksum addresses.` +
          ` (before: ${value}, after: ${checksummed})`,
      );

    return checksummed;
  }
  return value;
}

function processJsonObject(
  filePath: string,
  check: boolean,
  data: Record<string, any>,
): Record<string, any> {
  return Object.fromEntries(
    Object.entries(data)
      .map(([k, v]) => [k, processJson(filePath, check, v)])
      .sort(([a], [b]) => a.localeCompare(b)),
  );
}

function processJsonArray(
  filePath: string,
  check: boolean,
  data: any[],
): any[] {
  return data.map((i) => processJson(filePath, check, i));
}

function processJson(filePath: string, check: boolean, data: any): any {
  if (typeof data === 'object' && data !== null) {
    return Array.isArray(data)
      ? processJsonArray(filePath, check, data)
      : processJsonObject(filePath, check, data);
  }
  return processJsonValue(filePath, check, data);
}

// File processing
async function processFile(
  filePath: string,
  checkOnly: boolean,
  cache: Record<string, string> | null,
): Promise<[string, string]> {
  const t = hrtime();

  const file = await fs.readFile(filePath, 'utf-8');
  const checksum = getFileChecksum(file);
  if (cache && cache[filePath] === checksum) {
    console.log(chalk.gray(filePath), `${timeDiff(t)}ms`, '✨');
    return [filePath, checksum];
  }

  const data = JSON.parse(file);

  const updatedData = processJson(filePath, checkOnly, data);
  if (checkOnly) {
    console.log(chalk.gray(filePath), `${timeDiff(t)}ms`, '✅');
    return [filePath, checksum];
  }

  const noUpdate = JSON.stringify(data) === JSON.stringify(updatedData);

  if (noUpdate) {
    console.log(chalk.gray(filePath), `${timeDiff(t)}ms`, '🍻');
    return [filePath, checksum];
  }

  await fs.writeFile(filePath, JSON.stringify(updatedData, null, 2) + '\n');
  console.log(filePath, `${timeDiff(t)}ms`);
  return [filePath, checksum];
}

// Main execution logic
async function executeCommand(
  globPattern: string,
  checkOnly: boolean,
): Promise<void> {
  const t = hrtime();
  const cache = await loadCache('format-json');
  const files = await glob(globPattern);

  if (files.length === 0) {
    console.warn('[WARN] No files found matching the specified pattern.');
    return;
  }

  const jsonFiles = files.filter((file) => path.extname(file) === '.json');
  if (jsonFiles.length === 0) {
    throw new Error('No JSON files found in the matched files.');
  }

  const result = await Promise.all(
    jsonFiles.map(
      (filePath) =>
        new Promise<[string, string]>((resolve, reject) =>
          processFile(filePath, checkOnly, cache)
            .then(resolve)
            .catch((err) => {
              console.error(`[ERROR] Error processing ${filePath}:`, err);
              reject(err);
            }),
        ),
    ),
  );

  if (jsonFiles.length < files.length) {
    console.warn(
      `[WARN] ${files.length - jsonFiles.length} non-JSON files were skipped.`,
    );
  }

  await saveCache('format-json', Object.fromEntries(result));

  console.log(`✨ Job Done. Total time: ${timeDiff(t)}ms`);
}

// Command setup
new Command()
  .name('format-json')
  .description(
    `Format JSON files
- Sort JSON
- Ethereum address to checksummed address`,
  )
  .requiredOption('-i --input <pattern>', 'Glob pattern for files to process')
  .option(
    '-c --check',
    'Check for non-checksum addresses without modifying files',
    false,
  )
  .action(async (options) => {
    try {
      await executeCommand(options.input, options.check);
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
