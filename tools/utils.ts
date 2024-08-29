import { createHash } from 'crypto';
import { promises as fs } from 'fs';
import * as path from 'path';

export function getFileChecksum(filePath: string): string {
  return createHash('sha256').update(filePath).digest('hex');
}

export async function loadCache(
  toolName: string,
): Promise<Record<string, string> | null> {
  const cacheDir = `${process.cwd()}/cache/tools`;
  const cachePath = path.join(cacheDir, `${toolName}.json`);
  const exists = await fs.access(cachePath).then(
    () => true,
    () => false,
  );
  if (!exists) return null;

  const cache = await fs.readFile(cachePath, 'utf-8');
  return JSON.parse(cache);
}

export async function saveCache(
  toolName: string,
  cache: Record<string, string>,
) {
  const cacheDir = `${process.cwd()}/cache/tools`;
  await fs.mkdir(cacheDir, { recursive: true });

  const cachePath = path.join(cacheDir, `${toolName}.json`);
  await fs.writeFile(cachePath, JSON.stringify(cache, null, 2) + '\n');
}

export function hrtime(): number {
  const [t1, t2] = process.hrtime();
  return t1 * 1_000_000_000 + t2;
}

export function timeDiff(start: number): string {
  return ((hrtime() - start) / 1_000_000).toPrecision(3);
}
