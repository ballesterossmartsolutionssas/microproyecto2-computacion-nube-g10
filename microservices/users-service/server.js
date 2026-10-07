const http = require('http');
const os = require('os');

const PORT = process.env.PORT || 3001;
const INSTANCE = process.env.INSTANCE_NAME || os.hostname();

const server = http.createServer((req, res) => {
  res.setHeader('Content-Type', 'application/json');
  res.setHeader('X-Served-By', INSTANCE);

  if (req.url === '/health' || req.url === '/healthz') {
    res.writeHead(200);
    return res.end(JSON.stringify({
      status: 'UP',
      service: 'users-service',
      instance: INSTANCE,
      port: PORT,
      timestamp: new Date().toISOString()
    }));
  }

  // Respuesta a /api/users o cualquier subruta
  res.writeHead(200);
  res.end(JSON.stringify({
    service: 'users-service',
    instance: INSTANCE,
    port: PORT,
    path: req.url,
    message: 'Servicio de Usuarios (registro, autenticación y perfiles)',
    users: [
      { id: 1, name: 'Juan Camilo Ballesteros', email: 'juan_cam.ballesteros@uao.edu.co', role: 'admin' },
      { id: 2, name: 'Valentina Valestegui', email: 'valentina.valestegui@uao.edu.co', role: 'developer' },
      { id: 3, name: 'Juan Miguel Carabali', email: 'juan_miguel.carabali@uao.edu.co', role: 'tester' }
    ],
    timestamp: new Date().toISOString()
  }, null, 2) + '\n');
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`[users-service] Corriendo en puerto ${PORT} | Instancia: ${INSTANCE}`);
});
