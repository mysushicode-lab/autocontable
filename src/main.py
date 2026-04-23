"""
Main entry point for invoice processing system
"""
import sys
import os

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from src.storage.database import init_database


def main():
    """Initialize and run the system"""
    print("Initializing Invoice Processing & Bank Reconciliation System...")
    
    # Initialize database
    init_database()
    
    print("System initialized successfully!")
    print("\nNext steps:")
    print("1. Edit config/.env with your email credentials")
    print("2. Run: python -m src.scheduler.main (for automated processing)")
    print("3. Run: uvicorn src.api.main:app --reload (for API server)")


if __name__ == "__main__":
    main()
