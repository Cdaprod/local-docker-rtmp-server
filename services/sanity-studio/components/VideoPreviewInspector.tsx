import React from 'react'
import { useDocumentValue } from 'sanity'

const VideoPreviewInspector: React.FC = () => {
  const { displayed: doc } = useDocumentValue() || {}
  const videoUrl = doc?.externalUrl
  return (
    <div style={{ padding: '1rem' }}>
      <h2>{doc?.title || 'No Title'}</h2>
      {videoUrl ? (
        <video
          src={videoUrl}
          controls
          style={{ width: '100%', maxHeight: '400px' }}
        />
      ) : (
        <p>No external URL - please set the videoAsset or externalUrl.</p>
      )}
      <h3>Associated Clips</h3>
      <ul>
        {doc?.clips?.map((ref: any) => (
          <li key={ref._ref}>{ref._ref}</li>
        )) || <li>No clips yet.</li>}
      </ul>
    </div>
  )
}

export default VideoPreviewInspector
