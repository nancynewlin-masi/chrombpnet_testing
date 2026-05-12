#!/bin/bash
# =============================================================================
# submit_pipeline.sh -- Submit ChromBPNet pipeline (s0–s5) via SLURM
#
# PIPELINE STEPS:
#   s0  Preprocessing        (once per sample)
#   s1  Bias model           (per fold)
#   s2  Full model           (per fold)
#   s3  Contribution scores  (per fold)
#   s4  MoDISco motifs       (per fold)
#   s5  MoDISco reports      (per fold) ← final step
#
# SAMPLES (pre-configured):
#   D14_Ctrl_merged_new
#   D14_L_merged_new
#   D14_NL_merged_new
#
# USAGE:
#   bash submit_pipeline.sh --name D14_Ctrl_merged_new
#   bash submit_pipeline.sh --name D14_Ctrl_merged_new --step s2 --fold 1
#   bash submit_pipeline.sh --name D14_Ctrl_merged_new --dry-run
#
# OPTIONAL FLAGS:
#   --step STEP        Run only this step (default: all = s0..s5)
#   --fold N           Run only fold N (default: all folds)
#   --dry-run          Preview jobs without submitting
#   --filters N        Convolutional filters      (default: 1024)
#   --layers  N        Dilated conv layers         (default: 8)
#   --lr      FLOAT    Learning rate               (default: 0.001)
#   --batch-size N     Batch size                  (default: 128)
#   --epochs  N        Epochs                      (default: 50)
#   --nfolds  N        Number of folds             (default: 5)
#   --genome PATH      Override genome FASTA
#   --chrom-sizes PATH Override chromosome sizes
#   --blacklist PATH   Override blacklist BED
#   --bigwig PATH      Override bigwig (auto-detected from --name)
#   --peaks PATH       Override peaks  (auto-detected from --name)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORIG_CMD="bash submit_pipeline.sh $*"

# =============================================================================
# Sample → input file mapping
#
# Bigwigs and peaks live outside the repo (too large for GitHub). TEST_DATA_DIR
# defaults to the lab-shared location below; override with the TEST_DATA_DIR
# env var if your copy is elsewhere.
# =============================================================================
TEST_DATA_DIR="${TEST_DATA_DIR:-/data1/collab002/sail/shared/projects/peer-lab/chrombpnet_luis/test_data}"

declare -A SAMPLE_BIGWIG SAMPLE_PEAKS
SAMPLE_BIGWIG[D14_Ctrl_merged_new]="${TEST_DATA_DIR}/bigwig/D14_Ctrl_merged_cutsites.bw"
SAMPLE_PEAKS[D14_Ctrl_merged_new]="${TEST_DATA_DIR}/macs3_peaks/D14_Ctrl_merged_peaks.narrowPeak"

SAMPLE_BIGWIG[D14_L_merged_new]="${TEST_DATA_DIR}/bigwig/D14_L_merged_cutsites.bw"
SAMPLE_PEAKS[D14_L_merged_new]="${TEST_DATA_DIR}/macs3_peaks/D14_L_merged_peaks.narrowPeak"

SAMPLE_BIGWIG[D14_NL_merged_new]="${TEST_DATA_DIR}/bigwig/D14_NL_merged_cutsites.bw"
SAMPLE_PEAKS[D14_NL_merged_new]="${TEST_DATA_DIR}/macs3_peaks/D14_NL_merged_peaks.narrowPeak"

# =============================================================================
# Parse arguments
# =============================================================================
DRY_RUN=false
CLI_NAME=""
CLI_STEP="all"
CLI_FOLD=""
CLI_BIGWIG=""
CLI_PEAKS=""

OVR_FILTERS="" OVR_LAYERS="" OVR_LR="" OVR_BATCH_SIZE="" OVR_EPOCHS=""
OVR_NFOLDS="" OVR_GENOME="" OVR_CHROM_SIZES="" OVR_BLACKLIST=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)       DRY_RUN=true;          shift ;;
        --name)          CLI_NAME="$2";         shift 2 ;;
        --step)          CLI_STEP="$2";         shift 2 ;;
        --fold)          CLI_FOLD="$2";         shift 2 ;;
        --bigwig)        CLI_BIGWIG="$2";       shift 2 ;;
        --peaks)         CLI_PEAKS="$2";        shift 2 ;;
        --filters)       OVR_FILTERS="$2";      shift 2 ;;
        --layers)        OVR_LAYERS="$2";       shift 2 ;;
        --lr)            OVR_LR="$2";           shift 2 ;;
        --batch-size)    OVR_BATCH_SIZE="$2";   shift 2 ;;
        --epochs)        OVR_EPOCHS="$2";       shift 2 ;;
        --nfolds)        OVR_NFOLDS="$2";       shift 2 ;;
        --genome)        OVR_GENOME="$2";       shift 2 ;;
        --chrom-sizes)   OVR_CHROM_SIZES="$2";  shift 2 ;;
        --blacklist)     OVR_BLACKLIST="$2";    shift 2 ;;
        -h|--help)
            head -40 "$0" | grep '^#' | sed 's/^# \?//'; exit 0 ;;
        *)
            echo "ERROR: Unknown option: $1. Use --help."; exit 1 ;;
    esac
done

if [[ -z "${CLI_NAME}" ]]; then
    echo "ERROR: --name is required.  Known samples:"
    for s in "${!SAMPLE_BIGWIG[@]}"; do echo "  $s"; done
    exit 1
fi

# Resolve input files (CLI override takes precedence over auto-map)
if [[ -z "${CLI_BIGWIG}" ]]; then
    CLI_BIGWIG="${SAMPLE_BIGWIG[${CLI_NAME}]:-}"
    if [[ -z "${CLI_BIGWIG}" ]]; then
        echo "ERROR: No bigwig registered for '${CLI_NAME}'. Use --bigwig to specify."
        exit 1
    fi
fi

if [[ -z "${CLI_PEAKS}" ]]; then
    CLI_PEAKS="${SAMPLE_PEAKS[${CLI_NAME}]:-}"
    if [[ -z "${CLI_PEAKS}" ]]; then
        echo "ERROR: No peaks registered for '${CLI_NAME}'. Use --peaks to specify."
        exit 1
    fi
fi

for f in "${CLI_BIGWIG}" "${CLI_PEAKS}"; do
    if [[ ! -f "${f}" ]]; then echo "ERROR: File not found: ${f}"; exit 1; fi
done
CLI_BIGWIG="$(realpath "${CLI_BIGWIG}")"
CLI_PEAKS="$(realpath "${CLI_PEAKS}")"

# Validate step
VALID_STEPS=("s0" "s1" "s2" "s3" "s4" "s5" "all")
step_valid=false
for vs in "${VALID_STEPS[@]}"; do
    if [[ "${CLI_STEP}" == "${vs}" ]]; then step_valid=true; fi
done
if ! ${step_valid}; then
    echo "ERROR: Invalid step '${CLI_STEP}'. Valid: ${VALID_STEPS[*]}"; exit 1
fi

# Source config for defaults
export SAMPLE_NAME="${CLI_NAME}"
source "${SCRIPT_DIR}/config.sh"

if [[ -n "${OVR_FILTERS}" ]];     then FILTERS="${OVR_FILTERS}"; fi
if [[ -n "${OVR_LAYERS}" ]];      then LAYERS="${OVR_LAYERS}"; fi
if [[ -n "${OVR_LR}" ]];          then LEARNING_RATE="${OVR_LR}"; fi
if [[ -n "${OVR_BATCH_SIZE}" ]];  then BATCH_SIZE="${OVR_BATCH_SIZE}"; fi
if [[ -n "${OVR_EPOCHS}" ]];      then EPOCHS="${OVR_EPOCHS}"; fi
if [[ -n "${OVR_NFOLDS}" ]];      then NUM_FOLDS="${OVR_NFOLDS}"; fi
if [[ -n "${OVR_GENOME}" ]];      then GENOME_FA="${OVR_GENOME}"; fi
if [[ -n "${OVR_CHROM_SIZES}" ]]; then CHROM_SIZES="${OVR_CHROM_SIZES}"; fi
if [[ -n "${OVR_BLACKLIST}" ]];   then BLACKLIST="${OVR_BLACKLIST}"; fi

# Folds
declare -a FOLDS=()
if [[ -n "${CLI_FOLD}" ]]; then
    (( CLI_FOLD >= 0 && CLI_FOLD < NUM_FOLDS )) || \
        { echo "ERROR: Fold ${CLI_FOLD} out of range (0–$((NUM_FOLDS-1)))"; exit 1; }
    FOLDS=("${CLI_FOLD}")
else
    for ((f=0; f<NUM_FOLDS; f++)); do FOLDS+=("${f}"); done
fi

# Steps
declare -a STEPS=()
if [[ "${CLI_STEP}" == "all" ]]; then
    STEPS=("s0" "s1" "s2" "s3" "s4" "s5")
else
    STEPS=("${CLI_STEP}")
fi

mkdir -p "${LOG_DIR}" "${RESULTS_DIR}" "${SLURM_DIR}" "${SUBMITTED_DIR}" "${REPORTS_DIR}"

# Hyperparameter overrides block (injected into generated SLURM scripts)
HP_EXPORTS=""
if [[ -n "${OVR_FILTERS}" ]];     then HP_EXPORTS+="export FILTERS=${OVR_FILTERS}"$'\n'; fi
if [[ -n "${OVR_LAYERS}" ]];      then HP_EXPORTS+="export LAYERS=${OVR_LAYERS}"$'\n'; fi
if [[ -n "${OVR_LR}" ]];          then HP_EXPORTS+="export LEARNING_RATE=${OVR_LR}"$'\n'; fi
if [[ -n "${OVR_BATCH_SIZE}" ]];  then HP_EXPORTS+="export BATCH_SIZE=${OVR_BATCH_SIZE}"$'\n'; fi
if [[ -n "${OVR_EPOCHS}" ]];      then HP_EXPORTS+="export EPOCHS=${OVR_EPOCHS}"$'\n'; fi
if [[ -n "${OVR_NFOLDS}" ]];      then HP_EXPORTS+="export NUM_FOLDS=${OVR_NFOLDS}"$'\n'; fi
if [[ -n "${OVR_GENOME}" ]];      then HP_EXPORTS+="export GENOME_FA=\"${OVR_GENOME}\""$'\n'; fi
if [[ -n "${OVR_CHROM_SIZES}" ]]; then HP_EXPORTS+="export CHROM_SIZES=\"${OVR_CHROM_SIZES}\""$'\n'; fi
if [[ -n "${OVR_BLACKLIST}" ]];   then HP_EXPORTS+="export BLACKLIST=\"${OVR_BLACKLIST}\""$'\n'; fi

# =============================================================================
# Step metadata
# =============================================================================
declare -A STEP_SCRIPT STEP_LABEL STEP_GRES STEP_TIME STEP_CPUS STEP_MEM

STEP_SCRIPT[s0]="scripts/s0_preprocessing.sh"
STEP_SCRIPT[s1]="scripts/s1_bias_model.sh"
STEP_SCRIPT[s2]="scripts/s2_full_model.sh"
STEP_SCRIPT[s3]="scripts/s3_contributions.sh"
STEP_SCRIPT[s4]="scripts/s4_modisco_motifs.sh"
STEP_SCRIPT[s5]="scripts/s5_modisco_report.sh"

STEP_LABEL[s0]="Preprocessing"
STEP_LABEL[s1]="Bias model training"
STEP_LABEL[s2]="Full model training"
STEP_LABEL[s3]="Contribution scores"
STEP_LABEL[s4]="MoDISco motifs"
STEP_LABEL[s5]="MoDISco reports"

# Note for HPC team: change resource requests here
STEP_GRES[s0]="gpu:1";          STEP_TIME[s0]="6:00:00";     STEP_CPUS[s0]=2;               STEP_MEM[s0]="16G"
STEP_GRES[s1]="${SLURM_GRES}";  STEP_TIME[s1]="${SLURM_TIME}"; STEP_CPUS[s1]="${SLURM_CPUS}"; STEP_MEM[s1]="${SLURM_MEM}"
STEP_GRES[s2]="${SLURM_GRES}";  STEP_TIME[s2]="${SLURM_TIME}"; STEP_CPUS[s2]="${SLURM_CPUS}"; STEP_MEM[s2]="${SLURM_MEM}"
STEP_GRES[s3]="${SLURM_GRES}";  STEP_TIME[s3]="${SLURM_TIME}"; STEP_CPUS[s3]="${SLURM_CPUS}"; STEP_MEM[s3]="${SLURM_MEM}"
STEP_GRES[s4]="gpu:1";          STEP_TIME[s4]="72:00:00";    STEP_CPUS[s4]="${SLURM_CPUS}"; STEP_MEM[s4]="${SLURM_MEM}"
STEP_GRES[s5]="gpu:1";          STEP_TIME[s5]="4:00:00";     STEP_CPUS[s5]=2;               STEP_MEM[s5]="32G"

# =============================================================================
# Job generation and submission
# =============================================================================
DRY_COUNTER=0
RETURN_JID=""
SUBMISSIONS_LOG="${SUBMITTED_DIR}/submissions.log"

generate_and_submit() {
    local step="$1"
    local fold="${2:-}"
    local dep_jobid="${3:-}"

    local job_name fold_export=""
    if [[ -n "${fold}" ]]; then
        job_name="${step}_${CLI_NAME}_fold_${fold}"
        fold_export="export FOLD=${fold}"
    else
        job_name="${step}_${CLI_NAME}"
    fi

    local TIMESTAMP; TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    local log_prefix="${job_name}_${TIMESTAMP}"
    local script_path="${SLURM_DIR}/${job_name}.sh"

    local gres_line=""
    if [[ -n "${STEP_GRES[${step}]}" ]]; then gres_line="#SBATCH --gres=${STEP_GRES[${step}]}"; fi

    cat > "${script_path}" << SLURM_EOF
#!/bin/bash
#SBATCH --job-name=${job_name}
#SBATCH --output=${LOG_DIR}/${log_prefix}.out
#SBATCH --error=${LOG_DIR}/${log_prefix}.err
#SBATCH --partition=${PARTITION}
${gres_line}
#SBATCH --cpus-per-task=${STEP_CPUS[${step}]}
#SBATCH --ntasks=1
#SBATCH --mem=${STEP_MEM[${step}]}
#SBATCH --time=${STEP_TIME[${step}]}

set -euo pipefail

export SAMPLE_NAME="${CLI_NAME}"
export BIGWIG_FILE="${CLI_BIGWIG}"
export PEAKS_FILE="${CLI_PEAKS}"
${fold_export}
${HP_EXPORTS}
bash "${SCRIPT_DIR}/${STEP_SCRIPT[${step}]}"
SLURM_EOF

    chmod +x "${script_path}"

    if ${DRY_RUN}; then
        DRY_COUNTER=$((DRY_COUNTER + 1))
        RETURN_JID="DRY_${DRY_COUNTER}"
        echo "  [DRY-RUN] ${job_name}"
        echo "    Script: ${script_path}"
        if [[ -n "${dep_jobid}" ]]; then echo "    Depends: ${dep_jobid}"; fi
    else
        local sbatch_cmd="sbatch"
        if [[ -n "${dep_jobid}" ]]; then sbatch_cmd="sbatch --dependency=afterok:${dep_jobid}"; fi
        local result; result=$(${sbatch_cmd} "${script_path}")
        RETURN_JID=$(echo "${result}" | awk '{print $NF}')

        echo "  [SUBMITTED] ${job_name} -> Job ${RETURN_JID}"
        if [[ -n "${dep_jobid}" ]]; then echo "    Depends on: ${dep_jobid}"; fi

        local fold_info="" dep_info=""
        if [[ -n "${fold}" ]];      then fold_info="fold=${fold}"; fi
        if [[ -n "${dep_jobid}" ]]; then dep_info="depends=${dep_jobid}"; fi

        printf '[%s]  job=%-12s  sample=%-25s  step=%-4s  %-8s  %s\n' \
            "$(date '+%Y-%m-%d %H:%M:%S')" \
            "${RETURN_JID}" "${CLI_NAME}" "${step}" "${fold_info}" "${dep_info}" \
            >> "${SUBMISSIONS_LOG}"
        printf '  cmd: %s\n  script: %s\n\n' "${ORIG_CMD}" "${script_path}" \
            >> "${SUBMISSIONS_LOG}"
    fi
}

# =============================================================================
# Submit
# =============================================================================
echo ""
echo "  ChromBPNet Pipeline (s0–s5) -- SLURM Submission"
echo "  ─────────────────────────────────────────────────"
echo "  Sample:    ${CLI_NAME}"
echo "  Bigwig:    ${CLI_BIGWIG}"
echo "  Peaks:     ${CLI_PEAKS}"
echo "  Steps:     ${STEPS[*]}"
echo "  Folds:     ${FOLDS[*]}"
echo "  Partition: ${PARTITION}"
echo "  Params:    filters=${FILTERS} layers=${LAYERS} lr=${LEARNING_RATE} bs=${BATCH_SIZE} epochs=${EPOCHS}"
if ${DRY_RUN}; then echo "  Mode:      DRY RUN"; fi
echo ""

TOTAL=0
declare -A LAST_JOBID

for step in "${STEPS[@]}"; do
    echo "  ── Step ${step}: ${STEP_LABEL[${step}]} ──"
    echo ""

    if [[ "${step}" == "s0" ]]; then
        generate_and_submit "${step}" "" ""
        for fold in "${FOLDS[@]}"; do LAST_JOBID[${fold}]="${RETURN_JID}"; done
        TOTAL=$((TOTAL + 1))

    else
        for fold in "${FOLDS[@]}"; do
            dep="${LAST_JOBID[${fold}]:-}"
            generate_and_submit "${step}" "${fold}" "${dep}"
            LAST_JOBID[${fold}]="${RETURN_JID}"
            TOTAL=$((TOTAL + 1))
        done
    fi
    echo ""
done

echo "  ─────────────────────────────────────────────────"
if ${DRY_RUN}; then
    echo "  Dry run complete. ${TOTAL} jobs would be submitted."
else
    echo "  ${TOTAL} jobs submitted."
    echo "  Log: ${SUBMISSIONS_LOG}"
fi
echo ""
echo "  Monitor:  squeue -u \$USER"
echo "  Logs:     ${LOG_DIR}/"
echo "  Results:  ${RESULTS_DIR}/${CLI_NAME}/"
echo ""
