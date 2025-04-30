// /services/sanity-studio/schemas/videoRenderJob.ts

import { defineField, defineType } from 'sanity'

export const videoRenderJob = defineType({
  name: 'videoRenderJob',
  title: 'Video Render Job',
  type: 'document',
  fields: [
    defineField({
      name: 'title',
      title: 'Title',
      type: 'string',
      validation: Rule => Rule.required().min(5).max(150),
      description: 'Short title describing this render job.'
    }),
    defineField({
      name: 'backgroundAsset',
      title: 'Background Video',
      type: 'file',
      options: { accept: 'video/*' },
      description: 'Upload the background video (base layer).',
    }),
    defineField({
      name: 'overlayAsset',
      title: 'Overlay Video',
      type: 'file',
      options: { accept: 'video/*' },
      description: 'Upload the overlay video (e.g., UI elements).',
    }),
    defineField({
      name: 'chromaKey',
      title: 'Chroma Key Color',
      type: 'string',
      initialValue: '#00FF00',
      description: 'Hex color to use as the chroma key. Default is green (#00FF00).',
      validation: Rule => Rule.regex(/^#([0-9a-fA-F]{6})$/, { name: "hex color" }),
    }),
    defineField({
      name: 'status',
      title: 'Status',
      type: 'string',
      options: {
        list: [
          { title: 'Queued', value: 'queued' },
          { title: 'Processing', value: 'processing' },
          { title: 'Completed', value: 'completed' },
          { title: 'Failed', value: 'failed' },
        ],
      },
      initialValue: 'queued',
      validation: Rule => Rule.required(),
      description: 'Current status of the render job.'
    }),
    defineField({
      name: 'outputAsset',
      title: 'Rendered Output',
      type: 'file',
      options: { accept: 'video/*' },
      description: 'Final rendered output video (after processing).',
    }),
    defineField({
      name: 'createdAt',
      title: 'Created At',
      type: 'datetime',
      initialValue: () => new Date().toISOString(),
      readOnly: true,
      description: 'Creation time.'
    }),
    defineField({
      name: 'updatedAt',
      title: 'Updated At',
      type: 'datetime',
      initialValue: () => new Date().toISOString(),
      description: 'Last update time.'
    }),
  ]
})