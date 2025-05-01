// /schemas/video.ts
import { defineType, defineField } from 'sanity'

export const video = defineType({
  name: 'video',
  title: 'Video',
  type: 'document',
  fields: [
    // --- General Metadata ---
    defineField({
      name: 'title',
      title: 'Title',
      type: 'string',
      validation: Rule => Rule.required().min(3),
    }),
    defineField({
      name: 'description',
      title: 'Description',
      type: 'text',
    }),

    // --- Asset Handling ---
    defineField({
      name: 'videoAsset',
      title: 'Video Asset',
      type: 'file',
      options: { accept: 'video/*' },
    }),
    defineField({
      name: 'externalUrl',
      title: 'External URL',
      type: 'url',
      description: 'Stream or NAS URL if not uploaded.',
    }),

    // --- Organization ---
    defineField({
      name: 'tags',
      title: 'Tags',
      type: 'array',
      of: [{ type: 'string' }],
    }),
    defineField({
      name: 'category',
      title: 'Category',
      type: 'string',
      options: {
        list: ['Tutorial', 'Livestream', 'Promo', 'Internal', 'Other'],
        layout: 'dropdown',
      },
    }),

    // --- Relationships ---
    defineField({
      name: 'clips',
      title: 'Associated Clips',
      type: 'array',
      of: [{ type: 'reference', to: [{ type: 'clip' }] }],
      description: 'Clips generated from this video.',
    }),

    // --- System Fields ---
    defineField({
      name: 'createdAt',
      title: 'Created At',
      type: 'datetime',
      readOnly: true,
      initialValue: () => new Date().toISOString(),
    }),
    defineField({
      name: 'updatedAt',
      title: 'Updated At',
      type: 'datetime',
      readOnly: true,
      hidden: true,
    }),
  ],
})
