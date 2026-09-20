'use strict';

/*
 * Aplicacion minima de demostracion para la practica de Ansible + AWS.
 *
 * Su unico objetivo es permitir verificar de extremo a extremo la cadena
 * Internet -> Nginx (443/TLS) -> reverse proxy -> Node.js (127.0.0.1:3000).
 *
 * Escucha SOLO en loopback: el puerto 3000 no esta publicado en el security
 * group y nunca debe ser accesible desde Internet de forma directa.
 *
 * Toda la configuracion llega por variables de entorno desde la unidad systemd,
 * de modo que este fichero es estatico y Ansible no lo re-renderiza nunca.
 */

const http = require('node:http');
const os = require('node:os');

const HOST = process.env.APP_HOST || '127.0.0.1';
const PORT = Number.parseInt(process.env.APP_PORT || '3000', 10);
const DOMAIN = process.env.APP_DOMAIN || 'sin-dominio';

const startedAt = new Date().toISOString();

const server = http.createServer((req, res) => {
  if (req.url === '/healthz') {
    res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
    res.end('{"status":"ok"}\n');
    return;
  }

  const payload = [
    '{',
    '  "mensaje": "Servidor aprovisionado con Ansible",',
    '  "dominio": "' + DOMAIN + '",',
    '  "host": "' + os.hostname() + '",',
    '  "node": "' + process.version + '",',
    '  "escuchando_en": "' + HOST + ':' + PORT + '",',
    '  "arrancado": "' + startedAt + '",',
    '  "ahora": "' + new Date().toISOString() + '",',
    '  "ruta": "' + req.url + '"',
    '}',
    ''
  ].join('\n');

  res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
  res.end(payload);
});

server.listen(PORT, HOST, () => {
  console.log('demoapp escuchando en http://' + HOST + ':' + PORT);
});

// Parada limpia para que systemd no tenga que matar el proceso.
for (const signal of ['SIGTERM', 'SIGINT']) {
  process.on(signal, () => {
    console.log('Recibida senal ' + signal + ', cerrando servidor');
    server.close(() => process.exit(0));
  });
}
