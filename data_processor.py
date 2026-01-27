import pandas as pd
import numpy as np
from typing import List, Dict

class DataProcessor:
    def __init__(self, data: pd.DataFrame):
        self.data = data
        self.original = data.copy()
    
    def clean_missing_values(self, strategy: str = 'drop'):
        """Handle missing values in dataframe."""
        if strategy == 'drop':
            self.data = self.data.dropna()
        elif strategy == 'mean':
            self.data = self.data.fillna(self.data.mean())
        elif strategy == 'median':
            self.data = self.data.fillna(self.data.median())
        return self
    
    def normalize_columns(self, columns: List[str]):
        """Normalize specified columns to 0-1 range."""
        for col in columns:
            min_val = self.data[col].min()
            max_val = self.data[col].max()
            self.data[col] = (self.data[col] - min_val) / (max_val - min_val)
        return self
    
    def export_summary(self) -> Dict:
        """Export statistical summary."""
        return {
            'rows': len(self.data),
            'columns': len(self.data.columns),
            'dtypes': self.data.dtypes.to_dict()
        }
