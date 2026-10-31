const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const zlib = require('node:zlib');
const {createRequire} = require('node:module');
const req = createRequire('/usr/src/app/server/package.json');
const sharp = req('sharp');
const mailer = req('nodemailer');
const socketReq = createRequire(req.resolve('socket.io'));
const engineReq = createRequire(socketReq.resolve('engine.io'));
const WebSocket = engineReq('ws');
const base = 'http://127.0.0.1:2283';
const delay = (ms) => new Promise((r) => setTimeout(r, ms));

async function main() {
  const version = await (await fetch(base + '/api/server/version')).json();
  assert.deepEqual(version, {major: 3, minor: 3, patch: 5, prerelease: null});
  assert.equal((await fetch(base)).status, 200);
  const specification = await (await fetch(base + '/api/spec.json')).json();
  assert.equal(specification.components.schemas.ApiKeyCreateDto.type, 'object');
  assert.equal(specification.components.schemas.ApiKeyCreateDto.properties.permissions.type, 'array');
  assert.equal(specification.components.schemas.AssetResponseDto.properties.livePhotoVideoId.type, 'string');
  assert.equal(specification.components.schemas.AssetResponseDto.properties.livePhotoVideoId.nullable, true);
  function checkReferences(value) {
    if (!value || typeof value !== 'object') return;
    if (typeof value.$ref === 'string' && value.$ref.startsWith('#/components/schemas/')) {
      const name = value.$ref.slice('#/components/schemas/'.length).replace(/~1/g, '/').replace(/~0/g, '~');
      assert.ok(specification.components.schemas[name], 'Unresolved schema reference: ' + name);
    }
    for (const child of Object.values(value)) checkReferences(child);
  }
  checkReferences(specification);
  const credentials = {email: 'pilot@example.test', password: crypto.randomBytes(24).toString('hex')};
  let response = await fetch(base + '/api/auth/admin-sign-up', {
    method: 'POST', headers: {'content-type': 'application/json'},
    body: JSON.stringify({...credentials, name: 'Disposable pilot'}),
  });
  assert.equal(response.status, 201, await response.text());
  // Exercise normal compressed JSON through the patched body-parser path.
  response = await fetch(base + '/api/auth/login', {
    method: 'POST', headers: {'content-type': 'application/json', 'content-encoding': 'gzip'},
    body: zlib.gzipSync(JSON.stringify(credentials)),
  });
  assert.equal(response.status, 201);
  const {accessToken} = await response.json();
  assert.ok(accessToken);
  const headers = {Authorization: 'Bearer ' + accessToken};

  // Test the actual websocket-only Engine.IO + Socket.IO handshake.
  for (const valid of [true, false]) await new Promise((resolve, reject) => {
    const ws = new WebSocket('ws://127.0.0.1:2283/api/socket.io/?EIO=4&transport=websocket', {
      headers: valid ? headers : {Authorization: 'Bearer invalid-runtime-test-token'},
    });
    const timer = setTimeout(() => {ws.close(); reject(new Error('WebSocket timeout'));}, 10000);
    ws.onerror = () => {clearTimeout(timer); reject(new Error('WebSocket failed'));};
    ws.onmessage = ({data}) => {
      const packet = String(data);
      if (packet.startsWith('0')) {
        assert.ok(JSON.parse(packet.slice(1)).sid);
        ws.send('40');
      } else if (packet.startsWith('42')) {
        const [event, value] = JSON.parse(packet.slice(2));
        if (valid && event === 'on_server_version') {
          assert.deepEqual(value, version);
          clearTimeout(timer); ws.close(); resolve();
        } else if (event === 'error' && value === 'unauthorized') {
          clearTimeout(timer); ws.close();
          if (valid) reject(new Error('Valid WebSocket credentials rejected')); else resolve();
        } else if (!valid && event === 'on_server_version') {
          clearTimeout(timer); ws.close(); reject(new Error('Invalid WebSocket credentials accepted'));
        }
      }
    };
  });

  // Verify Nodemailer 10's normal rendering/attachment API without external SMTP.
  const mail = await mailer.createTransport({streamTransport: true, buffer: true}).sendMail({
    from: 'Photos <photos@example.test>', to: 'Pilot <pilot@example.test>',
    subject: 'Pilot', text: 'Test', html: '<p>Test</p>',
    attachments: [{filename: 'sample.txt', content: 'sample', cid: 'sample'}],
  });
  assert.match(mail.message.toString(), /multipart\/(alternative|mixed|related)/);
  assert.match(mail.message.toString(), /filename="?sample\.txt/);
  assert.match(mail.message.toString(), /Content-ID: <sample>/);
  assert.deepEqual(mail.envelope.to, ['pilot@example.test']);

  const bytes = await sharp({create: {width: 64, height: 48, channels: 3, background: '#2277aa'}}).jpeg().toBuffer();
  const svg = Buffer.from('<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16"><rect width="16" height="16" fill="red"/></svg>');
  assert.equal((await sharp(await sharp(svg).png().toBuffer()).metadata()).width, 16);
  const form = new FormData();
  form.set('assetData', new Blob([bytes], {type: 'image/jpeg'}), 'pilot.jpg');
  form.set('fileCreatedAt', new Date().toISOString());
  form.set('fileModifiedAt', new Date().toISOString());
  response = await fetch(base + '/api/assets', {method: 'POST', headers, body: form});
  assert.equal(response.status, 201);
  const asset = await response.json();
  assert.ok(asset.id);
  response = await fetch(base + '/api/assets/' + asset.id + '/original', {headers});
  assert.equal(response.status, 200);
  const original = Buffer.from(await response.arrayBuffer());
  assert.equal(crypto.createHash('sha256').update(original).digest('hex'), crypto.createHash('sha256').update(bytes).digest('hex'));
  let thumbnail;
  for (let n = 0; n < 90; n++) {
    response = await fetch(base + '/api/assets/' + asset.id + '/thumbnail?size=thumbnail', {headers});
    if (response.ok) {thumbnail = Buffer.from(await response.arrayBuffer()); break;}
    await delay(1000);
  }
  assert.ok(thumbnail, 'thumbnail generation did not complete');
  assert.ok((await sharp(thumbnail).metadata()).width > 0);
  console.log('PASS: version/UI, compressed JSON login, WebSocket, mail, native SVG/JPEG, original hash and thumbnail');
}
main().catch((error) => {console.error(error.message); process.exitCode = 1;});
