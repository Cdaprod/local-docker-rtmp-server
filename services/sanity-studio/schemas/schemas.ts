import { type SchemaTypeDefinition } from 'sanity'

import { video } from './video'
import { clip } from './clip'
import { blackBoxMetadata } from './blackBoxMetadata'

export const schema: { types: SchemaTypeDefinition[] } = {
  types: [video, clip, blackBoxMetadata],
}