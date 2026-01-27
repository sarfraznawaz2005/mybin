from datetime import datetime, timedelta
import hashlib
import json

class CacheManager:
    def __init__(self, max_size_mb=100, ttl_seconds=3600):
        self.cache = {}
        self.max_size = max_size_mb * 1024 * 1024
        self.ttl = timedelta(seconds=ttl_seconds)
    
    def get(self, key):
        entry = self.cache.get(key)
        if not entry:
            return None
        if datetime.now() - entry['timestamp'] > self.ttl:
            del self.cache[key]
            return None
        return entry['value']
    
    def set(self, key, value):
        entry = {
            'value': value,
            'timestamp': datetime.now(),
            'size': len(str(value))
        }
        
        # Evict old entries if at capacity
        while self._get_cache_size() + entry['size'] > self.max_size:
            self._evict_oldest()
        
        self.cache[key] = entry
    
    def _evict_oldest(self):
        oldest_key = min(self.cache.keys(), key=lambda k: self.cache[k]['timestamp'])
        del self.cache[oldest_key]
    
    def _get_cache_size(self):
        return sum(e['size'] for e in self.cache.values())
    
    def clear(self):
        self.cache.clear()
    
    def save_to_disk(self, filepath):
        with open(filepath, 'w') as f:
            json.dump(self.cache, f)
