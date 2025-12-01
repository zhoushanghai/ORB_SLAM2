#!/bin/bash

################################################################################
# Quick Single-Sequence Evaluation Script for INTR6000P
#
# This script runs ORB_SLAM2 on a single sequence and evaluates with EVO.
# Useful for testing and debugging.
#
# Usage: bash quick_eval_intr6000p.sh <difficulty> <sequence>
# Example: bash quick_eval_intr6000p.sh easy carwelding2
################################################################################

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check arguments
if [[ $# -ne 2 ]]; then
    log_error "Usage: $0 <difficulty> <sequence>"
    echo "Example: $0 easy carwelding2"
    echo "Available sequences:"
    echo "  easy: carwelding2, factory1, hospital"
    echo "  medium: factory2, factory6"
    echo "  hard: amusement1, amusement2"
    exit 1
fi

DIFFICULTY="$1"
SEQUENCE="$2"

# Base paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORBSLAM_ROOT="$SCRIPT_DIR"
DATASET_ROOT="$SCRIPT_DIR/INTR6000P"

# Configuration
ORBSLAM_EXEC="$ORBSLAM_ROOT/Examples/Monocular/mono_euroc"
VOCABULARY="$ORBSLAM_ROOT/Vocabulary/ORBvoc.txt"
# CAMERA_CONFIG="$DATASET_ROOT/tartanair_1.yaml"
CAMERA_CONFIG="/home/hz/intr6000/ORB_SLAM2/tartanair.yaml"
GT_ROOT="$DATASET_ROOT/INTR6000P_GT_POSES"

# Paths for this sequence
SEQ_PATH="$DATASET_ROOT/$DIFFICULTY/$SEQUENCE"
IMAGES_PATH="$SEQ_PATH/image_left"
TIMESTAMPS_FILE="$SEQ_PATH/timestamps.txt"
GT_FILE="$GT_ROOT/$DIFFICULTY/${SEQUENCE}.txt"

# Output paths
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_DIR="$SCRIPT_DIR/output/quick_eval_${DIFFICULTY}_${SEQUENCE}_${TIMESTAMP}"
TRAJ_FILE="$OUTPUT_DIR/trajectory.txt"
LOG_FILE="$OUTPUT_DIR/orbslam.log"
EVO_STATS="$OUTPUT_DIR/evo_statistics.txt"

# Check uv is available
if ! command -v uv &> /dev/null; then
    log_error "uv not found! Please install it first:"
    log_error "curl -LsSf https://astral.sh/uv/install.sh | sh"
    log_error "Then restart your shell or run: export PATH=\"\$HOME/.local/bin:\$PATH\""
    exit 1
fi

# Ensure uv is in PATH
export PATH="$HOME/.local/bin:$PATH"

# Validate inputs
if [[ ! -d "$SEQ_PATH" ]]; then
    log_error "Sequence not found: $DIFFICULTY/$SEQUENCE"
    log_error "Path checked: $SEQ_PATH"
    exit 1
fi

if [[ ! -f "$GT_FILE" ]]; then
    log_error "Ground truth file not found: $GT_FILE"
    exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

log_info "============================================"
log_info "Quick Evaluation: $DIFFICULTY/$SEQUENCE"
log_info "============================================"
log_info "Sequence path: $SEQ_PATH"
log_info "Ground truth: $GT_FILE"
log_info "Output directory: $OUTPUT_DIR"
echo ""

# Step 1: Run ORB_SLAM2
log_info "Step 1: Running ORB_SLAM2..."
cd "$ORBSLAM_ROOT"

"$ORBSLAM_EXEC" "$VOCABULARY" "$CAMERA_CONFIG" "$IMAGES_PATH" "$TIMESTAMPS_FILE" "$OUTPUT_DIR" > "$LOG_FILE" 2>&1 || {
    log_error "ORB_SLAM2 failed! Check log: $LOG_FILE"
    exit 1
}

# Check for trajectory output
if [[ -f "KeyFrameTrajectory.txt" ]]; then
    mv "KeyFrameTrajectory.txt" "$TRAJ_FILE"
    log_success "Trajectory saved: $TRAJ_FILE"
elif [[ -f "CameraTrajectory.txt" ]]; then
    mv "CameraTrajectory.txt" "$TRAJ_FILE"
    log_success "Trajectory saved: $TRAJ_FILE"
else
    log_error "No trajectory file generated!"
    log_error "Check ORB_SLAM2 log: $LOG_FILE"
    exit 1
fi

echo ""

# Step 2: Evaluate with EVO
log_info "Step 2: Evaluating with EVO..."

export PATH="$HOME/.local/bin:$PATH"

echo 'Running EVO APE with Sim(3) alignment...'
uv run --with evo evo_ape tum "$GT_FILE" "$TRAJ_FILE" \
    -r trans_part -as \
    --save_results "$OUTPUT_DIR/ape_results.zip" \
    --verbose > "$EVO_STATS" 2>&1 || {
    log_error "EVO evaluation failed!"
    exit 1
}

echo 'Generating and saving plots...'
PLOT_FILE="$OUTPUT_DIR/trajectory_plot.png"
log_info "Running: uv run evo_ape tum \"$GT_FILE\" \"$TRAJ_FILE\" -r trans_part --plot --plot_mode xyz --save_plot \"$PLOT_FILE\" --serialize_plot \"$OUTPUT_DIR/plot_data.zip\" -as"
uv run evo_ape tum "$GT_FILE" "$TRAJ_FILE" -r trans_part --plot --plot_mode xyz --save_plot "$PLOT_FILE" --serialize_plot "$OUTPUT_DIR/plot_data.zip" -as || true


log_success "EVO evaluation completed"
echo ""

# Step 3: Display results
log_info "============================================"
log_info "Results Summary"
log_info "============================================"

if [[ -f "$EVO_STATS" ]]; then
    echo ""
    grep -A 10 "^APE" "$EVO_STATS" || grep -i "rmse\|mean\|std" "$EVO_STATS" || cat "$EVO_STATS"
    echo ""
fi

log_info "Output files:"
log_info "  - Trajectory: $TRAJ_FILE"
log_info "  - EVO stats: $EVO_STATS"
log_info "  - ORB_SLAM2 log: $LOG_FILE"
log_info "  - Results: $OUTPUT_DIR/ape_results.zip"
if [[ -f "$OUTPUT_DIR/trajectory_plot.pdf" ]]; then
    log_info "  - Plot: $OUTPUT_DIR/trajectory_plot.pdf"
fi
echo ""

log_success "Evaluation complete!"


# Easy 难度：
# ./quick_eval_intr6000p.sh easy carwelding2
# ./quick_eval_intr6000p.sh easy factory1
# ./quick_eval_intr6000p.sh easy hospital
# Medium 难度：
# ./quick_eval_intr6000p.sh medium factory2
# ./quick_eval_intr6000p.sh medium factory6
# Hard 难度：
# ./quick_eval_intr6000p.sh hard amusement1
# ./quick_eval_intr6000p.sh hard amusement2