#!/bin/bash

################################################################################
# Results Visualization Script for INTR6000P Evaluations
#
# This script provides quick visualization and analysis of evaluation results.
#
# Usage: bash visualize_results.sh <result_directory>
# Example: bash visualize_results.sh batch_eval_results_20251127_123456/
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
if [[ $# -ne 1 ]]; then
    log_error "Usage: $0 <result_directory>"
    echo "Example: $0 batch_eval_results_20251127_123456/"
    exit 1
fi

RESULT_DIR="$1"

# Validate directory
if [[ ! -d "$RESULT_DIR" ]]; then
    log_error "Directory not found: $RESULT_DIR"
    exit 1
fi

if [[ ! -f "$RESULT_DIR/results.csv" ]]; then
    log_error "results.csv not found in: $RESULT_DIR"
    exit 1
fi

CSV_FILE="$RESULT_DIR/results.csv"

echo ""
echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║         INTR6000P Results Visualization                    ║${NC}"
echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

log_info "Result Directory: $RESULT_DIR"
echo ""

# Overall Statistics
TOTAL_SEQUENCES=$(tail -n +2 "$CSV_FILE" | wc -l)
SUCCESS_COUNT=$(grep ",SUCCESS," "$CSV_FILE" | wc -l)
FAILED_COUNT=$((TOTAL_SEQUENCES - SUCCESS_COUNT))

echo -e "${CYAN}Overall Statistics:${NC}"
echo "----------------------------------------------------------------"
echo "Total Sequences:     $TOTAL_SEQUENCES"
echo "Successful:          $SUCCESS_COUNT ($(echo "scale=1; $SUCCESS_COUNT * 100 / $TOTAL_SEQUENCES" | bc)%)"
echo "Failed:              $FAILED_COUNT ($(echo "scale=1; $FAILED_COUNT * 100 / $TOTAL_SEQUENCES" | bc)%)"
echo ""

# RMSE Statistics (for successful runs only)
if [[ $SUCCESS_COUNT -gt 0 ]]; then
    echo -e "${CYAN}RMSE Statistics (meters):${NC}"
    echo "----------------------------------------------------------------"

    grep ",SUCCESS," "$CSV_FILE" | cut -d',' -f4 | awk '
    BEGIN { min=999999; max=0; sum=0; count=0; }
    {
        sum += $1;
        count++;
        if ($1 < min) min = $1;
        if ($1 > max) max = $1;
        values[count] = $1;
    }
    END {
        mean = sum / count;
        # Calculate standard deviation
        sumsq = 0;
        for (i=1; i<=count; i++) {
            sumsq += (values[i] - mean) ^ 2;
        }
        stddev = sqrt(sumsq / count);

        printf "Mean:                %.4f\n", mean;
        printf "Std Dev:             %.4f\n", stddev;
        printf "Min:                 %.4f\n", min;
        printf "Max:                 %.4f\n", max;
    }
    '
    echo ""
fi

# Results by Difficulty
echo -e "${CYAN}Results by Difficulty:${NC}"
echo "----------------------------------------------------------------"

for DIFFICULTY in easy medium hard; do
    DIFF_TOTAL=$(grep "^$DIFFICULTY," "$CSV_FILE" | wc -l)
    if [[ $DIFF_TOTAL -eq 0 ]]; then
        continue
    fi

    DIFF_SUCCESS=$(grep "^$DIFFICULTY,.*,SUCCESS," "$CSV_FILE" | wc -l)
    DIFF_FAILED=$((DIFF_TOTAL - DIFF_SUCCESS))

    echo ""
    echo -e "${YELLOW}[$DIFFICULTY]${NC}"

    if [[ $DIFF_SUCCESS -gt 0 ]]; then
        AVG_RMSE=$(grep "^$DIFFICULTY,.*,SUCCESS," "$CSV_FILE" | cut -d',' -f4 | \
            awk '{sum+=$1; count++} END {printf "%.4f", sum/count}')
        echo "  Sequences:  $DIFF_SUCCESS/$DIFF_TOTAL successful"
        echo "  Avg RMSE:   ${AVG_RMSE}m"

        # Best and worst
        BEST=$(grep "^$DIFFICULTY,.*,SUCCESS," "$CSV_FILE" | cut -d',' -f2,4 | \
            sort -t',' -k2 -n | head -1)
        WORST=$(grep "^$DIFFICULTY,.*,SUCCESS," "$CSV_FILE" | cut -d',' -f2,4 | \
            sort -t',' -k2 -n | tail -1)

        BEST_SEQ=$(echo "$BEST" | cut -d',' -f1)
        BEST_RMSE=$(echo "$BEST" | cut -d',' -f2)
        WORST_SEQ=$(echo "$WORST" | cut -d',' -f1)
        WORST_RMSE=$(echo "$WORST" | cut -d',' -f2)

        echo -e "  Best:       ${GREEN}$BEST_SEQ (${BEST_RMSE}m)${NC}"
        echo -e "  Worst:      ${RED}$WORST_SEQ (${WORST_RMSE}m)${NC}"
    else
        echo "  Sequences:  0/$DIFF_TOTAL successful"
        echo "  All sequences failed!"
    fi
done

echo ""

# Failed Sequences Details
if [[ $FAILED_COUNT -gt 0 ]]; then
    echo -e "${CYAN}Failed Sequences:${NC}"
    echo "----------------------------------------------------------------"
    grep -v ",SUCCESS," "$CSV_FILE" | grep -v "^Difficulty" | while IFS=',' read -r difficulty sequence status rest; do
        echo -e "  ${RED}✗${NC} $difficulty/$sequence - $status"
    done
    echo ""
fi

# Top 5 Best Results
if [[ $SUCCESS_COUNT -gt 0 ]]; then
    echo -e "${CYAN}Top 5 Best Results:${NC}"
    echo "----------------------------------------------------------------"
    grep ",SUCCESS," "$CSV_FILE" | cut -d',' -f1,2,4 | sort -t',' -k3 -n | head -5 | \
        awk -F',' '{printf "  %d. %-10s %-20s RMSE: %.4fm\n", NR, $1, $2, $3}'
    echo ""
fi

# Top 5 Worst Results
if [[ $SUCCESS_COUNT -gt 5 ]]; then
    echo -e "${CYAN}Top 5 Worst Results:${NC}"
    echo "----------------------------------------------------------------"
    grep ",SUCCESS," "$CSV_FILE" | cut -d',' -f1,2,4 | sort -t',' -k3 -nr | head -5 | \
        awk -F',' '{printf "  %d. %-10s %-20s RMSE: %.4fm\n", NR, $1, $2, $3}'
    echo ""
fi

# RMSE Distribution
if [[ $SUCCESS_COUNT -gt 0 ]]; then
    echo -e "${CYAN}RMSE Distribution:${NC}"
    echo "----------------------------------------------------------------"

    EXCELLENT=$(grep ",SUCCESS," "$CSV_FILE" | cut -d',' -f4 | awk '$1 < 0.1' | wc -l)
    GOOD=$(grep ",SUCCESS," "$CSV_FILE" | cut -d',' -f4 | awk '$1 >= 0.1 && $1 < 0.3' | wc -l)
    MEDIUM=$(grep ",SUCCESS," "$CSV_FILE" | cut -d',' -f4 | awk '$1 >= 0.3 && $1 < 0.5' | wc -l)
    POOR=$(grep ",SUCCESS," "$CSV_FILE" | cut -d',' -f4 | awk '$1 >= 0.5' | wc -l)

    echo "  Excellent (< 0.1m):    $EXCELLENT"
    echo "  Good (0.1-0.3m):       $GOOD"
    echo "  Medium (0.3-0.5m):     $MEDIUM"
    echo "  Poor (>= 0.5m):        $POOR"
    echo ""

    # ASCII Bar Chart
    echo "  Visual Distribution:"
    MAX_COUNT=$(echo -e "$EXCELLENT\n$GOOD\n$MEDIUM\n$POOR" | sort -n | tail -1)
    if [[ $MAX_COUNT -gt 0 ]]; then
        BAR_WIDTH=40

        print_bar() {
            local count=$1
            local label=$2
            local color=$3
            local bar_length=$((count * BAR_WIDTH / MAX_COUNT))
            printf "    %-15s ${color}" "$label"
            for ((i=0; i<bar_length; i++)); do printf "█"; done
            printf "${NC} %d\n" "$count"
        }

        print_bar $EXCELLENT "Excellent" "$GREEN"
        print_bar $GOOD "Good" "$CYAN"
        print_bar $MEDIUM "Medium" "$YELLOW"
        print_bar $POOR "Poor" "$RED"
    fi
    echo ""
fi

# Available Files
echo -e "${CYAN}Available Output Files:${NC}"
echo "----------------------------------------------------------------"
ls -lh "$RESULT_DIR" | tail -n +2 | awk '{printf "  %s  %s\n", $9, $5}'
echo ""

# Quick Actions
echo -e "${CYAN}Quick Actions:${NC}"
echo "----------------------------------------------------------------"
echo "View summary:        cat $RESULT_DIR/evaluation_summary.txt"
echo "View CSV:            cat $RESULT_DIR/results.csv"
echo "Open CSV:            libreoffice $RESULT_DIR/results.csv"

if ls "$RESULT_DIR"/*/trajectory_plot.pdf 1> /dev/null 2>&1; then
    FIRST_PDF=$(ls "$RESULT_DIR"/*/trajectory_plot.pdf | head -1)
    echo "View plots:          evince $RESULT_DIR/*/trajectory_plot.pdf"
fi

if ls "$RESULT_DIR"/*/evo_statistics.txt 1> /dev/null 2>&1; then
    echo "View EVO stats:      cat $RESULT_DIR/*/evo_statistics.txt"
fi

echo ""

# Check if we can generate combined plots with EVO
if command -v evo_ape &> /dev/null; then
    echo -e "${CYAN}Advanced Visualization (EVO):${NC}"
    echo "----------------------------------------------------------------"
    echo "To generate combined trajectory plots, run:"
    echo ""
    echo "workon evaluation"
    for DIFFICULTY in easy medium hard; do
        if grep "^$DIFFICULTY,.*,SUCCESS," "$CSV_FILE" > /dev/null 2>&1; then
            echo "# $DIFFICULTY sequences:"
            grep "^$DIFFICULTY,.*,SUCCESS," "$CSV_FILE" | while IFS=',' read -r diff seq status rmse mean median std min max traj; do
                GT_FILE="$RESULT_DIR/../INTR6000P/INTR6000P_GT_POSES/$diff/${seq}.txt"
                if [[ -f "$traj" ]] && [[ -f "$GT_FILE" ]]; then
                    echo "evo_traj tum $GT_FILE --ref $traj -p --plot_mode xyz"
                fi
            done | head -3
        fi
    done
    echo ""
fi

log_success "Visualization complete!"
echo ""
