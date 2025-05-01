

# Create lib/automation/index.ts
sudo tee lib/automation/index.ts > /dev/null << 'EOF'
#!/usr/bin/env ts-node
// lib/automation/index.ts
import yargs from 'yargs'
import { hideBin } from 'yargs/helpers'
import { generateClipsFromVideo } from './clipGenerator'
import { enrichClipMetadata } from './metadataInferrer'
import { exportBlackBoxCSV } from './bbgExporter'
import { autoDetectAndGenerateClips } from './sceneClipGenerator'

const argv = yargs(hideBin(process.argv))
  .command(
    'auto-detect-clips',
    'Automatically detect scenes and generate clips from a video',
    (y) =>
      y.option('videoId', {
        type: 'string',
        demandOption: true,
        description: 'The Sanity document ID of the video to process',
      }),
    async (args) => {
      console.log(\`Auto-detecting scenes for video \${args.videoId}…\`)
      try {
        const ids = await autoDetectAndGenerateClips(args.videoId as string)
        console.log(\`Created clips: \${ids.join(', ')}\`)
      } catch (err: any) {
        console.error('Error in auto-detect-clips:', err.message)
        process.exit(1)
      }
    }
  )
  .command(
    'generate-clips',
    'Generate clips from a source video',
    (y) =>
      y
        .option('videoId', {
          type: 'string',
          demandOption: true,
          description: 'The Sanity document ID of the source video',
        })
        .option('segments', {
          type: 'string',
          demandOption: true,
          description: 'JSON array of {start, end, title?} specs, e.g. \'[{"start":0,"end":5},{"start":10,"end":15,"title":"Intro"}]\'',
        }),
    async (args) => {
      const segments = JSON.parse(args.segments as string) as Array<{ start: number; end: number; title?: string }>
      console.log(`Generating ${segments.length} clips for video ${args.videoId}…`)
      try {
        const ids = await generateClipsFromVideo(args.videoId as string, segments)
        console.log(`Created clips: ${ids.join(', ')}`)
      } catch (err: any) {
        console.error('Error generating clips:', err.message)
        process.exit(1)
      }
    }
  )
  .command(
    'enrich-metadata',
    'Auto-generate description & keywords for a clip',
    (y) =>
      y.option('clipId', {
        type: 'string',
        demandOption: true,
        description: 'The Sanity document ID of the clip to enrich',
      }),
    async (args) => {
      console.log(`Enriching metadata for clip ${args.clipId}…`)
      try {
        await enrichClipMetadata(args.clipId as string)
        console.log('Metadata enrichment complete.')
      } catch (err: any) {
        console.error('Error enriching metadata:', err.message)
        process.exit(1)
      }
    }
  )
  .command(
    'export-csv',
    'Export all clips to BlackBox CSV',
    (y) =>
      y.option('out', {
        type: 'string',
        default: './blackbox_export.csv',
        description: 'Output path for the CSV file',
      }),
    async (args) => {
      console.log(`Exporting clips to ${args.out}…`)
      try {
        await exportBlackBoxCSV(args.out as string)
        console.log('CSV export complete.')
      } catch (err: any) {
        console.error('Error exporting CSV:', err.message)
        process.exit(1)
      }
    }
  )
  .demandCommand(1, 'You need to specify a command')
  .strict()
  .help()
  .parse()
EOF

# Create lib/automation/README.md for details on lib/automation/index.ts
sudo tee lib/automation/README.md > /dev/null << 'EOF'
# Automation CLI Index

### Run the CLI via:

```bash
ts-node lib/automation/index.ts generate-clips --videoId=<ID> --segments='[{"start":0,"end":5}]'
ts-node lib/automation/index.ts enrich-metadata --clipId=<ID>
ts-node lib/automation/index.ts export-csv --out=./blackbox.csv
```

### Troubleshooting Automation:

- Make sure you have sanityClient.ts exporting a configured Sanity client, and that your other modules (clipGenerator.ts, etc.) export the named functions.

EOF

# Create lib/automation/sanityClient.ts
sudo tee lib/automation/sanityClient.ts > /dev/null << 'EOF'
// lib/automation/sanityClient.ts
import { createClient } from 'sanity'
export const sanityClient = createClient({
  projectId: process.env.NEXT_PUBLIC_SANITY_PROJECT_ID!,
  dataset:   process.env.NEXT_PUBLIC_SANITY_DATASET!,
  apiVersion: '2025-01-01',
  useCdn: false,
  token: process.env.SANITY_API_TOKEN,
})
EOF

# Create components/VideoPreviewInspector.tsx
sudo tee components/VideoPreviewInspector.tsx > /dev/null << 'EOF'
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
EOF

# Create components/VideoClipEditor.tsx
sudo tee components/VideoClipEditor.tsx > /dev/null << 'EOF'
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
EOF

# Create lib/automation/types.ts
sudo tee lib/automation/types.ts > /dev/null << 'EOF'
export interface VideoDoc { _id: string; videoAsset: { asset: { _ref: string } }; /* … */ }
export interface ClipDoc { _id: string; fileKey: string; /* … */ }
EOF

# Create lib/automation/clipGenerator.ts
sudo tee lib/automation/clipGenerator.ts > /dev/null <<'EOF'
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
EOF

# Create lib/automation/sceneClipGenerator.ts
sudo tee lib/automation/sceneClipGenerator.ts > /dev/null <<'EOF'
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
EOF

# Create lib/automation/metadataInferrer.ts
sudo tee lib/automation/metadataInferrer.ts > /dev/null <<'EOF'
import { Configuration, OpenAIApi } from 'openai'
import { sanityClient } from './sanityClient'

const openai = new OpenAIApi(new Configuration({ apiKey: process.env.OPENAI_API_KEY! }))

export async function inferMetadataForClip(clipDoc: any) {
  const prompt = `Generate a one-sentence description (min 5 words, max 200 characters) and 12 comma-separated keywords for: ${clipDoc.title || 'a stock video clip'}`
  const res = await openai.createCompletion({
    model: 'text-davinci-003',
    prompt,
    max_tokens: 150
  })

  const [description, keywordsLine] = res.data.choices[0].text?.trim().split('\n') || []
  const keywords = keywordsLine?.split(',').map(k => k.trim()).filter(Boolean) || []

  return {
    description: description?.slice(0, 200) || '',
    keywords: Array.from(new Set(keywords)).slice(0, 49)
  }
}

export async function enrichClipMetadata(clipId: string) {
  const clip = await sanityClient.fetch(`*[_type=="clip" && _id==$id][0]`, { id: clipId })
  if (!clip) throw new Error(`Clip not found: ${clipId}`)

  const { description, keywords } = await inferMetadataForClip(clip)
  await sanityClient.patch(clipId).set({ description, keywords }).commit()
}
EOF

# Create lib/automation/bbgExporter.ts
sudo tee lib/automation/bbgExporter.ts > /dev/null <<'EOF'
import { createWriteStream } from 'fs'
import { sanityClient } from './sanityClient'

export async function exportBlackBoxCSV(path: string) {
  const clips = await sanityClient.fetch(`*[_type == "clip"]{
    "FileName": fileKey,
    description,
    keywords,
    category,
    batchName,
    editorial,
    editorialCaption,
    editorialCity,
    editorialState,
    editorialCountry,
    editorialDate
  }`)

  const stream = createWriteStream(path)
  stream.write('File Name,Description,Keywords,Category,Batch name,Editorial,Editorial Text,Editorial City,Editorial State,Editorial Country,Editorial Date\n')

  for (const clip of clips) {
    const desc = `"${clip.description?.replace(/"/g, '""') || ''}"`
    const kw = clip.keywords?.join(', ') || ''
    const row = [
      clip.FileName, desc, kw, clip.category || '', clip.batchName || '',
      clip.editorial ? 'True' : 'False',
      clip.editorialCaption || '', clip.editorialCity || '',
      clip.editorialState || '', clip.editorialCountry || '',
      clip.editorialDate?.split('T')[0] || ''
    ].join(',') + '\n'
    stream.write(row)
  }

  stream.end()
  console.log(`Exported ${clips.length} clips to ${path}`)
}
EOF

# Create lib/automation/s3AssetHelper.ts
sudo tee lib/automation/s3AssetHelper.ts > /dev/null <<'EOF'
import AWS from 'aws-sdk'
import fs from 'fs'
import path from 'path'

const s3 = new AWS.S3({
  endpoint: process.env.MINIO_ENDPOINT!,
  accessKeyId: process.env.MINIO_ACCESS_KEY!,
  secretAccessKey: process.env.MINIO_SECRET_KEY!,
  s3ForcePathStyle: true,
  sslEnabled: false,
  region: process.env.MINIO_REGION || 'us-east-1'
})

export async function getObjectFromS3(key: string): Promise<string> {
  const result = await s3.getObject({ Bucket: process.env.MINIO_BUCKET!, Key: key }).promise()
  const filePath = path.join('/tmp', path.basename(key))
  fs.writeFileSync(filePath, result.Body as Buffer)
  return filePath
}

export async function uploadObjectToS3(key: string, filePath: string, contentType: string) {
  const Body = fs.createReadStream(filePath)
  await s3.upload({
    Bucket: process.env.MINIO_BUCKET!,
    Key: key,
    Body,
    ContentType: contentType
  }).promise()
}
EOF

# Update schemas/schemas.ts to use video, clip, blackBoxMetadata, and videoRenderJob
sudo tee schemas/schemas.ts > /dev/null << 'EOF'
// schemas/schemas.ts
import { type SchemaTypeDefinition } from 'sanity'
import { video } from './video'
import { clip } from './clip'
import { blackBoxMetadata } from './blackBoxMetadata'
import { videoRenderJob } from './videoRenderJob'

export const schema: { types: SchemaTypeDefinition[] } = {
  types: [video, clip, blackBoxMetadata, videoRenderJob],
}
EOF

# Update clip.ts with all fields your automation code uses
sudo tee schemas/clip.ts > /dev/null << 'EOF'
import { defineType, defineField } from 'sanity'

export const clip = defineType({
  name: 'clip',
  title: 'Clip',
  type: 'document',
  fields: [
    defineField({
      name: 'sourceVideo',
      title: 'Source Video',
      type: 'reference',
      to: [{ type: 'video' }],
      validation: Rule => Rule.required(),
      description: 'Reference to the original video document.',
    }),
    defineField({
      name: 'fileKey',
      title: 'Storage Key',
      type: 'string',
      readOnly: true,
      description: 'S3/MinIO key for the clip file.',
    }),
    defineField({
      name: 'startTime',
      title: 'Start Time (s)',
      type: 'number',
      validation: Rule => Rule.required().min(0),
    }),
    defineField({
      name: 'endTime',
      title: 'End Time (s)',
      type: 'number',
      validation: Rule => Rule.required().min(0).custom((end, ctx) => {
        const start = ctx.document.startTime
        return end > start ? true : 'End must be greater than start'
      }),
    }),
    defineField({
      name: 'title',
      title: 'Clip Title',
      type: 'string',
      description: 'Short, descriptive title for this clip.',
      validation: Rule => Rule.required().min(3),
    }),
    defineField({
      name: 'description',
      title: 'Description',
      type: 'text',
      description: 'One-sentence description (5+ words, ≤200 chars).',
      validation: Rule => Rule.required().min(15).max(200).custom(text => {
        const count = text.trim().split(/\\s+/).length
        return count >= 5 ? true : 'Must be at least 5 words'
      }),
    }),
    defineField({
      name: 'keywords',
      title: 'Keywords',
      type: 'array',
      of: [{ type: 'string' }],
      description: '8–49 unique keywords.',
      validation: Rule => Rule.required().min(8).max(49).unique(),
    }),
    defineField({
      name: 'category',
      title: 'Category',
      type: 'string',
      options: {
        list: ['Nature','Business','Technology','People','Urban','Other'],
        layout: 'dropdown',
      },
      description: 'Select a BlackBox stock category.',
    }),
    defineField({
      name: 'batchName',
      title: 'Batch Name',
      type: 'string',
      description: 'Group identifier for related clips.',
    }),
    defineField({
      name: 'editorial',
      title: 'Editorial Only',
      type: 'boolean',
      description: 'Check if this clip is editorial content.',
      initialValue: false,
    }),
    defineField({
      name: 'editorialCaption',
      title: 'Editorial Caption',
      type: 'string',
      hidden: ({document}) => !document?.editorial,
    }),
    defineField({
      name: 'editorialCity',
      title: 'Editorial City',
      type: 'string',
      hidden: ({document}) => !document?.editorial,
    }),
    defineField({
      name: 'editorialState',
      title: 'Editorial State',
      type: 'string',
      hidden: ({document}) => !document?.editorial,
    }),
    defineField({
      name: 'editorialCountry',
      title: 'Editorial Country',
      type: 'string',
      hidden: ({document}) => !document?.editorial,
    }),
    defineField({
      name: 'editorialDate',
      title: 'Editorial Date',
      type: 'datetime',
      hidden: ({document}) => !document?.editorial,
    }),
    defineField({
      name: 'createdAt',
      title: 'Created At',
      type: 'datetime',
      readOnly: true,
      initialValue: () => new Date().toISOString(),
    }),
  ],
})
EOF

# Clean up video.ts: remove the incorrect import & blackBoxMetadataFields spread
sudo tee schemas/video.ts > /dev/null << 'EOF'
// /schemas/video.ts
import { defineType, defineField } from 'sanity'

export const video = defineType({
  name: 'video',
  title: 'Video',
  type: 'document',
  fields: [
    // --- General Metadata ---
    defineField({
      name: 'title',
      title: 'Title',
      type: 'string',
      validation: Rule => Rule.required().min(3),
    }),
    defineField({
      name: 'description',
      title: 'Description',
      type: 'text',
    }),

    // --- Asset Handling ---
    defineField({
      name: 'videoAsset',
      title: 'Video Asset',
      type: 'file',
      options: { accept: 'video/*' },
    }),
    defineField({
      name: 'externalUrl',
      title: 'External URL',
      type: 'url',
      description: 'Stream or NAS URL if not uploaded.',
    }),

    // --- Organization ---
    defineField({
      name: 'tags',
      title: 'Tags',
      type: 'array',
      of: [{ type: 'string' }],
    }),
    defineField({
      name: 'category',
      title: 'Category',
      type: 'string',
      options: {
        list: ['Tutorial', 'Livestream', 'Promo', 'Internal', 'Other'],
        layout: 'dropdown',
      },
    }),

    // --- Relationships ---
    defineField({
      name: 'clips',
      title: 'Associated Clips',
      type: 'array',
      of: [{ type: 'reference', to: [{ type: 'clip' }] }],
      description: 'Clips generated from this video.',
    }),

    // --- System Fields ---
    defineField({
      name: 'createdAt',
      title: 'Created At',
      type: 'datetime',
      readOnly: true,
      initialValue: () => new Date().toISOString(),
    }),
    defineField({
      name: 'updatedAt',
      title: 'Updated At',
      type: 'datetime',
      readOnly: true,
      hidden: true,
    }),
  ],
})
EOF

# Create deskStructure.ts
sudo tee deskStructure.ts > /dev/null << 'EOF'
import { StructureBuilder } from 'sanity/structure'
import S from '@sanity/desk-tool/structure-builder'
import VideoPreviewInspector from './components/VideoPreviewInspector'
import VideoClipEditor from './components/VideoClipEditor'

export default (S: StructureBuilder) =>
  S.list()
    .title('Video Studio')
    .items([
      S.documentTypeListItem('video')
        .title('Videos')
        .schemaType('video')
        .child(videoId =>
          S.document()
            .documentId(videoId)
            .schemaType('video')
            .views([
              S.view.form(),
              S.view.component(VideoPreviewInspector).title('Preview'),
              S.view.component(VideoClipEditor).title('Clip Editor'),
            ])
        ),
      S.documentTypeListItem('clip').title('Clips'),
      S.documentTypeListItem('blackBoxMetadata').title('BlackBox Metadata'),
      S.documentTypeListItem('videoRenderJob').title('Render Jobs'),
    ])
EOF

# Update sanity.config.ts to use the new deskStructure
sudo tee sanity.config.ts > /dev/null << 'EOF'
import { defineConfig } from 'sanity'
import { deskTool } from 'sanity/desk'
import deskStructure from './deskStructure'
import { schema } from './schemas/schema'
// @ts-ignore
import S3AssetSource from 'sanity-plugin-asset-source-s3'

const withS3 = process.env.MINIO_ENDPOINT !== undefined

export default defineConfig({
  name: 'videoRenderStudio',
  title: 'Video Render Studio',

  projectId: process.env.NEXT_PUBLIC_SANITY_PROJECT_ID!,
  dataset: process.env.NEXT_PUBLIC_SANITY_DATASET!,

  plugins: [
    deskTool({ structure: deskStructure }),
    ...(withS3
      ? [S3AssetSource({
          clientConfig: {
            endpoint: process.env.MINIO_ENDPOINT,
            region: process.env.MINIO_REGION,
            credentials: {
              accessKeyId: process.env.MINIO_ACCESS_KEY!,
              secretAccessKey: process.env.MINIO_SECRET_KEY!,
            },
            forcePathStyle: true,
          },
          bucket: process.env.MINIO_BUCKET!,
        })]
      : []),
  ],

  schema,
})
EOF
