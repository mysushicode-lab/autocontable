#!/usr/bin/env python3
"""Quick test to verify WhatsApp routes are registered."""
import sys
sys.path.insert(0, '.')

try:
    from src.api.main import app
    
    routes = []
    for route in app.routes:
        if hasattr(route, 'path') and 'whatsapp' in route.path.lower():
            methods = getattr(route, 'methods', [])
            routes.append(f"{', '.join(methods):10} {route.path}")
    
    if routes:
        print("✓ WhatsApp routes registered:")
        for r in routes:
            print(f"  {r}")
    else:
        print("✗ No WhatsApp routes found")
        sys.exit(1)
        
except Exception as e:
    print(f"✗ Error loading app: {e}")
    sys.exit(1)
