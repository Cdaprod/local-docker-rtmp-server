# /app/minio/video_storage_bucket_client.py
from minio import Minio
from minio.error import S3Error

class VideoStorageClient:
    def __init__(
        self,
        endpoint: str,
        access_key: str,
        secret_key: str,
        secure: bool = True,
        bucket_name: str = "video-storage"
    ):
        self.client = Minio(
            endpoint,
            access_key=access_key,
            secret_key=secret_key,
            secure=secure
        )
        self.bucket_name = bucket_name
        # Ensure bucket exists
        if not self.client.bucket_exists(bucket_name):
            self.client.make_bucket(bucket_name)

    def upload_file(self, file_path: str, object_name: str):
        """
        Upload local file to MinIO bucket.
        """
        try:
            self.client.fput_object(
                self.bucket_name, object_name, file_path
            )
            return {"bucket": self.bucket_name, "object": object_name}
        except S3Error as err:
            raise RuntimeError(f"MinIO upload error: {err}")

    def download_file(self, object_name: str, dest_path: str):
        """
        Download object from MinIO to local path.
        """
        try:
            self.client.fget_object(
                self.bucket_name, object_name, dest_path
            )
            return dest_path
        except S3Error as err:
            raise RuntimeError(f"MinIO download error: {err}")