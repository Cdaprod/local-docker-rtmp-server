obs = obslua

function script_description()
    return "Automatically starts streaming to RTMP after launch"
end

function script_load(settings)
    obs.timer_add(start_streaming, 5000)
end

function start_streaming()
    local is_streaming = obs.obs_frontend_streaming_active()
    if not is_streaming then
        obs.obs_frontend_streaming_start()
        print("[OBS] Auto-started RTMP stream.")
    else
        print("[OBS] Stream already active.")
    end

    obs.remove_current_callback()
end