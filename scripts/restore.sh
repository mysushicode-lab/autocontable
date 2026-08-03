#!/bin/bash
# Restore autocontable from a backup archive
# Usage: ./restore.sh /path/to/backup.tar.gz

set -euo pipefail

BACKUP_FILE="${1:-}"
DATA_DIR="${DATA_DIR:-/app/data}"
BACKUP_DIR="${BACKUP_DIR:-/app/backups}"

if [ -z "${BACKUP_FILE}" ]; then
    echo "Usage: $0 <backup_archive.tar.gz>"
    echo ""
    echo "Available backups:"
    ls -lh "${BACKUP_DIR}"/autocontable_backup_*.tar.gz 2>/dev/null || echo "  (none found)"
    exit 1
fi

if [ ! -f "${BACKUP_FILE}" ]; then
    echo "ERROR: Backup file not found: ${BACKUP_FILE}"
    exit 1
fi

echo "[restore] Restoring from: ${BACKUP_FILE}"
echo "[restore] Target: ${DATA_DIR}"
echo ""
read -p "This will OVERWRITE current data. Continue? (yes/no) " CONFIRM
if [ "${CONFIRM}" != "yes" ]; then
    echo "[restore] Aborted."
    exit 0
fi

# Create temp extraction dir
TEMP_DIR=$(mktemp -d)
tar -xzf "${BACKUP_FILE}" -C "${TEMP_DIR}"

# Restore database
echo "[restore] Restoring database..."
if [ -f "${TEMP_DIR}/accounting.db" ]; then
    cp "${TEMP_DIR}/accounting.db" "${DATA_DIR}/accounting.db"
fi

# Restore uploads
echo "[restore] Restoring uploads..."
if [ -d "${TEMP_DIR}/uploads" ]; then
    rm -rf "${DATA_DIR}/uploads"
    cp -r "${TEMP_DIR}/uploads" "${DATA_DIR}/uploads"
fi

# Restore exports if present
if [ -d "${TEMP_DIR}/exports" ]; then
    rm -rf "${DATA_DIR}/exports"
    cp -r "${TEMP_DIR}/exports" "${DATA_DIR}/exports"
fi

rm -rf "${TEMP_DIR}"
echo "[restore] Done. Restart the application to use restored data."
