"""Rate limiting setup using slowapi.

Reference: https://slowapi.readthedocs.io/
"""
from slowapi import Limiter
from slowapi.util import get_remote_address

# Single shared limiter instance. The key function uses the client's IP.
# In a multi-instance / behind-proxy deployment, ensure your reverse proxy
# sets X-Forwarded-For and use a custom key function if needed.
limiter = Limiter(key_func=get_remote_address)
