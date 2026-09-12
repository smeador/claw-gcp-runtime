import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { spawn } from 'node:child_process';
import { once } from 'node:events';
import net from 'node:net';
import test from 'node:test';

const source = fileURLToPath(new URL('../../opentofu/modules/cost_controls/function_source/', import.meta.url));
const require = createRequire(path.join(source, 'package.json'));
const { InstancesClient } = require('@google-cloud/compute');
const { CloudEvent, HTTP } = require('cloudevents');
const event = payload => ({ data: { message: { data: Buffer.from(JSON.stringify(payload)).toString('base64') } } });

// Exercise the installed SDK's class shape while ensuring tests cannot stop a VM.
const calls = [];
let status = 'RUNNING';
const originalGet = InstancesClient.prototype.get;
const originalStop = InstancesClient.prototype.stop;
InstancesClient.prototype.get = async args => { calls.push(['get', args]); return [{ status }]; };
InstancesClient.prototype.stop = async args => { calls.push(['stop', args]); return [{}]; };
const { stopLabVm } = require(path.join(source, 'index.js'));

for (const [name, payload, expectedStatus, expectedMethods] of [
  ['within budget', {costAmount: 5, budgetAmount: 10}, 'RUNNING', []],
  ['at budget', {costAmount: 10, budgetAmount: 10}, 'RUNNING', []],
  ['over budget', {costAmount: 11, budgetAmount: 10}, 'RUNNING', ['get', 'stop']],
  ['already stopped', {costAmount: 11, budgetAmount: 10}, 'TERMINATED', ['get']],
  ['invalid amount', {costAmount: 'invalid', budgetAmount: 10}, 'RUNNING', []],
]) {
  test(`upgraded SDK: ${name}`, async () => {
    calls.length = 0;
    status = expectedStatus;
    const saved = Object.fromEntries(['TARGET_PROJECT_ID','TARGET_INSTANCE_ZONE','TARGET_INSTANCE'].map(k => [k, process.env[k]]));
    Object.assign(process.env, {TARGET_PROJECT_ID:'fixture-project',TARGET_INSTANCE_ZONE:'fixture-zone',TARGET_INSTANCE:'fixture-vm'});
    try {
      await stopLabVm(event(payload));
      assert.deepEqual(calls.map(c => c[0]), expectedMethods);
      for (const [,args] of calls) assert.deepEqual(args, {project:'fixture-project',zone:'fixture-zone',instance:'fixture-vm'});
    } finally {
      for (const [k,v] of Object.entries(saved)) { if(v === undefined) delete process.env[k]; else process.env[k] = v; }
    }
  });
}

test('CloudEvents uuid override generates IDs and round-trips both HTTP bindings', () => {
  const e = new CloudEvent({ source: '/fixture', type: 'fixture.test', data: {value: 1} });
  assert.match(e.id, /^[a-f0-9-]{36}$/);
  for (const binding of [HTTP.structured(e), HTTP.binary(e)]) {
    const decoded = HTTP.toEvent(binding);
    assert.equal(decoded.id, e.id);
    assert.deepEqual(decoded.data, e.data);
  }
});

test('real Functions Framework accepts structured and binary Pub/Sub events', { timeout: 20000 }, async () => {
  const socket = net.createServer();
  await new Promise(resolve => socket.listen(0, '127.0.0.1', resolve));
  const port = socket.address().port;
  await new Promise(resolve => socket.close(resolve));
  const child = spawn(process.execPath, [path.join(source, 'node_modules/@google-cloud/functions-framework/build/src/main.js'), '--source', source, '--target', 'stopLabVm', '--signature-type', 'cloudevent', '--port', String(port)], {
    stdio: ['ignore','pipe','pipe'], env: { ...process.env, GOOGLE_APPLICATION_CREDENTIALS: '/nonexistent-fixture-credentials', GCE_METADATA_HOST: '127.0.0.1:9' },
  });
  let logs = '';
  try {
    await new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error('Framework startup timeout: '+logs)), 10000);
      const collect = chunk => { logs += chunk; if (logs.includes('URL:')) { clearTimeout(timer); resolve(); } };
      child.stdout.on('data', collect);
      child.stderr.on('data', collect);
      child.once('error', err => {clearTimeout(timer);reject(err);});
      child.once('exit', code => {clearTimeout(timer);reject(new Error(`Framework exited ${code}: ${logs}`));});
    });
    const e = new CloudEvent({ source: '//pubsub.googleapis.com/projects/fixture/topics/budget', type: 'google.cloud.pubsub.topic.v1.messagePublished', data: event({costAmount:1,budgetAmount:100}).data });
    for (const binding of [HTTP.structured(e), HTTP.binary(e)]) {
      const body = typeof binding.body === 'string' ? binding.body : JSON.stringify(binding.body);
      const response = await fetch(`http://127.0.0.1:${port}`, {method:'POST',headers:binding.headers,body});
      assert.equal(response.status, 204, await response.text());
    }
  } finally {
    if (child.exitCode === null) { const exited = once(child, 'exit'); child.kill('SIGTERM'); await exited; }
  }
});

test.after(() => { InstancesClient.prototype.get = originalGet; InstancesClient.prototype.stop = originalStop; });
