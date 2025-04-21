Based on your SDK PDF (Z 7UsbMtpE_04.pdf), here’s a clear summary of the most relevant commands and steps you’ll need to trigger image capture, retrieve the image, and get live view from your Nikon Z 7 in PC Remote Mode via USB.

⸻

Your Goals with SDK

You want to:
	1.	Trigger a capture from your host machine
	2.	Pull the image directly from SDRAM (not memory card)
	3.	Optionally get live view JPEG frames in a loop

⸻

High-Level Workflow

A. Start a Session

Before any command, you must open a session:
	•	This is a PTP requirement.
	•	The session tracks transaction IDs and ensures orderly control.

B. Live View Workflow (for preview or remote control)

Step	Command	Notes
1	StartLiveView (0x9201)	Puts camera in remote live view mode
2	Poll DeviceReady until response is not Device_Busy	Confirms readiness
3	Loop: GetLiveViewImage (0x9203)	JPEG frame returned
4	EndLiveView (0x9202)	Ends session  ￼



⸻

C. Image Capture to SDRAM

Step	Command	Notes
1	InitiateCaptureRecInSdram (0x90C0)	Triggers capture, saves to SDRAM
2	Wait for event: ObjectAddedInSdram	Signals that image is ready
3	Call GetObjectInfo	Gets metadata for the image
4	Call GetObject or GetPartialObject	Transfers image data
5	Wait for CaptureCompleteRecInSdram	Ensures all images are transferred  ￼



⸻

Core Operation Codes You Need

Name	Code	Description
StartLiveView	0x9201	Begin remote live view
GetLiveViewImage	0x9203	JPEG frame from camera
EndLiveView	0x9202	Exit live view
InitiateCaptureRecInSdram	0x90C0	Capture image directly to SDRAM
AfAndCaptureRecInSdram	0x90CB	Same, with autofocus
GetObjectInfo	0x1008	Metadata of captured object
GetObject	0x1009	Pull entire image from SDRAM
GetEvent	0x1013	Check for status, new object, or capture complete
DeviceReady	0x101B	Check if camera is ready to receive commands  ￼



⸻

Live View Properties

You can tweak settings via property codes before and during live view:

Property	Code	Meaning
LiveViewImageSize	0xD1AC	QVGA (1), VGA (2), XGA (3)
LiveViewImageCompression	0xD1BC	Fine / Basic / Normal (0–5)
LiveViewZoomArea	0xD1BD	Controls area zoomed-in
RemoteLiveViewStatus	0xD1A2	1 = active  ￼



⸻

Python or libusb Implementation

You’ll likely need to:
	•	Send USB Bulk Transfers to the camera
	•	Encode PTP Container structures with the correct opcodes
	•	Use a persistent TransactionID across commands

I can scaffold a Python+PyUSB minimal implementation for this if you want to automate capturing images or streaming Live View to a web app or local viewer.

⸻

Let me know your preferred language (Python/C++) and platform (Linux/RPi/macOS), and I’ll start building you the code.