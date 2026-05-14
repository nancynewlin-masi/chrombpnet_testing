#!/bin/bash
# =============================================================================
# s4_modisco_motifs.sh -- TF-MoDISco motif discovery
#
# REQUIRED ENV VARS: SAMPLE_NAME, FOLD
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/config.sh"

mkdir -p "${MODISCO_DIR}"

MODISCO_H5="${MODISCO_DIR}/modisco_results_counts_scores.h5"

echo "============================================================"
echo "TF-MoDISco -- Fold ${FOLD}"
echo "Sample:   ${SAMPLE_NAME}"
echo "Input:    ${CONTRIB_H5}"
echo "Output:   ${MODISCO_H5}"
echo "Seqlets:  ${MODISCO_SEQLETS}"
echo "Leiden:   ${MODISCO_LEIDEN}"
echo "Started:  $(date)"
echo "============================================================"
echo ""

if [[ ! -f "${CONTRIB_H5}" ]]; then
    echo "ERROR: Contribution scores not found: ${CONTRIB_H5}"
    echo "  -> Run s3_contributions.sh for fold ${FOLD} first."
    exit 1
fi
echo "[OK] Input validated."
echo ""

# HPC: Change source to eval to load conda
#source "${CONDA_INIT}"
eval "$(conda shell.bash hook)"
conda activate "${ENV_CHROMBPNET}"

modisco motifs \
    -i "${CONTRIB_H5}" \
    -n "${MODISCO_SEQLETS}" \
    -l "${MODISCO_LEIDEN}" \
    -o "${MODISCO_H5}"

echo ""
echo "============================================================"
echo "MoDISco done! -- Fold ${FOLD} -- $(date)"
echo "Output: ${MODISCO_H5}"
echo "============================================================"
