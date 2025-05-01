

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