#!/bin/bash
# =============================================================================
# s2_full_model.sh -- Full ChromBPNet model training
#
# Trains the full ChromBPNet model using the bias model from s1.
#
# REQUIRED ENV VARS: SAMPLE_NAME, BIGWIG_FILE, PEAKS_FILE, FOLD
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/config.sh"

if [[ -d "${FULL_MODEL_DIR}" ]]; then
    echo "[CLEANUP] Removing stale full_model output: ${FULL_MODEL_DIR}"
    rm -rf "${FULL_MODEL_DIR}"
fi
mkdir -p "${FULL_MODEL_DIR}"

echo "============================================================"
echo "ChromBPNet Full Model -- Fold ${FOLD}"
echo "Sample:     ${SAMPLE_NAME}"
echo "Bias model: ${BIAS_MODEL_H5}"
echo "Output:     ${FULL_MODEL_DIR}"
echo "Started:    $(date)"
echo "============================================================"
echo ""

if [[ ! -f "${BIAS_MODEL_H5}" ]]; then
    echo "ERROR: Bias model not found: ${BIAS_MODEL_H5}"
    echo "  -> Run s1_bias_model.sh for fold ${FOLD} first."
    exit 1
fi

NEGATIVES="${NEGATIVES_BED}"
[[ ! -f "${NEGATIVES}" ]] && NEGATIVES="${FOLD_DIR}/${SAMPLE_NAME}_output_negatives.bed"
SPLITS_JSON="${SPLITS_DIR}/${SAMPLE_NAME}_fold_${FOLD}.json"

for f in "${BIGWIG_FILE}" "${PEAKS_FILTERED}" "${NEGATIVES}" "${SPLITS_JSON}" "${GENOME_FA}" "${CHROM_SIZES}"; do
    if [[ ! -f "${f}" ]]; then echo "ERROR: Not found: ${f}"; exit 1; fi
done
echo "[OK] All input files validated."
echo ""

source "${CONDA_INIT}"
conda activate "${ENV_CHROMBPNET}"
module load cudnn/8.1.0-cuda11.2 2>/dev/null || true

echo "[Running] Training full ChromBPNet model..."
chrombpnet pipeline \
    -ibw "${BIGWIG_FILE}" \
    -d   "${DATA_TYPE}" \
    -g   "${GENOME_FA}" \
    -c   "${CHROM_SIZES}" \
    -p   "${PEAKS_FILTERED}" \
    -n   "${NEGATIVES}" \
    -fl  "${SPLITS_JSON}" \
    -b   "${BIAS_MODEL_H5}" \
    -o   "${FULL_MODEL_DIR}" \
    -fp  "${SAMPLE_NAME}" \
    --filters "${FILTERS}" \
    --n-dilation-layers "${LAYERS}" \
    --learning-rate "${LEARNING_RATE}" \
    --batch-size "${BATCH_SIZE}" \
    --epochs "${EPOCHS}"

echo ""
echo "============================================================"
echo "Full model done! -- Fold ${FOLD} -- $(date)"
echo "Nobias model: ${NOBIAS_MODEL_H5}"
echo "============================================================"
