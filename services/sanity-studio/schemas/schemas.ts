// /services/sanity-studio/schemas/schema.ts

import { type SchemaTypeDefinition } from 'sanity'
import { videoRenderJob } from './videoRenderJob'

export const schema: { types: SchemaTypeDefinition[] } = {
  types: [videoRenderJob],
}