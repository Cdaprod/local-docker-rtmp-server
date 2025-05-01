import AWS from 'aws-sdk'
import fs from 'fs'
import path from 'path'

const s3 = new AWS.S3({
  endpoint: process.env.MINIO_ENDPOINT!,
  accessKeyId: process.env.MINIO_ACCESS_KEY!,
  secretAccessKey: process.env.MINIO_SECRET_KEY!,
  s3ForcePathStyle: true,
  sslEnabled: false,
  region: process.env.MINIO_REGION || 'us-east-1'
})

export async function getObjectFromS3(key: string): Promise<string> {
  const result = await s3.getObject({ Bucket: process.env.MINIO_BUCKET!, Key: key }).promise()
  const filePath = path.join('/tmp', path.basename(key))
  fs.writeFileSync(filePath, result.Body as Buffer)
  return filePath
}

export async function uploadObjectToS3(key: string, filePath: string, contentType: string) {
  const Body = fs.createReadStream(filePath)
  await s3.upload({
    Bucket: process.env.MINIO_BUCKET!,
    Key: key,
    Body,
    ContentType: contentType
  }).promise()
}
