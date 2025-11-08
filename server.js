const WebSocket = require('ws');
const url = require('url');
const admin = require('firebase-admin');

// --- [SECURITY V3] Inisialisasi Firebase Admin (SESUAI .env.local) ---
try {
  // 1. Ambil 3 variabel dari environment
  const projectId = process.env.FIREBASE_PROJECT_ID;
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
  // 2. Ambil private key DAN perbaiki formatnya (ganti '\\n' jadi '\n')
  const privateKey = process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n');

  // 3. Pastikan semuanya ada
  if (!projectId || !clientEmail || !privateKey) {
    throw new Error("Missing Firebase Admin environment variables (PROJECT_ID, CLIENT_EMAIL, PRIVATE_KEY)");
  }

  // 4. Inisialisasi app
  admin.initializeApp({
    credential: admin.credential.cert({
      projectId,
      clientEmail,
      privateKey,
    })
  });
  console.log("Firebase Admin SDK (Satpam) v3 berhasil terhubung.");
} catch (error) {
  console.error("GAGAL KONEK KE FIREBASE ADMIN:", error.message);
  console.log("Pastikan 3 variabel Firebase Admin (PROJECT_ID, CLIENT_EMAIL, PRIVATE_KEY) sudah diatur di Environment Variables Render.");
}
const db = admin.firestore();
// --- [AKHIR SECURITY V3] ---


const PORT = process.env.PORT || 8080;
const wss = new WebSocket.Server({ port: PORT });

console.log(`Relay Server (POIN 3) v3 berjalan di port ${PORT}`);

// Fungsi untuk memverifikasi Kunci Lisensi (tidak berubah)
async function verifyLicense(licenseKey) {
  if (!licenseKey) {
    return false;
  }
  try {
    const licenseRef = db.collection('licenses').doc(licenseKey);
    const doc = await licenseRef.get();

    if (!doc.exists) {
      console.log(`Verifikasi GAGAL: Kunci '${licenseKey}' tidak ditemukan.`);
      return false;
    }
    
    if (doc.data().status === 'active') {
      console.log(`Verifikasi SUKSES: Kunci '${licenseKey}' valid dan aktif.`);
      return true;
    } else {
      console.log(`Verifikasi GAGAL: Kunci '${licenseKey}' tidak aktif.`);
      return false;
    }
  } catch (error) {
    console.error("Error saat verifikasi lisensi:", error);
    return false;
  }
}

// Logika koneksi WebSocket (tidak berubah)
wss.on('connection', async (ws, req) => {
  const fullUrl = new url.URL(req.url, `wss://${req.headers.host}`);
  
  const licenseKey = fullUrl.searchParams.get('license');
  const isLicenseValid = await verifyLicense(licenseKey);

  if (!isLicenseValid) {
    console.log("Koneksi ditolak (lisensi tidak valid atau hilang).");
    ws.close(1008, "Invalid License Key");
    return;
  }

  console.log('Klien baru terhubung (lisensi OK).');

  ws.on('message', message => {
    const messageString = message.toString();
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