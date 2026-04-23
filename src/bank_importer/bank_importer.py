"""
Main bank importer orchestrating different parsers
"""
import os
from typing import List, Dict
from .csv_parser import CSVParser
from .ofx_parser import OFXParser


class BankImporter:
    """Import bank statements from various formats"""
    
    def __init__(self):
        self.csv_parser = CSVParser()
        self.ofx_parser = OFXParser()
    
    def import_file(self, file_path: str, column_mapping: Dict = None) -> List[Dict]:
        """
        Import bank statement file
        
        Args:
            file_path: Path to bank statement file
            column_mapping: Column mapping for CSV files
            
        Returns:
            List of transaction dictionaries
        """
        file_ext = os.path.splitext(file_path)[1].lower()
        
        if file_ext == '.csv':
            return self.csv_parser.parse(file_path, column_mapping)
        elif file_ext == '.ofx':
            return self.ofx_parser.parse(file_path)
        elif file_ext == '.qfx':
            return self.ofx_parser.parse(file_path)
        else:
            raise ValueError(f"Unsupported file format: {file_ext}")
    
    def import_csv(self, file_path: str, column_mapping: Dict = None) -> List[Dict]:
        """Import CSV bank statement"""
        return self.csv_parser.parse(file_path, column_mapping)
    
    def import_ofx(self, file_path: str) -> List[Dict]:
        """Import OFX bank statement"""
        return self.ofx_parser.parse(file_path)
