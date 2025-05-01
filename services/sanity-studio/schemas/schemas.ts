// schemas/schemas.ts
import { type SchemaTypeDefinition } from 'sanity'
import { video } from './video'
import { clip } from './clip'
import { blackBoxMetadata } from './blackBoxMetadata'
import { videoRenderJob } from './videoRenderJob'

export const schema: { types: SchemaTypeDefinition[] } = {
  types: [video, clip, blackBoxMetadata, videoRenderJob],
}
