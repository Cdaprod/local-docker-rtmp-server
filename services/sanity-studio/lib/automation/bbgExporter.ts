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
