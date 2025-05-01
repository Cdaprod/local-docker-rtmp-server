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
