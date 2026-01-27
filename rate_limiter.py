import time
from collections import defaultdict, deque
from threading import Lock

class RateLimiter:
    def __init__(self, max_requests=100, time_window=60):
        self.max_requests = max_requests
        self.time_window = time_window
        self.requests = defaultdict(deque)
        self.lock = Lock()
    
    def is_allowed(self, user_id):
        """Check if user request is within rate limits."""
        now = time.time()
        
        with self.lock:
            user_requests = self.requests[user_id]
            
            # Remove old requests outside time window
            while user_requests and user_requests[0] < now - self.time_window:
                user_requests.popleft()
            
            # Check if under limit
            if len(user_requests) >= self.max_requests:
                return False
            
            # Add current request
            user_requests.append(now)
            return True
    
    def get_remaining(self, user_id):
        """Get number of requests remaining for user."""
        now = time.time()
        with self.lock:
            user_requests = self.requests[user_id]
            while user_requests and user_requests[0] < now - self.time_window:
                user_requests.popleft()
            return max(0, self.max_requests - len(user_requests))
    
    def reset(self, user_id):
        """Reset rate limit for specific user (admin use)."""
        with self.lock:
            self.requests[user_id].clear()
