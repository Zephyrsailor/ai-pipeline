import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const CLI_PATH = join(__dirname, '..', 'src', 'index.js');

function run(args = []) {
  return new Promise((resolve, reject) => {
    execFile('node', [CLI_PATH, ...args], (error, stdout, stderr) => {
      if (error && error.code !== 0) {
        reject(error);
        return;
      }
      resolve({ stdout: stdout.trim(), stderr: stderr.trim(), exitCode: 0 });
    });
  });
}

describe('hello-cli', () => {
  it('should print "Hello, World!" with no arguments', async () => {
    const { stdout, exitCode } = await run();
    assert.equal(stdout, 'Hello, World!');
    assert.equal(exitCode, 0);
  });

  it('should print "Hello, Alice!" with argument "Alice"', async () => {
    const { stdout, exitCode } = await run(['Alice']);
    assert.equal(stdout, 'Hello, Alice!');
    assert.equal(exitCode, 0);
  });

  it('should print "Hello, John Doe!" with quoted argument "John Doe"', async () => {
    const { stdout, exitCode } = await run(['John Doe']);
    assert.equal(stdout, 'Hello, John Doe!');
    assert.equal(exitCode, 0);
  });
});
