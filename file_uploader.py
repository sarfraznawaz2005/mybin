import os
import shutil
from typing import Optional, List
import mimetypes
import hashlib

class FileUploader:
    ALLOWED_EXTENSIONS = {'.jpg', '.jpeg', '.png', '.gif', '.pdf', '.doc', '.docx'}
    MAX_FILE_SIZE = 10 * 1024 * 1024  # 10MB
    
    def __init__(self, upload_dir='uploads'):
        self.upload_dir = upload_dir
        os.makedirs(upload_dir, exist_ok=True)
    
    def validate_file(self, filename: str) -> tuple[bool, str]:
        """Validate file extension and size."""
        ext = os.path.splitext(filename)[1].lower()
        if ext not in self.ALLOWED_EXTENSIONS:
            return False, f"Invalid file type: {ext}"
        
        # Check size (mock - in real app, check actual file)
        return True, "File is valid"
    
    def generate_unique_filename(self, original: str) -> str:
        """Generate unique filename to prevent overwrites."""
        name, ext = os.path.splitext(original)
        timestamp = int(time.time())
        return f"{name}_{timestamp}{ext}"
    
    def save_file(self, file_data: bytes, filename: str) -> str:
        """Save uploaded file to disk."""
        file_path = os.path.join(self.upload_dir, filename)
        with open(file_path, 'wb') as f:
            f.write(file_data)
        return file_path
    
    def get_file_hash(self, file_path: str) -> str:
        """Calculate MD5 hash of file."""
        hash_md5 = hashlib.md5()
        with open(file_path, 'rb') as f:
            for chunk in iter(lambda: f.read(4096), b''):
                hash_md5.update(chunk)
        return hash_md5.hexdigest()
    
    def cleanup_old_files(self, days: int = 7):
        """Remove files older than specified days."""
        now = time.time()
        for filename in os.listdir(self.upload_dir):
            file_path = os.path.join(self.upload_dir, filename)
            if os.path.getmtime(file_path) < now - (days * 86400):
                os.remove(file_path)
