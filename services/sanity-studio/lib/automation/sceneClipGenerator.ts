import { exec } from 'child_process'
import fs from 'fs'
import path from 'path'
import { generateClipsFromVideo } from './clipGenerator'
import { getObjectFromS3 } from './s3AssetHelper'
import { sanityClient } from './sanityClient'
import { Configuration, OpenAIApi } from 'openai'

const openai = new OpenAIApi(new Configuration({ apiKey: process.env.OPENAI_API_KEY! }))

function detectScenesUsingFFmpeg(inputPath: string): Promise<Array<{ start: number, end: number }>> {
  return new Promise((resolve, reject) => {
    const logFile = path.join('/tmp', `scene_${Date.now()}.log`)
    const command = `ffmpeg -i "${inputPath}" -filter_complex "select='gt(scene,0.4)',metadata=print:file=${logFile}" -vsync vfr -f null -`
    exec(command, async (err) => {
      if (err) return reject(err)
      const lines = fs.readFileSync(logFile, 'utf-8').split('\n')
      const timestamps = lines
        .filter(l => l.includes('pts_time'))
        .map(l => parseFloat(l.split('pts_time:')[1]))
        .filter(Number.isFinite)

      const segments: Array<{ start: number, end: number }> = []
      let prev = 0
      for (const ts of timestamps) {
        const end = Math.floor(ts)
        if (end - prev >= 5 && end - prev <= 59) segments.push({ start: prev, end })
        prev = end
      }
      return resolve(segments)
    })
  })
}

async function generateTitleAndKeywords(videoTitle: string, segment: { start: number, end: number }) {
  const prompt = `Create a short 3–6 word title and 8 keywords for a scene clip from the video titled "${videoTitle}", covering time ${segment.start}s to ${segment.end}s.`
  const res = await openai.createCompletion({
    model: 'text-davinci-003',
    prompt,
    max_tokens: 100
  })
  const [title, keywordsRaw] = res.data.choices[0].text?.trim().split('\n') || []
  const keywords = keywordsRaw?.split(',').map(k => k.trim()).filter(Boolean) || []
  return {
    title: title?.trim() || `Clip ${segment.start}-${segment.end}`,
    keywords: Array.from(new Set(keywords)).slice(0, 49)
  }
}

export async function autoDetectAndGenerateClips(videoId: string): Promise<string[]> {
  const videoDoc = await sanityClient.fetch(`*[_type == "video" && _id == $id][0]`, { id: videoId })
  if (!videoDoc) throw new Error(`Video document not found: ${videoId}`)

  const sourcePath = await getObjectFromS3(videoDoc.fileKey)
  const segments = await detectScenesUsingFFmpeg(sourcePath)

  const enriched = await Promise.all(
    segments.map(async seg => {
      const meta = await generateTitleAndKeywords(videoDoc.title, seg)
      return { ...seg, ...meta }
    })
  )

  return generateClipsFromVideo(videoId, enriched)
}
