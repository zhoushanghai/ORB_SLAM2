#!/bin/bash

################################################################################
# Automated ORB_SLAM2 Evaluation Script for INTR6000P Dataset
#
# This script automates:
# 1. Running ORB_SLAM2 on all INTR6000P sequences (easy/medium/hard)
# 2. Evaluating trajectories against ground truth using EVO
# 3. Generating comprehensive summary reports
#
# Usage: bash run_intr6000p_evaluation.sh [--dry-run]
################################################################################

set -e  # Exit on error

# ============================================================================
# CONFIGURATION
# ============================================================================

# Base paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORBSLAM_ROOT="$SCRIPT_DIR"
DATASET_ROOT="$SCRIPT_DIR/INTR6000P"

# ORB_SLAM2 configuration
ORBSLAM_EXEC="$ORBSLAM_ROOT/Examples/Monocular/mono_euroc"
VOCABULARY="$ORBSLAM_ROOT/Vocabulary/ORBvoc.txt"
CAMERA_CONFIG="$DATASET_ROOT/tartanair.yaml"

# Dataset paths
GT_ROOT="$DATASET_ROOT/INTR6000P_GT_POSES"

# Output directory
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_ROOT="$SCRIPT_DIR/intr6000p_results_$TIMESTAMP"
TRAJ_DIR="$OUTPUT_ROOT/trajectories"
EVO_DIR="$OUTPUT_ROOT/evo_results"
LOG_DIR="$OUTPUT_ROOT/logs"

# EVO virtualenv
VIRTUALENV_NAME="evaluation"

# Dry run mode
DRY_RUN=false
if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=true
    echo "🔍 DRY RUN MODE - No actual execution"
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ============================================================================
# SETUP FUNCTIONS
# ============================================================================

setup_directories() {
    log_info "Creating output directories..."
    mkdir -p "$TRAJ_DIR"
    mkdir -p "$EVO_DIR"
    mkdir -p "$LOG_DIR"
    log_success "Directories created at: $OUTPUT_ROOT"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check ORB_SLAM2 executable
    if [[ ! -f "$ORBSLAM_EXEC" ]]; then
        log_error "ORB_SLAM2 executable not found: $ORBSLAM_EXEC"
        exit 1
    fi
    
    # Check vocabulary
    if [[ ! -f "$VOCABULARY" ]]; then
        log_error "Vocabulary file not found: $VOCABULARY"
        exit 1
    fi
    
    # Check camera config
    if [[ ! -f "$CAMERA_CONFIG" ]]; then
        log_error "Camera config not found: $CAMERA_CONFIG"
        exit 1
    fi
    
    # Check virtualenv - look for the virtualenv directory
    if [[ ! -d "$HOME/.virtualenvs/$VIRTUALENV_NAME" ]]; then
        log_error "Virtualenv '$VIRTUALENV_NAME' not found at $HOME/.virtualenvs/$VIRTUALENV_NAME"
        log_error "Please ensure the EVO virtualenv is created first."
        exit 1
    fi
    
    log_success "All prerequisites satisfied"
}

# ============================================================================
# CORE FUNCTIONS
# ============================================================================

run_orbslam() {
    local difficulty="$1"
    local sequence="$2"
    local seq_path="$DATASET_ROOT/$difficulty/$sequence"
    local images_path="$seq_path/image_left"
    local timestamps_file="$seq_path/timestamps.txt"
    local output_file="$TRAJ_DIR/${difficulty}_${sequence}_trajectory.txt"
    local log_file="$LOG_DIR/${difficulty}_${sequence}_orbslam.log"
    
    log_info "Running ORB_SLAM2 on $difficulty/$sequence..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_warning "DRY RUN: Would run ORB_SLAM2 on $seq_path"
        # Create dummy output for dry run
        echo "1700000000.000000 0.0 0.0 0.0 0.0 0.0 0.0 1.0" > "$output_file"
        return 0
    fi
    
    # Run ORB_SLAM2
    cd "$ORBSLAM_ROOT"
    "$ORBSLAM_EXEC" "$VOCABULARY" "$CAMERA_CONFIG" "$images_path" "$timestamps_file" > "$log_file" 2>&1 || {
        log_error "ORB_SLAM2 failed for $difficulty/$sequence (check $log_file)"
        return 1
    }
    
    # Check if trajectory was generated
    if [[ -f "KeyFrameTrajectory.txt" ]]; then
        mv "KeyFrameTrajectory.txt" "$output_file"
        log_success "Trajectory saved to: $output_file"
    elif [[ -f "CameraTrajectory.txt" ]]; then
        mv "CameraTrajectory.txt" "$output_file"
        log_success "Trajectory saved to: $output_file"
    else
        log_error "No trajectory file generated for $difficulty/$sequence"
        return 1
    fi
    
    cd "$SCRIPT_DIR"
    return 0
}

evaluate_with_evo() {
    local difficulty="$1"
    local sequence="$2"
    local traj_file="$TRAJ_DIR/${difficulty}_${sequence}_trajectory.txt"
    local gt_file="$GT_ROOT/$difficulty/${sequence}.txt"
    local evo_output_dir="$EVO_DIR/${difficulty}_${sequence}"
    local results_file="$evo_output_dir/ape_results.zip"
    local stats_file="$evo_output_dir/statistics.txt"
    
    log_info "Evaluating $difficulty/$sequence with EVO..."
    
    if [[ ! -f "$traj_file" ]]; then
        log_error "Trajectory file not found: $traj_file"
        return 1
    fi
    
    if [[ ! -f "$gt_file" ]]; then
        log_error "Ground truth file not found: $gt_file"
        return 1
    fi
    
    mkdir -p "$evo_output_dir"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_warning "DRY RUN: Would evaluate with EVO"
        echo "rmse: 0.123456" > "$stats_file"
        return 0
    fi
    
    # Activate virtualenv and run EVO
    bash -c "
        export WORKON_HOME=\$HOME/.virtualenvs
        source /usr/share/virtualenvwrapper/virtualenvwrapper.sh
        workon $VIRTUALENV_NAME
        
        # Run EVO APE
        evo_ape tum '$gt_file' '$traj_file' \
            -r trans_part \
            --save_results '$results_file' \
            --verbose > '$stats_file' 2>&1
        
        # Generate plots
        evo_ape tum '$gt_file' '$traj_file' \
            -r trans_part \
            --plot --plot_mode xyz \
            --save_plot '$evo_output_dir/plot.pdf' \
            >> '$stats_file' 2>&1 || true
    " || {
        log_error "EVO evaluation failed for $difficulty/$sequence"
        return 1
    }
    
    log_success "EVO evaluation completed for $difficulty/$sequence"
    
    # Extract RMSE from results
    if [[ -f "$stats_file" ]]; then
        RMSE=$(grep -i "rmse" "$stats_file" | head -1 || echo "N/A")
        echo "$RMSE"
    fi
    
    return 0
}

process_sequence() {
    local difficulty="$1"
    local sequence="$2"
    
    echo ""
    log_info "========================================="
    log_info "Processing: $difficulty/$sequence"
    log_info "========================================="
    
    # Run ORB_SLAM2
    if ! run_orbslam "$difficulty" "$sequence"; then
        log_error "Failed to process $difficulty/$sequence"
        echo "$difficulty,$sequence,FAILED,N/A" >> "$OUTPUT_ROOT/results.csv"
        return 1
    fi
    
    # Evaluate with EVO
    local rmse=$(evaluate_with_evo "$difficulty" "$sequence")
    
    echo "$difficulty,$sequence,SUCCESS,$rmse" >> "$OUTPUT_ROOT/results.csv"
    
    log_success "Completed: $difficulty/$sequence"
    return 0
}

# ============================================================================
# SUMMARY GENERATION
# ============================================================================

generate_summary() {
    local summary_file="$OUTPUT_ROOT/summary_report.txt"
    
    log_info "Generating summary report..."
    
    cat > "$summary_file" << EOF
================================================================================
ORB_SLAM2 INTR6000P Evaluation Summary
================================================================================
Generated: $(date)
Output Directory: $OUTPUT_ROOT

EOF
    
    # Add results from CSV
    if [[ -f "$OUTPUT_ROOT/results.csv" ]]; then
        echo "Results by Difficulty Level:" >> "$summary_file"
        echo "----------------------------" >> "$summary_file"
        echo "" >> "$summary_file"
        
        for difficulty in easy medium hard; do
            echo "[$difficulty]" >> "$summary_file"
            grep "^$difficulty," "$OUTPUT_ROOT/results.csv" | while IFS=',' read -r diff seq status rmse; do
                if [[ "$status" == "SUCCESS" ]]; then
                    echo "  ✓ $seq: $rmse" >> "$summary_file"
                else
                    echo "  ✗ $seq: FAILED" >> "$summary_file"
                fi
            done
            echo "" >> "$summary_file"
        done
    fi
    
    cat >> "$summary_file" << EOF

Detailed Results:
-----------------
- Trajectories: $TRAJ_DIR
- EVO Results: $EVO_DIR
- Logs: $LOG_DIR

Commands to view results:
-------------------------
# View summary
cat $summary_file

# View specific EVO results
cat $EVO_DIR/<difficulty>_<sequence>/statistics.txt

# View trajectory plots (if generated)
evince $EVO_DIR/<difficulty>_<sequence>/plot.pdf

================================================================================
EOF
    
    log_success "Summary report saved to: $summary_file"
    
    # Display summary
    cat "$summary_file"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    log_info "Starting INTR6000P Automated Evaluation"
    log_info "========================================"
    
    # Check prerequisites
    check_prerequisites
    
    # Setup directories
    setup_directories
    
    # Initialize results CSV
    echo "difficulty,sequence,status,rmse" > "$OUTPUT_ROOT/results.csv"
    
    # Define all sequences by difficulty
    declare -A SEQUENCES
    SEQUENCES[easy]="carwelding2 factory1 hospital"
    SEQUENCES[medium]="factory2 factory6"
    SEQUENCES[hard]="amusement1 amusement2"
    
    # Process all sequences
    local total=0
    local success=0
    local failed=0
    
    for difficulty in easy medium hard; do
        for sequence in ${SEQUENCES[$difficulty]}; do
            total=$((total + 1))
            
            if process_sequence "$difficulty" "$sequence"; then
                success=$((success + 1))
            else
                failed=$((failed + 1))
            fi
        done
    done
    
    # Generate summary
    generate_summary
    
    # Final statistics
    echo ""
    log_info "========================================"
    log_info "Evaluation Complete!"
    log_info "========================================"
    log_info "Total sequences: $total"
    log_success "Successful: $success"
    if [[ $failed -gt 0 ]]; then
        log_error "Failed: $failed"
    fi
    log_info "Results saved to: $OUTPUT_ROOT"
    echo ""
}

# Run main function
main "$@"
