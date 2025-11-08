const WebSocket = require('ws');
const url = require('url');
const admin = require('firebase-admin');

// --- [SECURITY V2] Inisialisasi Firebase Admin ---
// Ambil kredensial dari Environment Variables (akan kita atur di Render)
try {
  const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_KEY);
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
  console.log("Firebase Admin SDK (Satpam) berhasil terhubung.");
} catch (error) {
  console.error("GAGAL KONEK KE FIREBASE ADMIN:", error.message);
  console.log("Pastikan FIREBASE_SERVICE_ACCOUNT_KEY sudah diatur di Environment Variables Render.");
}
const db = admin.firestore();
// --- [AKHIR SECURITY V2] ---

const PORT = process.env.PORT || 8080;
const wss = new WebSocket.Server({ port: PORT });

console.log(`Relay Server (POIN 3) v2 berjalan di port ${PORT}`);

// Fungsi untuk memverifikasi Kunci Lisensi
async function verifyLicense(licenseKey) {
  if (!licenseKey) {
    return false; // Jika tidak ada kunci, tolak
  }
  try {
    const licenseRef = db.collection('licenses').doc(licenseKey);
    const doc = await licenseRef.get();

    if (!doc.exists) {
      console.log(`Verifikasi GAGAL: Kunci '${licenseKey}' tidak ditemukan.`);
      return false; // Kunci tidak ada di database
    }
    
    if (doc.data().status === 'active') {
      console.log(`Verifikasi SUKSES: Kunci '${licenseKey}' valid dan aktif.`);
      return true; // Kunci ada dan aktif
    } else {
      console.log(`Verifikasi GAGAL: Kunci '${licenseKey}' tidak aktif.`);
      return false; // Kunci ada tapi statusnya 'inactive'
    }
  } catch (error) {
    console.error("Error saat verifikasi lisensi:", error);
    return false;
  }
}


// Ini berjalan setiap kali ada koneksi baru
wss.on('connection', async (ws, req) => {
  // Ambil URL lengkap (termasuk parameter)
  const fullUrl = new url.URL(req.url, `wss://${req.headers.host}`);
  
  // --- [SECURITY V2] Verifikasi Kunci Lisensi ---
  const licenseKey = fullUrl.searchParams.get('license');
  const isLicenseValid = await verifyLicense(licenseKey);

  if (!isLicenseValid) {
    // Jika lisensi tidak valid, TOLAK koneksi
    console.log("Koneksi ditolak (lisensi tidak valid atau hilang).");
    ws.close(1008, "Invalid License Key"); // 1008 = Policy Violation
    return;
  }
  // --- [AKHIR SECURITY V2] ---

  // Jika lolos, baru lanjutkan
  console.log('Klien baru terhubung (lisensi OK).');

  ws.on('message', message => {
    const messageString = message.toString();
    // Broadcast ke semua klien LAIN
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