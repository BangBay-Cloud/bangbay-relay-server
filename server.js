// Impor library WebSocket
const WebSocket = require('ws');

// Tentukan port. WAJIB pakai process.env.PORT agar bisa dibaca Render/Railway
const PORT = process.env.PORT || 8080;

// Buat server WebSocket baru di port tersebut
const wss = new WebSocket.Server({ port: PORT });

console.log(`Relay Server (POIN 3) berjalan di port ${PORT}`);

// Ini adalah fungsi yang berjalan setiap kali ada koneksi baru (dari OBS Dock atau Overlay)
wss.on('connection', ws => {
  console.log('Klien baru terhubung.');

  // Ini berjalan saat server menerima pesan dari satu klien
  ws.on('message', message => {
    
    // Ubah pesan (yang mungkin buffer) menjadi string
    const messageString = message.toString();

    // Kirim (broadcast) pesan ini ke SEMUA klien LAIN yang terhubung
    wss.clients.forEach(client => {
      if (client !== ws && client.readyState === WebSocket.OPEN) {
        client.send(messageString);
      }
    });
  });

  ws.on('close', () => {
    console.log('Klien terputus.');
  });
  
  ws.on('error', error => {
    console.error('WebSocket error:', error);
  });
});