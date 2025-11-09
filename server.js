// File: relay/server.js (v4 - Satpam Cerdas)
const WebSocket = require('ws');
const url = require('url');
const admin = require('firebase-admin');

// --- Inisialisasi Firebase Admin (Tidak berubah) ---
try {
  const projectId = process.env.FIREBASE_PROJECT_ID;
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
  const privateKey = process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n');
  if (!projectId || !clientEmail || !privateKey) {
    throw new Error("Missing Firebase Admin environment variables");
  }
  admin.initializeApp({
    credential: admin.credential.cert({ projectId, clientEmail, privateKey })
  });
  console.log("Firebase Admin SDK (Satpam) v4 berhasil terhubung.");
} catch (error) {
  console.error("GAGAL KONEK KE FIREBASE ADMIN:", error.message);
}
const db = admin.firestore();
// --- Akhir Inisialisasi ---

const PORT = process.env.PORT || 8080;
const wss = new WebSocket.Server({ port: PORT });
console.log(`Relay Server (POIN 3) v4 berjalan di port ${PORT}`);

// --- [FUNGSI VERIFIKASI BARU (v4)] ---
// Sekarang dia juga butuh Room ID untuk mengecek
async function verifyLicense(licenseKey, roomId) {
  if (!licenseKey || !roomId) {
    return false; // Jika Kunci atau Room ID tidak ada, tolak
  }
  try {
    const licenseRef = db.collection('licenses').doc(licenseKey);
    const doc = await licenseRef.get();

    if (!doc.exists) {
      console.log(`Verifikasi GAGAL: Kunci '${licenseKey}' tidak ditemukan.`);
      return false;
    }
    
    const licenseData = doc.data();

    if (licenseData.status !== 'active') {
      console.log(`Verifikasi GAGAL: Kunci '${licenseKey}' tidak aktif.`);
      return false;
    }

    // --- LOGIKA PENGUNCIAN (BINDING) ---
    // Kasus 1: Kunci masih "perawan" (relayRoomId masih null)
    if (licenseData.relayRoomId === null) {
      // Ini adalah aktivasi pertama!
      // Kunci lisensi ini ke Room ID yang dipakai sekarang
      await licenseRef.update({ relayRoomId: roomId });
      console.log(`AKTIVASI SUKSES: Kunci '${licenseKey}' diikat ke Room ID '${roomId}'.`);
      return true; // Izinkan koneksi
    }

    // Kasus 2: Kunci sudah terikat
    if (licenseData.relayRoomId === roomId) {
      // Room ID-nya COCOK. Ini pengguna yang sah.
      console.log(`Verifikasi SUKSES: Kunci '${licenseKey}' cocok dengan Room ID '${roomId}'.`);
      return true; // Izinkan koneksi
    } else {
      // Room ID-nya BEDA. Ini pembajak!
      console.log(`Verifikasi GAGAL: Kunci '${licenseKey}' sudah terikat ke Room ID lain.`);
      return false; // Tolak koneksi
    }
    // --- AKHIR LOGIKA PENGUNCIAN ---
    
  } catch (error) {
    console.error("Error saat verifikasi lisensi:", error);
    return false;
  }
}

// --- Logika koneksi WebSocket (SEKARANG MENGIRIM ROOM ID) ---
wss.on('connection', async (ws, req) => {
  const fullUrl = new url.URL(req.url, `wss://${req.headers.host}`);
  
  const licenseKey = fullUrl.searchParams.get('license');
  const roomId = fullUrl.searchParams.get('session'); // Ambil Room ID dari parameter 'session'
  
  const isLicenseValid = await verifyLicense(licenseKey, roomId); // Kirim keduanya ke "Satpam"

  if (!isLicenseValid) {
    console.log("Koneksi ditolak (lisensi/room id tidak valid).");
    ws.close(1008, "Invalid License Key or Room ID");
    return;
  }

  // --- (Sisa kode tidak berubah) ---
  console.log(`Klien baru terhubung (Room: ${roomId}, Lisensi: OK).`);

  ws.on('message', message => {
    const messageString = message.toString();
    wss.clients.forEach(client => {
      if (client !== ws && client.readyState === WebSocket.OPEN) {
        client.send(messageString);
      }
    });
  });

  ws.on('close', () => {
    console.log(`Klien (Room: ${roomId}) terputus.`);
  });
  
  ws.on('error', error => {
    console.error('WebSocket error:', error);
  });
});