#!/usr/bin/env python3

def anonymize_large_text(value):
    """Test function that returns a large string (>33 characters)"""
    # Create a large YAML-like string that's much bigger than SHA256_DIGEST_SIZE
    return """
---
config:
  database:
    host: anonymized.example.com
    port: 5432
    username: anon_user
    password: REDACTED_PASSWORD_HASH_1234567890ABCDEF
    connection_pool:
      min_size: 5
      max_size: 20
      timeout: 30
  cache:
    type: redis
    host: cache-anonymized.example.com
    port: 6379
    ttl: 3600
  logging:
    level: INFO
    file: /var/log/anonymized/app.log
    max_size: 104857600
    backup_count: 10
  features:
    - feature_anonymized_1
    - feature_anonymized_2
    - feature_anonymized_3
    - feature_anonymized_4
    - feature_anonymized_5
  metadata:
    created_by: ANONYMIZED_USER
    created_at: 2025-01-01T00:00:00Z
    last_modified: 2025-01-01T00:00:00Z
    version: 1.0.0-anonymized
    environment: production-anonymized
---
    """.strip()

def test_exactly_33_chars(value):
    """Test function that returns exactly 33 characters (boundary condition)"""
    return "A" * 33

def test_exactly_32_chars(value):
    """Test function that returns exactly 32 characters (just under boundary)"""
    return "B" * 32

def test_empty(value):
    """Test function that returns empty string"""
    return ""

def test_one_char(value):
    """Test function that returns single character"""
    return "X"
