import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
const routes = new Map([
  ['/', ['../../docs/design-system/preview.html', 'text/html; charset=utf-8']],
  ['/docs/design-system/preview.html', ['../../docs/design-system/preview.html', 'text/html; charset=utf-8']],
  ['/apps/web/src/styles/tokens.css', ['../../apps/web/src/styles/tokens.css', 'text/css; charset=utf-8']],
]);
createServer(async (request, response) => {
  const route = routes.get(request.url?.split('?')[0]);
  if (!route) { response.writeHead(404); response.end('Not found'); return; }
  try {
    const content = await readFile(new URL(route[0], import.meta.url));
    response.writeHead(200, { 'Content-Type': route[1], 'Cache-Control': 'no-store' });
    response.end(content);
  } catch { response.writeHead(500); response.end('Run npm run tokens:build first.'); }
}).listen(4174, '127.0.0.1', () => console.log('Ttak tokens: http://127.0.0.1:4174'));
