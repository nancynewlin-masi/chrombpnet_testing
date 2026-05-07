#!/bin/bash
# =============================================================================
# s1_bias_model.sh -- Chromosome splits, nonpeaks, and bias model training
#
# Run after s0_preprocessing.sh. Trains the ChromBPNet bias model for one fold.
#
# REQUIRED ENV VARS: SAMPLE_NAME, BIGWIG_FILE, PEAKS_FILE, FOLD
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/config.sh"

if [[ -d "${BIAS_MODEL_DIR}" ]]; then
    echo "[CLEANUP] Removing stale bias_model output: ${BIAS_MODEL_DIR}"
    rm -rf "${BIAS_MODEL_DIR}"
fi
AUX_DIR="${FOLD_DIR}/${SAMPLE_NAME}_output_auxiliary"
[[ -d "${AUX_DIR}" ]] && rm -rf "${AUX_DIR}"

mkdir -p "${SPLITS_DIR}" "${BIAS_MODEL_DIR}"

echo "============================================================"
echo "ChromBPNet Bias Model -- Fold ${FOLD}"
echo "Sample:  ${SAMPLE_NAME}"
echo "Bigwig:  ${BIGWIG_FILE}"
echo "Peaks:   ${PEAKS_FILTERED}"
echo "Output:  ${FOLD_DIR}"
echo "Started: $(date)"
echo "============================================================"
echo ""

for f in "${BIGWIG_FILE}" "${PEAKS_FILTERED}" "${CHROM_SIZES_MAIN}" "${GENOME_FA}" "${CHROM_SIZES}" "${BLACKLIST}"; do
    if [[ ! -f "${f}" ]]; then
        echo "ERROR: Not found: ${f}"
        [[ "${f}" == "${PEAKS_FILTERED}" || "${f}" == "${CHROM_SIZES_MAIN}" ]] && \
            echo "  -> Run s0_preprocessing.sh first."
        exit 1
    fi
done
echo "[OK] All input files validated."
echo ""

source "${CONDA_INIT}"
conda activate "${ENV_CHROMBPNET}"
module load cudnn/8.1.0-cuda11.2 2>/dev/null || true

echo "[1/3] Preparing chromosome splits (fold_${FOLD})..."
echo "  Test:  ${TEST_CHROMS}"
echo "  Val:   ${VAL_CHROMS}"

chrombpnet prep splits \
    -c "${CHROM_SIZES_MAIN}" \
    -tcr ${TEST_CHROMS} \
    -vcr ${VAL_CHROMS} \
    -op "${SPLITS_DIR}/${SAMPLE_NAME}_fold_${FOLD}"
echo ""

echo "[2/3] Generating non-peak regions..."
chrombpnet prep nonpeaks \
    -g "${GENOME_FA}" \
    -c "${CHROM_SIZES}" \
    -p "${PEAKS_FILTERED}" \
    -fl "${SPLITS_DIR}/${SAMPLE_NAME}_fold_${FOLD}.json" \
    -br "${BLACKLIST}" \
    -o "${FOLD_DIR}/${SAMPLE_NAME}_output"

NONPEAKS_RAW="${FOLD_DIR}/${SAMPLE_NAME}_output_negatives.bed"
if [[ -f "${NONPEAKS_RAW}" ]]; then
    mv "${NONPEAKS_RAW}" "${NEGATIVES_BED}"
    echo "  Written: ${NEGATIVES_BED}  ($(wc -l < "${NEGATIVES_BED}") regions)"
else
    NEGATIVES_BED="${NONPEAKS_RAW}"
fi
echo ""

echo "[3/3] Training bias model..."
chrombpnet bias pipeline \
    -ibw "${BIGWIG_FILE}" \
    -d   "${DATA_TYPE}" \
    -g   "${GENOME_FA}" \
    -c   "${CHROM_SIZES}" \
    -p   "${PEAKS_FILTERED}" \
    -n   "${NEGATIVES_BED}" \
    -fl  "${SPLITS_DIR}/${SAMPLE_NAME}_fold_${FOLD}.json" \
    -b   "${BIAS_WEIGHT}" \
    -o   "${BIAS_MODEL_DIR}" \
    -fp  "${SAMPLE_NAME}"

echo ""
echo "============================================================"
echo "Bias model done! -- Fold ${FOLD} -- $(date)"
echo "Model: ${BIAS_MODEL_H5}"
echo "============================================================"
