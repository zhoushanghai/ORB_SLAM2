#!/bin/bash

################################################################################
# Batch Evaluation Script for INTR6000P Dataset
#
# This script automatically runs ORB_SLAM2 on all sequences in the INTR6000P
# dataset and evaluates results with EVO.
#
# Usage: bash batch_eval_intr6000p.sh [options]
# Options:
#   --difficulty <easy|medium|hard|all>  Run only specified difficulty (default: all)
#   --sequences <seq1,seq2,...>          Run only specified sequences (comma-separated)
#   --no-visualization                   Skip plot generation
#   --output-dir <path>                  Custom output directory
#
# Example: bash batch_eval_intr6000p.sh
#          bash batch_eval_intr6000p.sh --difficulty easy
#          bash batch_eval_intr6000p.sh --sequences carwelding2,factory1
################################################################################

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_result() { echo -e "${CYAN}[RESULT]${NC} $1"; }

# Parse command line arguments
DIFFICULTY_FILTER="all"
SEQUENCE_FILTER=""
ENABLE_VISUALIZATION=true
CUSTOM_OUTPUT_DIR=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --difficulty)
            DIFFICULTY_FILTER="$2"
            shift 2
            ;;
        --sequences)
            SEQUENCE_FILTER="$2"
            shift 2
            ;;
        --no-visualization)
            ENABLE_VISUALIZATION=false
            shift
            ;;
        --output-dir)
            CUSTOM_OUTPUT_DIR="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --difficulty <easy|medium|hard|all>  Run only specified difficulty (default: all)"
            echo "  --sequences <seq1,seq2,...>          Run only specified sequences"
            echo "  --no-visualization                   Skip plot generation"
            echo "  --output-dir <path>                  Custom output directory"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Base paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORBSLAM_ROOT="$SCRIPT_DIR"
DATASET_ROOT="$SCRIPT_DIR/INTR6000P"

# Configuration
ORBSLAM_EXEC="$ORBSLAM_ROOT/Examples/Monocular/mono_euroc"
VOCABULARY="$ORBSLAM_ROOT/Vocabulary/ORBvoc.txt"
CAMERA_CONFIG="$DATASET_ROOT/tartanair.yaml"
GT_ROOT="$DATASET_ROOT/INTR6000P_GT_POSES"

# Output setup
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
if [[ -n "$CUSTOM_OUTPUT_DIR" ]]; then
    OUTPUT_ROOT="$CUSTOM_OUTPUT_DIR"
else
    OUTPUT_ROOT="$SCRIPT_DIR/output/batch_eval_results_${TIMESTAMP}"
fi
SUMMARY_FILE="$OUTPUT_ROOT/evaluation_summary.txt"
RESULTS_CSV="$OUTPUT_ROOT/results.csv"

# Create output directory
mkdir -p "$OUTPUT_ROOT"

# Validate prerequisites
if [[ ! -f "$ORBSLAM_EXEC" ]]; then
    log_error "ORB_SLAM2 executable not found: $ORBSLAM_EXEC"
    log_error "Please build ORB_SLAM2 first!"
    exit 1
fi

if [[ ! -f "$VOCABULARY" ]]; then
    log_error "Vocabulary file not found: $VOCABULARY"
    exit 1
fi

if [[ ! -d "$DATASET_ROOT" ]]; then
    log_error "Dataset not found: $DATASET_ROOT"
    exit 1
fi

# Check uv is available
if ! command -v uv &> /dev/null; then
    log_error "uv not found! Please install it first:"
    log_error "curl -LsSf https://astral.sh/uv/install.sh | sh"
    log_error "Then restart your shell or run: export PATH=\"\$HOME/.local/bin:\$PATH\""
    exit 1
fi

# Ensure uv is in PATH
export PATH="$HOME/.local/bin:$PATH"

# Dataset definition
declare -A SEQUENCES
SEQUENCES[easy]="carwelding2 factory1 hospital"
SEQUENCES[medium]="factory2 factory6"
SEQUENCES[hard]="amusement1 amusement2"

# Filter sequences based on arguments
declare -A FILTERED_SEQUENCES

if [[ "$DIFFICULTY_FILTER" == "all" ]]; then
    for diff in easy medium hard; do
        FILTERED_SEQUENCES[$diff]="${SEQUENCES[$diff]}"
    done
else
    if [[ -z "${SEQUENCES[$DIFFICULTY_FILTER]}" ]]; then
        log_error "Invalid difficulty: $DIFFICULTY_FILTER"
        log_error "Valid options: easy, medium, hard, all"
        exit 1
    fi
    FILTERED_SEQUENCES[$DIFFICULTY_FILTER]="${SEQUENCES[$DIFFICULTY_FILTER]}"
fi

if [[ -n "$SEQUENCE_FILTER" ]]; then
    IFS=',' read -ra SEQ_ARRAY <<< "$SEQUENCE_FILTER"
    declare -A TEMP_FILTERED
    for diff in "${!FILTERED_SEQUENCES[@]}"; do
        for seq in ${FILTERED_SEQUENCES[$diff]}; do
            for filter_seq in "${SEQ_ARRAY[@]}"; do
                if [[ "$seq" == "$filter_seq" ]]; then
                    TEMP_FILTERED[$diff]="${TEMP_FILTERED[$diff]} $seq"
                fi
            done
        done
    done
    FILTERED_SEQUENCES=()
    for diff in "${!TEMP_FILTERED[@]}"; do
        FILTERED_SEQUENCES[$diff]="${TEMP_FILTERED[$diff]}"
    done
fi

# Count total sequences
TOTAL_SEQUENCES=0
for diff in "${!FILTERED_SEQUENCES[@]}"; do
    for seq in ${FILTERED_SEQUENCES[$diff]}; do
        ((TOTAL_SEQUENCES++))
    done
done

if [[ $TOTAL_SEQUENCES -eq 0 ]]; then
    log_error "No sequences to evaluate!"
    exit 1
fi

# Print header
echo ""
echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║         INTR6000P Batch Evaluation Script                  ║${NC}"
echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
log_info "Total sequences to evaluate: $TOTAL_SEQUENCES"
log_info "Output directory: $OUTPUT_ROOT"
log_info "Visualization: $ENABLE_VISUALIZATION"
echo ""

# Initialize results storage
declare -A RMSE_RESULTS
declare -A MEAN_RESULTS
declare -A MEDIAN_RESULTS
declare -A STD_RESULTS
declare -A MIN_RESULTS
declare -A MAX_RESULTS
declare -A STATUS_RESULTS

CURRENT_SEQ=0
SUCCESSFUL_RUNS=0
FAILED_RUNS=0

# CSV header
echo "Difficulty,Sequence,Status,RMSE(m),Mean(m),Median(m),Std(m),Min(m),Max(m),Trajectory_File" > "$RESULTS_CSV"

# Main evaluation loop
for DIFFICULTY in easy medium hard; do
    if [[ -z "${FILTERED_SEQUENCES[$DIFFICULTY]}" ]]; then
        continue
    fi

    for SEQUENCE in ${FILTERED_SEQUENCES[$DIFFICULTY]}; do
        ((CURRENT_SEQ++))

        echo ""
        echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
        log_info "[$CURRENT_SEQ/$TOTAL_SEQUENCES] Processing: $DIFFICULTY/$SEQUENCE"
        echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"

        # Setup paths
        SEQ_PATH="$DATASET_ROOT/$DIFFICULTY/$SEQUENCE"
        IMAGES_PATH="$SEQ_PATH/image_left"
        TIMESTAMPS_FILE="$SEQ_PATH/timestamps.txt"
        GT_FILE="$GT_ROOT/$DIFFICULTY/${SEQUENCE}.txt"

        SEQ_OUTPUT_DIR="$OUTPUT_ROOT/${DIFFICULTY}_${SEQUENCE}"
        TRAJ_FILE="$SEQ_OUTPUT_DIR/trajectory.txt"
        LOG_FILE="$SEQ_OUTPUT_DIR/orbslam.log"
        EVO_STATS="$SEQ_OUTPUT_DIR/evo_statistics.txt"

        mkdir -p "$SEQ_OUTPUT_DIR"

        # Validate inputs
        if [[ ! -d "$SEQ_PATH" ]]; then
            log_error "Sequence not found: $SEQ_PATH"
            STATUS_RESULTS[${DIFFICULTY}_${SEQUENCE}]="MISSING_DATA"
            ((FAILED_RUNS++))
            continue
        fi

        if [[ ! -f "$GT_FILE" ]]; then
            log_error "Ground truth not found: $GT_FILE"
            STATUS_RESULTS[${DIFFICULTY}_${SEQUENCE}]="MISSING_GT"
            ((FAILED_RUNS++))
            continue
        fi

        # Run ORB_SLAM2
        log_info "Running ORB_SLAM2..."
        cd "$ORBSLAM_ROOT"

        START_TIME=$(date +%s)
        "$ORBSLAM_EXEC" "$VOCABULARY" "$CAMERA_CONFIG" "$IMAGES_PATH" "$TIMESTAMPS_FILE" > "$LOG_FILE" 2>&1
        SLAM_EXIT_CODE=$?
        END_TIME=$(date +%s)
        ELAPSED_TIME=$((END_TIME - START_TIME))

        if [[ $SLAM_EXIT_CODE -ne 0 ]]; then
            log_error "ORB_SLAM2 failed! Check log: $LOG_FILE"
            STATUS_RESULTS[${DIFFICULTY}_${SEQUENCE}]="SLAM_FAILED"
            ((FAILED_RUNS++))
            echo "$DIFFICULTY,$SEQUENCE,SLAM_FAILED,N/A,N/A,N/A,N/A,N/A,N/A,N/A" >> "$RESULTS_CSV"
            continue
        fi

        log_success "ORB_SLAM2 completed in ${ELAPSED_TIME}s"

        # Check for trajectory output
        FOUND_TRAJ=false
        if [[ -f "KeyFrameTrajectory.txt" ]]; then
            mv "KeyFrameTrajectory.txt" "$TRAJ_FILE"
            FOUND_TRAJ=true
        elif [[ -f "CameraTrajectory.txt" ]]; then
            mv "CameraTrajectory.txt" "$TRAJ_FILE"
            FOUND_TRAJ=true
        fi

        if [[ "$FOUND_TRAJ" == false ]]; then
            log_error "No trajectory file generated!"
            STATUS_RESULTS[${DIFFICULTY}_${SEQUENCE}]="NO_TRAJECTORY"
            ((FAILED_RUNS++))
            echo "$DIFFICULTY,$SEQUENCE,NO_TRAJECTORY,N/A,N/A,N/A,N/A,N/A,N/A,N/A" >> "$RESULTS_CSV"
            continue
        fi

        # Run EVO evaluation
        log_info "Running EVO evaluation..."

        export PATH="$HOME/.local/bin:$PATH"
        uv run --with evo evo_ape tum "$GT_FILE" "$TRAJ_FILE" \
            -r trans_part \
            --save_results "$SEQ_OUTPUT_DIR/ape_results.zip" \
            --verbose > "$EVO_STATS" 2>&1
        EVO_EXIT_CODE=$?

        if [[ $EVO_EXIT_CODE -ne 0 ]]; then
            log_error "EVO evaluation failed!"
            STATUS_RESULTS[${DIFFICULTY}_${SEQUENCE}]="EVO_FAILED"
            ((FAILED_RUNS++))
            echo "$DIFFICULTY,$SEQUENCE,EVO_FAILED,N/A,N/A,N/A,N/A,N/A,N/A,$TRAJ_FILE" >> "$RESULTS_CSV"
            continue
        fi

        # Generate visualization if enabled
        if [[ "$ENABLE_VISUALIZATION" == true ]]; then
            log_info "Generating visualization..."
            export PATH="$HOME/.local/bin:$PATH"
            uv run --with evo evo_ape tum "$GT_FILE" "$TRAJ_FILE" \
                -r trans_part \
                --plot --plot_mode xyz -as \
                --save_plot "$SEQ_OUTPUT_DIR/trajectory_plot.pdf" \
                > /dev/null 2>&1 || log_warn "Visualization generation failed (non-critical)"
        fi

        # Extract metrics
        if [[ -f "$EVO_STATS" ]]; then
            RMSE=$(grep -oP "rmse\s+\K[\d\.]+" "$EVO_STATS" | head -1)
            MEAN=$(grep -oP "mean\s+\K[\d\.]+" "$EVO_STATS" | head -1)
            MEDIAN=$(grep -oP "median\s+\K[\d\.]+" "$EVO_STATS" | head -1)
            STD=$(grep -oP "std\s+\K[\d\.]+" "$EVO_STATS" | head -1)
            MIN=$(grep -oP "min\s+\K[\d\.]+" "$EVO_STATS" | head -1)
            MAX=$(grep -oP "max\s+\K[\d\.]+" "$EVO_STATS" | head -1)

            RMSE_RESULTS[${DIFFICULTY}_${SEQUENCE}]="$RMSE"
            MEAN_RESULTS[${DIFFICULTY}_${SEQUENCE}]="$MEAN"
            MEDIAN_RESULTS[${DIFFICULTY}_${SEQUENCE}]="$MEDIAN"
            STD_RESULTS[${DIFFICULTY}_${SEQUENCE}]="$STD"
            MIN_RESULTS[${DIFFICULTY}_${SEQUENCE}]="$MIN"
            MAX_RESULTS[${DIFFICULTY}_${SEQUENCE}]="$MAX"
            STATUS_RESULTS[${DIFFICULTY}_${SEQUENCE}]="SUCCESS"

            log_success "Evaluation successful!"
            log_result "RMSE: ${RMSE}m | Mean: ${MEAN}m | Std: ${STD}m"

            echo "$DIFFICULTY,$SEQUENCE,SUCCESS,$RMSE,$MEAN,$MEDIAN,$STD,$MIN,$MAX,$TRAJ_FILE" >> "$RESULTS_CSV"
            ((SUCCESSFUL_RUNS++))
        else
            log_error "Could not extract metrics"
            STATUS_RESULTS[${DIFFICULTY}_${SEQUENCE}]="NO_METRICS"
            ((FAILED_RUNS++))
            echo "$DIFFICULTY,$SEQUENCE,NO_METRICS,N/A,N/A,N/A,N/A,N/A,N/A,$TRAJ_FILE" >> "$RESULTS_CSV"
        fi
    done
done

# Generate summary report
echo ""
echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║                 Evaluation Summary                         ║${NC}"
echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

{
    echo "INTR6000P Batch Evaluation Summary"
    echo "Generated: $(date)"
    echo "Total Sequences: $TOTAL_SEQUENCES"
    echo "Successful: $SUCCESSFUL_RUNS"
    echo "Failed: $FAILED_RUNS"
    echo ""
    echo "================================================================"
    echo "Detailed Results"
    echo "================================================================"
    echo ""

    for DIFFICULTY in easy medium hard; do
        if [[ -z "${FILTERED_SEQUENCES[$DIFFICULTY]}" ]]; then
            continue
        fi

        echo "[$DIFFICULTY]"
        echo "----------------------------------------------------------------"
        printf "%-20s %-10s %-10s %-10s %-10s\n" "Sequence" "Status" "RMSE(m)" "Mean(m)" "Std(m)"
        echo "----------------------------------------------------------------"

        for SEQUENCE in ${FILTERED_SEQUENCES[$DIFFICULTY]}; do
            KEY="${DIFFICULTY}_${SEQUENCE}"
            STATUS="${STATUS_RESULTS[$KEY]:-UNKNOWN}"
            RMSE="${RMSE_RESULTS[$KEY]:-N/A}"
            MEAN="${MEAN_RESULTS[$KEY]:-N/A}"
            STD="${STD_RESULTS[$KEY]:-N/A}"

            printf "%-20s %-10s %-10s %-10s %-10s\n" "$SEQUENCE" "$STATUS" "$RMSE" "$MEAN" "$STD"
        done
        echo ""
    done

    echo "================================================================"
    echo "Files Generated"
    echo "================================================================"
    echo "Summary: $SUMMARY_FILE"
    echo "CSV Results: $RESULTS_CSV"
    echo "Individual Results: $OUTPUT_ROOT/<difficulty>_<sequence>/"
    echo ""

} | tee "$SUMMARY_FILE"

# Display summary to terminal with colors
log_info "Results Summary:"
echo ""

for DIFFICULTY in easy medium hard; do
    if [[ -z "${FILTERED_SEQUENCES[$DIFFICULTY]}" ]]; then
        continue
    fi

    echo -e "${YELLOW}[$DIFFICULTY]${NC}"
    echo "----------------------------------------------------------------"
    printf "%-20s %-10s %-10s %-10s %-10s\n" "Sequence" "Status" "RMSE(m)" "Mean(m)" "Std(m)"
    echo "----------------------------------------------------------------"

    for SEQUENCE in ${FILTERED_SEQUENCES[$DIFFICULTY]}; do
        KEY="${DIFFICULTY}_${SEQUENCE}"
        STATUS="${STATUS_RESULTS[$KEY]:-UNKNOWN}"
        RMSE="${RMSE_RESULTS[$KEY]:-N/A}"
        MEAN="${MEAN_RESULTS[$KEY]:-N/A}"
        STD="${STD_RESULTS[$KEY]:-N/A}"

        if [[ "$STATUS" == "SUCCESS" ]]; then
            STATUS_COLOR="${GREEN}SUCCESS${NC}"
        else
            STATUS_COLOR="${RED}$STATUS${NC}"
        fi

        printf "%-20s %-20s %-10s %-10s %-10s\n" "$SEQUENCE" "$STATUS_COLOR" "$RMSE" "$MEAN" "$STD"
    done
    echo ""
done

echo ""
log_info "Complete results saved to: $OUTPUT_ROOT"
log_info "Summary: $SUMMARY_FILE"
log_info "CSV: $RESULTS_CSV"
echo ""

if [[ $SUCCESSFUL_RUNS -eq $TOTAL_SEQUENCES ]]; then
    log_success "All evaluations completed successfully!"
    exit 0
else
    log_warn "$FAILED_RUNS out of $TOTAL_SEQUENCES evaluations failed"
    exit 1
fi
