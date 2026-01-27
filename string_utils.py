def truncate_string(text: str, max_length: int = 100, suffix: str = '...') -> str:
    """Truncate string to max_length and add suffix if needed."""
    if len(text) <= max_length:
        return text
    return text[:max_length - len(suffix)] + suffix

def capitalize_words(text: str) -> str:
    """Capitalize first letter of each word."""
    return ' '.join(word.capitalize() for word in text.split())

def remove_extra_spaces(text: str) -> str:
    """Remove multiple consecutive spaces and trim."""
    words = text.split()
    return ' '.join(words)

def validate_email(email: str) -> bool:
    """Simple email validation (basic check only)."""
    return '@' in email and '.' in email.split('@')[-1]

def format_currency(amount: float, currency: str = 'USD') -> str:
    """Format amount as currency string."""
    return f"{currency} {amount:,.2f}"
