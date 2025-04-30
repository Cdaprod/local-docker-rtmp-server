Perfect — you want to broadcast a video feed from OBS without audio.

Let’s break down how to achieve this based on how you’re running OBS (GUI or CLI) and your broadcast method (RTMP, YouTube, etc.).

⸻

Option 1: Mute Audio Sources in OBS GUI

If you’re running OBS with GUI access (X11 or VNC):
	1.	Launch OBS
	2.	In the Audio Mixer, click the speaker icon next to:
	•	Mic/Aux
	•	Desktop Audio
	3.	Right-click > Properties or Filters if you want to remove audio input completely.

Then start streaming as usual.

⸻

Option 2: Mute Audio via obs-cli or WebSocket API

If you’re running headless or automated:

Use the obs-cli (Go client) or WebSocket API to mute audio sources before streaming:

obs-cli --password "your_ws_password" SourceSettings SetMute \
  --source-name "Mic/Aux" \
  --mute true

Or mute both:

obs-cli SourceSettings SetMute --source-name "Mic/Aux" --mute true
obs-cli SourceSettings SetMute --source-name "Desktop Audio" --mute true

You can also disable audio in your stream settings in .json profile files.

⸻

Option 3: CLI Launch with Audio Disabled

If you start OBS with --startstreaming (no GUI), mute audio via config:

obs --startstreaming --scene "CameraOnly" --collection "Minimal" --profile "NoAudio"

In the profile NoAudio, go to:

~/.config/obs-studio/basic/profiles/NoAudio/basic.ini

Set:

[Audio]
SampleRate=44100
Channels=2
DesktopAudioDevice1=disabled
DesktopAudioDevice2=disabled
Mic/AuxAudioDevice=disabled

Restart OBS, and audio won’t be included in the stream.

⸻

Bonus: Stream to RTMP Without Audio via FFmpeg filter (if you bypass OBS)

ffmpeg -f v4l2 -i /dev/video0 -an -f flv rtmp://your.server/live/stream

-an disables audio.

⸻

Confirm Setup

To help finalize your setup, can you share:
	•	Are you running OBS in a container or natively on Pi?
	•	Using OBS GUI, CLI, or WebSocket control?
	•	Streaming via RTMP, YouTube, or local WebRTC?

I can generate a script or Docker override config that enforces “video only” mode.