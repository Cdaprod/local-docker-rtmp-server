import { defineField, defineType } from 'sanity'

export const blackBoxMetadata = defineType({
  name: 'blackBoxMetadata',
  title: 'BlackBox Metadata',
  type: 'document',
  fields: [
    defineField({
      name: 'video',
      title: 'Linked Video',
      type: 'reference',
      to: [{ type: 'video' }],
      validation: Rule => Rule.required(),
    }),
    defineField({
      name: 'keywords',
      title: 'Keywords',
      type: 'array',
      of: [{ type: 'string' }],
      validation: Rule => Rule.min(5),
    }),
    defineField({
      name: 'location',
      title: 'Location',
      type: 'string',
    }),
    defineField({
      name: 'category',
      title: 'BlackBox Category',
      type: 'string',
      options: {
        list: ['Nature', 'Business', 'Technology', 'People', 'Urban', 'Other'],
        layout: 'dropdown',
      },
    }),
    defineField({
      name: 'modelRelease',
      title: 'Model Release Attached',
      type: 'boolean',
    }),
    defineField({
      name: 'propertyRelease',
      title: 'Property Release Attached',
      type: 'boolean',
    }),
    defineField({
      name: 'exported',
      title: 'Exported to BlackBox',
      type: 'boolean',
      initialValue: false,
    }),
    defineField({
      name: 'lastExportedAt',
      title: 'Last Exported At',
      type: 'datetime',
    }),
  ],
})