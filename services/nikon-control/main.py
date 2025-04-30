import usb.core
import usb.util
from loguru import logger

logger.info("Searching for Nikon camera...")
dev = usb.core.find(idVendor=0x04b0)  # Nikon's Vendor ID

if dev is None:
    logger.error("Nikon camera not found.")
else:
    logger.success(f"Found Nikon camera: {hex(dev.idVendor)}:{hex(dev.idProduct)}")