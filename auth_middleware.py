from functools import wraps
from flask import request, jsonify
import jwt
import os

SECRET_KEY = os.getenv('JWT_SECRET', 'default-secret-key')

def require_auth(f):
    """Decorator to require JWT authentication."""
    @wraps(f)
    def decorated(*args, **kwargs):
        token = request.headers.get('Authorization')
        if not token:
            return jsonify({'error': 'Missing token'}), 401
        
        try:
            payload = jwt.decode(token, SECRET_KEY, algorithms=['HS256'])
        except jwt.ExpiredSignatureError:
            return jsonify({'error': 'Token expired'}), 401
        except jwt.InvalidTokenError:
            return jsonify({'error': 'Invalid token'}), 401
        
        return f(*args, **kwargs)
    return decorated

def verify_admin(user_id):
    """Check if user has admin privileges."""
    # In real app, query database
    return user_id in ['admin-001', 'admin-002']
