#!/usr/bin/env python3
"""
Average contribution scores across folds.

Reads per-fold contributions.counts_scores.h5 (and optionally profile_scores.h5)
files from a sample directory, averages projected_shap, raw, and shap scores,
and writes a merged output H5 file.
"""

import argparse
import sys
from pathlib import Path

try:
    import hdf5plugin  # required by HDF5 1.14 for some compression filters
except ImportError:
    pass

import h5py
import numpy as np


def main():
    parser = argparse.ArgumentParser(description="Average contribution H5 files across folds")
    parser.add_argument("--sample-dir", required=True,
                        help="Sample results directory containing fold_0..fold_N")
    parser.add_argument("--output", required=True, help="Output H5 file path")
    parser.add_argument("--folds", type=int, nargs="+", default=None,
                        help="Specific folds to average (default: all available)")
    parser.add_argument("--num-folds", type=int, default=5,
                        help="Total number of folds (used if --folds not given)")
    parser.add_argument("--score-type", default="counts_scores",
                        choices=["counts_scores", "profile_scores"],
                        help="Score type to average")
    args = parser.parse_args()

    sample_dir = Path(args.sample_dir)

    # Determine which folds to use
    if args.folds is not None:
        fold_ids = args.folds
    else:
        fold_ids = list(range(args.num_folds))

    # Build file paths
    file_paths = []
    for fold in fold_ids:
        path = sample_dir / f"fold_{fold}" / f"contributions.{args.score_type}.h5"
        if not path.exists():
            print(f"ERROR: Missing fold {fold}: {path}", file=sys.stderr)
            sys.exit(1)
        file_paths.append((fold, path))
        print(f"  fold_{fold}: {path}")

    n_folds = len(file_paths)
    print(f"\nLoading and averaging {n_folds} fold files...")

    projected_shap_sum = None
    raw_sum = None
    shap_sum = None

    for i, (fold, path) in enumerate(file_paths):
        print(f"  Loading fold_{fold}...")
        with h5py.File(path, "r") as h5:
            ps = h5["projected_shap"]["seq"][()].astype(np.float32)
            rw = h5["raw"]["seq"][()].astype(np.int32)
            sh = h5["shap"]["seq"][()].astype(np.float32)

            if projected_shap_sum is None:
                projected_shap_sum = ps
                raw_sum = rw.astype(np.float32)
                shap_sum = sh
                print(f"    Dimensions: projected_shap={ps.shape}, raw={rw.shape}, shap={sh.shape}")
            else:
                if ps.shape != projected_shap_sum.shape:
                    print(f"ERROR: Shape mismatch in fold {fold}: {ps.shape} vs {projected_shap_sum.shape}",
                          file=sys.stderr)
                    sys.exit(1)
                projected_shap_sum += ps
                raw_sum += rw.astype(np.float32)
                shap_sum += sh

    print("\nAveraging...")
    projected_shap_avg = projected_shap_sum / n_folds
    raw_avg = raw_sum / n_folds
    shap_avg = shap_sum / n_folds

    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    print(f"Saving to {output_path}...")
    with h5py.File(output_path, "w") as out:
        proj_group = out.create_group("projected_shap")
        raw_group = out.create_group("raw")
        shap_group = out.create_group("shap")

        proj_group.create_dataset("seq", data=projected_shap_avg, dtype="float16")
        raw_group.create_dataset("seq", data=np.round(raw_avg).astype(np.int8), dtype="int8")
        shap_group.create_dataset("seq", data=shap_avg, dtype="float16")

        out.attrs["averaged_folds"] = ",".join(str(f) for f, _ in file_paths)
        out.attrs["n_folds"] = n_folds

    print(f"Done! Output: {output_path}")
    print(f"  Averaged folds: {[f for f, _ in file_paths]}")


if __name__ == "__main__":
    main()
