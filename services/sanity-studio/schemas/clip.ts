import { defineType, defineField } from 'sanity'

export const clip = defineType({
  name: 'clip',
  title: 'Clip',
  type: 'document',
  fields: [
    defineField({
      name: 'sourceVideo',
      title: 'Source Video',
      type: 'reference',
      to: [{ type: 'video' }],
      validation: Rule => Rule.required(),
      description: 'Reference to the original video document.',
    }),
    defineField({
      name: 'fileKey',
      title: 'Storage Key',
      type: 'string',
      readOnly: true,
      description: 'S3/MinIO key for the clip file.',
    }),
    defineField({
      name: 'startTime',
      title: 'Start Time (s)',
      type: 'number',
      validation: Rule => Rule.required().min(0),
    }),
    defineField({
      name: 'endTime',
      title: 'End Time (s)',
      type: 'number',
      validation: Rule => Rule.required().min(0).custom((end, ctx) => {
        const start = ctx.document.startTime
        return end > start ? true : 'End must be greater than start'
      }),
    }),
    defineField({
      name: 'title',
      title: 'Clip Title',
      type: 'string',
      description: 'Short, descriptive title for this clip.',
      validation: Rule => Rule.required().min(3),
    }),
    defineField({
      name: 'description',
      title: 'Description',
      type: 'text',
      description: 'One-sentence description (5+ words, ≤200 chars).',
      validation: Rule => Rule.required().min(15).max(200).custom(text => {
        const count = text.trim().split(/\\s+/).length
        return count >= 5 ? true : 'Must be at least 5 words'
      }),
    }),
    defineField({
      name: 'keywords',
      title: 'Keywords',
      type: 'array',
      of: [{ type: 'string' }],
      description: '8–49 unique keywords.',
      validation: Rule => Rule.required().min(8).max(49).unique(),
    }),
    defineField({
      name: 'category',
      title: 'Category',
      type: 'string',
      options: {
        list: ['Nature','Business','Technology','People','Urban','Other'],
        layout: 'dropdown',
      },
      description: 'Select a BlackBox stock category.',
    }),
    defineField({
      name: 'batchName',
      title: 'Batch Name',
      type: 'string',
      description: 'Group identifier for related clips.',
    }),
    defineField({
      name: 'editorial',
      title: 'Editorial Only',
      type: 'boolean',
      description: 'Check if this clip is editorial content.',
      initialValue: false,
    }),
    defineField({
      name: 'editorialCaption',
      title: 'Editorial Caption',
      type: 'string',
      hidden: ({document}) => !document?.editorial,
    }),
    defineField({
      name: 'editorialCity',
      title: 'Editorial City',
      type: 'string',
      hidden: ({document}) => !document?.editorial,
    }),
    defineField({
      name: 'editorialState',
      title: 'Editorial State',
      type: 'string',
      hidden: ({document}) => !document?.editorial,
    }),
    defineField({
      name: 'editorialCountry',
      title: 'Editorial Country',
      type: 'string',
      hidden: ({document}) => !document?.editorial,
    }),
    defineField({
      name: 'editorialDate',
      title: 'Editorial Date',
      type: 'datetime',
      hidden: ({document}) => !document?.editorial,
    }),
    defineField({
      name: 'createdAt',
      title: 'Created At',
      type: 'datetime',
      readOnly: true,
      initialValue: () => new Date().toISOString(),
    }),
  ],
})
