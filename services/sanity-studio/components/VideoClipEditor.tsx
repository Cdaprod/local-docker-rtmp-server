import React, { useState } from 'react'
import { useDocumentValue } from 'sanity'
import axios from 'axios'

const VideoClipEditor: React.FC = () => {
  const { displayed: doc } = useDocumentValue() || {}
  const [loading, setLoading] = useState(false)
  const [message, setMessage] = useState('')

  const handleAutoDetect = async () => {
    if (!doc?._id) return
    setLoading(true)
    setMessage('Detecting scenes...')
    try {
      const resp = await axios.post(
        \`\${process.env.BACKEND_URL}/api/videos/\${doc._id}/scene-detect\`,
        { minDuration: 3, maxDuration: 60 }
      )
      const segments = resp.data.segments
      setMessage(\`Detected \${segments.length} segments. Creating clips...\`)
      await axios.post(
        \`\${process.env.BACKEND_URL}/api/clips/batch-create\`,
        { videoId: doc._id, clips: segments }
      )
      setMessage('Clips created. Refresh to see them.')
    } catch (err: any) {
      console.error(err)
      setMessage('Error during auto-detect. Check console.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div style={{ padding: '1rem' }}>
      <button onClick={handleAutoDetect} disabled={loading}>
        {loading ? 'Processing…' : 'Auto-Detect & Create Clips'}
      </button>
      {message && <p>{message}</p>}
    </div>
  )
}

export default VideoClipEditor
