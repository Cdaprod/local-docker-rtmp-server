package video

import (
	"log"

	"gocv.io/x/gocv"
)

// PreviewStream listens to a UDP socket and decodes MPEG-TS frames using FFmpeg pipeline.
func PreviewStream(uri string) error {
	webcam, err := gocv.VideoCaptureFile(uri)
	if err != nil {
		return err
	}
	defer webcam.Close()

	window := gocv.NewWindow("OpenNDI Preview")
	defer window.Close()

	img := gocv.NewMat()
	defer img.Close()

	log.Println("Preview started. Press ESC to exit.")

	for {
		if ok := webcam.Read(&img); !ok {
			log.Println("Stream closed")
			break
		}
		if img.Empty() {
			continue
		}
		window.IMShow(img)
		if window.WaitKey(1) == 27 {
			break // ESC key
		}
	}
	return nil
}