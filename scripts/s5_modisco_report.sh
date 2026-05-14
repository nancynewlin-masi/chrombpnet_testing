#!/bin/bash
# =============================================================================
# s5_modisco_report.sh -- MoDISco HTML report and MEME export
#
# REQUIRED ENV VARS: SAMPLE_NAME, FOLD
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/config.sh"

MODISCO_H5="${MODISCO_DIR}/modisco_results_counts_scores.h5"
REPORT_DIR="${MODISCO_DIR}/modisco_report"
OUTPUT_MEME="${MODISCO_DIR}/modisco_motifs.meme.txt"

mkdir -p "${REPORT_DIR}"

echo "============================================================"
echo "MoDISco Report -- Fold ${FOLD}"
echo "Sample:  ${SAMPLE_NAME}"
echo "Input:   ${MODISCO_H5}"
echo "Report:  ${REPORT_DIR}"
echo "Started: $(date)"
echo "============================================================"
echo ""

if [[ ! -f "${MODISCO_H5}" ]]; then
    echo "ERROR: MoDISco results not found: ${MODISCO_H5}"
    echo "  -> Run s4_modisco_motifs.sh for fold ${FOLD} first."
    exit 1
fi
echo "[OK] Input validated."
echo ""

# HPC: Change source to eval to load conda
#source "${CONDA_INIT}"
eval "$(conda shell.bash hook)"
conda activate "${ENV_CHROMBPNET}"
export LD_LIBRARY_PATH="${CONDA_PREFIX}/lib:${LD_LIBRARY_PATH:-}"

echo "[1/2] Generating HTML report..."
if [[ -f "${MEME_DB}" ]]; then
    modisco report \
        -i "${MODISCO_H5}" \
        -o "${REPORT_DIR}" \
        -s "./" \
        -m "${MEME_DB}" \
        -n "${MODISCO_TOP_MATCHES}"
    echo "  Report: ${REPORT_DIR}/report.html"
else
    echo "  [SKIP] MEME database not found: ${MEME_DB}"
fi
echo ""

echo "[2/2] Exporting motifs to MEME format..."
modisco meme \
    -i "${MODISCO_H5}" \
    -t PFM \
    -o "${OUTPUT_MEME}"
echo "  Output: ${OUTPUT_MEME}"
echo ""

echo "============================================================"
echo "MoDISco report done! -- Fold ${FOLD} -- $(date)"
echo "============================================================"
