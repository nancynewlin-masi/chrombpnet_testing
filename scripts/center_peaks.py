#!/usr/bin/env python3
"""
center_peaks.py -- Center narrowPeak regions on summit and extend +/- 500bp.

Takes a narrowPeak/BED file (10-column) and outputs a BED file where each peak
is re-centered on its summit (col1_start + col10_summit) and extended 500bp
in each direction, producing uniform 1000bp regions.

USAGE:
    python center_peaks.py <input.bed> <output.bed>
"""

import sys


def center_peaks(inpeak_file, out_file):
    with open(inpeak_file, "r") as f_in, open(out_file, "w") as f_out:
        for line in f_in:
            line_split = line.strip().split("\t")
            chro, start, peak = line_split[0], line_split[1], line_split[9]
            midpoint = int(start) + int(peak)
            start_new = midpoint - 500
            end_new = midpoint + 500
            assert end_new - start_new == 1000
            f_out.write(f"{chro}\t{start_new}\t{end_new}\t.\t.\t.\t.\t.\t.\t500\n")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <input.narrowPeak> <output.bed>", file=sys.stderr)
        sys.exit(1)
    center_peaks(sys.argv[1], sys.argv[2])
    print(f"  Centered peaks written to: {sys.argv[2]}")
