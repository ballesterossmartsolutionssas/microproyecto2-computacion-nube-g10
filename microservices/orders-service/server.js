const http = require('http');
const os = require('os');

const PORT = process.env.PORT || 3003;
const INSTANCE = process.env.INSTANCE_NAME || os.hostname();

const server = http.createServer((req, res) => {
  res.setHeader('Content-Type', 'application/json');
  res.setHeader('X-Served-By', INSTANCE);

  if (req.url === '/health' || req.url === '/healthz') {
    res.writeHead(200);
    return res.end(JSON.stringify({
      status: 'UP',
      service: 'orders-service',
      instance: INSTANCE,
      port: PORT,
      timestamp: new Date().toISOString()
    }));
  }

  res.writeHead(200);
  res.end(JSON.stringify({
    service: 'orders-service',
    instance: INSTANCE,
    port: PORT,
    path: req.url,
    message: 'Servicio de Órdenes (ciclo de vida de pedidos)',
    orders: [
      { orderId: 'ORD-7001', userId: 1, items: 2, total: 1910, status: 'COMPLETED' },
      { orderId: 'ORD-7002', userId: 2, items: 1, total: 450, status: 'PROCESSING' },
      { orderId: 'ORD-7003', userId: 3, items: 3, total: 329, status: 'SHIPPED' },
      { orderId: 'ORD-7004', userId: 1, items: 1, total: 99, status: 'PENDING' }
    ],
    timestamp: new Date().toISOString()
  }, null, 2) + '\n');
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`[orders-service] Corriendo en puerto ${PORT} | Instancia: ${INSTANCE}`);
});
