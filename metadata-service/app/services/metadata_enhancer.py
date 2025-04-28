import os
from datetime import datetime
from typing import Dict

# Predefined stock video fields (extensible later)
STOCK_VIDEO_CATEGORIES = [
    "Nature", "Technology", "Business", "People", "Lifestyle", "Sports", 
    "Abstract", "Architecture", "Animals", "Transportation"
]

def detect_content_category(file_name: str) -> str:
    """Basic keyword-based detection for category assignment."""
    lower_name = file_name.lower()
    if "drone" in lower_name:
        return "Nature"
    elif "interview" in lower_name:
        return "People"
    elif "timelapse" in lower_name or "time_lapse" in lower_name:
        return "Architecture"
    elif "sports" in lower_name:
        return "Sports"
    # fallback
    return "Abstract"

def enrich_for_stock_market(metadata: Dict, file_path: str) -> Dict:
    """Add fields required for stock video submission if applicable."""
    base_name = os.path.basename(file_path)
    stock_metadata = {
        "stock_title": f"Stock Footage: {os.path.splitext(base_name)[0]}",
        "stock_description": "Cinematic stock footage auto-tagged via CDA pipeline.",
        "stock_tags": metadata.get("tags", []),
        "stock_batch_name": "CDA-Default-Batch",
        "stock_editorial": False,
        "stock_category": detect_content_category(base_name),
    }
    metadata.update(stock_metadata)
    return metadata

def enrich_metadata(base_metadata: dict, file_path: str) -> dict:
    """Main entrypoint to enrich metadata intelligently."""
    # --- Dynamic Enrichments ---
    base_metadata["enriched_at"] = datetime.utcnow().isoformat() + "Z"
    
    # Only enrich if path or settings call for stock video treatment
    if "stock" in file_path.lower() or "footage" in file_path.lower():
        base_metadata = enrich_for_stock_market(base_metadata, file_path)
    
    # Future: More enrichments (stream types, asset linking, user tracking) here

    return base_metadata