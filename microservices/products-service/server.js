const http = require('http');
const os = require('os');

const PORT = process.env.PORT || 3002;
const INSTANCE = process.env.INSTANCE_NAME || os.hostname();

const server = http.createServer((req, res) => {
  res.setHeader('Content-Type', 'application/json');
  res.setHeader('X-Served-By', INSTANCE);

  if (req.url === '/health' || req.url === '/healthz') {
    res.writeHead(200);
    return res.end(JSON.stringify({
      status: 'UP',
      service: 'products-service',
      instance: INSTANCE,
      port: PORT,
      timestamp: new Date().toISOString()
    }));
  }

  res.writeHead(200);
  res.end(JSON.stringify({
    service: 'products-service',
    instance: INSTANCE,
    port: PORT,
    path: req.url,
    message: 'Servicio de Productos (catálogo, stock e imágenes)',
    products: [
      { id: 101, name: 'Laptop Dell XPS 15', price: 1800, stock: 15, category: 'Computadores' },
      { id: 102, name: 'Monitor LG 27 UltraFine 4K', price: 450, stock: 28, category: 'Pantallas' },
      { id: 103, name: 'Teclado Mecanico Keychron K2', price: 110, stock: 45, category: 'Perifericos' },
      { id: 104, name: 'Mouse Logitech MX Master 3S', price: 99, stock: 60, category: 'Perifericos' }
    ],
    timestamp: new Date().toISOString()
  }, null, 2) + '\n');
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`[products-service] Corriendo en puerto ${PORT} | Instancia: ${INSTANCE}`);
});
