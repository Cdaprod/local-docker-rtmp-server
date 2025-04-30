// /services/sanity-studio/sanity.config.ts

import { defineConfig } from 'sanity'
import { deskTool } from 'sanity/desk'
import { schema } from './schemas/schema'

export default defineConfig({
  name: 'videoRenderStudio',
  title: 'Video Render Studio',

  projectId: process.env.NEXT_PUBLIC_SANITY_PROJECT_ID || 'your_project_id_here',
  dataset: process.env.NEXT_PUBLIC_SANITY_DATASET || 'production',

  plugins: [deskTool()],

  schema: schema,
})