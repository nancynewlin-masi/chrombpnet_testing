#!/bin/bash
# =============================================================================
# config.sh -- Shared configuration for ChromBPNet pipeline (D14 samples)
#
# Sourced by all step scripts. Requires SAMPLE_NAME to be set.
# FOLD is required for fold-specific steps (s1–s5).
#
# Override any variable by exporting it before sourcing this file.
# =============================================================================

SAMPLE_NAME="${SAMPLE_NAME:?ERROR: SAMPLE_NAME not set.}"

CHROMBPNET_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# =============================================================================
# Reference files (mouse GRCm38/mm10)
#
# Defaults point to the lab-shared copy under references/mm10/ (kept outside
# git; see README). Override any path by exporting before sourcing.
# =============================================================================
REFERENCES_DIR="${REFERENCES_DIR:-${CHROMBPNET_DIR}/references/mm10}"
GENOME_FA="${GENOME_FA:-${REFERENCES_DIR}/GRCm38.primary_assembly.genome.fa}"
CHROM_SIZES="${CHROM_SIZES:-${REFERENCES_DIR}/genome.chromosome-sizes.txt}"
BLACKLIST="${BLACKLIST:-${REFERENCES_DIR}/mm10.blacklist.bed}"
MEME_DB="${MEME_DB:-${REFERENCES_DIR}/motifs.meme.txt}"

# =============================================================================
# Output directories
# =============================================================================
LOG_DIR="${CHROMBPNET_DIR}/logs"
RESULTS_DIR="${CHROMBPNET_DIR}/results"
SLURM_DIR="${CHROMBPNET_DIR}/slurm_jobs"
SUBMITTED_DIR="${CHROMBPNET_DIR}/submitted_jobs"
REPORTS_DIR="${CHROMBPNET_DIR}/reports"

# =============================================================================
# Conda envs (resolved by name against the user's own conda installation).
# Override any of these by exporting before running submit_pipeline.sh.
# =============================================================================
CONDA_INIT="${CONDA_INIT:-${HOME}/miniconda3/etc/profile.d/conda.sh}"
ENV_CHROMBPNET="${ENV_CHROMBPNET:-chrombpnet}"   # built by install_chrombpnet.sh
ENV_BEDTOOLS="${ENV_BEDTOOLS:-${ENV_CHROMBPNET}}" # bedtools is included in chrombpnet

# =============================================================================
# ChromBPNet hyperparameters
# =============================================================================
FILTERS="${FILTERS:-1024}"
LAYERS="${LAYERS:-8}"
LEARNING_RATE="${LEARNING_RATE:-0.001}"
BATCH_SIZE="${BATCH_SIZE:-128}"
EPOCHS="${EPOCHS:-50}"
BIAS_WEIGHT="${BIAS_WEIGHT:-0.5}"
DATA_TYPE="${DATA_TYPE:-ATAC}"
INPUT_LENGTH="${INPUT_LENGTH:-2114}"

# =============================================================================
# Cross-validation: 5 folds for mouse genome (mm10)
# =============================================================================
NUM_FOLDS="${NUM_FOLDS:-5}"

declare -a FOLD_TEST_CHROMS FOLD_VAL_CHROMS

FOLD_TEST_CHROMS[0]="chr1 chr3 chr6"
FOLD_TEST_CHROMS[1]="chr2 chr8 chr17"
FOLD_TEST_CHROMS[2]="chr5 chr9 chr11"
FOLD_TEST_CHROMS[3]="chr4 chr10 chr18"
FOLD_TEST_CHROMS[4]="chr5 chr15 chr12"

FOLD_VAL_CHROMS[0]="chr8 chr19"
FOLD_VAL_CHROMS[1]="chr5 chr10 chr18"
FOLD_VAL_CHROMS[2]="chr12 chr14"
FOLD_VAL_CHROMS[3]="chr2 chr7"
FOLD_VAL_CHROMS[4]="chr3 chr6"

# =============================================================================
# MoDISco parameters
# =============================================================================
MODISCO_SEQLETS="${MODISCO_SEQLETS:-1000000}"
MODISCO_LEIDEN="${MODISCO_LEIDEN:-2}"
MODISCO_TOP_MATCHES="${MODISCO_TOP_MATCHES:-10}"

# =============================================================================
# SLURM defaults
# =============================================================================
PARTITION="${PARTITION:-peerd}"
SLURM_GRES="${SLURM_GRES:-gpu:a100:1}"
SLURM_CPUS="${SLURM_CPUS:-4}"
SLURM_MEM="${SLURM_MEM:-160G}"
SLURM_TIME="${SLURM_TIME:-100:00:00}"

# =============================================================================
# Derived paths
# =============================================================================
SAMPLE_DIR="${RESULTS_DIR}/${SAMPLE_NAME}"
PEAKS_FILTERED="${SAMPLE_DIR}/peaks_no_blacklist.bed"
PEAKS_CENTERED="${SAMPLE_DIR}/peaks_centered.bed"
CHROM_SIZES_MAIN="${SAMPLE_DIR}/main_chroms.sizes"

if [[ -n "${FOLD:-}" ]]; then
    TEST_CHROMS="${FOLD_TEST_CHROMS[${FOLD}]}"
    VAL_CHROMS="${FOLD_VAL_CHROMS[${FOLD}]}"
    FOLD_DIR="${SAMPLE_DIR}/fold_${FOLD}"
    SPLITS_DIR="${FOLD_DIR}/splits"
    NEGATIVES_BED="${FOLD_DIR}/${SAMPLE_NAME}_negatives.bed"
    BIAS_MODEL_DIR="${FOLD_DIR}/bias_model"
    BIAS_MODEL_H5="${BIAS_MODEL_DIR}/models/${SAMPLE_NAME}_bias.h5"
    FULL_MODEL_DIR="${FOLD_DIR}/full_model"
    NOBIAS_MODEL_H5="${FULL_MODEL_DIR}/models/${SAMPLE_NAME}_chrombpnet_nobias.h5"
    CONTRIB_PREFIX="${FOLD_DIR}/contributions"
    CONTRIB_H5="${CONTRIB_PREFIX}.counts_scores.h5"
    MODISCO_DIR="${FOLD_DIR}/modisco"
fi
