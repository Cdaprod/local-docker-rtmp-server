// /services/sanity-studio/sanity.config.ts

import { defineConfig } from 'sanity'
import { deskTool } from 'sanity/desk'
import { schema } from './schemas/schema'
// @ts-ignore
import S3AssetSource from 'sanity-plugin-asset-source-s3'
import { StructureBuilder } from 'sanity/structure'

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