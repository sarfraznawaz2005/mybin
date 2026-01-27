from typing import List, Dict, Any
import re
from datetime import datetime

class ValidatorService:
    def __init__(self):
        self.rules = {
            'email': self._validate_email,
            'phone': self._validate_phone,
            'url': self._validate_url,
            'date': self._validate_date
        }
    
    def _validate_email(self, value: str) -> Dict[str, Any]:
        pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        if not re.match(pattern, value):
            return {'valid': False, 'error': 'Invalid email format'}
        return {'valid': True}
    
    def _validate_phone(self, value: str) -> Dict[str, Any]:
        digits = re.sub(r'[^0-9]', '', value)
        if len(digits) < 10 or len(digits) > 15:
            return {'valid': False, 'error': 'Phone must be 10-15 digits'}
        return {'valid': True}
    
    def _validate_url(self, value: str) -> Dict[str, Any]:
        pattern = r'^https?://[^\s/$].*'
        if not re.match(pattern, value):
            return {'valid': False, 'error': 'Invalid URL format'}
        return {'valid': True}
    
    def _validate_date(self, value: str) -> Dict[str, Any]:
        try:
            datetime.fromisoformat(value)
            return {'valid': True}
        except ValueError:
            return {'valid': False, 'error': 'Invalid ISO date format'}
    
    def validate_field(self, field_name: str, value: str) -> Dict[str, Any]:
        validator = self.rules.get(field_name)
        if not validator:
            return {'valid': True, 'note': 'No validation rule'}
        return validator(value)
    
    def validate_all(self, data: Dict[str, str]) -> Dict[str, List]:
        results = {}
        for field, value in data.items():
            results[field] = self.validate_field(field, value)
        return results
