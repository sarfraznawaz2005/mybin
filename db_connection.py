import sqlite3
from contextlib import contextmanager

class DatabaseConnection:
    def __init__(self, db_path):
        self.db_path = db_path
        self.connection = None
    
    @contextmanager
    def connect(self):
        """Context manager for database connections."""
        self.connection = sqlite3.connect(self.db_path)
        self.connection.row_factory = sqlite3.Row
        try:
            yield self.connection
            self.connection.commit()
        finally:
            self.connection.close()
    
    def execute_query(self, query, params=None):
        """Execute SQL query with optional parameters."""
        with self.connect() as conn:
            cursor = conn.cursor()
            if params:
                cursor.execute(query, params)
            else:
                cursor.execute(query)
            return cursor.fetchall()
