#!/usr/bin/env bash
# Reproduce the `chrombpnet` env from GitHub forks.
# Usage: bash install_chrombpnet.sh
# Requires: conda on PATH, git, network access to github.com.

set -euo pipefail

ENV_NAME="chrombpnet"

if conda env list | awk 'NF && $1 != "#" {print $1}' | grep -qx "${ENV_NAME}"; then
    echo "Env '${ENV_NAME}' already exists. Remove it first: conda env remove -n ${ENV_NAME} -y" >&2
    exit 1
fi

conda create -n "${ENV_NAME}" python=3.8 -y
conda install -y -n "${ENV_NAME}" -c conda-forge -c bioconda \
    samtools bedtools ucsc-bedgraphtobigwig pybigwig meme

PIP="$(conda env list | awk -v e="${ENV_NAME}" '$1 == e {print $NF}')/bin/pip"

"${PIP}" install "chrombpnet @ git+https://github.com/SotoLF/private_chrombpnet.git@master"

"${PIP}" install \
    MACS3==3.0.0b1 \
    pysam==0.23.3 \
    pybigtools==0.2.5 \
    seaborn==0.13.2 \
    hmmlearn==0.3.3 \
    tangermeme==1.0.3 \
    torch==2.4.1 \
    bam2bw==0.4.1

"${PIP}" install --upgrade "modisco @ git+https://github.com/kundajelab/tfmodisco.git"
"${PIP}" install --upgrade --force-reinstall --no-deps \
    "modisco-lite @ git+https://github.com/SotoLF/private_tfmodisco-lite.git@patched"
"${PIP}" install --upgrade --force-reinstall --no-deps \
    "memelite @ git+https://github.com/SotoLF/private_memesuite-lite.git@patched"
