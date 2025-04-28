# app/services/finalizer_service.py

import os
import json
import asyncio
import logging
from datetime import datetime
from typing import Dict, List, Any, Optional
from app.core.minio_client import MinIOClient
from app.core.config import MINIO_METADATA_BUCKET, MINIO_ASSETS_BUCKET
from app.core.logging import log_streamer
from app.services.finalizer import finalize_video

# Regular logger setup
logger = logging.getLogger("finalizer_service")
logger.setLevel(logging.INFO)
handler = logging.StreamHandler()
formatter = logging.Formatter("%(asctime)s - %(name)s - %(levelname)s - %(message)s")
handler.setFormatter(formatter)
logger.addHandler(handler)

class FinalizerService:
    def __init__(self):
        self.minio = MinIOClient()
        self.pending_queue = []
        self.is_running = False
    
    async def start(self):
        """Start the finalizer service"""
        if self.is_running:
            logger.warning("Finalizer service is already running")
            return
        
        self.is_running = True
        msg = "Finalizer service started"
        logger.info(msg)
        log_streamer.info(msg)
        
        asyncio.create_task(self._process_queue())
    
    async def stop(self):
        """Stop the finalizer service"""
        self.is_running = False
        msg = "Finalizer service stopped"
        logger.info(msg)
        log_streamer.info(msg)
    
    async def queue_finalization(self, source: str, metadata: Dict[str, Any]) -> str:
        """Add a video to the finalization queue"""
        job_id = f"fin-{datetime.utcnow().strftime('%Y%m%d%H%M%S')}"
        
        job = {
            "job_id": job_id,
            "source": source,
            "metadata": metadata,
            "status": "queued",
            "created_at": datetime.utcnow().isoformat()
        }
        
        self.pending_queue.append(job)
        
        # Save job to MinIO
        self.minio.upload_json(
            bucket_name=MINIO_METADATA_BUCKET,
            object_name=f"jobs/{job_id}.json",
            data=job
        )
        
        msg = f"Queued finalization job {job_id} for {source}"
        logger.info(msg)
        log_streamer.info(msg)
        
        return job_id
    
    async def _process_queue(self):
        """Process the finalization queue"""
        while self.is_running:
            if not self.pending_queue:
                await asyncio.sleep(5)
                continue
            
            job = self.pending_queue.pop(0)
            await self._process_job(job)
    
    async def _process_job(self, job: Dict[str, Any]):
        """Process a single finalization job"""
        job_id = job["job_id"]
        source = job["source"]
        
        try:
            msg = f"Processing finalization job {job_id} for {source}"
            logger.info(msg)
            log_streamer.info(msg)
            
            # Update job status
            job["status"] = "processing"
            job["updated_at"] = datetime.utcnow().isoformat()
            self.minio.upload_json(
                bucket_name=MINIO_METADATA_BUCKET,
                object_name=f"jobs/{job_id}.json",
                data=job
            )
            
            # Perform finalization (run in thread pool to not block event loop)
            loop = asyncio.get_event_loop()
            thumb_path, metadata = await loop.run_in_executor(
                None, lambda: finalize_video(source)
            )
            
            # Merge with provided metadata
            metadata.update(job["metadata"])
            
            # Upload thumbnail
            assets_bucket = MINIO_ASSETS_BUCKET
            metadata_bucket = MINIO_METADATA_BUCKET
            thumb_key = os.path.basename(thumb_path)
            meta_key = f"{os.path.splitext(thumb_key)[0]}_metadata.json"
            
            with open(thumb_path, "rb") as f:
                self.minio.upload_file(
                    bucket_name=assets_bucket,
                    object_name=thumb_key,
                    file_data=f,
                    content_type="image/jpeg"
                )
            
            self.minio.upload_json(
                bucket_name=metadata_bucket,
                object_name=meta_key,
                data=metadata
            )
            
            # Update job status
            job["status"] = "completed"
            job["results"] = {
                "thumbnail": f"s3://{assets_bucket}/{thumb_key}",
                "metadata": f"s3://{metadata_bucket}/{meta_key}"
            }
            job["completed_at"] = datetime.utcnow().isoformat()
            
            self.minio.upload_json(
                bucket_name=MINIO_METADATA_BUCKET,
                object_name=f"jobs/{job_id}.json",
                data=job
            )
            
            msg = f"Completed finalization job {job_id}"
            logger.info(msg)
            log_streamer.info(msg)
            
            # Clean up temporary files
            if os.path.exists(thumb_path):
                os.unlink(thumb_path)
                
        except Exception as e:
            error_msg = f"Error processing job {job_id}: {str(e)}"
            logger.error(error_msg)
            log_streamer.error(error_msg)
            
            job["status"] = "failed"
            job["error"] = str(e)
            job["updated_at"] = datetime.utcnow().isoformat()
            self.minio.upload_json(
                bucket_name=MINIO_METADATA_BUCKET,
                object_name=f"jobs/{job_id}.json",
                data=job
            )
    
    async def get_job_status(self, job_id: str) -> Optional[Dict[str, Any]]:
        """Get the status of a finalization job"""
        try:
            data = self.minio.download_json(
                bucket_name=MINIO_METADATA_BUCKET,
                object_name=f"jobs/{job_id}.json"
            )
            return data
        except Exception as e:
            error_msg = f"Error retrieving job {job_id}: {str(e)}"
            logger.error(error_msg)
            log_streamer.error(error_msg)
            return None
    
    async def list_jobs(self, status: Optional[str] = None) -> List[Dict[str, Any]]:
        """List finalization jobs"""
        try:
            objects = self.minio.list_objects(
                bucket_name=MINIO_METADATA_BUCKET,
                prefix="jobs/"
            )
            
            jobs = []
            for obj in objects:
                job_data = self.minio.download_json(
                    bucket_name=MINIO_METADATA_BUCKET,
                    object_name=obj["name"]
                )
                
                if job_data and (status is None or job_data.get("status") == status):
                    jobs.append(job_data)
            
            return jobs
        except Exception as e:
            error_msg = f"Error listing jobs: {str(e)}"
            logger.error(error_msg)
            log_streamer.error(error_msg)
            return []

# Singleton instance
finalizer_service = FinalizerService()