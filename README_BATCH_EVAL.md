# INTR6000P Batch Evaluation Guide

This guide explains how to use the batch evaluation script for the INTR6000P dataset with ORB_SLAM2.

## Quick Start

### Run all sequences in the dataset:
```bash
cd /home/hz/intr6000/ORB_SLAM2
./batch_eval_intr6000p.sh
```

### Run only easy sequences:
```bash
./batch_eval_intr6000p.sh --difficulty easy
```

### Run specific sequences:
```bash
./batch_eval_intr6000p.sh --sequences carwelding2,factory1
```

### Run without visualization (faster):
```bash
./batch_eval_intr6000p.sh --no-visualization
```

## Dataset Structure

The INTR6000P dataset includes:

### Easy Sequences:
- carwelding2
- factory1
- hospital

### Medium Sequences:
- factory2
- factory6

### Hard Sequences:
- amusement1
- amusement2

## Script Options

| Option | Description | Example |
|--------|-------------|---------|
| `--difficulty <level>` | Run only specified difficulty (easy/medium/hard/all) | `--difficulty easy` |
| `--sequences <list>` | Run only specified sequences (comma-separated) | `--sequences carwelding2,factory1` |
| `--no-visualization` | Skip PDF plot generation (saves time) | `--no-visualization` |
| `--output-dir <path>` | Custom output directory | `--output-dir ./my_results` |
| `-h, --help` | Show help message | `-h` |

## Output Structure

After running, results are saved in `batch_eval_results_<timestamp>/`:

```
batch_eval_results_20251127_123456/
├── evaluation_summary.txt          # Human-readable summary
├── results.csv                     # CSV format results
├── easy_carwelding2/
│   ├── trajectory.txt              # Estimated trajectory
│   ├── orbslam.log                 # ORB_SLAM2 log
│   ├── evo_statistics.txt          # Detailed EVO metrics
│   ├── ape_results.zip             # EVO results archive
│   └── trajectory_plot.pdf         # Trajectory visualization
├── easy_factory1/
│   └── ...
└── ...
```

## Results Interpretation

### Key Metrics (in meters):

- **RMSE**: Root Mean Square Error - overall trajectory accuracy
- **Mean**: Average position error
- **Median**: Median position error (robust to outliers)
- **Std**: Standard deviation of errors
- **Min/Max**: Minimum and maximum errors

### What's Good Performance?

- **High Accuracy**: RMSE < 0.1m
- **Medium Accuracy**: RMSE 0.1-0.5m
- **Low Accuracy**: RMSE > 0.5m

### Status Codes:

- `SUCCESS`: Evaluation completed successfully
- `SLAM_FAILED`: ORB_SLAM2 crashed or failed
- `NO_TRAJECTORY`: No trajectory file generated (tracking lost)
- `EVO_FAILED`: EVO evaluation failed
- `MISSING_DATA`: Sequence data not found
- `MISSING_GT`: Ground truth not found

## Prerequisites

Before running the script, ensure:

1. **ORB_SLAM2 is built:**
   ```bash
   cd /home/hz/intr6000/ORB_SLAM2
   ./build.sh
   ```

2. **uv package manager is installed:**
   ```bash
   curl -LsSf https://astral.sh/uv/install.sh | sh
   source $HOME/.local/bin/env  # or restart your shell
   ```

   The script will automatically install EVO using uv when needed.

3. **Dataset is downloaded:**
   - INTR6000P dataset should be in: `/home/hz/intr6000/ORB_SLAM2/INTR6000P/`
   - Ground truth files should be in: `/home/hz/intr6000/ORB_SLAM2/INTR6000P/INTR6000P_GT_POSES/`

## Troubleshooting

### Problem: "uv not found"
**Solution:**
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
source $HOME/.local/bin/env  # or restart your shell
```

### Problem: "ORB_SLAM2 executable not found"
**Solution:**
```bash
cd /home/hz/intr6000/ORB_SLAM2
./build.sh
```

### Problem: "No trajectory file generated"
**Possible causes:**
- Tracking lost during sequence
- Initialization failed
- Check `orbslam.log` for details

### Problem: Visualization fails
**Solution:**
- Use `--no-visualization` flag
- Or install display dependencies: `sudo apt-get install python3-tk`

## Viewing Results

### View summary:
```bash
cat batch_eval_results_*/evaluation_summary.txt
```

### View CSV in spreadsheet:
```bash
libreoffice batch_eval_results_*/results.csv
```

### View trajectory plots:
```bash
evince batch_eval_results_*/easy_carwelding2/trajectory_plot.pdf
```

### Compare results with EVO:
```bash
uv run --with evo evo_ape tum ground_truth.txt trajectory.txt -r trans_part --plot --plot_mode xyz -as
```

## Advanced Usage

### Run in background with logging:
```bash
nohup ./batch_eval_intr6000p.sh > batch_eval.log 2>&1 &
tail -f batch_eval.log
```

### Compare multiple runs:
```bash
# First run
./batch_eval_intr6000p.sh --output-dir results_run1

# Second run (after changes)
./batch_eval_intr6000p.sh --output-dir results_run2

# Compare CSVs
diff results_run1/results.csv results_run2/results.csv
```

### Extract specific metrics:
```bash
# Get all RMSE values
cat batch_eval_results_*/results.csv | grep SUCCESS | cut -d',' -f4

# Calculate average RMSE
cat batch_eval_results_*/results.csv | grep SUCCESS | cut -d',' -f4 | \
    awk '{sum+=$1; count++} END {print sum/count}'
```

## Performance Tips

1. **Use `--no-visualization`** to save ~30% time
2. **Run specific difficulties** to test incrementally
3. **Use `--sequences`** to debug specific failures
4. **Monitor with `htop`** to ensure system resources are available

## Citation

If you use this evaluation script, please cite:
- ORB_SLAM2: Mur-Artal and Tardós, TRO 2017
- EVO: Grupp, https://github.com/MichaelGrupp/evo
- INTR6000P: [Your dataset citation]

## Support

For issues or questions:
- Check `orbslam.log` files for SLAM errors
- Check `evo_statistics.txt` for evaluation details
- Refer to: [quick_eval_intr6000p.sh](quick_eval_intr6000p.sh) for single-sequence debugging
