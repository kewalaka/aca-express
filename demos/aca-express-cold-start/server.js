const BOOT_TIME = Date.now();

const http = require('http');
const os = require('os');

let requestCount = 0;

function parseRegion(dnsSuffix) {
  // Format: <hash>.<region>.azurecontainerapps.io
  if (!dnsSuffix) return 'local';
  const parts = dnsSuffix.split('.');
  return parts.length >= 3 ? parts[1] : 'local';
}

const appName = process.env.CONTAINER_APP_NAME || 'aca-demo';
const revision = process.env.CONTAINER_APP_REVISION || 'local-rev';
const region = parseRegion(process.env.CONTAINER_APP_ENV_DNS_SUFFIX);
const hostname = process.env.CONTAINER_APP_HOSTNAME || os.hostname();

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

const server = http.createServer((req, res) => {
  if (req.method === 'OPTIONS') {
    res.writeHead(204, CORS_HEADERS);
    res.end();
    return;
  }

  if (req.method === 'GET' && req.url === '/') {
    requestCount += 1;
    const body = JSON.stringify({
      appName,
      revision,
      region,
      hostname,
      bootMs: Date.now() - BOOT_TIME,
      requestCount,
      uptimeMs: Math.round(process.uptime() * 1000),
    });

    res.writeHead(200, {
      ...CORS_HEADERS,
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(body),
    });
    res.end(body);
    return;
  }

  res.writeHead(404, { ...CORS_HEADERS, 'Content-Type': 'text/plain' });
  res.end('Not found');
});

const PORT = process.env.PORT || 8080;
server.listen(PORT, () => {
  console.log(`ACA Express demo server listening on port ${PORT}`);
  console.log(`App: ${appName} | Revision: ${revision} | Region: ${region}`);
});
