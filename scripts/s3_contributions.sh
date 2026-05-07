#!/bin/bash
# =============================================================================
# s3_contributions.sh -- Per-base contribution scores from the nobias model
#
# REQUIRED ENV VARS: SAMPLE_NAME, PEAKS_FILE, FOLD
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/config.sh"

echo "============================================================"
echo "ChromBPNet Contribution Scores -- Fold ${FOLD}"
echo "Sample:  ${SAMPLE_NAME}"
echo "Model:   ${NOBIAS_MODEL_H5}"
echo "Peaks:   ${PEAKS_CENTERED}"
echo "Output:  ${CONTRIB_PREFIX}.*"
echo "Started: $(date)"
echo "============================================================"
echo ""

if [[ ! -f "${NOBIAS_MODEL_H5}" ]]; then
    echo "ERROR: Nobias model not found: ${NOBIAS_MODEL_H5}"
    echo "  -> Run s2_full_model.sh for fold ${FOLD} first."
    exit 1
fi

for f in "${PEAKS_CENTERED}" "${GENOME_FA}" "${CHROM_SIZES}"; do
    if [[ ! -f "${f}" ]]; then echo "ERROR: Not found: ${f}"; exit 1; fi
done
echo "[OK] All input files validated."
echo ""

source "${CONDA_INIT}"
conda activate "${ENV_CHROMBPNET}"
module load cudnn/8.1.0-cuda11.2 2>/dev/null || true

echo "[Running] Computing contribution scores..."
chrombpnet contribs_bw \
    -m "${NOBIAS_MODEL_H5}" \
    -r "${PEAKS_CENTERED}" \
    -g "${GENOME_FA}" \
    -c "${CHROM_SIZES}" \
    -op "${CONTRIB_PREFIX}"

echo ""
echo "============================================================"
echo "Contributions done! -- Fold ${FOLD} -- $(date)"
ls -lh "${CONTRIB_PREFIX}."*
echo "============================================================"
