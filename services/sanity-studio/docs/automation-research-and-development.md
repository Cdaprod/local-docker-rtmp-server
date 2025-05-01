Automation Libraries for Sanity Studio Video Workflow

Video Workflow Context & Requirements

The user’s video workflow involves turning raw footage into multiple stock clips with rich metadata. Each source video (raw footage) can yield several clips, which need to meet BlackBox Global’s stock footage requirements. Key rules include descriptive titles (unique or incremented if similar), descriptions of 15–200 characters (minimum 5 words), and 8–49 comma-separated keywords with no duplicates ￼. Clips must also be categorized (from a fixed list of BlackBox categories) and marked if they are editorial content, including location and shoot date if applicable. All video clips should have no audio and adhere to duration limits (e.g. 5–59 seconds per BlackBox guidelines). To support this workflow, we propose a set of modular TypeScript libraries for Sanity Studio, along with schema enhancements and Studio integration, to automate clip creation, metadata enrichment, and BlackBox CSV export.

Folder Structure (lib/automation/)

Organize the automation code into a dedicated folder for clarity and reuse. For example:
	•	clipGenerator.ts – Handles video clip extraction from a source video (using ffmpeg) and creates new clip documents.
	•	metadataInferrer.ts – Auto-generates metadata (title, description, keywords) for video clips, optionally leveraging AI/ML models (OpenAI, HuggingFace) for suggestions.
	•	bbgExporter.ts – Exports clip metadata to BlackBox Global’s CSV schema, ensuring field mapping and compliance (e.g. correct formatting, field counts).
	•	s3AssetHelper.ts – Utility for interacting with the S3/MinIO storage (fetching source videos and uploading generated clips).
	•	index.ts (optional) – Consolidates exports of the above, or provides CLI entry points for batch operations (so CI/CD can run ts-node lib/automation/index.ts ...).

This structure keeps each concern separate and makes the codebase more maintainable and testable. All files can be authored in TypeScript and imported as needed in the Sanity Studio configuration or scripts. This modular approach aligns with Sanity v3 best practices, allowing us to load only what’s needed and keep business logic out of the schema definitions.

Schema Design & BlackBox Compliance

We introduce two new document types in the schema: video (source footage) and clip (an extracted stock clip). The schema is defined in a modular way (each type in its own file, then imported into the schemaTypes array ￼) to comply with Sanity v3’s structure. Key schema definitions and validations:
	•	video (source video) – Stores minimal info about the raw footage. Fields might include:
	•	title – A short name for the footage (used to suggest clip titles or batch names).
	•	fileKey or sourceAsset – Reference to the video file. If using Sanity assets, this could be a file type; if using external storage, this might be a string path or filename on S3/MinIO.
	•	(Optional) clips – An array of references to clip documents extracted from this video. This can be maintained for convenience (we can also query clips by their sourceVideo reference).
	•	(Optional) plannedClips – An array of objects for user to input desired clip segments (start/end times, tentative title) before extraction. This can drive the clip generation action.
	•	clip (stock clip) – Stores metadata for each extracted clip. Fields align with BlackBox requirements:
	•	sourceVideo – Reference to the parent video document (helps trace origin and group clips by source).
	•	fileKey/asset – The actual video clip file (on Sanity CDN or external storage).
	•	title – Short descriptive title for the clip. We enforce uniqueness per source or use numbering if multiple clips have similar titles (e.g. "Beach Sunset 01/02").
	•	description – Text field for the clip description. Validation ensures 15–200 chars and ≥5 words (to meet BlackBox’s requirements, e.g. no empty or too short descriptions). For example:

{
  name: 'description',
  type: 'text',
  validation: Rule => Rule.required().min(15).max(200).custom(val => {
    const wordCount = val.trim().split(/\s+/).length
    return wordCount >= 5 || 'Description must be at least 5 words'
  })
}


	•	keywords – An array of strings for keywords/tags. We enforce between 8 and 49 keywords, all unique ￼. For example:

{
  name: 'keywords',
  type: 'array',
  of: [{type: 'string'}],
  validation: Rule => Rule.min(8).max(49).unique()
}

This can be rendered with a custom input component that joins/splits by comma for user convenience, but storing as an array makes it easy to ensure uniqueness and count.

	•	category – A string or reference for the stock category. We can use a dropdown list of allowed categories (as provided by BlackBox). For instance, options: { list: ['Nature','Business','Technology', …] } to restrict values.
	•	batchName – Optional string for grouping related clips (e.g. all clips from the same shoot). This can default to the source video title or be set by the user to group submissions (BlackBox’s "Batch name" field).
	•	editorial – Boolean flag for editorial content. If true, additional fields appear (using conditional fields) for editorialCaption (a short context text for editorial clips), editorialCity, editorialState, editorialCountry, and editorialDate. These fields correspond to BlackBox’s requirements for editorial footage (e.g. who/what is depicted, and where/when) and should be required when editorial is true.
	•	shootingCountry and shootingDate – If needed for all clips (not just editorial), we can include fields for the country (e.g. "Georgia, USA") and the date when the footage was captured. This can be auto-populated from the source video or entered by the user. (In our user’s context, these might be constant or known values.)

All these fields ensure that a clip document contains all information needed to generate a BlackBox-compliant metadata row. By enforcing rules at the schema level, we reduce the chance of invalid metadata (e.g. too few keywords or missing description) being submitted ￼ ￼. The schema types are then included in the Studio configuration’s schema array for modular loading ￼. For example:

// schemas/video.ts
import {defineType} from 'sanity'
export default defineType({
  name: 'video',
  type: 'document',
  title: 'Source Video',
  fields: [ /* ...fields as above... */ ]
})

// schemas/clip.ts
export default defineType({
  name: 'clip',
  type: 'document',
  title: 'Video Clip',
  fields: [ /* ...fields as above... */ ],
  preview: { select: { title: 'title', media: 'asset' } } // show thumbnail if possible
})

These schema enhancements make Sanity a single source of truth for all metadata. The next step is implementing the automation logic to populate and use these fields.

Clip Extraction Library (clipGenerator.ts)

This library handles extracting sub-clips from a raw video file and creating new clip documents in Sanity. It uses ffmpeg (via a Node.js wrapper like fluent-ffmpeg) to perform the video trimming. The process is as follows:
	1.	Fetch Source Video: Given a source video document ID (or the document itself), retrieve the video file from storage. If using external storage (MinIO/S3), we fetch the file via the S3 helper (see s3AssetHelper.ts). This may download the file to a temporary local path or stream it to ffmpeg.
	2.	Extract Clips with ffmpeg: For each desired clip segment (defined by start and end timestamps in seconds, or start+duration), run ffmpeg to cut that portion. We also remove audio tracks by default to meet stock requirements (e.g., adding -an option) since stock footage should be silent. We can use fluent-ffmpeg methods to set start time and duration and save to a new file ￼. For example:

import ffmpeg from 'fluent-ffmpeg'
import { getObjectFromS3, uploadObjectToS3 } from './s3AssetHelper'
import { sanityClient } from './sanityClient' // assume configured Sanity client

interface ClipSpec { start: number; end: number; title?: string }

export async function generateClipsFromVideo(videoId: string, clips: ClipSpec[]): Promise<string[]> {
  // 1. Load source video document and file
  const videoDoc = await sanityClient.fetch(/* GROQ */ `*[_type=="video" && _id==$id][0]`, {id: videoId})
  if (!videoDoc) throw new Error(`Video ${videoId} not found`)
  const sourceKey = videoDoc.fileKey  // e.g. "videos/raw/filename.mp4" in S3
  const sourcePath = await getObjectFromS3(sourceKey)  // downloads file and returns local path

  const createdClipIds: string[] = []
  for (const spec of clips) {
    const { start, end, title } = spec
    const duration = end - start
    if (duration < 5 || duration > 60) {
      console.warn(`Clip duration ${duration}s is out of recommended range (5-59s). Skipping or adjusting.`)
      // We enforce stock clip length constraints
    }
    // 2. Use ffmpeg to cut the clip
    const outputPath = `/tmp/${videoId}-${start}-${end}.mp4`
    await new Promise((resolve, reject) => {
      ffmpeg(sourcePath)
        .setStartTime(start)
        .setDuration(duration)
        .outputOptions('-an')  // remove audio
        .saveToFile(outputPath)  // save the trimmed clip
        .on('end', resolve)
        .on('error', reject)
    })
    // 3. Upload the clip to storage
    const clipKey = `videos/clips/${videoId}-${start}-${end}.mp4`
    await uploadObjectToS3(clipKey, outputPath, 'video/mp4')
    // 4. Create a new Sanity document for the clip
    const clipDoc = {
      _type: 'clip',
      sourceVideo: { _type: 'reference', _ref: videoId },
      fileKey: clipKey,
      title: title || videoDoc.title || `Clip ${start}-${end}`,
      description: '',       // empty for now, to be filled by metadataInferrer
      keywords: [],          // to be filled in later
      category: videoDoc.category || null,   // if source video has a category, inherit
      batchName: videoDoc.title || videoDoc._id,
      editorial: false       // default; can be set manually if needed
    }
    const created = await sanityClient.create(clipDoc)
    createdClipIds.push(created._id)
  }
  return createdClipIds
}

In the above code, we use ffmpeg().setStartTime(...).setDuration(...).saveToFile(...) as shown in the Stack Overflow example ￼. We loop through each requested clip spec, generate an output file, and then upload it to S3. We then create a new Sanity document for the clip with initial metadata. The batchName is set to the source video’s title or ID to group related clips. The description and keywords are left blank initially – these will be filled by the metadata inferrer.

	3.	Attach Clips to Source (optional): We can update the source video document to reference the new clips (e.g., push their IDs into a clips array field) if we want to easily browse clips under each video in the Studio. This can be done with a Sanity patch after creation of all clips.

The clip generator library thus automates what would be a manual editing process. It ensures the raw footage is cut to produce individual stock-ready files. By automating this, a user can select a video in Studio, provide the desired clip time ranges (e.g. via a field or config), and then trigger generateClipsFromVideo to produce all clips in one go.

Metadata Enrichment Library (metadataInferrer.ts)

Once clips are created, the next challenge is generating high-quality metadata (title, description, keywords) for each clip. The metadata inferrer library provides functions to analyze a clip (or its context) and suggest/populate these fields, optionally using AI models for better results. Key features:
	•	Title Inference: Generate a concise, descriptive title. If the source video or clip has some context (e.g., the source’s title or initial notes), the inferrer can use that. Otherwise, it could rely on visual analysis or predefined patterns. For instance, a clip might be titled "Sunset Over Mountains Aerial – 4K" based on content. If multiple clips would have the same title, the library can append an increment number (...01, ...02) to differentiate (the user’s notes indicate incrementing similar titles).
	•	Description Suggestion: Create a sentence or two describing what’s happening in the clip, including relevant context (who, what, where, when) and important keywords ￼. This can be aided by AI: for example, using an OpenAI GPT-4 prompt to summarize the clip’s content in a way that meets the 5-word minimum and includes important terms. The description should be unique for each clip, even if clips are similar ￼, to improve discoverability.
	•	Keyword/Tag Generation: Suggest a set of 8–49 keywords capturing the clip’s content (subjects, setting, mood, etc.) ￼. An AI model or computer vision service could identify objects or themes in a frame. For example, for a nature clip of a forest, keywords might include "forest, trees, nature, wilderness, green, sunlight, landscape, tranquil". The inferrer ensures no duplicates and that the count is within range. It might also incorporate BlackBox’s advice of covering "who, what, when, where, how" in the keywords.
	•	Use of AI/ML (Optional): This library can integrate with AI services to enhance metadata quality. For instance, we could use OpenAI’s API to generate text based on prompts, or Hugging Face models for object detection or captioning. An example approach is to feed a brief prompt to GPT-4 like: "Generate a title (5 words or less) and 10 keywords for a stock video clip showing [scene]." Many creators are already using GPT-4 to generate engaging metadata for stock footage ￼. We can also use a frame from the video and run it through an image recognition model (e.g., via HuggingFace) to get labels, which we then refine into keywords or input to GPT. These AI features are optional – if API keys are provided, the code can call them; otherwise, it can fall back to simpler rule-based suggestions or leave fields for manual entry.

Implementation: The metadataInferrer.ts might export functions like inferMetadata(clipDoc) or separate inferTitle, inferDescription, inferKeywords. It will read the clip’s data (and possibly the source video’s data or a preview image) and then produce metadata. Pseudocode for using OpenAI might look like:

import { Configuration, OpenAIApi } from 'openai'
import vision from '@huggingface/inference'  // hypothetical usage

const openAI = new OpenAIApi(new Configuration({ apiKey: process.env.OPENAI_API_KEY }))

export async function inferMetadataForClip(clipDoc) {
  let baseDescription = ''
  // If we have a thumbnail or can grab one:
  // const imageBuffer = await getFrameImage(clipDoc.fileKey)
  // const tags = await vision.imageClassification(imageBuffer) 
  // baseDescription = tags.join(', ') or some interpretation

  const prompt = `You are an expert stock footage curator. Write a one-sentence description (at least 5 words) of a video clip showing: ${clipDoc.title || 'the scene'}. Include specific details and avoid abbreviations. Then suggest 12 relevant comma-separated keywords.`
  const aiResponse = await openAI.createCompletion({
    model: 'text-davinci-003',
    prompt,
    max_tokens: 150
  })
  const text = aiResponse.data.choices[0].text || ''
  // Parse the AI response to extract a description and keywords list.
  const [desc, keywordsLine] = text.split('\n')  // assuming the AI formats it on separate lines
  const keywords = keywordsLine ? keywordsLine.split(',').map(k => k.trim()) : []
  return { desc, keywords }
}

// Optionally a function to directly patch the Sanity document:
export async function enrichClipMetadata(clipId: string) {
  const clip = await sanityClient.fetch(`*[_type=="clip" && _id==$id][0]`, {id: clipId})
  if (!clip) throw new Error('Clip not found')
  const { desc, keywords } = await inferMetadataForClip(clip)
  // Apply BlackBox rules: cap keywords to 49, ensure uniqueness, etc.
  const uniqueKeywords = Array.from(new Set(keywords)).slice(0, 49)
  await sanityClient.patch(clipId).set({
    description: desc.substring(0, 200),  // ensure max 200 chars
    keywords: uniqueKeywords
  }).commit()
}

In this example, we use the OpenAI API to generate a description and keywords in one go (we’d prompt it to ensure the output format is predictable). We then parse and clean the result, enforcing limits. The actual prompt engineering can be refined with examples to get the desired output format. Also, note that external API calls should be handled carefully (with try/catch and perhaps retried or rate-limited). The HuggingFace vision usage in comments indicates how one might integrate a vision model for tag suggestions as a supplement.

The metadata inferrer can be invoked for a single clip or in batch. For instance, after generating clips, one could call enrichClipMetadata on each new clip ID. The result is that each clip document in Sanity is populated with a reasonable title, description, and set of keywords – which the user can then review and tweak in the Studio. By automating this step, we save time and ensure compliance with BlackBox’s metadata standards (e.g., correct keyword count and descriptive text). Notably, this approach aligns with how stock footage creators are incorporating AI to boost efficiency ￼.

BlackBox Exporter Library (bbgExporter.ts)

This library is responsible for extracting data from Sanity and outputting a CSV (or Excel) in the exact format that BlackBox Global expects. BlackBox provides a template with specific columns and rules, so our exporter will map our clip schema to those columns. Key points:
	•	Schema Mapping: The columns in the BlackBox metadata CSV include File Name, Description, Keywords, Category, Batch name, Editorial (True/False), Editorial Caption, City, State, Country, Date. Our Sanity clip fields correspond directly to these. For example, clip.fileKey (or the asset’s original filename) maps to File Name, clip.description to Description, the joined keywords array to Keywords, etc. We ensure to output boolean editorial as "True"/"False". Fields like Editorial City/State/Country/Date come from the clip document if applicable (or are left blank for non-editorial clips).
	•	Data Extraction: We can query all clips that need to be exported. For instance, we might filter clips by some criterion (maybe a boolean field like readyForExport or by creation date or presence of required metadata). Using Sanity’s query API, we fetch an array of clip documents with all the fields needed. Alternatively, we could get the data in portions and stream the CSV writing. Given potentially thousands of clips, a streaming approach or writing directly to file is sensible for performance.
	•	CSV Generation: We then format each clip’s data as a row in the CSV. We have to be careful to escape commas in the description. A robust approach is to use a CSV library (like json2csv or similar) to handle quoting. However, for clarity, here’s how one might do it manually in TS:

import { createWriteStream } from 'fs'
import { sanityClient } from './sanityClient'

export async function exportBlackBoxCSV(outputPath: string) {
  const clips = await sanityClient.fetch(`*[_type=="clip" && defined(description) && defined(keywords)]{
    "FileName": fileKey, 
    "Description": description, 
    "Keywords": keywords, 
    "Category": category,
    "BatchName": batchName,
    "Editorial": editorial,
    "EditorialText": editorialCaption,
    "City": editorialCity,
    "State": editorialState,
    "Country": editorialCountry,
    "Date": editorialDate
  }`)
  const stream = createWriteStream(outputPath)
  // Write header
  stream.write(`File Name,Description,Keywords,Category,Batch name,Editorial,Editorial Text,Editorial City,Editorial State,Editorial Country,Editorial Date\n`)
  for (const clip of clips) {
    // Ensure Description is quoted if it contains commas
    const desc = `"${clip.Description.replace(/\"/g, '""')}"`  // escape double-quotes by doubling them
    const keywordsStr = clip.Keywords.join(', ')  // keywords already separated by comma
    const category = clip.Category || ''
    const batch = clip.BatchName || ''
    const editorialFlag = clip.Editorial ? 'True' : 'False'
    const edText = clip.EditorialText || ''
    const city = clip.City || ''
    const state = clip.State || ''
    const country = clip.Country || ''
    const date = clip.Date ? new Date(clip.Date).toISOString().split('T')[0] : ''
    const row = `${clip.FileName},${desc},${keywordsStr},${category},${batch},${editorialFlag},${edText},${city},${state},${country},${date}\n`
    stream.write(row)
  }
  stream.end()
  console.log(`Exported ${clips.length} clips to ${outputPath}`)
}

In the above code, we fetch all clip documents that have a description and keywords (assuming those indicate readiness). We then write a CSV header followed by each clip’s data. Descriptions are wrapped in quotes, and any internal quotes are escaped by doubling (""). Keywords are joined by comma+space; since keywords themselves should not contain commas (they’re single terms), this is safe. The booleans and optional fields are converted to the expected string. We format date to ISO (or any required format; BlackBox might not need time, just the date). The resulting CSV will match the BlackBox template (as seen in their Excel) so it can be uploaded directly.

	•	Export Formats: We target CSV because it’s universally accepted (the BlackBox template is effectively a CSV in an XLSX). If needed, this could also generate an XLSX by using a library like xlsx. But a properly formatted CSV is usually sufficient.
	•	Usage: This exporter can be run as a one-off CLI command (e.g., sanity exec exportBlackBoxCSV.js) or triggered via the Studio UI (see integration section). After running, the user will have a file (e.g., BlackBoxExport.csv) ready to upload. By automating this, we eliminate manual copying of metadata into spreadsheets and ensure consistency (the script will output exactly what’s in Sanity).

In summary, the BBG exporter library guarantees that the data stored in Sanity can fluidly move to BlackBox’s system. It respects all the compliance rules (ensuring no missing fields, proper formatting) so that the submission process is streamlined.

S3/MinIO Asset Integration (s3AssetHelper.ts)

If the videos and clips are stored in an S3-compatible storage (like MinIO), this helper library abstracts the details of connecting to that storage. It allows our other libraries (clip generator, etc.) to remain focused on logic rather than storage APIs. Main functions:
	•	Initialize S3 Client: Use AWS SDK to connect to the MinIO server. We will configure the endpoint (URL of the MinIO service), access keys, and force path style addressing (since MinIO often runs on a custom domain/port). For example:

import AWS from 'aws-sdk'
const s3 = new AWS.S3({
  endpoint: process.env.MINIO_ENDPOINT, // e.g. 'http://localhost:9000'
  accessKeyId: process.env.MINIO_ACCESS_KEY,
  secretAccessKey: process.env.MINIO_SECRET_KEY,
  s3ForcePathStyle: true,              // needed for MinIO compatibility [oai_citation:13‡stackoverflow.com](https://stackoverflow.com/questions/74732461/aws-sdk-s3-node-js-connect-to-local-minio-server#:~:text=All%20you%20need%20to%20do,I%20do%20it%20this%20way)
  sslEnabled: false                    // if using HTTP (no SSL) [oai_citation:14‡stackoverflow.com](https://stackoverflow.com/questions/74732461/aws-sdk-s3-node-js-connect-to-local-minio-server#:~:text=sslEnabled%3A%20false%20endpoint%3A%20http%3A%2F%2Flocalhost%3Aport%2F%20accessKeyId%3A,dummy%20secretAccessKey%3A%20dummydummy)
})

The above uses AWS SDK v2; with v3, it’s similar (just using S3Client and passing forcePathStyle: true). The key setting is s3ForcePathStyle: true ￼, which ensures the bucket name is not assumed in the subdomain. This configuration is proven to resolve connection issues when using AWS SDK with MinIO ￼ ￼.

	•	Download (Get) Object: A function getObjectFromS3(key: string): Promise<string> that takes a storage key/path and retrieves the file. It could either save the file to a temp directory and return the file path, or return a buffer/stream. For simplicity, our clip generator used it to get a local file path. Implementation uses s3.getObject(params).promise() and writes the data to disk. For example:

import { writeFileSync } from 'fs'
export async function getObjectFromS3(key: string): Promise<string> {
  const data = await s3.getObject({ Bucket: process.env.MINIO_BUCKET, Key: key }).promise()
  const filePath = `/tmp/${key.split('/').pop()}`
  writeFileSync(filePath, data.Body)
  return filePath
}

This assumes data.Body is a Buffer. We derive a filename from the key (everything after last /) for local use. In a production setup, we’d handle errors (e.g., file not found) and ensure the tmp directory exists/cleanup.

	•	Upload (Put) Object: Similarly, uploadObjectToS3(key: string, filePath: string, contentType: string): Promise<void> will read a local file and upload it to the specified bucket/key. For example:

import { createReadStream } from 'fs'
export async function uploadObjectToS3(key: string, filePath: string, contentType: string) {
  const Body = createReadStream(filePath)
  await s3.upload({
    Bucket: process.env.MINIO_BUCKET,
    Key: key,
    Body,
    ContentType: contentType
  }).promise()
}

This streams the file to MinIO. After this, the new clip is stored and accessible (we might also generate a public URL or set proper ACL if needed by the application). The fileKey saved in our Sanity clip doc corresponds to this Key so we can retrieve it later or reference it for the CSV (as File Name).

	•	Utility Functions: We might add helpers like getSignedUrl(key) if we need a temporary URL (for example, to display a video thumbnail in Studio via an <video> tag), or listObjects(prefix) if we want to scan a bucket. But those are optional. For our main needs, simple get/upload covers it.

By configuring the S3 client for MinIO once, all our automation code can use getObjectFromS3 and uploadObjectToS3 without worrying about credentials or endpoints scattered throughout the code. This aligns with the DRY principle and allows easy switching to another storage (or Sanity’s native store) by changing this one module. It also means our Studio can remain stateless with regard to large files – we fetch and process videos on demand in these Node functions, which can be run on a server or CI runner that has access to the storage.

Integrating Automation into Sanity Studio

To make these automation tools accessible, we integrate them into the Sanity Studio UI and workflow. Sanity v3 allows adding custom document actions and custom tools to extend the Studio’s functionality ￼ ￼. Here’s how we can integrate each piece:
	•	Custom Document Actions: We can create actions that appear in the dropdown menu of a document (e.g., a button in the "…" menu or as a primary action). For example, on a video document, we add a "Generate Clips" action. On a clip document, we add an "Enrich Metadata" action. These actions are defined as JavaScript functions that Sanity Studio will call when clicked ￼. In our sanity.config.ts, we register them under the document.actions configuration, optionally filtering by document type ￼. For instance:

// in sanity.config.ts
import { GenerateClipsAction } from './lib/automation/actions/generateClipsAction'
import { EnrichMetadataAction } from './lib/automation/actions/enrichMetadataAction'

export default defineConfig({
  // ... other config ...
  document: {
    actions: (prev, context) => {
      const actions = [...prev]
      if (context.schemaType === 'video') {
        actions.push(GenerateClipsAction)
      }
      if (context.schemaType === 'clip') {
        actions.push(EnrichMetadataAction)
      }
      return actions
    }
  }
})

Each action module exports a function that returns an object with a label and an onHandle handler ￼. For example, GenerateClipsAction might open a dialog or use predefined plannedClips from the document:

import { generateClipsFromVideo } from '../clipGenerator'
export function GenerateClipsAction(props) {
  return {
    label: 'Generate Clips',
    onHandle: async () => {
      const videoId = props.id
      const doc = props.draft || props.published
      const clipSpecs = doc?.plannedClips ?? []  // assume this contains {start, end, title} items
      if (!clipSpecs.length) {
        window.alert('No clip segments specified!')
        return
      }
      try {
        await generateClipsFromVideo(videoId, clipSpecs)
        window.alert(`Clips created from video.`)
      } catch(err) {
        console.error(err)
        window.alert(`Error generating clips: ${err.message}`)
      }
      props.onComplete()  // finish the action, refresh the document
    }
  }
}

This action uses the generateClipsFromVideo function from our library. We retrieve the needed data (in this case, plannedClips which the user could fill out in the form), then call the function. We provide user feedback via alert (a more polished implementation could use the Sanity UI to show toasts or dialogs). After completion, we call props.onComplete() or simply rely on Studio to reflect any new documents (since the clip docs are created, they will appear in the dataset). The pattern for custom actions is illustrated in Sanity’s docs ￼, and we adapt it to call our internal logic.
Similarly, EnrichMetadataAction for a clip document would call enrichClipMetadata(clipId) from our inferrer. It could even prompt the user if they want to override existing metadata or only fill missing fields. For example:

export function EnrichMetadataAction(props) {
  return {
    label: 'Auto-Fill Metadata',
    onHandle: async () => {
      const clipId = props.id
      try {
        await enrichClipMetadata(clipId)
        window.alert('Metadata updated with suggestions.')
      } catch(err) {
        console.error(err)
        window.alert('Failed to generate metadata.')
      }
      props.onComplete()
    }
  }
}

Because the action runs in the browser context of the Studio, heavy operations (like running ffmpeg or calling external APIs) must be accessible. In our design, these functions are part of the codebase – if the Studio is running in a container/Node environment, it might be able to invoke them directly. However, if the Studio is deployed as a static app, the actions would need to trigger an API (for instance, a serverless function or a backend service that has the libraries available). Given the full-stack Dockerized setup, one approach is to have a Node process co-located that can be called (maybe via an HTTP endpoint or a message queue). Another approach is to run the automation via CLI/CI (discussed below) rather than directly in the production Studio. For simplicity, this design assumes the developer can run these in a controlled environment (e.g., locally or via an admin panel) – the key is the functions are modular and can be called as needed.

	•	Batch Operations / Custom Tools: For exporting to CSV or processing many clips at once, a custom Tool in the Studio might be more convenient. We can create a custom React component under ./components/BulkExportTool.tsx and register it as a new tool in sanity.config.ts (using the defineConfig({ plugins: [deskTool(), myTool()] }) approach). This tool could present a UI like "Export BlackBox CSV" with options (e.g., select all clips or those in a certain batch). When the user clicks a button, it can run the exportBlackBoxCSV function. Since that function writes to a file on the server side, we might instead adjust it to return the CSV text to the client and then trigger a download. For example, the tool could use the Sanity client to fetch clip data and then create a Blob URL for download. This avoids needing a server round-trip. An outline of such a tool:

// components/BulkExportTool.tsx
import {useState} from 'react'
import {useClient} from 'sanity'  // to run GROQ queries
export default function BulkExportTool() {
  const client = useClient()
  const [downloading, setDownloading] = useState(false)
  const handleExport = async () => {
    setDownloading(true)
    const clips = await client.fetch(`*[_type=="clip"]{FileName: fileKey, Description: description, Keywords: keywords, Category: category, Batch: batchName, Editorial: editorial, ...}`)
    // construct CSV content similar to bbgExporter logic
    let csv = 'File Name,Description,Keywords,Category,Batch name,Editorial,Editorial Text,Editorial City,Editorial State,Editorial Country,Editorial Date\n'
    clips.forEach(clip => { /* format each clip into csv string */ })
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' })
    const url = URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url
    link.setAttribute('download', `BlackBoxExport.csv`)
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)
    setDownloading(false)
  }
  return (
    <div>
      <h2>BlackBox CSV Export</h2>
      <p>Export all clips to a CSV for BlackBox.global</p>
      <button onClick={handleExport} disabled={downloading}>
        {downloading ? 'Exporting...' : 'Export CSV'}
      </button>
    </div>
  )
}

We would register this tool in sanity.config.ts with something like:

import BulkExportTool from './components/BulkExportTool'
// ...
export default defineConfig({
  // ...,
  plugins: [deskTool(), visionTool(), /* other plugins */],
  tools: (prev) => [...prev, {name: 'bbgExport', title: 'BlackBox Export', component: BulkExportTool}]
})

This adds a new menu item "BlackBox Export" in the Studio. An advanced user can click it and initiate the export. This approach uses the Sanity client in the browser to fetch data and prepare CSV, which is fine for moderate data sizes and avoids server complexities. For thousands of clips, the operation might be heavy on the client; in such a case, running exportBlackBoxCSV on a server or CI might be preferable.

	•	CI/CLI Integration: We designed the libraries to be usable outside the Studio as well. For example, using the Sanity CLI’s exec command or a Node script, one could automate these tasks. You could write a script batch_process.js that calls generateClipsFromVideo for all new videos, then calls enrichClipMetadata for all newly created clips, and finally calls exportBlackBoxCSV. This script can be run in a CI pipeline or as a scheduled job. Because our code is modular and relies on the Sanity JS client and AWS SDK (which can run in Node), it’s straightforward to wire up. This fits a GitOps approach – for instance, when new footage is added (perhaps tracked via Git or an upload trigger), the automation can run and commit the CSV or push updates back to the repo. The advanced developer can decide whether to use the Studio UI for manual control or CI for fully automatic operation (or a hybrid: e.g., use Studio to mark content "approved" then CI picks it up for processing).
	•	Sanity v3 Best Practices: We ensure all integrations use the v3 APIs. For example, we use defineConfig and register actions via the configuration (as shown above) instead of the deprecated part: system. We structure schema in separate files and export an array of types ￼. The Studio’s code remains mostly declarative (schema, actions, tools) while our heavy logic resides in the lib/automation modules – this separation of concerns is important. We avoid directly modifying Sanity internals; instead we use official hooks like useDocumentOperation (as in Sanity’s example for patching inside an action ￼) or the client to update documents.

By integrating at multiple levels (document actions for single-item operations, tools for bulk operations, and external scripts for automation), we provide flexibility. The developer can trigger clip creation and metadata generation on a per-video basis during curation, and then periodically export all data for upload. All of this happens without tedious manual steps, and within the robust content management environment of Sanity Studio.

Conclusion

With the above libraries and integrations, the Sanity Studio becomes a powerful automation hub for the user’s video workflow. The clip generator automatically cuts raw videos into stock-ready clips, the metadata inferrer intelligently populates titles/descriptions/keywords (meeting BlackBox’s strict guidelines), and the BlackBox exporter produces a ready-to-go CSV of all clips ￼. The solution respects Sanity v3 conventions (modular schemas, plugin architecture) and is extensible for future needs – for example, swapping AI models or adjusting to new distribution platforms would only require changes in the respective library module. By designing the code to be modular, reusable, and triggerable via UI or CI, we ensure the system can be adapted to different workflows (interactive or fully automated). This empowers an advanced developer to maintain a smooth content pipeline: from raw video in a NAS, through Sanity-managed metadata enrichment, all the way to compliant BlackBox Global submissions. The end result is a significant reduction in manual effort and a more consistent, error-free metadata generation process for thousands of video clips.