#!/bin/bash
# =============================================================================
# s0_preprocessing.sh -- Peak filtering and chromosome preparation
#
# Filters peaks against the blacklist and creates a main-chromosome sizes file.
# Run ONCE per sample before submitting fold-specific jobs.
#
# REQUIRED ENV VARS (set by submit_pipeline.sh):
#   SAMPLE_NAME, BIGWIG_FILE, PEAKS_FILE
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/config.sh"

mkdir -p "${SAMPLE_DIR}"

echo "============================================================"
echo "ChromBPNet Preprocessing"
echo "Sample:  ${SAMPLE_NAME}"
echo "Bigwig:  ${BIGWIG_FILE}"
echo "Peaks:   ${PEAKS_FILE}"
echo "Output:  ${SAMPLE_DIR}"
echo "Started: $(date)"
echo "============================================================"
echo ""

for f in "${BIGWIG_FILE}" "${PEAKS_FILE}" "${GENOME_FA}" "${CHROM_SIZES}" "${BLACKLIST}"; do
    if [[ ! -f "${f}" ]]; then echo "ERROR: Not found: ${f}"; exit 1; fi
done
echo "[OK] All input files validated."
echo ""

echo "[1/3] Creating main-chromosome sizes..."
grep -E '^chr[0-9]+\b|^chrX\b|^chrY\b' "${CHROM_SIZES}" > "${CHROM_SIZES_MAIN}"
echo "  Written: ${CHROM_SIZES_MAIN}  ($(wc -l < "${CHROM_SIZES_MAIN}") chromosomes)"
echo ""

echo "[2/3] Filtering peaks against blacklist..."
source "${CONDA_INIT}"
conda activate "${ENV_BEDTOOLS}"

bedtools intersect -v \
    -a "${PEAKS_FILE}" \
    -b "${BLACKLIST}" \
    > "${PEAKS_FILTERED}"

echo "  Before: $(zcat -f "${PEAKS_FILE}" | wc -l)  After: $(wc -l < "${PEAKS_FILTERED}")"
echo "  Written: ${PEAKS_FILTERED}"
echo ""

echo "[3/3] Centering peaks on summit (1000bp regions)..."
conda activate "${ENV_CHROMBPNET}"

python "${SCRIPT_DIR}/scripts/center_peaks.py" \
    "${PEAKS_FILTERED}" \
    "${PEAKS_CENTERED}"

echo "  Centered peaks: $(wc -l < "${PEAKS_CENTERED}")"
echo "  Written: ${PEAKS_CENTERED}"
echo ""

echo "============================================================"
echo "Preprocessing done! -- $(date)"
echo "Next: submit s1 (bias model) for each fold."
echo "============================================================"
