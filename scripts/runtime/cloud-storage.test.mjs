import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync, copyFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
const repo = fileURLToPath(new URL('../../', import.meta.url));

function run({ free = 12000000, reclaim = 12000000, buildStatus = 0, pruneStatus = 0, same = false, action = 'deploy', lockStatus = 0 } = {}) {
  const root = mkdtempSync(path.join(tmpdir(), 'cloud-storage-test-'));
  try {
    for (const dir of ['scripts/runtime', 'scripts/lib', 'bin']) mkdirSync(path.join(root, dir), { recursive: true });
    for (const file of ['scripts/runtime/lifecycle.sh', 'scripts/lib/cloud-storage.sh']) copyFileSync(path.join(repo, file), path.join(root, file));
    writeFileSync(path.join(root, 'free'), String(free));
    writeFileSync(path.join(root, 'scripts/lib/runtime-common.sh'), `
runtime_init_env() { RUNTIME_DEPLOY_ROOT="$TEST_ROOT"; RUNTIME_COMPOSE_FILE=compose.yml; RUNTIME_DEFAULT_CRON_FILE=cron.json; }
runtime_prepare_cloud_state() { :; }
runtime_render_cloud_artifacts() { :; }
runtime_migrate_state() { echo migrate >> "$TEST_ROOT/calls"; }
runtime_compose_cmd() {
  echo "compose $*" >> "$TEST_ROOT/calls"
  case "$*" in
    *'build '*) return "$TEST_BUILD_STATUS";;
    *'ps -q'*) echo fixture-container;;
  esac
}
`);
    writeFileSync(path.join(root, 'scripts/runtime/cron.sh'), 'echo cron >> "$TEST_ROOT/calls"\n');
    const mock = `#!/usr/bin/env node
const fs = require('node:fs');
const path = require('node:path');
const root=process.env.TEST_ROOT, name=path.basename(process.argv[1]), args=process.argv.slice(2), s=args.join(' ');
fs.appendFileSync(root+'/calls', name+' '+s+'\\n');
if (name==='flock') process.exit(Number(process.env.TEST_LOCK_STATUS));
if (name==='df') console.log('Filesystem 1024-blocks Used Available Capacity Mounted on\\n/dev/mock 30000000 0 '+fs.readFileSync(root+'/free','utf8')+' 0% /');
if (name==='docker') {
 if (s.startsWith('info ')) console.log(root);
 if (s.startsWith('inspect ')) console.log('sha256:old');
 if (s.startsWith('image inspect ')) console.log(process.env.TEST_SAME==='1' ? 'sha256:old' : 'sha256:new');
 if (s.startsWith('image prune')) {
   if (!s.includes('until=')) fs.writeFileSync(root+'/free', process.env.TEST_RECLAIM);
   if (process.env.TEST_PRUNE_STATUS!=='0' && fs.existsSync(root+'/built')) process.exit(Number(process.env.TEST_PRUNE_STATUS));
 }
 if (s.startsWith('image tag')) fs.writeFileSync(root+'/built','1');
}
`;
    for (const bin of ['docker', 'df', 'flock']) writeFileSync(path.join(root, 'bin', bin), mock, { mode: 0o755 });
    const result = spawnSync('bash', [path.join(root, 'scripts/runtime/lifecycle.sh'), 'cloud', action, 'fixture-secret-name'], {
      encoding: 'utf8', env: { ...process.env, PATH: `${root}/bin:${process.env.PATH}`, TEST_ROOT: root, TEST_RECLAIM: String(reclaim), TEST_BUILD_STATUS: String(buildStatus), TEST_PRUNE_STATUS: String(pruneStatus), TEST_LOCK_STATUS: String(lockStatus), TEST_SAME: same ? '1' : '0' },
    });
    let calls = '';
    try { calls = readFileSync(path.join(root, 'calls'), 'utf8'); } catch {}
    return { ...result, calls };
  } finally { rmSync(root, { recursive: true, force: true }); }
}

for (const action of ['deploy', 'rebuild']) {
  test(`${action}: prunes before and after build, preserves rollback before stopping gateway`, () => {
    const r = run({ action });
    assert.equal(r.status, 0, r.stderr);
    assert.equal(r.calls.match(/docker image prune --force --filter until=24h/g)?.length, 2);
    assert.ok(r.calls.indexOf('image prune') < r.calls.indexOf('compose -f compose.yml build'));
    assert.ok(r.calls.indexOf('image tag sha256:old claw-runtime-openclaw:cloud-rollback') < r.calls.indexOf('migrate'));
    assert.ok(r.calls.lastIndexOf('image prune') > r.calls.indexOf('cron'));
    assert.doesNotMatch(r.calls, /image prune.*--all|system prune|volume|container rm/);
  });
}
test('low space triggers recent dangling cleanup and permits build after recovery', () => {
  const r = run({ free: 1500000 });
  assert.equal(r.status, 0, r.stderr);
  assert.match(r.calls, /docker image prune --force\n/);
  assert.match(r.calls, /docker builder prune --all --force --keep-storage 1GB/);
});
test('insufficient space aborts before build or gateway stop', () => {
  const r = run({ free: 1500000, reclaim: 2000000 });
  assert.notEqual(r.status, 0);
  assert.match(r.stderr, /Insufficient Docker disk space/);
  assert.doesNotMatch(r.calls, /compose|migrate/);
});
test('failed build still cleans up and preserves original status and running gateway', () => {
  const r = run({ buildStatus: 42 });
  assert.equal(r.status, 42, r.stderr);
  assert.equal(r.calls.match(/docker image prune/g)?.length, 2);
  assert.doesNotMatch(r.calls, /image tag|migrate|cron/);
});
test('same image redeploy leaves prior rollback tag unchanged', () => {
  const r = run({ same: true });
  assert.equal(r.status, 0, r.stderr);
  assert.doesNotMatch(r.calls, /image tag/);
});
test('cleanup failure is reported instead of hidden after successful deploy', () => {
  const r = run({ pruneStatus: 9 });
  assert.notEqual(r.status, 0);
  assert.match(r.stderr, /cleanup failed/);
});
test('concurrent runtime deploy does not build or prune', () => {
  const r = run({ lockStatus: 1 });
  assert.notEqual(r.status, 0);
  assert.doesNotMatch(r.calls, /docker|compose|migrate/);
});
