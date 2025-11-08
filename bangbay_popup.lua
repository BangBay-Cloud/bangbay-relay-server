-- Wajib ada di setiap skrip OBS Lua
obs = obslua

-- == 1. KONFIGURASI PENTING (URL PRODUKSI FINAL) ==
local BASE_URL_VERCEL = "https://bengkel-overlay-bang-bay.vercel.app"
local RELAY_URL_RENDER = "wss://bangbay-relay-server.onrender.com"
local RELAY_URL_PARAM_NAME = "relay"
local ROOM_ID_PARAM_NAME = "session"
-- --- [SECURITY V15] ---
local LICENSE_KEY_PARAM_NAME = "license" -- Nama parameter baru

-- Variabel global untuk menyimpan referensi (Anti-Crash)
local global_dock_source = nil
local global_settings = nil 

-- == 2. FUNGSI UNTUK DESKRIPSI ==
function script_description()
    return "=== BangBay Digital ID - Popup Chat Kit (POIN 3) ===\n\n" ..
           "1. Masukkan Room ID & Kunci Lisensi Anda (dari web).\n" ..
           "2. Isi detail Pembuat Overlay.\n" ..
           "3. Klik 'Buat Source Baru' atau 'Update Source'.\n" ..
           "4. PENTING: Tambahkan Source itu ke Scene Anda secara manual.\n" ..
           "   (Scene > + > Browser > Add Existing > Pilih nama Source Anda)"
end

-- == 3. FUNGSI UNTUK MEMBUAT TAMPILAN UI ==
function script_properties()
    local props = obs.obs_properties_create()
    
    -- --- Grup 1: Koneksi ---
    obs.obs_properties_add_group(props, "group_connection", "Pengaturan Koneksi (Wajib)", obs.OBS_GROUP_NORMAL, nil)
    obs.obs_properties_add_text(props, "room_id", "Room ID (dari SSN)", obs.OBS_TEXT_DEFAULT)
    
    -- --- [SECURITY V15] TAMBAHKAN KOTAK TEKS KUNCI LISENSI ---
    obs.obs_properties_add_text(props, "license_key", "Kunci Lisensi (dari Web)", obs.OBS_TEXT_PASSWORD) -- Pakai tipe PASSWORD agar disensor

    -- --- Grup 2: Pengaturan Dock (Global) ---
    obs.obs_properties_add_group(props, "group_dock", "Pengaturan Dock (Otomatis)", obs.OBS_GROUP_NORMAL, nil)
    local dock_list = obs.obs_properties_add_list(props, "reader_name", "Pilih Tema Dock", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
    obs.obs_property_list_add_string(dock_list, "Dock Ngobrol (Default)", "ngobrol-01")

    -- --- Grup 3: Pembuat Overlay (Bisa Berubah-ubah) ---
    obs.obs_properties_add_group(props, "group_overlay", "Pembuat Overlay (Manual)", obs.OBS_GROUP_NORMAL, nil)
    local overlay_list = obs.obs_properties_add_list(props, "theme_name", "Pilih Tema Overlay", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
    obs.obs_property_list_add_string(overlay_list, "Speech Bubble (FIX)", "theme_bubble")
    obs.obs_property_list_add_string(overlay_list, "Pop-up macOS (BARU)", "theme_macos")
    obs.obs_property_list_add_string(overlay_list, "Widget Statis (FINAL)", "theme_STATIS_FINAL")
    obs.obs_properties_add_text(props, "overlay_source_name", "Nama Source (Custom)", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_button(props, "create_button", "Buat Source Baru", create_overlay_button_clicked)
    obs.obs_properties_add_button(props, "update_button", "Update Source yang Ada", update_overlay_button_clicked)
    
    return props
end

-- --- [SECURITY V15] Fungsi HELPER untuk mengambil settings ---
function get_overlay_settings(settings)
    -- Ambil nilai baru:
    local room_id = obs.obs_data_get_string(settings, "room_id")
    local license_key = obs.obs_data_get_string(settings, "license_key") -- Ambil Kunci Lisensi
    local theme_name = obs.obs_data_get_string(settings, "theme_name")
    local overlay_source_name = obs.obs_data_get_string(settings, "overlay_source_name")

    -- Validasi baru:
    if room_id == "" or license_key == "" or theme_name == "" or overlay_source_name == "" then
        print("Skrip BangBay Popup: Harap isi SEMUA field (Room ID, Kunci Lisensi, Tema, Nama Source).")
        return nil, nil, nil, nil
    end

    -- Buat URL baru dengan Kunci Lisensi:
    local overlay_query_params = "?" .. ROOM_ID_PARAM_NAME .. "=" .. room_id .. "&" .. RELAY_URL_PARAM_NAME .. "=" .. RELAY_URL_RENDER .. "&" .. LICENSE_KEY_PARAM_NAME .. "=" .. license_key
    local overlay_url = BASE_URL_VERCEL .. "/" .. theme_name .. overlay_query_params
    
    local overlay_settings_data = obs.obs_data_create()
    obs.obs_data_set_string(overlay_settings_data, "url", overlay_url)
    obs.obs_data_set_int(overlay_settings_data, "width", 1920)
    obs.obs_data_set_int(overlay_settings_data, "height", 1080)
    obs.obs_data_set_bool(overlay_settings_data, "is_local_file", false)
    obs.obs_data_set_bool(overlay_settings_data, "restart_when_active", true) 
    obs.obs_data_set_string(overlay_settings_data, "css", "body { background-color: rgba(0, 0, 0, 0); margin: 0px auto; overflow: hidden; }")

    return overlay_source_name, overlay_settings_data
end


-- == 4. FUNGSI UNTUK TOMBOL "BUAT SOURCE BARU" ==
-- (Fungsi ini tidak berubah, dia otomatis pakai helper baru)
function create_overlay_button_clicked(props, prop)
    print("Skrip BangBay Popup: Tombol 'Buat Source Baru' diklik.")
    if global_settings == nil then return end
    local overlay_source_name, overlay_settings_data = get_overlay_settings(global_settings)
    if overlay_settings_data == nil then return end
    local existing_source = obs.obs_get_source_by_name(overlay_source_name)
    if existing_source == nil then
        local new_overlay_source = obs.obs_source_create("browser_source", overlay_source_name, overlay_settings_data, nil)
        if new_overlay_source ~= nil then
            print("Skrip BangBay Popup: Source '" .. overlay_source_name .. "' berhasil DIBUAT. Harap tambahkan ke scene Anda secara manual.")
            obs.obs_source_release(new_overlay_source)
        end
    else
        print("Skrip BangBay Popup: GAGAL. Source '" .. overlay_source_name .. "' sudah ada. Gunakan tombol 'Update Source'.")
        obs.obs_source_release(existing_source)
    end
    obs.obs_data_release(overlay_settings_data)
end

-- == 5. FUNGSI UNTUK TOMBOL "UPDATE SOURCE" ==
-- (Fungsi ini tidak berubah, dia otomatis pakai helper baru)
function update_overlay_button_clicked(props, prop)
    print("Skrip BangBay Popup: Tombol 'Update Source' diklik.")
    if global_settings == nil then return end
    local overlay_source_name, overlay_settings_data = get_overlay_settings(global_settings)
    if overlay_settings_data == nil then return end
    local existing_source = obs.obs_get_source_by_name(overlay_source_name)
    if existing_source == nil then
        print("Skrip BangBay Popup: GAGAL. Source '" .. overlay_source_name .. "' tidak ditemukan. Gunakan tombol 'Buat Source Baru' dulu.")
    else
        obs.obs_source_update(existing_source, overlay_settings_data)
        obs.obs_source_release(existing_source)
        print("Skrip BangBay Popup: Source '" .. overlay_source_name .. "' berhasil DIPERBARUI dengan tema baru.")
    end
    obs.obs_data_release(overlay_settings_data)
end

-- == 6. FUNGSI LOGIKA UTAMA (SAAT PENGATURAN DIUBAH) ==
function script_update(settings)
    global_settings = settings 
    -- Ambil nilai baru:
    local room_id    = obs.obs_data_get_string(settings, "room_id")
    local license_key = obs.obs_data_get_string(settings, "license_key") -- Ambil Kunci Lisensi
    local reader_name = obs.obs_data_get_string(settings, "reader_name")
    
    -- Validasi baru:
    if room_id == "" or license_key == "" then 
        print("Skrip BangBay Popup: Harap isi Room ID dan Kunci Lisensi.") 
        return 
    end
    if reader_name == "" then print("Skrip BangBay Popup: Harap pilih tema Dock.") return end
    
    -- HANYA MENGURUS DOCK (Otomatis)
    local dock_name = "BangBay_Dock"
    -- Buat URL baru dengan Kunci Lisensi:
    local dock_query_params = "?" .. ROOM_ID_PARAM_NAME .. "=" .. room_id .. "&" .. RELAY_URL_PARAM_NAME .. "=" .. RELAY_URL_RENDER .. "&" .. LICENSE_KEY_PARAM_NAME .. "=" .. license_key
    local dock_url = BASE_URL_VERCEL .. "/" .. reader_name .. dock_query_params
    
    local dock_settings = obs.obs_data_create()
    obs.obs_data_set_string(dock_settings, "url", dock_url)
    obs.obs_data_set_int(dock_settings, "width", 400) 
    obs.obs_data_set_int(dock_settings, "height", 600)
    obs.obs_data_set_bool(dock_settings, "is_local_file", false)
    obs.obs_data_set_bool(dock_settings, "restart_when_active", true)
    if global_dock_source == nil then global_dock_source = obs.obs_get_source_by_name(dock_name) end
    if global_dock_source == nil then
        global_dock_source = obs.obs_source_create("browser_source", dock_name, dock_settings, nil)
        print("Skrip BangBay Popup: Dock berhasil dibuat.")
    else
        obs.obs_source_update(global_dock_source, dock_settings)
        print("Skrip BangBay Popup: Dock berhasil diperbarui.")
    end
    if obs.obs_frontend_add_dock then obs.obs_frontend_add_dock(global_dock_source) end
    obs.obs_data_release(dock_settings)
end

-- == 7. FUNGSI UNTUK MEMBERSIHKAN (ANTI-CRASH v11) ==
function script_unload()
    print("Skrip BangBay Popup: Unloading...")
    if global_dock_source ~= nil then
        global_dock_source = nil
        print("Skrip BangBay Popup: Referensi dock dibersihkan.")
    end
end