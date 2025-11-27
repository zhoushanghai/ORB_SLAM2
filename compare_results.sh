#!/bin/bash

################################################################################
# Results Comparison Script for INTR6000P Evaluations
#
# This script compares results from multiple evaluation runs and generates
# a side-by-side comparison report.
#
# Usage: bash compare_results.sh <result_dir1> <result_dir2> [result_dir3...]
# Example: bash compare_results.sh batch_eval_results_20251127_1/ batch_eval_results_20251127_2/
################################################################################

# Colors
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

# Check arguments
if [[ $# -lt 2 ]]; then
    log_error "Usage: $0 <result_dir1> <result_dir2> [result_dir3...]"
    echo "Example: $0 batch_eval_results_20251127_1/ batch_eval_results_20251127_2/"
    exit 1
fi

# Validate input directories
RESULT_DIRS=("$@")
for dir in "${RESULT_DIRS[@]}"; do
    if [[ ! -d "$dir" ]]; then
        log_error "Directory not found: $dir"
        exit 1
    fi
    if [[ ! -f "$dir/results.csv" ]]; then
        log_error "results.csv not found in: $dir"
        exit 1
    fi
done

# Create output directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_DIR="$SCRIPT_DIR/comparison_${TIMESTAMP}"
mkdir -p "$OUTPUT_DIR"

COMPARISON_FILE="$OUTPUT_DIR/comparison_report.txt"
COMPARISON_CSV="$OUTPUT_DIR/comparison.csv"

log_info "Comparing ${#RESULT_DIRS[@]} result sets..."
echo ""

# Print header
{
    echo "INTR6000P Results Comparison Report"
    echo "Generated: $(date)"
    echo ""
    echo "Comparing:"
    for i in "${!RESULT_DIRS[@]}"; do
        echo "  Run $((i+1)): ${RESULT_DIRS[$i]}"
    done
    echo ""
    echo "================================================================"
} | tee "$COMPARISON_FILE"

# Extract all unique sequences
declare -A ALL_SEQUENCES
for dir in "${RESULT_DIRS[@]}"; do
    while IFS=',' read -r difficulty sequence status rmse mean median std min max traj; do
        if [[ "$difficulty" != "Difficulty" ]]; then
            ALL_SEQUENCES["${difficulty}_${sequence}"]=1
        fi
    done < "$dir/results.csv"
done

# CSV header
echo -n "Difficulty,Sequence" > "$COMPARISON_CSV"
for i in "${!RESULT_DIRS[@]}"; do
    echo -n ",Run$((i+1))_Status,Run$((i+1))_RMSE,Run$((i+1))_Mean,Run$((i+1))_Std" >> "$COMPARISON_CSV"
done
echo "" >> "$COMPARISON_CSV"

# Compare each sequence
for DIFFICULTY in easy medium hard; do
    HAS_SEQUENCES=false

    for seq_key in $(echo "${!ALL_SEQUENCES[@]}" | tr ' ' '\n' | sort); do
        diff=$(echo "$seq_key" | cut -d'_' -f1)
        if [[ "$diff" != "$DIFFICULTY" ]]; then
            continue
        fi

        if [[ "$HAS_SEQUENCES" == false ]]; then
            {
                echo ""
                echo "[$DIFFICULTY]"
                echo "----------------------------------------------------------------"
            } | tee -a "$COMPARISON_FILE"
            HAS_SEQUENCES=true
        fi

        sequence=$(echo "$seq_key" | cut -d'_' -f2-)

        echo "" | tee -a "$COMPARISON_FILE"
        echo -e "${YELLOW}Sequence: $sequence${NC}" | tee -a "$COMPARISON_FILE"

        # CSV line start
        echo -n "$DIFFICULTY,$sequence" >> "$COMPARISON_CSV"

        # Compare across all runs
        declare -a RMSE_VALUES
        declare -a STATUS_VALUES

        for i in "${!RESULT_DIRS[@]}"; do
            dir="${RESULT_DIRS[$i]}"

            # Find sequence in CSV
            line=$(grep "^$DIFFICULTY,$sequence," "$dir/results.csv")

            if [[ -n "$line" ]]; then
                IFS=',' read -r d s status rmse mean median std min max traj <<< "$line"
                STATUS_VALUES[$i]="$status"
                RMSE_VALUES[$i]="$rmse"

                echo "  Run $((i+1)): Status=$status, RMSE=${rmse}m, Mean=${mean}m, Std=${std}m" | tee -a "$COMPARISON_FILE"
                echo -n ",$status,$rmse,$mean,$std" >> "$COMPARISON_CSV"
            else
                STATUS_VALUES[$i]="NOT_RUN"
                RMSE_VALUES[$i]="N/A"
                echo "  Run $((i+1)): NOT_RUN" | tee -a "$COMPARISON_FILE"
                echo -n ",NOT_RUN,N/A,N/A,N/A" >> "$COMPARISON_CSV"
            fi
        done

        echo "" >> "$COMPARISON_CSV"

        # Calculate improvement if applicable
        if [[ ${#RESULT_DIRS[@]} -eq 2 ]] && [[ "${STATUS_VALUES[0]}" == "SUCCESS" ]] && [[ "${STATUS_VALUES[1]}" == "SUCCESS" ]]; then
            RMSE1="${RMSE_VALUES[0]}"
            RMSE2="${RMSE_VALUES[1]}"

            if [[ "$RMSE1" != "N/A" ]] && [[ "$RMSE2" != "N/A" ]]; then
                IMPROVEMENT=$(echo "scale=4; (($RMSE1 - $RMSE2) / $RMSE1) * 100" | bc 2>/dev/null || echo "N/A")
                if [[ "$IMPROVEMENT" != "N/A" ]]; then
                    if (( $(echo "$IMPROVEMENT > 0" | bc -l) )); then
                        echo -e "  ${GREEN}Improvement: +${IMPROVEMENT}%${NC}" | tee -a "$COMPARISON_FILE"
                    elif (( $(echo "$IMPROVEMENT < 0" | bc -l) )); then
                        DEGRADATION=$(echo "scale=4; $IMPROVEMENT * -1" | bc)
                        echo -e "  ${RED}Degradation: -${DEGRADATION}%${NC}" | tee -a "$COMPARISON_FILE"
                    else
                        echo "  No change" | tee -a "$COMPARISON_FILE"
                    fi
                fi
            fi
        fi
    done
done

# Summary statistics
{
    echo ""
    echo "================================================================"
    echo "Summary Statistics"
    echo "================================================================"
    echo ""
} | tee -a "$COMPARISON_FILE"

for i in "${!RESULT_DIRS[@]}"; do
    dir="${RESULT_DIRS[$i]}"
    echo "Run $((i+1)): ${RESULT_DIRS[$i]}" | tee -a "$COMPARISON_FILE"

    # Count successes
    SUCCESS_COUNT=$(grep ",SUCCESS," "$dir/results.csv" | wc -l)
    TOTAL_COUNT=$(tail -n +2 "$dir/results.csv" | wc -l)

    echo "  Total Sequences: $TOTAL_COUNT" | tee -a "$COMPARISON_FILE"
    echo "  Successful: $SUCCESS_COUNT" | tee -a "$COMPARISON_FILE"
    echo "  Failed: $((TOTAL_COUNT - SUCCESS_COUNT))" | tee -a "$COMPARISON_FILE"

    # Average RMSE for successful runs
    AVG_RMSE=$(grep ",SUCCESS," "$dir/results.csv" | cut -d',' -f4 | \
        awk '{sum+=$1; count++} END {if(count>0) printf "%.4f", sum/count; else print "N/A"}')
    echo "  Average RMSE: ${AVG_RMSE}m" | tee -a "$COMPARISON_FILE"

    # Best and worst RMSE
    if [[ "$AVG_RMSE" != "N/A" ]]; then
        BEST_RMSE=$(grep ",SUCCESS," "$dir/results.csv" | cut -d',' -f2,4 | \
            sort -t',' -k2 -n | head -1)
        WORST_RMSE=$(grep ",SUCCESS," "$dir/results.csv" | cut -d',' -f2,4 | \
            sort -t',' -k2 -n | tail -1)

        BEST_SEQ=$(echo "$BEST_RMSE" | cut -d',' -f1)
        BEST_VAL=$(echo "$BEST_RMSE" | cut -d',' -f2)
        WORST_SEQ=$(echo "$WORST_RMSE" | cut -d',' -f1)
        WORST_VAL=$(echo "$WORST_RMSE" | cut -d',' -f2)

        echo "  Best: $BEST_SEQ (${BEST_VAL}m)" | tee -a "$COMPARISON_FILE"
        echo "  Worst: $WORST_SEQ (${WORST_VAL}m)" | tee -a "$COMPARISON_FILE"
    fi

    echo "" | tee -a "$COMPARISON_FILE"
done

# Overall comparison for 2 runs
if [[ ${#RESULT_DIRS[@]} -eq 2 ]]; then
    {
        echo "================================================================"
        echo "Overall Comparison (Run 1 vs Run 2)"
        echo "================================================================"
        echo ""
    } | tee -a "$COMPARISON_FILE"

    # Get average RMSEs
    AVG_RMSE1=$(grep ",SUCCESS," "${RESULT_DIRS[0]}/results.csv" | cut -d',' -f4 | \
        awk '{sum+=$1; count++} END {if(count>0) printf "%.4f", sum/count; else print "N/A"}')
    AVG_RMSE2=$(grep ",SUCCESS," "${RESULT_DIRS[1]}/results.csv" | cut -d',' -f4 | \
        awk '{sum+=$1; count++} END {if(count>0) printf "%.4f", sum/count; else print "N/A"}')

    if [[ "$AVG_RMSE1" != "N/A" ]] && [[ "$AVG_RMSE2" != "N/A" ]]; then
        OVERALL_IMPROVEMENT=$(echo "scale=2; (($AVG_RMSE1 - $AVG_RMSE2) / $AVG_RMSE1) * 100" | bc)

        echo "Average RMSE Run 1: ${AVG_RMSE1}m" | tee -a "$COMPARISON_FILE"
        echo "Average RMSE Run 2: ${AVG_RMSE2}m" | tee -a "$COMPARISON_FILE"
        echo "" | tee -a "$COMPARISON_FILE"

        if (( $(echo "$OVERALL_IMPROVEMENT > 0" | bc -l) )); then
            echo -e "${GREEN}Overall Improvement: +${OVERALL_IMPROVEMENT}%${NC}" | tee -a "$COMPARISON_FILE"
        elif (( $(echo "$OVERALL_IMPROVEMENT < 0" | bc -l) )); then
            DEGRADATION=$(echo "scale=2; $OVERALL_IMPROVEMENT * -1" | bc)
            echo -e "${RED}Overall Degradation: -${DEGRADATION}%${NC}" | tee -a "$COMPARISON_FILE"
        else
            echo "No overall change" | tee -a "$COMPARISON_FILE"
        fi
    fi
fi

{
    echo ""
    echo "================================================================"
    echo "Output Files"
    echo "================================================================"
    echo "Report: $COMPARISON_FILE"
    echo "CSV: $COMPARISON_CSV"
    echo ""
} | tee -a "$COMPARISON_FILE"

log_success "Comparison complete!"
log_info "Results saved to: $OUTPUT_DIR"
echo ""
