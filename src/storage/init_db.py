"""
Initialize the database
"""
import sys
import os

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from src.storage.database import init_database

if __name__ == "__main__":
    init_database()
