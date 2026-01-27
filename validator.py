class EmailValidator:
    def __init__(self):
        self.pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    
    def validate(self, email):
        """Validate email address format."""
        import re
        return bool(re.match(self.pattern, email))
    
    def validate_bulk(self, emails):
        """Validate multiple email addresses."""
        results = {}
        for email in emails:
            results[email] = self.validate(email)
        return results
