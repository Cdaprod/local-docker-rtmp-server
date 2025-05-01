import ffmpeg from 'fluent-ffmpeg'
import { getObjectFromS3, uploadObjectToS3 } from './s3AssetHelper'
import { sanityClient } from './sanityClient'

interface ClipSpec {
  start: number
  end: number
  title?: string
}

export async function generateClipsFromVideo(videoId: string, clips: ClipSpec[]): Promise<string[]> {
  const videoDoc = await sanityClient.fetch(`*[_type=="video" && _id==$id][0]`, { id: videoId })
  if (!videoDoc) throw new Error(`Video ${videoId} not found`)

  const sourceKey = videoDoc.fileKey
  const sourcePath = await getObjectFromS3(sourceKey)

  const createdClipIds: string[] = []
  for (const spec of clips) {
    const { start, end, title } = spec
    const duration = end - start
    if (duration < 5 || duration > 59) {
      console.warn(`Skipping invalid duration: ${duration}s`)
      continue
    }

    const outputPath = `/tmp/${videoId}-${start}-${end}.mp4`
    await new Promise((resolve, reject) => {
      ffmpeg(sourcePath)
        .setStartTime(start)
        .setDuration(duration)
        .outputOptions('-an')
        .save(outputPath)
        .on('end', resolve)
        .on('error', reject)
    })

    const clipKey = `videos/clips/${videoId}-${start}-${end}.mp4`
    await uploadObjectToS3(clipKey, outputPath, 'video/mp4')

    const clipDoc = {
      _type: 'clip',
      sourceVideo: { _type: 'reference', _ref: videoId },
      fileKey: clipKey,
      title: title || `Clip ${start}-${end}`,
      description: '',
      keywords: [],
      category: videoDoc.category || null,
      batchName: videoDoc.title || videoDoc._id,
      editorial: false
    }

    const created = await sanityClient.create(clipDoc)
    createdClipIds.push(created._id)
  }
  return createdClipIds
}
