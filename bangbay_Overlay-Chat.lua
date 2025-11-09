-- By BangBay Digital ID
obs = obslua


local BASE_URL_VERCEL = "https://bengkel-overlay-bang-bay.vercel.app"
local RELAY_URL_RENDER = "wss://bangbay-relay-server.onrender.com"
local RELAY_URL_PARAM_NAME = "relay"
local ROOM_ID_PARAM_NAME = "session"
local LICENSE_KEY_PARAM_NAME = "license" 


local global_dock_source = nil
local global_overlay_sources = {} 
local global_settings = nil 


function script_description()
    return "=== BangBay Digital ID - Popup Chat Kit V00.1 ===\n\n" ..
           "1. Masukkan Room ID, Kunci Lisensi & pilih tema Dock.\n" ..
           "2. Isi detail Pembuat Overlay.\n" ..
           "3. PENTING: Klik Scene tujuan Anda di OBS agar aktif.\n" ..
           "4. Klik tombol 'Terapkan Overlay' di bawah."
end


function script_properties()
    local props = obs.obs_properties_create()
    

    obs.obs_properties_add_group(props, "group_connection", "Pengaturan Koneksi (Wajib)", obs.OBS_GROUP_NORMAL, nil)
    obs.obs_properties_add_text(props, "room_id", "Room ID (dari SSN)", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_text(props, "license_key", "Kunci Lisensi (dari Web)", obs.OBS_TEXT_PASSWORD)
    obs.obs_properties_add_group(props, "group_dock", "Pengaturan Dock (Otomatis)", obs.OBS_GROUP_NORMAL, nil)
    local dock_list = obs.obs_properties_add_list(props, "reader_name", "Pilih Tema Dock", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
    obs.obs_property_list_add_string(dock_list, "Dock Ngobrol (Default)", "ngobrol-01")
    obs.obs_properties_add_group(props, "group_overlay", "Pembuat Overlay (Manual)", obs.OBS_GROUP_NORMAL, nil)
    local overlay_list = obs.obs_properties_add_list(props, "theme_name", "Pilih Tema Overlay", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
    obs.obs_property_list_add_string(overlay_list, "Speech Bubble", "theme_bubble")
    obs.obs_property_list_add_string(overlay_list, "Pop-up macOS", "theme_macos")
    obs.obs_property_list_add_string(overlay_list, "Widget Statis", "theme_STATIS_FINAL")
    obs.obs_property_list_add_string(overlay_list, "Obsidian Edge", "theme_obsidian-edge")
    obs.obs_property_list_add_string(overlay_list, "Obsidian", "theme_obsidian-stack")
    obs.obs_property_list_add_string(overlay_list, "Rainbow", "theme_rainbow")
    obs.obs_property_list_add_string(overlay_list, "Spine", "theme_spine")
    obs.obs_property_list_add_string(overlay_list, "Ticker", "theme_ticker_manual")
    obs.obs_properties_add_text(props, "overlay_source_name", "Nama Source (Custom)", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_button(props, 
        "apply_button",
        "Terapkan Overlay ke Scene Aktif",
        apply_overlay_button_clicked
    )
    return props
end

function apply_overlay_button_clicked(props, prop)
    print("Skrip BangBay Popup: Tombol 'Terapkan Overlay' diklik.")

    if global_settings == nil then
        print("Skrip BangBay Popup: Settings belum siap. Coba ketik sesuatu di Room ID dulu.")
        return
    end
    local room_id = obs.obs_data_get_string(global_settings, "room_id")
    local license_key = obs.obs_data_get_string(global_settings, "license_key")
    local theme_name = obs.obs_data_get_string(global_settings, "theme_name")
    local overlay_source_name = obs.obs_data_get_string(global_settings, "overlay_source_name")
    if room_id == "" or license_key == "" then 
        print("Skrip BangBay Popup: Harap isi Room ID dan Kunci Lisensi.") 
        return 
    end
    if theme_name == "" or overlay_source_name == "" then
        print("Skrip BangBay Popup: Harap isi Tema Overlay dan Nama Source.")
        return
    end
    local overlay_query_params = "?" .. ROOM_ID_PARAM_NAME .. "=" .. room_id .. "&" .. RELAY_URL_PARAM_NAME .. "=" .. RELAY_URL_RENDER .. "&" .. LICENSE_KEY_PARAM_NAME .. "=" .. license_key
    local overlay_url = BASE_URL_VERCEL .. "/" .. theme_name .. overlay_query_params
    local overlay_settings = obs.obs_data_create()

    obs.obs_data_set_string(overlay_settings, "url", overlay_url)
    obs.obs_data_set_int(overlay_settings, "width", 1080)
    obs.obs_data_set_int(overlay_settings, "height", 1920)
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
function script_update(settings)
    global_settings = settings 
    local room_id    = obs.obs_data_get_string(settings, "room_id")
    local license_key = obs.obs_data_get_string(settings, "license_key")
    local reader_name = obs.obs_data_get_string(settings, "reader_name")


    if room_id == "" or license_key == "" then 
        print("Skrip BangBay Popup: Harap isi Room ID dan Kunci Lisensi.") 
        return 
    end
    if reader_name == "" then print("Skrip BangBay Popup: Harap pilih tema Dock.") return end
    local dock_query_params = "?" .. ROOM_ID_PARAM_NAME .. "=" .. room_id .. "&" .. RELAY_URL_PARAM_NAME .. "=" .. RELAY_URL_RENDER .. "&" .. LICENSE_KEY_PARAM_NAME .. "=" .. license_key
    local dock_name = "BangBay_Dock"
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