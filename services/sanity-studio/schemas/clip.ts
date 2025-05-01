import { defineType, defineField } from 'sanity'

export const clip = defineType({
  name: 'clip',
  title: 'Clip',
  type: 'document',
  fields: [
    defineField({
      name: 'video',
      title: 'Source Video',
      type: 'reference',
      to: [{ type: 'video' }],
      validation: Rule => Rule.required(),
      description: 'The full video this clip was taken from.'
    }),
    defineField({
      name: 'startTime',
      title: 'Start Time (seconds)',
      type: 'number',
      validation: Rule => Rule.required().min(0),
    }),
    defineField({
      name: 'endTime',
      title: 'End Time (seconds)',
      type: 'number',
      validation: Rule =>
        Rule.required()
          .min(0)
          .custom((endTime, context) => {
            const startTime = context?.document?.startTime
            return endTime > startTime
              ? true
              : 'End time must be greater than start time'
          }),
    }),
    defineField({
      name: 'label',
      title: 'Clip Label',
      type: 'string',
      description: 'A short label for this clip (optional)',
    }),
    defineField({
      name: 'createdAt',
      title: 'Created At',
      type: 'datetime',
      initialValue: () => new Date().toISOString(),
      readOnly: true,
    }),
  ],
})