Next Steps / Clarifications
	1.	Stock-segment removal:
	•	How do you define which parts to drop?
	•	Does your CSV include remove_ranges (e.g. "00:00:00-00:00:05;00:03:10-00:03:20")?
	2.	CSV schema:
	•	Confirm header names (source_path, batch_name, maybe remove_ranges).
	3.	Mounting vs. Docker:
	•	Will you run this inside Docker (and mount the NAS share into /mnt/video_share)?
	•	Or directly on the host where the share is already mounted read-only?

Once I have that, I can refine the FFmpeg commands (to drop multiple segments or apply more complex edits) and fully tune the batch script.