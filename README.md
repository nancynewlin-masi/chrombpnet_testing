# This fork
Fork for HPC Team to iterate on 
HPC Team: Nancy, Erica, Jamie, Lohit

# ChromBPNet Pipeline — D14 ATAC samples

5-fold cross-validation ChromBPNet pipeline for three D14 ATAC samples. Trains
bias and full models, computes contribution scores, runs TF-MoDISco motif
discovery, and exports motifs to TSV.

Samples:
- `D14_Ctrl_merged_new`
- `D14_L_merged_new`
- `D14_NL_merged_new`

## Quick start

```bash
# Run the full pipeline (s0–s5) for each sample, all 5 folds:
bash submit_pipeline.sh --name D14_Ctrl_merged_new
bash submit_pipeline.sh --name D14_L_merged_new
bash submit_pipeline.sh --name D14_NL_merged_new

```

Each sample submits 26 SLURM jobs: 1 (s0) + 5 (s1) + 5 (s2) + 5 (s3) + 5 (s4)
+ 5 (s5). Jobs are chained via `--dependency=afterok` so a fold's s2 waits
for its s1 to finish, etc.

## Input data

The bigwig and `narrowPeak` files for the three samples are too large to
ship in git and live outside the repo. By default
[submit_pipeline.sh](submit_pipeline.sh) looks for them under:

```
/data1/collab002/sail/shared/projects/peer-lab/chrombpnet_luis/test_data/
├── bigwig/
│   ├── D14_Ctrl_merged_cutsites.bw
│   ├── D14_L_merged_cutsites.bw
│   └── D14_NL_merged_cutsites.bw
└── macs3_peaks/
    ├── D14_Ctrl_merged_peaks.narrowPeak
    ├── D14_L_merged_peaks.narrowPeak
    └── D14_NL_merged_peaks.narrowPeak
```

If your copy lives elsewhere, override with the `TEST_DATA_DIR` env var:

```bash
TEST_DATA_DIR=/path/to/test_data bash submit_pipeline.sh --name D14_Ctrl_merged_new
```

Or override individual files at submit time with `--bigwig PATH` and
`--peaks PATH`.

## Setup

Build the `chrombpnet` conda env with the bundled installer:

```bash
bash install_chrombpnet.sh
```

Takes ~5 min for conda + ~15 min for pip (pulls torch + CUDA libs, ~5 GB
total). The 3 patched packages (`chrombpnet`, `modiscolite`, `memelite`)
come from public GitHub forks under `SotoLF/`; `modisco` comes from
`kundajelab/tfmodisco`.

The env is referenced **by name** (`chrombpnet`) in [config.sh](config.sh)
and resolved against your own conda. Override with `ENV_CHROMBPNET=...` at
submit time if you named it differently.

The mm10 reference genome, chromosome sizes, blacklist, and MEME motif
database are kept under `references/mm10/` (gitignored — too large for
GitHub). The lab-shared copy lives at:

```
/data1/collab002/sail/shared/projects/peer-lab/chrombpnet_luis/references/mm10/
├── GRCm38.primary_assembly.genome.fa        # 2.6 GB
├── GRCm38.primary_assembly.genome.fa.fai    # samtools index
├── genome.chromosome-sizes.txt
├── mm10.blacklist.bed
└── motifs.meme.txt
```

If your copy lives elsewhere, point [config.sh](config.sh) at it via the
`REFERENCES_DIR` env var, or override individual paths at submit time
(`--genome`, `--chrom-sizes`, `--blacklist`, or `MEME_DB=...`).

## Pipeline steps and runtimes

Real wall-clock times from the previous pipeline run on the D14 samples
(SLURM `peerd` partition, 1× A100 GPU, 4 CPU, 160 GB):

| Step | Description                       | Scope       | Wall time (per job) |
|------|-----------------------------------|-------------|---------------------|
| s0   | Peak filtering, chrom sizes       | per sample  | <5 min              |
| s1   | Splits, nonpeaks, bias model      | per fold    | 3.5–4 hours         |
| s2   | Full ChromBPNet model             | per fold    | 7–10 hours          |
| s3   | Per-base contribution scores      | per fold    | 24–27 hours         |
| s4   | TF-MoDISco motif discovery        | per fold    | 20–37 hours         |
| s5   | MoDISco HTML report + MEME export | per fold    | 8–20 min            |

End-to-end with chained dependencies: ~3 days per sample.

## Output structure

Results land in `results/<sample>/`. Each fold writes ~12 GB.

```
results/D14_Ctrl_merged_new/
├── peaks_no_blacklist.bed                # s0: peaks with blacklist removed
├── peaks_centered.bed                    # s0: peaks ±500bp around summit (1 kb regions)
├── main_chroms.sizes                     # s0: chr1–19, X, Y only
│
└── fold_0/                               # (×5: fold_0..fold_4)
    ├── splits/<sample>_fold_0.json       # s1: chromosome split (test/val/train)
    ├── <sample>_negatives.bed            # s1: GC-matched non-peak regions
    ├── bias_model/                       # s1: bias model (~2 GB)
    │   └── models/<sample>_bias.h5       #     trained bias model
    ├── full_model/                       # s2: full model (~2 GB)
    │   └── models/
    │       ├── <sample>_chrombpnet.h5           # full model
    │       └── <sample>_chrombpnet_nobias.h5    # bias-corrected (used by s3)
    ├── contributions.counts_scores.h5    # s3: counts contribs (~6.6 GB)
    ├── contributions.counts_scores.bw    # s3: counts contribs bigwig (~1.8 GB)
    ├── contributions.profile_scores.h5   # s3: profile contribs
    ├── contributions.profile_scores.bw   # s3: profile contribs bigwig
    └── modisco/                          # s4–s5 (~360 MB)
        ├── modisco_results_counts_scores.h5  # s4: discovered motifs
        ├── modisco_motifs.meme.txt           # s5: motifs in MEME format
        └── modisco_report/
            ├── report.html                   # s5: motif report with TomTom matches
            └── *.png                         # CWM logos + matched motif PNGs
```

## Layout

```
chrombpnet_luis/
├── config.sh                # paths, hyperparameters, conda envs
├── install_chrombpnet.sh    # builds the `chrombpnet` conda env
├── submit_pipeline.sh       # SLURM submission orchestrator
└── scripts/                 # s0–s5 step scripts + Python helpers
```

The following directories live on the filesystem (gitignored):

```
test_data/                   # bigwigs + narrowPeaks (see "Input data")
references/mm10/             # reference genome, blacklist, MEME motifs
logs/                        # SLURM stdout/stderr
slurm_jobs/                  # generated SLURM scripts
submitted_jobs/              # submissions.log
results/                     # per-sample fold outputs
reports/                     # cross-sample modisco TSV + QC
```
