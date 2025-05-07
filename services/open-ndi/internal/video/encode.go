package video

// EncodeConfig holds encoder tuning params
type EncodeConfig struct {
	UseHardware bool
	Resolution  string
	Bitrate     string
}