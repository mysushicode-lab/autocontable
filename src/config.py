"""
Centralized environment loading.

Import this module FIRST in any entry point (main.py, scheduler, etc.)
to guarantee .env and .env.local are loaded before any other module reads os.getenv().
"""
import os
from pathlib import Path
from dotenv import load_dotenv

PROJECT_ROOT = Path(__file__).resolve().parent.parent

_env_file = PROJECT_ROOT / '.env'
_env_local = PROJECT_ROOT / '.env.local'

load_dotenv(_env_file, override=False)
load_dotenv(_env_local, override=True)
