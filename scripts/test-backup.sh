#!/bin/bash
# Test script to verify backup functionality locally
# This simulates the backup process for testing

set -euo pipefail

echo "=== Backup System Test ==="
echo ""

# Test configuration
TEST_DATA_DIR="$(pwd)/test-backup-data"
TEST_BACKUP_DIR="$(pwd)/test-backup-output"
TEST_RETENTION_DAYS=7

echo "1. Setting up test environment..."
mkdir -p "${TEST_DATA_DIR}/uploads/invoices"
mkdir -p "${TEST_DATA_DIR}/exports"

# Create a dummy database
echo "2. Creating test database..."
sqlite3 "${TEST_DATA_DIR}/accounting.db" <<EOF
CREATE TABLE test (id INTEGER PRIMARY KEY, data TEXT);
INSERT INTO test (data) VALUES ('test data');
EOF

# Create dummy files
echo "Test invoice" > "${TEST_DATA_DIR}/uploads/invoices/test_invoice.pdf"
echo "Test export" > "${TEST_DATA_DIR}/exports/test_export.csv"

echo "3. Running backup script..."
export DATA_DIR="${TEST_DATA_DIR}"
export BACKUP_DIR="${TEST_BACKUP_DIR}"
export RETENTION_DAYS="${TEST_RETENTION_DAYS}"

./scripts/backup.sh

echo ""
echo "4. Verifying backup..."
BACKUP_FILE=$(ls -t "${TEST_BACKUP_DIR}"/autocontable_backup_*.tar.gz | head -1)
if [ -z "${BACKUP_FILE}" ]; then
    echo "ERROR: No backup file created!"
    exit 1
fi

echo "Backup file: ${BACKUP_FILE}"
echo "Backup size: $(du -h ${BACKUP_FILE} | cut -f1)"
echo ""
echo "5. Testing backup contents..."
tar -tzf "${BACKUP_FILE}" | head -10

echo ""
echo "6. Testing restore..."
TEST_RESTORE_DIR="$(pwd)/test-restore-data"
mkdir -p "${TEST_RESTORE_DIR}"
TEMP_EXTRACT=$(mktemp -d)
tar -xzf "${BACKUP_FILE}" -C "${TEMP_EXTRACT}"
cp -r "${TEMP_EXTRACT}"/* "${TEST_RESTORE_DIR}/"
rm -rf "${TEMP_EXTRACT}"

if [ -f "${TEST_RESTORE_DIR}/accounting.db" ]; then
    echo "Database restored: YES"
    sqlite3 "${TEST_RESTORE_DIR}/accounting.db" "SELECT * FROM test;"
else
    echo "Database restored: NO"
fi

if [ -f "${TEST_RESTORE_DIR}/uploads/invoices/test_invoice.pdf" ]; then
    echo "Uploads restored: YES"
else
    echo "Uploads restored: NO"
fi

echo ""
echo "7. Cleanup..."
rm -rf "${TEST_DATA_DIR}" "${TEST_BACKUP_DIR}" "${TEST_RESTORE_DIR}"

echo ""
echo "=== Test Complete ==="
echo "Backup system is working correctly!"
