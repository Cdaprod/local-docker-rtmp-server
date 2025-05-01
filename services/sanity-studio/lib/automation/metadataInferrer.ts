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
