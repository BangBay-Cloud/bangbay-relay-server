-- Wajib ada di setiap skrip OBS Lua
obs = obslua

-- == 1. KONFIGURASI PENTING (URL PRODUKSI FINAL) ==
local BASE_URL_VERCEL = "https://bengkel-overlay-bang-bay.vercel.app"
local RELAY_URL_RENDER = "wss://bangbay-relay-server.onrender.com"
local RELAY_URL_PARAM_NAME = "relay"
local ROOM_ID_PARAM_NAME = "session"
-- --- [TAMBAHAN 1: Parameter Kunci Lisensi] ---
local LICENSE_KEY_PARAM_NAME = "license" 
-- --- [AKHIR TAMBAHAN 1] ---

-- Variabel global untuk menyimpan referensi (Anti-Crash)
local global_dock_source = nil
local global_overlay_sources = {} 
local global_settings = nil 

-- == 2. FUNGSI UNTUK DESKRIPSI ==
function script_description()
    return "=== BangBay Digital ID - Popup Chat Kit (POIN 3) ===\n\n" ..
           "1. Masukkan Room ID, Kunci Lisensi & pilih tema Dock.\n" .. -- Diedit sedikit
           "2. Isi detail Pembuat Overlay.\n" ..
           "3. PENTING: Klik Scene tujuan Anda di OBS agar aktif.\n" ..
           "4. Klik tombol 'Terapkan Overlay' di bawah."
end

-- == 3. FUNGSI UNTUK MEMBUAT TAMPILAN UI ==
function script_properties()
    local props = obs.obs_properties_create()
    
    -- --- Grup 1: Koneksi ---
    obs.obs_properties_add_group(props, "group_connection", "Pengaturan Koneksi (Wajib)", obs.OBS_GROUP_NORMAL, nil)
    obs.obs_properties_add_text(props, "room_id", "Room ID (dari SSN)", obs.OBS_TEXT_DEFAULT)

    -- --- [TAMBAHAN 2: Kotak Teks Kunci Lisensi] ---
    obs.obs_properties_add_text(props, "license_key", "Kunci Lisensi (dari Web)", obs.OBS_TEXT_PASSWORD) -- Tipe PASSWORD agar disensor
    -- --- [AKHIR TAMBAHAN 2] ---

    -- --- Grup 2: Pengaturan Dock (Global) ---
    obs.obs_properties_add_group(props, "group_dock", "Pengaturan Dock (Otomatis)", obs.OBS_GROUP_NORMAL, nil)
    local dock_list = obs.obs_properties_add_list(props, "reader_name", "Pilih Tema Dock", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
    obs.obs_property_list_add_string(dock_list, "Dock Ngobrol (Default)", "ngobrol-01")

    -- --- Grup 3: Pembuat Overlay (Bisa Berubah-ubah) ---
    obs.obs_properties_add_group(props, "group_overlay", "Pembuat Overlay (Manual)", obs.OBS_GROUP_NORMAL, nil)
    
    -- 1. Drop-down untuk Tema Overlay
    local overlay_list = obs.obs_properties_add_list(props, "theme_name", "Pilih Tema Overlay", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
    obs.obs_property_list_add_string(overlay_list, "Speech Bubble (FIX)", "theme_bubble")
    obs.obs_property_list_add_string(overlay_list, "Pop-up macOS (BARU)", "theme_macos")
    obs.obs_property_list_add_string(overlay_list, "Widget Statis (FINAL)", "theme_STATIS_FINAL")
    -- (Tambahkan tema lain di sini)

    -- 2. Kotak Teks untuk "Nama Sources" (Custom)
    obs.obs_properties_add_text(props, "overlay_source_name", "Nama Source (Custom)", obs.OBS_TEXT_DEFAULT)
    
    -- Tombol "APPLY/OK" (Kode Asli-mu)
    obs.obs_properties_add_button(props, 
        "apply_button",                -- ID internal
        "Terapkan Overlay ke Scene Aktif", -- Teks di tombol
        apply_overlay_button_clicked   -- Fungsi yang dipanggil saat diklik
    )
    
    return props
end

-- == 4. FUNGSI YANG DIPANGGIL TOMBOL "APPLY/OK" ==
function apply_overlay_button_clicked(props, prop)
    print("Skrip BangBay Popup: Tombol 'Terapkan Overlay' diklik.")

    if global_settings == nil then
        print("Skrip BangBay Popup: Settings belum siap. Coba ketik sesuatu di Room ID dulu.")
        return
    end

    -- --- [TAMBAHAN 3: Ambil & Validasi Kunci Lisensi] ---
    local room_id = obs.obs_data_get_string(global_settings, "room_id")
    local license_key = obs.obs_data_get_string(global_settings, "license_key") -- Ambil Kunci Lisensi
    local theme_name = obs.obs_data_get_string(global_settings, "theme_name")
    local overlay_source_name = obs.obs_data_get_string(global_settings, "overlay_source_name")

    -- Validasi BARU
    if room_id == "" or license_key == "" then 
        print("Skrip BangBay Popup: Harap isi Room ID dan Kunci Lisensi.") 
        return 
    end
    if theme_name == "" or overlay_source_name == "" then
        print("Skrip BangBay Popup: Harap isi Tema Overlay dan Nama Source.")
        return
    end

    -- Buat URL BARU dengan Kunci Lisensi
    local overlay_query_params = "?" .. ROOM_ID_PARAM_NAME .. "=" .. room_id .. "&" .. RELAY_URL_PARAM_NAME .. "=" .. RELAY_URL_RENDER .. "&" .. LICENSE_KEY_PARAM_NAME .. "=" .. license_key
    -- --- [AKHIR TAMBAHAN 3] ---
    
    local overlay_url = BASE_URL_VERCEL .. "/" .. theme_name .. overlay_query_params
    
    -- Sisa logika v10 (Anti-Crash) tidak diubah...
    local overlay_settings = obs.obs_data_create()
    obs.obs_data_set_string(overlay_settings, "url", overlay_url)
    obs.obs_data_set_int(overlay_settings, "width", 1920)
    obs.obs_data_set_int(overlay_settings, "height", 1080)
    obs.obs_data_set_bool(overlay_settings, "is_local_file", false)
    obs.obs_data_set_bool(overlay_settings, "restart_when_active", true) 
    obs.obs_data_set_string(overlay_settings, "css", "body { background-color: rgba(0, 0, 0, 0); margin: 0px auto; overflow: hidden; }")

    local overlay_source = global_overlay_sources[overlay_source_name]
    if overlay_source == nil then
        overlay_source = obs.obs_get_source_by_name(overlay_source_name)
        if overlay_source ~= nil then
            global_overlay_sources[overlay_source_name] = overlay_source
        end
    end
    
    if overlay_source == nil then
        overlay_source = obs.obs_source_create("browser_source", overlay_source_name, overlay_settings, nil)
        global_overlay_sources[overlay_source_name] = overlay_source
        
        local current_scene_source = obs.obs_frontend_get_current_scene()
        if current_scene_source ~= nil then
            local scene = obs.obs_scene_from_source(current_scene_source)
            if scene ~= nil then
                obs.obs_scene_add(scene, overlay_source)
                obs.obs_scene_release(scene)
                print("Skrip BangBay Popup: Overlay '" .. overlay_source_name .. "' berhasil dibuat dan ditambahkan ke scene AKTIF.")
            end
            obs.obs_source_release(current_scene_source) 
        else
            print("Skrip BangBay Popup: GAGAL menemukan scene aktif. Klik salah satu scene dulu.")
        end
    else
        obs.obs_source_update(overlay_source, overlay_settings)
        print("Skrip BangBay Popup: Overlay '" .. overlay_source_name .. "' berhasil diperbarui.")
    end
    obs.obs_data_release(overlay_settings)
end

-- == 5. FUNGSI LOGIKA UTAMA (SAAT PENGATURAN DIUBAH) ==
function script_update(settings)
    global_settings = settings 
    
    -- --- [TAMBAHAN 4: Ambil & Validasi Kunci Lisensi] ---
    local room_id    = obs.obs_data_get_string(settings, "room_id")
    local license_key = obs.obs_data_get_string(settings, "license_key") -- Ambil Kunci Lisensi
    local reader_name = obs.obs_data_get_string(settings, "reader_name")

    -- Validasi BARU
    if room_id == "" or license_key == "" then 
        print("Skrip BangBay Popup: Harap isi Room ID dan Kunci Lisensi.") 
        return 
    end
    if reader_name == "" then print("Skrip BangBay Popup: Harap pilih tema Dock.") return end

    -- Buat URL BARU dengan Kunci Lisensi
    local dock_query_params = "?" .. ROOM_ID_PARAM_NAME .. "=" .. room_id .. "&" .. RELAY_URL_PARAM_NAME .. "=" .. RELAY_URL_RENDER .. "&" .. LICENSE_KEY_PARAM_NAME .. "=" .. license_key
    -- --- [AKHIR TAMBAHAN 4] ---

    -- A. MEMBUAT/UPDATE DOCK (Global, hanya 1)
    local dock_name = "BangBay_Dock"
    local dock_url = BASE_URL_VERCEL .. "/" .. reader_name .. dock_query_params
    
    -- Sisa logika v10 (Anti-Crash) tidak diubah...
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

-- == 6. FUNGSI UNTUK MEMBERSIHKAN (ANTI-CRASH) ==
-- (Fungsi ini tidak berubah dari v10)
function script_unload()
    print("Skrip BangBay Popup: Unloading...")
    if global_dock_source ~= nil then
        obs.obs_source_release(global_dock_source)
        global_dock_source = nil
        print("Skrip BangBay Popup: Dock source dilepaskan.")
    end
    if global_overlay_sources ~= nil then
        for name, source in pairs(global_overlay_sources) do
            obs.obs_source_release(source)
            print("Skrip BangBay Popup: Overlay source '" .. name .. "' dilepaskan.")
        end
        global_overlay_sources = {}
    end
end