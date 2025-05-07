package video

// Transport handles sending encoded frames to network
type Transport struct {
	Target string
	Proto  string
}