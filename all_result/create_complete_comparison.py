#!/usr/bin/env python3
"""
Complete comparison of all sequences including failed ones
"""

import os
import re
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
import numpy as np
from pathlib import Path

# Configuration
BASELINE_DIR = Path("baseline_output")
REFINE_DIR = Path("refine_output")
OUTPUT_DIR = Path("analysis_output")

def extract_metrics_from_file(filepath):
    """Extract APE metrics from evo_statistics.txt file"""
    try:
        with open(filepath, 'r') as f:
            content = f.read()

        # Extract sequence info
        gt_match = re.search(r'INTR6000P_GT_POSES/(\w+)/(\w+)\.txt', content)
        difficulty = gt_match.group(1) if gt_match else "unknown"
        sequence = gt_match.group(2) if gt_match else "unknown"

        # Extract number of poses
        poses_match = re.search(r'Compared (\d+) absolute pose pairs', content)
        num_poses = int(poses_match.group(1)) if poses_match else 0

        # Extract scale correction
        scale_match = re.search(r'Scale correction: ([\d.]+)', content)
        scale = float(scale_match.group(1)) if scale_match else None

        # Extract APE metrics (with Sim(3) Umeyama alignment)
        metrics = {}
        ape_section = re.search(r'APE w\.r\.t\. translation part \(m\)\s+\(with Sim\(3\) Umeyama alignment\)(.*?)---',
                                content, re.DOTALL)

        if ape_section:
            ape_text = ape_section.group(1)
            for metric in ['max', 'mean', 'median', 'min', 'rmse', 'sse', 'std']:
                pattern = rf'{metric}\s+([\d.]+)'
                match = re.search(pattern, ape_text)
                if match:
                    metrics[metric] = float(match.group(1))

        return {
            'difficulty': difficulty,
            'sequence': sequence,
            'num_poses': num_poses,
            'scale': scale,
            'metrics': metrics,
            'status': 'success'
        }
    except Exception as e:
        return {
            'difficulty': 'unknown',
            'sequence': 'unknown',
            'num_poses': 0,
            'scale': None,
            'metrics': {},
            'status': 'failed'
        }

def get_all_expected_sequences():
    """Get all expected sequences from the dataset"""
    return {
        'easy': ['carwelding2', 'factory1', 'hospital'],
        'medium': ['factory2', 'factory6'],
        'hard': ['amusement1', 'amusement2']
    }

def collect_all_results_complete():
    """Collect all results including missing/failed sequences"""
    expected = get_all_expected_sequences()

    # Create a complete list of all expected sequences
    all_sequences = {}
    for diff, seqs in expected.items():
        for seq in seqs:
            key = f"{diff}_{seq}"
            all_sequences[key] = {
                'difficulty': diff,
                'sequence': seq,
                'baseline': None,
                'refined': None
            }

    # Collect baseline results
    for stats_file in BASELINE_DIR.glob('**/evo_statistics.txt'):
        data = extract_metrics_from_file(stats_file)
        key = f"{data['difficulty']}_{data['sequence']}"
        if key in all_sequences:
            all_sequences[key]['baseline'] = data

    # Collect refine results
    for stats_file in REFINE_DIR.glob('**/evo_statistics.txt'):
        data = extract_metrics_from_file(stats_file)
        key = f"{data['difficulty']}_{data['sequence']}"
        if key in all_sequences:
            all_sequences[key]['refined'] = data

    return all_sequences

def create_complete_comparison_table(all_sequences):
    """Create comprehensive comparison table with all sequences"""

    # Sort sequences by difficulty and name
    sorted_keys = sorted(all_sequences.keys(),
                        key=lambda x: (all_sequences[x]['difficulty'], all_sequences[x]['sequence']))

    fig, ax = plt.subplots(figsize=(20, 12))
    ax.axis('tight')
    ax.axis('off')

    # Table headers
    headers = ['Sequence', 'Difficulty', 'Baseline\nStatus', 'Baseline\nPoses', 'Baseline\nRMSE (m)',
               'Refined\nStatus', 'Refined\nPoses', 'Refined\nRMSE (m)', 'Improvement\n(%)', 'Notes']

    # Prepare table data
    table_data = []

    for key in sorted_keys:
        seq_data = all_sequences[key]
        seq_name = seq_data['sequence']
        difficulty = seq_data['difficulty'].capitalize()

        baseline = seq_data['baseline']
        refined = seq_data['refined']

        # Baseline info
        if baseline and baseline['num_poses'] > 0:
            b_status = '✓ Success'
            b_poses = str(baseline['num_poses'])
            b_rmse = f"{baseline['metrics'].get('rmse', 0):.4f}"
        elif baseline:
            b_status = '✗ Failed'
            b_poses = '0'
            b_rmse = 'N/A'
        else:
            b_status = '- Missing'
            b_poses = '-'
            b_rmse = '-'

        # Refined info
        if refined and refined['num_poses'] > 0:
            r_status = '✓ Success'
            r_poses = str(refined['num_poses'])
            r_rmse = f"{refined['metrics'].get('rmse', 0):.4f}"
        elif refined:
            r_status = '✗ Failed'
            r_poses = '0'
            r_rmse = 'N/A'
        else:
            r_status = '- Missing'
            r_poses = '-'
            r_rmse = '-'

        # Calculate improvement
        if (baseline and baseline['num_poses'] > 0 and
            refined and refined['num_poses'] > 0):
            b_rmse_val = baseline['metrics'].get('rmse', 0)
            r_rmse_val = refined['metrics'].get('rmse', 0)
            if b_rmse_val > 0:
                improvement = ((b_rmse_val - r_rmse_val) / b_rmse_val) * 100
                improvement_str = f"{improvement:+.2f}%"
            else:
                improvement_str = 'N/A'
        else:
            improvement_str = 'N/A'
            improvement = None

        # Notes
        notes = []
        if not baseline:
            notes.append('No baseline')
        elif baseline['num_poses'] == 0:
            notes.append('Baseline failed')

        if not refined:
            notes.append('No refined')
        elif refined['num_poses'] == 0:
            notes.append('Refined failed')

        if improvement is not None:
            if improvement > 50:
                notes.append('Major improvement')
            elif improvement > 20:
                notes.append('Good improvement')
            elif improvement < -20:
                notes.append('Significant degradation')

        notes_str = ', '.join(notes) if notes else 'OK'

        table_data.append([
            seq_name, difficulty, b_status, b_poses, b_rmse,
            r_status, r_poses, r_rmse, improvement_str, notes_str
        ])

    # Create table
    table = ax.table(cellText=table_data, colLabels=headers,
                    cellLoc='center', loc='center',
                    colWidths=[0.12, 0.08, 0.10, 0.08, 0.10, 0.10, 0.08, 0.10, 0.10, 0.14])

    table.auto_set_font_size(False)
    table.set_fontsize(9)
    table.scale(1, 2.5)

    # Style the header
    for i in range(len(headers)):
        cell = table[(0, i)]
        cell.set_facecolor('#4472C4')
        cell.set_text_props(weight='bold', color='white')

    # Color code rows based on difficulty and status
    colors = {'easy': '#D5E8D4', 'medium': '#FFF4CC', 'hard': '#F8CECC'}

    for i, key in enumerate(sorted_keys):
        seq_data = all_sequences[key]
        difficulty = seq_data['difficulty']
        color = colors.get(difficulty, '#FFFFFF')

        for j in range(len(headers)):
            cell = table[(i + 1, j)]
            cell.set_facecolor(color)

            # Highlight issues
            cell_text = cell.get_text().get_text()
            if 'Failed' in cell_text or 'Missing' in cell_text:
                cell.set_text_props(color='red', weight='bold')
            elif '✓' in cell_text:
                cell.set_text_props(color='green', weight='bold')

    plt.title('Complete ORB-SLAM2 Evaluation: All Sequences Comparison',
             fontsize=16, fontweight='bold', pad=20)

    plt.savefig(OUTPUT_DIR / 'complete_comparison_table.png', dpi=300, bbox_inches='tight')
    plt.close()

    print(f"✓ Generated complete comparison table")

def create_success_rate_chart(all_sequences):
    """Create chart showing success rates"""

    difficulties = ['easy', 'medium', 'hard']
    baseline_success = []
    refined_success = []
    total_counts = []

    for diff in difficulties:
        seqs_in_diff = [s for s in all_sequences.values() if s['difficulty'] == diff]
        total = len(seqs_in_diff)
        total_counts.append(total)

        b_success = sum(1 for s in seqs_in_diff
                       if s['baseline'] and s['baseline']['num_poses'] > 0)
        r_success = sum(1 for s in seqs_in_diff
                       if s['refined'] and s['refined']['num_poses'] > 0)

        baseline_success.append(b_success)
        refined_success.append(r_success)

    fig, ax = plt.subplots(figsize=(12, 7))

    x = np.arange(len(difficulties))
    width = 0.35

    bars1 = ax.bar(x - width/2, baseline_success, width, label='Baseline', alpha=0.8, color='#3498db')
    bars2 = ax.bar(x + width/2, refined_success, width, label='Refined', alpha=0.8, color='#e74c3c')

    # Add total count labels
    for i, (b, r, total) in enumerate(zip(baseline_success, refined_success, total_counts)):
        ax.text(i, max(b, r) + 0.2, f'Total: {total}', ha='center', fontweight='bold')

        # Add success count on bars
        ax.text(i - width/2, b + 0.1, str(b), ha='center', va='bottom', fontweight='bold')
        ax.text(i + width/2, r + 0.1, str(r), ha='center', va='bottom', fontweight='bold')

    ax.set_xlabel('Difficulty Level', fontsize=12, fontweight='bold')
    ax.set_ylabel('Number of Successful Sequences', fontsize=12, fontweight='bold')
    ax.set_title('Tracking Success Rate by Difficulty', fontsize=14, fontweight='bold')
    ax.set_xticks(x)
    ax.set_xticklabels([d.capitalize() for d in difficulties])
    ax.legend()
    ax.grid(axis='y', alpha=0.3)

    # Set y-axis to show integers
    ax.set_ylim(0, max(total_counts) + 1)
    ax.yaxis.set_major_locator(plt.MaxNLocator(integer=True))

    plt.tight_layout()
    plt.savefig(OUTPUT_DIR / 'success_rate_chart.png', dpi=300, bbox_inches='tight')
    plt.close()

    print(f"✓ Generated success rate chart")

def create_rmse_comparison_all(all_sequences):
    """Create RMSE comparison including failed sequences"""

    fig, ax = plt.subplots(figsize=(16, 8))

    # Sort sequences
    sorted_keys = sorted(all_sequences.keys(),
                        key=lambda x: (all_sequences[x]['difficulty'], all_sequences[x]['sequence']))

    sequences = []
    baseline_rmse = []
    refined_rmse = []
    colors_list = []

    colors = {'easy': '#2ecc71', 'medium': '#f39c12', 'hard': '#e74c3c'}

    for key in sorted_keys:
        seq_data = all_sequences[key]
        sequences.append(f"{seq_data['difficulty']}_{seq_data['sequence']}")
        colors_list.append(colors.get(seq_data['difficulty'], '#95a5a6'))

        baseline = seq_data['baseline']
        refined = seq_data['refined']

        # Get RMSE or use NaN for failed/missing
        b_val = baseline['metrics'].get('rmse', np.nan) if baseline and baseline['num_poses'] > 0 else np.nan
        r_val = refined['metrics'].get('rmse', np.nan) if refined and refined['num_poses'] > 0 else np.nan

        baseline_rmse.append(b_val)
        refined_rmse.append(r_val)

    x = np.arange(len(sequences))
    width = 0.35

    # Create bars, handling NaN values
    for i in range(len(sequences)):
        if not np.isnan(baseline_rmse[i]):
            ax.bar(i - width/2, baseline_rmse[i], width, color='#3498db', alpha=0.8)
        else:
            # Draw a crossed-out bar for failed sequences
            ax.bar(i - width/2, 0.05, width, color='#cccccc', alpha=0.5, hatch='///')
            ax.text(i - width/2, 0.025, 'FAIL', ha='center', va='center',
                   fontsize=7, fontweight='bold', color='red')

        if not np.isnan(refined_rmse[i]):
            ax.bar(i + width/2, refined_rmse[i], width, color='#e74c3c', alpha=0.8)
        else:
            ax.bar(i + width/2, 0.05, width, color='#cccccc', alpha=0.5, hatch='///')
            ax.text(i + width/2, 0.025, 'FAIL', ha='center', va='center',
                   fontsize=7, fontweight='bold', color='red')

    # Create custom legend
    from matplotlib.patches import Patch
    legend_elements = [
        Patch(facecolor='#3498db', alpha=0.8, label='Baseline'),
        Patch(facecolor='#e74c3c', alpha=0.8, label='Refined'),
        Patch(facecolor='#cccccc', alpha=0.5, hatch='///', label='Failed/Missing')
    ]

    ax.set_xlabel('Sequence', fontsize=12, fontweight='bold')
    ax.set_ylabel('RMSE (meters)', fontsize=12, fontweight='bold')
    ax.set_title('RMSE Comparison: All Sequences (Including Failed)', fontsize=14, fontweight='bold')
    ax.set_xticks(x)
    ax.set_xticklabels([s.replace('_', '\n') for s in sequences], rotation=45, ha='right', fontsize=9)
    ax.legend(handles=legend_elements)
    ax.grid(axis='y', alpha=0.3)

    plt.tight_layout()
    plt.savefig(OUTPUT_DIR / 'rmse_comparison_all_sequences.png', dpi=300, bbox_inches='tight')
    plt.close()

    print(f"✓ Generated RMSE comparison for all sequences")

def generate_csv_export(all_sequences):
    """Export complete data to CSV"""
    import csv

    csv_path = OUTPUT_DIR / 'complete_comparison_data.csv'

    sorted_keys = sorted(all_sequences.keys(),
                        key=lambda x: (all_sequences[x]['difficulty'], all_sequences[x]['sequence']))

    with open(csv_path, 'w', newline='') as f:
        writer = csv.writer(f)

        # Write header
        writer.writerow([
            'Sequence', 'Difficulty',
            'Baseline_Status', 'Baseline_Poses', 'Baseline_RMSE', 'Baseline_Mean', 'Baseline_Median', 'Baseline_Max', 'Baseline_Std', 'Baseline_Scale',
            'Refined_Status', 'Refined_Poses', 'Refined_RMSE', 'Refined_Mean', 'Refined_Median', 'Refined_Max', 'Refined_Std', 'Refined_Scale',
            'RMSE_Improvement_Percent', 'Mean_Improvement_Percent'
        ])

        for key in sorted_keys:
            seq_data = all_sequences[key]
            baseline = seq_data['baseline']
            refined = seq_data['refined']

            row = [seq_data['sequence'], seq_data['difficulty']]

            # Baseline data
            if baseline and baseline['num_poses'] > 0:
                row.extend([
                    'Success',
                    baseline['num_poses'],
                    baseline['metrics'].get('rmse', ''),
                    baseline['metrics'].get('mean', ''),
                    baseline['metrics'].get('median', ''),
                    baseline['metrics'].get('max', ''),
                    baseline['metrics'].get('std', ''),
                    baseline.get('scale', '')
                ])
            elif baseline:
                row.extend(['Failed', 0, '', '', '', '', '', ''])
            else:
                row.extend(['Missing', '', '', '', '', '', '', ''])

            # Refined data
            if refined and refined['num_poses'] > 0:
                row.extend([
                    'Success',
                    refined['num_poses'],
                    refined['metrics'].get('rmse', ''),
                    refined['metrics'].get('mean', ''),
                    refined['metrics'].get('median', ''),
                    refined['metrics'].get('max', ''),
                    refined['metrics'].get('std', ''),
                    refined.get('scale', '')
                ])
            elif refined:
                row.extend(['Failed', 0, '', '', '', '', '', ''])
            else:
                row.extend(['Missing', '', '', '', '', '', '', ''])

            # Calculate improvements
            if (baseline and baseline['num_poses'] > 0 and
                refined and refined['num_poses'] > 0):
                b_rmse = baseline['metrics'].get('rmse', 0)
                r_rmse = refined['metrics'].get('rmse', 0)
                rmse_imp = ((b_rmse - r_rmse) / b_rmse * 100) if b_rmse > 0 else ''

                b_mean = baseline['metrics'].get('mean', 0)
                r_mean = refined['metrics'].get('mean', 0)
                mean_imp = ((b_mean - r_mean) / b_mean * 100) if b_mean > 0 else ''

                row.extend([rmse_imp, mean_imp])
            else:
                row.extend(['', ''])

            writer.writerow(row)

    print(f"✓ Exported data to CSV: {csv_path}")

def main():
    """Main execution"""
    print("=" * 60)
    print("Complete ORB-SLAM2 Evaluation Analysis (All Sequences)")
    print("=" * 60)

    OUTPUT_DIR.mkdir(exist_ok=True)

    print("\n[1/5] Collecting all results (including failed)...")
    all_sequences = collect_all_results_complete()
    print(f"  - Total sequences: {len(all_sequences)}")

    print("\n[2/5] Creating complete comparison table...")
    create_complete_comparison_table(all_sequences)

    print("\n[3/5] Creating success rate chart...")
    create_success_rate_chart(all_sequences)

    print("\n[4/5] Creating RMSE comparison for all sequences...")
    create_rmse_comparison_all(all_sequences)

    print("\n[5/5] Exporting data to CSV...")
    generate_csv_export(all_sequences)

    # Print summary
    print("\n" + "=" * 60)
    print("Summary Statistics")
    print("=" * 60)

    baseline_success = sum(1 for s in all_sequences.values()
                          if s['baseline'] and s['baseline']['num_poses'] > 0)
    refined_success = sum(1 for s in all_sequences.values()
                         if s['refined'] and s['refined']['num_poses'] > 0)

    print(f"Total sequences: {len(all_sequences)}")
    print(f"Baseline successful: {baseline_success}/{len(all_sequences)}")
    print(f"Refined successful: {refined_success}/{len(all_sequences)}")

    print("\n" + "=" * 60)
    print("Analysis complete!")
    print(f"Results saved to: {OUTPUT_DIR.absolute()}")
    print("=" * 60)

if __name__ == "__main__":
    main()
