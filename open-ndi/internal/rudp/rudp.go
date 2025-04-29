package rudp

import (
	"bytes"
	"encoding/binary"
	"errors"
)

const (
	FlagData = 0x01
)

type Packet struct {
	Seq   uint32
	Ack   uint32
	Flags uint8
	Data  []byte
}

func Encode(pkt Packet) ([]byte, error) {
	var buf bytes.Buffer
	if err := binary.Write(&buf, binary.BigEndian, pkt.Seq); err != nil {
		return nil, err
	}
	if err := binary.Write(&buf, binary.BigEndian, pkt.Ack); err != nil {
		return nil, err
	}
	if err := buf.WriteByte(pkt.Flags); err != nil {
		return nil, err
	}
	if _, err := buf.Write(pkt.Data); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

func Decode(data []byte) (Packet, error) {
	if len(data) < 9 {
		return Packet{}, errors.New("packet too short")
	}
	pkt := Packet{}
	pkt.Seq = binary.BigEndian.Uint32(data[0:4])
	pkt.Ack = binary.BigEndian.Uint32(data[4:8])
	pkt.Flags = data[8]
	pkt.Data = data[9:]
	return pkt, nil
}