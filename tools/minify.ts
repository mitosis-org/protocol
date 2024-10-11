import * as fs from 'fs';

function minifyFile(filePath: string): void {
  try {
    const data = fs.readFileSync(filePath, 'utf8');
    const minifiedContent = minifyContent(data);
    fs.writeFileSync(filePath, minifiedContent, 'utf8');
    console.log(`File ${filePath} has been successfully minified.`);
  } catch (error) {
    console.error(`Error processing file ${filePath}:`, error);
  }
}

function minifyContent(content: string): string {
  const multilineCommentRegex = /\/\*[\s\S]*?\*\//g;
  const singleLineCommentRegex = /\/\/.*$/gm;
  const emptyLinesRegex = /^\s*[\r\n]/gm;
  const multipleLineBreaksRegex = /[\r\n]+/g;
  const trailingWhitespaceRegex = /[ \t]+$/gm;

  return content
    .replace(multilineCommentRegex, '')
    .replace(singleLineCommentRegex, '')
    .replace(emptyLinesRegex, '')
    .replace(multipleLineBreaksRegex, '\n')
    .replace(trailingWhitespaceRegex, '')
    .trim();
}

function main() {
  const filePath = process.argv[2];

  if (!filePath) {
    console.log('Usage: yarn minify <file_path>');
    process.exit(1);
  }

  minifyFile(filePath);
}

main();
