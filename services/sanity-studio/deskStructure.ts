import { StructureBuilder } from 'sanity/structure'
import S from '@sanity/desk-tool/structure-builder'
import VideoPreviewInspector from './components/VideoPreviewInspector'
import VideoClipEditor from './components/VideoClipEditor'

export default (S: StructureBuilder) =>
  S.list()
    .title('Video Studio')
    .items([
      S.documentTypeListItem('video')
        .title('Videos')
        .schemaType('video')
        .child(videoId =>
          S.document()
            .documentId(videoId)
            .schemaType('video')
            .views([
              S.view.form(),
              S.view.component(VideoPreviewInspector).title('Preview'),
              S.view.component(VideoClipEditor).title('Clip Editor'),
            ])
        ),
      S.documentTypeListItem('clip').title('Clips'),
      S.documentTypeListItem('blackBoxMetadata').title('BlackBox Metadata'),
      S.documentTypeListItem('videoRenderJob').title('Render Jobs'),
    ])
