#!/bin/bash
# Automated backup script for autocontable
# Backs up SQLite database + uploaded documents to a local archive
# Designed to run via cron daily

set -euo pipefail

# Configuration (can be overridden via env vars)
DATA_DIR="${DATA_DIR:-/app/data}"
BACKUP_DIR="${BACKUP_DIR:-/app/backups}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="autocontable_backup_${TIMESTAMP}"

# Create backup directory
mkdir -p "${BACKUP_DIR}"

echo "[backup] Starting backup: ${BACKUP_NAME}"

# 1. SQLite safe backup (using .backup command to avoid corruption)
TEMP_DIR=$(mktemp -d)
if [ -f "${DATA_DIR}/accounting.db" ]; then
    sqlite3 "${DATA_DIR}/accounting.db" ".backup '${TEMP_DIR}/accounting.db'"
    echo "[backup] Database backed up"
else
    echo "[backup] WARNING: No database found at ${DATA_DIR}/accounting.db"
fi

# 2. Copy uploads directory
if [ -d "${DATA_DIR}/uploads" ]; then
    cp -r "${DATA_DIR}/uploads" "${TEMP_DIR}/uploads"
    echo "[backup] Uploads backed up ($(du -sh ${TEMP_DIR}/uploads | cut -f1))"
fi

# 3. Copy exports directory if exists
if [ -d "${DATA_DIR}/exports" ]; then
    cp -r "${DATA_DIR}/exports" "${TEMP_DIR}/exports"
fi

# 4. Create compressed archive
tar -czf "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" -C "${TEMP_DIR}" .
BACKUP_SIZE=$(du -sh "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" | cut -f1)
echo "[backup] Archive created: ${BACKUP_NAME}.tar.gz (${BACKUP_SIZE})"

# 5. Cleanup temp
rm -rf "${TEMP_DIR}"

# 6. Retention: remove backups older than RETENTION_DAYS
DELETED=$(find "${BACKUP_DIR}" -name "autocontable_backup_*.tar.gz" -mtime +${RETENTION_DAYS} -delete -print | wc -l)
if [ "${DELETED}" -gt 0 ]; then
    echo "[backup] Cleaned ${DELETED} old backup(s) (retention: ${RETENTION_DAYS} days)"
fi

# 7. List current backups
TOTAL_BACKUPS=$(ls -1 "${BACKUP_DIR}"/autocontable_backup_*.tar.gz 2>/dev/null | wc -l)
TOTAL_SIZE=$(du -sh "${BACKUP_DIR}" | cut -f1)
echo "[backup] Done. ${TOTAL_BACKUPS} backup(s) stored, total: ${TOTAL_SIZE}"
