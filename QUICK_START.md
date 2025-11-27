# Quick Start Guide - INTR6000P Batch Evaluation

## 🚀 Fastest Way to Run

```bash
cd /home/hz/intr6000/ORB_SLAM2
./batch_eval_intr6000p.sh
```

This will:
- Run ORB_SLAM2 on all 7 sequences in INTR6000P dataset
- Automatically compare with ground truth using EVO
- Generate detailed reports and visualizations
- Save everything to `batch_eval_results_<timestamp>/`

---

## 📁 Scripts Available

### 1. **batch_eval_intr6000p.sh** - Main batch evaluation script
Run all or selected sequences automatically.

```bash
# Run everything
./batch_eval_intr6000p.sh

# Run only easy sequences
./batch_eval_intr6000p.sh --difficulty easy

# Run specific sequences
./batch_eval_intr6000p.sh --sequences carwelding2,factory1

# Run without plots (faster)
./batch_eval_intr6000p.sh --no-visualization
```

### 2. **quick_eval_intr6000p.sh** - Single sequence evaluation
Test or debug individual sequences.

```bash
# Run single sequence
./quick_eval_intr6000p.sh easy carwelding2
```

### 3. **compare_results.sh** - Compare multiple runs
Compare results after making changes or testing different parameters.

```bash
# Compare two runs
./compare_results.sh batch_eval_results_1/ batch_eval_results_2/

# Compare multiple runs
./compare_results.sh run1/ run2/ run3/
```

### 4. **visualize_results.sh** - Visualize results
Quick statistics and visualization of evaluation results.

```bash
./visualize_results.sh batch_eval_results_20251127_123456/
```

---

## 📊 Understanding Results

### Output Directory Structure:
```
batch_eval_results_<timestamp>/
├── evaluation_summary.txt          # Human-readable summary
├── results.csv                     # Spreadsheet-friendly results
├── easy_carwelding2/
│   ├── trajectory.txt              # ORB_SLAM2 output
│   ├── orbslam.log                 # Full SLAM log
│   ├── evo_statistics.txt          # Detailed metrics
│   └── trajectory_plot.pdf         # Visual comparison
└── ...
```

### Key Metrics:
- **RMSE** (Root Mean Square Error): Overall trajectory accuracy
  - < 0.1m = Excellent
  - 0.1-0.3m = Good
  - 0.3-0.5m = Medium
  - \> 0.5m = Poor
- **Mean**: Average position error
- **Std**: Consistency of errors

### Quick Results Check:
```bash
# View summary
cat batch_eval_results_*/evaluation_summary.txt

# View CSV in terminal
column -t -s',' batch_eval_results_*/results.csv | less

# Open in spreadsheet
libreoffice batch_eval_results_*/results.csv
```

---

## 🎯 Common Use Cases

### Use Case 1: Full Evaluation
```bash
# Run all sequences with full reports
./batch_eval_intr6000p.sh
```

### Use Case 2: Quick Test (Easy sequences only)
```bash
# Faster evaluation for testing
./batch_eval_intr6000p.sh --difficulty easy --no-visualization
```

### Use Case 3: Debug Single Sequence
```bash
# Test single sequence with full output
./quick_eval_intr6000p.sh easy carwelding2
```

### Use Case 4: Compare Two Configurations
```bash
# Run with config 1
./batch_eval_intr6000p.sh --output-dir results_config1

# Change ORB_SLAM2 parameters, then run with config 2
./batch_eval_intr6000p.sh --output-dir results_config2

# Compare
./compare_results.sh results_config1/ results_config2/
```

### Use Case 5: Analyze Results
```bash
# Get detailed visualization
./visualize_results.sh batch_eval_results_<timestamp>/
```

---

## 🔧 Prerequisites

### 1. Build ORB_SLAM2:
```bash
cd /home/hz/intr6000/ORB_SLAM2
./build.sh
```

### 2. Install uv Package Manager:
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
source $HOME/.local/bin/env  # or restart your shell
```

EVO will be automatically installed by uv when you run the scripts.

### 3. Verify Dataset:
```bash
ls /home/hz/intr6000/ORB_SLAM2/INTR6000P/easy/
ls /home/hz/intr6000/ORB_SLAM2/INTR6000P/INTR6000P_GT_POSES/
```

---

## 🐛 Troubleshooting

### Problem: Scripts won't run
```bash
# Make executable
chmod +x *.sh
```

### Problem: "uv not found"
```bash
# Install uv
curl -LsSf https://astral.sh/uv/install.sh | sh
source $HOME/.local/bin/env  # or restart your shell
```

### Problem: "ORB_SLAM2 executable not found"
```bash
# Build ORB_SLAM2
cd /home/hz/intr6000/ORB_SLAM2
./build.sh
```

### Problem: Tracking fails on sequence
- Check log file: `cat batch_eval_results_*/easy_carwelding2/orbslam.log`
- Try single sequence: `./quick_eval_intr6000p.sh easy carwelding2`
- May need to adjust ORB_SLAM2 parameters in `tartanair.yaml`

---

## 📈 Extracting Specific Data

### Average RMSE across all sequences:
```bash
cat batch_eval_results_*/results.csv | grep SUCCESS | cut -d',' -f4 | \
    awk '{sum+=$1; count++} END {print "Average RMSE:", sum/count, "m"}'
```

### Count successes:
```bash
cat batch_eval_results_*/results.csv | grep -c SUCCESS
```

### Find best sequence:
```bash
cat batch_eval_results_*/results.csv | grep SUCCESS | sort -t',' -k4 -n | head -1
```

### Find worst sequence:
```bash
cat batch_eval_results_*/results.csv | grep SUCCESS | sort -t',' -k4 -n | tail -1
```

---

## 📚 Dataset Information

### INTR6000P Sequences:

**Easy (3 sequences):**
- carwelding2 - Indoor industrial environment
- factory1 - Factory setting
- hospital - Indoor hospital environment

**Medium (2 sequences):**
- factory2 - More challenging factory
- factory6 - Complex factory environment

**Hard (2 sequences):**
- amusement1 - Dynamic amusement park
- amusement2 - Challenging outdoor environment

---

## 💡 Tips

1. **Start with easy sequences** to verify setup: `./batch_eval_intr6000p.sh --difficulty easy`

2. **Use --no-visualization** for faster runs during development

3. **Keep result directories** for comparison later: `./batch_eval_intr6000p.sh --output-dir my_experiment_1`

4. **Monitor progress** with: `tail -f batch_eval.log` when running in background

5. **Review failed sequences** individually: `./quick_eval_intr6000p.sh <difficulty> <sequence>`

---

## 🔗 More Information

- Detailed guide: [README_BATCH_EVAL.md](README_BATCH_EVAL.md)
- ORB_SLAM2 paper: Mur-Artal and Tardós, TRO 2017
- EVO toolkit: https://github.com/MichaelGrupp/evo

---

## ⚡ Example Workflow

```bash
# 1. Go to ORB_SLAM2 directory
cd /home/hz/intr6000/ORB_SLAM2

# 2. Quick test on easy sequences
./batch_eval_intr6000p.sh --difficulty easy

# 3. View results
./visualize_results.sh batch_eval_results_<timestamp>/

# 4. If all looks good, run full evaluation
./batch_eval_intr6000p.sh

# 5. Compare with previous run
./compare_results.sh old_results/ batch_eval_results_<timestamp>/
```

---

**Happy Evaluating! 🎉**
