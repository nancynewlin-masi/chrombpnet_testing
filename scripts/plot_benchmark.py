#!/usr/bin/env python3
import pandas as pd
import matplotlib.pyplot as plt
import argparse
import sys

# ---- example ----
# python scripts/plot_benchmark.py --gpulogcsv=/data1/hpcadmin/newlinn/Proj_PeerBenchmark/chrombpnet_testing/logs/s2_D14_Ctrl_merged_new_fold_0_20260518_164423_gpulog.csv --outputpng=/data1/hpcadmin/newlinn/Proj_PeerBenchmark/chrombpnet_testing/reports/s2_D14_Ctrl_merged_new_fold_0_20260518_164423_gpulog.png
# ---------------

def to_number(series: pd.Series) -> pd.Series:
    # Extract first numeric value from strings like "41.42 W", "0 %", "81920 MiB"
    return pd.to_numeric(series.astype(str).str.extract(r"([-+]?\d*\.?\d+)")[0], errors="coerce")


def main():
    parser = argparse.ArgumentParser(description="Average contribution H5 files across folds")
    parser.add_argument("--gpulogcsv", required=True,
                        help="CSV file that was generated for a single step by running submit_pipeline.sh.")
    parser.add_argument("--outputpng", required=True,
                        help="path to output location")
    args = parser.parse_args()

    cols = [
        "timestamp","name","index","uuid",
        "utilization.gpu","utilization.memory",
        "memory.used","memory.total",
        "power.draw","pstate","clocks_throttle_reasons.active"
    ]

    df = pd.read_csv(args.gpulogcsv, header=None, names=cols, skipinitialspace=True)

    # Parse time
    df["timestamp"] = pd.to_datetime(df["timestamp"], format="%Y/%m/%d %H:%M:%S.%f", errors="coerce")
    df = df.dropna(subset=["timestamp"]).sort_values("timestamp")

    # Clean numeric columns
    df["gpu_util_pct"] = to_number(df["utilization.gpu"])
    df["mem_util_pct"] = to_number(df["utilization.memory"])
    df["mem_used_mib"] = to_number(df["memory.used"])
    df["power_w"]      = to_number(df["power.draw"])

    # Plot
    fig, axes = plt.subplots(3, 1, figsize=(12, 8), sharex=True)

    axes[0].plot(df["timestamp"], df["gpu_util_pct"], label="GPU util (%)")
    axes[0].plot(df["timestamp"], df["mem_util_pct"], label="Mem util (%)")
    axes[0].set_ylabel("%")
    axes[0].set_ylim(0, 100)
    axes[0].grid(True, alpha=0.3)
    axes[0].legend(loc="upper right")

    axes[1].plot(df["timestamp"], df["mem_used_mib"], color="tab:purple", label="Memory used (MiB)")
    axes[1].set_ylabel("MiB")
    axes[1].grid(True, alpha=0.3)
    axes[1].legend(loc="upper right")

    axes[2].plot(df["timestamp"], df["power_w"], color="tab:orange", label="Power draw (W)")
    axes[2].set_ylabel("W")
    axes[2].grid(True, alpha=0.3)
    axes[2].legend(loc="upper right")

    axes[2].set_xlabel("Time")
    fig.autofmt_xdate()
    fig.tight_layout()

    plt.savefig(args.outputpng, dpi=200, bbox_inches="tight")
    print(f"Wrote {args.outputpng}")

if __name__=="__main__":
    main()