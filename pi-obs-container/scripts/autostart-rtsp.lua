obs           = obslua
source_name   = "auto_rtsp_server"

function script_description()
    return "Auto-start RTSP Server at launch."
end

function script_load(settings)
    obs.timer_add(start_rtsp, 3000)
end

function start_rtsp()
    local rtsp_settings = obs.obs_data_create()
    obs.obs_data_set_bool(rtsp_settings, "enabled", true)
    obs.obs_data_set_int(rtsp_settings, "port", 8554)
    obs.obs_data_set_string(rtsp_settings, "path", "stream")
    obs.obs_data_set_bool(rtsp_settings, "publish_enabled", true)
    obs.obs_data_set_bool(rtsp_settings, "publish_video", true)
    obs.obs_data_set_bool(rtsp_settings, "publish_audio", true)

    obs.obs_frontend_set_profile_parameter("rtsp_server_settings", rtsp_settings)
    obs.obs_data_release(rtsp_settings)

    obs.remove_current_callback()
end