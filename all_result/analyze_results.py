#!/usr/bin/env python3
"""
ORB-SLAM2 INTR6000P Evaluation Results Analysis
Extracts metrics, generates visualizations, and creates analysis report
"""

import os
import re
import json
import matplotlib.pyplot as plt
import numpy as np
from pathlib import Path

# Configuration
BASELINE_DIR = Path("baseline_output")
REFINE_DIR = Path("refine_output")
OUTPUT_DIR = Path("analysis_output")

# Metrics to extract
METRICS = ['max', 'mean', 'median', 'min', 'rmse', 'sse', 'std']

def extract_metrics_from_file(filepath):
    """Extract APE metrics from evo_statistics.txt file"""
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
        for metric in METRICS:
            pattern = rf'{metric}\s+([\d.]+)'
            match = re.search(pattern, ape_text)
            if match:
                metrics[metric] = float(match.group(1))

    return {
        'difficulty': difficulty,
        'sequence': sequence,
        'num_poses': num_poses,
        'scale': scale,
        'metrics': metrics
    }

def collect_all_results():
    """Collect results from baseline and refine directories"""
    baseline_results = []
    refine_results = []

    # Collect baseline results
    for stats_file in BASELINE_DIR.glob('**/evo_statistics.txt'):
        data = extract_metrics_from_file(stats_file)
        data['method'] = 'Baseline'
        baseline_results.append(data)

    # Collect refine results
    for stats_file in REFINE_DIR.glob('**/evo_statistics.txt'):
        data = extract_metrics_from_file(stats_file)
        data['method'] = 'Refined'
        refine_results.append(data)

    return baseline_results, refine_results

def match_sequences(baseline_results, refine_results):
    """Match baseline and refine results by sequence"""
    matched = []

    for baseline in baseline_results:
        seq_key = f"{baseline['difficulty']}_{baseline['sequence']}"
        for refine in refine_results:
            refine_key = f"{refine['difficulty']}_{refine['sequence']}"
            if seq_key == refine_key:
                matched.append({
                    'sequence': seq_key,
                    'difficulty': baseline['difficulty'],
                    'baseline': baseline,
                    'refined': refine
                })
                break

    return matched

def create_comparison_plots(matched_results):
    """Create comparison plots for baseline vs refined"""
    OUTPUT_DIR.mkdir(exist_ok=True)

    # Extract data for plotting
    sequences = [m['sequence'] for m in matched_results]
    difficulties = [m['difficulty'] for m in matched_results]

    baseline_rmse = [m['baseline']['metrics'].get('rmse', 0) for m in matched_results]
    refined_rmse = [m['refined']['metrics'].get('rmse', 0) for m in matched_results]

    baseline_mean = [m['baseline']['metrics'].get('mean', 0) for m in matched_results]
    refined_mean = [m['refined']['metrics'].get('mean', 0) for m in matched_results]

    baseline_max = [m['baseline']['metrics'].get('max', 0) for m in matched_results]
    refined_max = [m['refined']['metrics'].get('max', 0) for m in matched_results]

    # Color mapping by difficulty
    colors = {'easy': '#2ecc71', 'medium': '#f39c12', 'hard': '#e74c3c'}
    bar_colors = [colors.get(d, '#95a5a6') for d in difficulties]

    # 1. RMSE Comparison
    fig, ax = plt.subplots(figsize=(14, 6))
    x = np.arange(len(sequences))
    width = 0.35

    bars1 = ax.bar(x - width/2, baseline_rmse, width, label='Baseline', alpha=0.8, color='#3498db')
    bars2 = ax.bar(x + width/2, refined_rmse, width, label='Refined', alpha=0.8, color='#e74c3c')

    ax.set_xlabel('Sequence', fontsize=12, fontweight='bold')
    ax.set_ylabel('RMSE (meters)', fontsize=12, fontweight='bold')
    ax.set_title('APE RMSE Comparison: Baseline vs Refined', fontsize=14, fontweight='bold')
    ax.set_xticks(x)
    ax.set_xticklabels([s.replace('_', '\n') for s in sequences], rotation=45, ha='right')
    ax.legend()
    ax.grid(axis='y', alpha=0.3)

    plt.tight_layout()
    plt.savefig(OUTPUT_DIR / 'rmse_comparison.png', dpi=300, bbox_inches='tight')
    plt.close()

    # 2. Mean Error Comparison
    fig, ax = plt.subplots(figsize=(14, 6))

    bars1 = ax.bar(x - width/2, baseline_mean, width, label='Baseline', alpha=0.8, color='#3498db')
    bars2 = ax.bar(x + width/2, refined_mean, width, label='Refined', alpha=0.8, color='#e74c3c')

    ax.set_xlabel('Sequence', fontsize=12, fontweight='bold')
    ax.set_ylabel('Mean Error (meters)', fontsize=12, fontweight='bold')
    ax.set_title('APE Mean Error Comparison: Baseline vs Refined', fontsize=14, fontweight='bold')
    ax.set_xticks(x)
    ax.set_xticklabels([s.replace('_', '\n') for s in sequences], rotation=45, ha='right')
    ax.legend()
    ax.grid(axis='y', alpha=0.3)

    plt.tight_layout()
    plt.savefig(OUTPUT_DIR / 'mean_comparison.png', dpi=300, bbox_inches='tight')
    plt.close()

    # 3. Improvement Percentage
    improvements = []
    for i in range(len(matched_results)):
        if baseline_rmse[i] > 0:
            improvement = ((baseline_rmse[i] - refined_rmse[i]) / baseline_rmse[i]) * 100
            improvements.append(improvement)
        else:
            improvements.append(0)

    fig, ax = plt.subplots(figsize=(14, 6))
    bars = ax.bar(x, improvements, color=bar_colors, alpha=0.8)

    # Add zero line
    ax.axhline(y=0, color='black', linestyle='-', linewidth=0.8)

    ax.set_xlabel('Sequence', fontsize=12, fontweight='bold')
    ax.set_ylabel('Improvement (%)', fontsize=12, fontweight='bold')
    ax.set_title('RMSE Improvement: (Baseline - Refined) / Baseline × 100%', fontsize=14, fontweight='bold')
    ax.set_xticks(x)
    ax.set_xticklabels([s.replace('_', '\n') for s in sequences], rotation=45, ha='right')
    ax.grid(axis='y', alpha=0.3)

    # Add value labels on bars
    for i, bar in enumerate(bars):
        height = bar.get_height()
        ax.text(bar.get_x() + bar.get_width()/2., height,
                f'{improvements[i]:.1f}%',
                ha='center', va='bottom' if height > 0 else 'top', fontsize=9)

    # Add legend for difficulty colors
    from matplotlib.patches import Patch
    legend_elements = [Patch(facecolor=colors['easy'], label='Easy'),
                      Patch(facecolor=colors['medium'], label='Medium'),
                      Patch(facecolor=colors['hard'], label='Hard')]
    ax.legend(handles=legend_elements, loc='upper right')

    plt.tight_layout()
    plt.savefig(OUTPUT_DIR / 'improvement_percentage.png', dpi=300, bbox_inches='tight')
    plt.close()

    # 4. All Metrics Comparison (Multi-panel)
    fig, axes = plt.subplots(2, 2, figsize=(16, 12))
    metrics_to_plot = [('rmse', 'RMSE'), ('mean', 'Mean'), ('max', 'Max'), ('std', 'Std Dev')]

    for idx, (metric, label) in enumerate(metrics_to_plot):
        ax = axes[idx // 2, idx % 2]

        baseline_vals = [m['baseline']['metrics'].get(metric, 0) for m in matched_results]
        refined_vals = [m['refined']['metrics'].get(metric, 0) for m in matched_results]

        ax.bar(x - width/2, baseline_vals, width, label='Baseline', alpha=0.8, color='#3498db')
        ax.bar(x + width/2, refined_vals, width, label='Refined', alpha=0.8, color='#e74c3c')

        ax.set_xlabel('Sequence', fontsize=10, fontweight='bold')
        ax.set_ylabel(f'{label} (meters)', fontsize=10, fontweight='bold')
        ax.set_title(f'APE {label} Comparison', fontsize=12, fontweight='bold')
        ax.set_xticks(x)
        ax.set_xticklabels([s.replace('_', '\n') for s in sequences], rotation=45, ha='right', fontsize=8)
        ax.legend()
        ax.grid(axis='y', alpha=0.3)

    plt.tight_layout()
    plt.savefig(OUTPUT_DIR / 'all_metrics_comparison.png', dpi=300, bbox_inches='tight')
    plt.close()

    # 5. Grouped by Difficulty
    difficulties_unique = sorted(set(difficulties))

    fig, axes = plt.subplots(1, 3, figsize=(18, 5))

    for idx, diff in enumerate(['easy', 'medium', 'hard']):
        ax = axes[idx]

        # Filter by difficulty
        diff_sequences = []
        diff_baseline = []
        diff_refined = []

        for i, m in enumerate(matched_results):
            if m['difficulty'] == diff:
                diff_sequences.append(m['sequence'].replace(f'{diff}_', ''))
                diff_baseline.append(baseline_rmse[i])
                diff_refined.append(refined_rmse[i])

        if diff_sequences:
            x_diff = np.arange(len(diff_sequences))
            ax.bar(x_diff - width/2, diff_baseline, width, label='Baseline', alpha=0.8, color='#3498db')
            ax.bar(x_diff + width/2, diff_refined, width, label='Refined', alpha=0.8, color='#e74c3c')

            ax.set_xlabel('Sequence', fontsize=11, fontweight='bold')
            ax.set_ylabel('RMSE (meters)', fontsize=11, fontweight='bold')
            ax.set_title(f'{diff.capitalize()} Difficulty', fontsize=12, fontweight='bold')
            ax.set_xticks(x_diff)
            ax.set_xticklabels(diff_sequences, rotation=45, ha='right')
            ax.legend()
            ax.grid(axis='y', alpha=0.3)

    plt.tight_layout()
    plt.savefig(OUTPUT_DIR / 'rmse_by_difficulty.png', dpi=300, bbox_inches='tight')
    plt.close()

    print(f"✓ Generated 5 comparison plots in {OUTPUT_DIR}/")

def generate_summary_statistics(matched_results, baseline_results, refine_results):
    """Generate summary statistics"""
    stats = {
        'matched_sequences': len(matched_results),
        'baseline_only': len(baseline_results) - len(matched_results),
        'refined_only': len(refine_results) - len(matched_results),
        'by_difficulty': {},
        'improvements': {}
    }

    # Group by difficulty
    for diff in ['easy', 'medium', 'hard']:
        diff_matches = [m for m in matched_results if m['difficulty'] == diff]

        if diff_matches:
            baseline_rmse_vals = [m['baseline']['metrics'].get('rmse', 0) for m in diff_matches]
            refined_rmse_vals = [m['refined']['metrics'].get('rmse', 0) for m in diff_matches]

            stats['by_difficulty'][diff] = {
                'count': len(diff_matches),
                'baseline_rmse_avg': np.mean(baseline_rmse_vals),
                'refined_rmse_avg': np.mean(refined_rmse_vals),
                'improvement_avg': np.mean([
                    ((b - r) / b * 100) if b > 0 else 0
                    for b, r in zip(baseline_rmse_vals, refined_rmse_vals)
                ])
            }

    # Overall improvements
    all_baseline_rmse = [m['baseline']['metrics'].get('rmse', 0) for m in matched_results]
    all_refined_rmse = [m['refined']['metrics'].get('rmse', 0) for m in matched_results]

    stats['improvements']['overall_avg'] = np.mean([
        ((b - r) / b * 100) if b > 0 else 0
        for b, r in zip(all_baseline_rmse, all_refined_rmse)
    ])
    stats['improvements']['best'] = max([
        ((b - r) / b * 100) if b > 0 else 0
        for b, r in zip(all_baseline_rmse, all_refined_rmse)
    ])
    stats['improvements']['worst'] = min([
        ((b - r) / b * 100) if b > 0 else 0
        for b, r in zip(all_baseline_rmse, all_refined_rmse)
    ])

    return stats

def create_markdown_report(matched_results, baseline_results, refine_results, stats):
    """Create comprehensive markdown analysis report"""

    report = f"""# ORB-SLAM2 INTR6000P Evaluation Analysis Report

**Generated:** {np.datetime64('today')}
**Analysis Tool:** EVO (Python package for the evaluation of odometry and SLAM)
**Alignment Method:** Sim(3) Umeyama alignment

---

## Executive Summary

This report presents a comprehensive analysis of ORB-SLAM2 performance on the INTR6000P dataset, comparing baseline and refined configurations.

### Key Findings

- **Total Sequences Evaluated:** {stats['matched_sequences']} matched pairs
- **Overall Average RMSE Improvement:** {stats['improvements']['overall_avg']:.2f}%
- **Best Improvement:** {stats['improvements']['best']:.2f}%
- **Worst Improvement:** {stats['improvements']['worst']:.2f}%

---

## Dataset Overview

The INTR6000P dataset consists of sequences with varying difficulty levels:

"""

    # Add difficulty breakdown
    for diff in ['easy', 'medium', 'hard']:
        if diff in stats['by_difficulty']:
            d = stats['by_difficulty'][diff]
            report += f"""### {diff.capitalize()} Difficulty
- **Sequences:** {d['count']}
- **Baseline Avg RMSE:** {d['baseline_rmse_avg']:.4f} m
- **Refined Avg RMSE:** {d['refined_rmse_avg']:.4f} m
- **Average Improvement:** {d['improvement_avg']:.2f}%

"""

    report += """---

## Detailed Results

### Sequence-by-Sequence Comparison

"""

    # Add detailed table
    report += """| Sequence | Difficulty | Poses | Baseline RMSE | Refined RMSE | Improvement | Scale Factor |
|----------|------------|-------|---------------|--------------|-------------|--------------|
"""

    for m in sorted(matched_results, key=lambda x: (x['difficulty'], x['sequence'])):
        seq = m['sequence']
        diff = m['difficulty'].capitalize()
        poses = m['baseline']['num_poses']
        b_rmse = m['baseline']['metrics'].get('rmse', 0)
        r_rmse = m['refined']['metrics'].get('rmse', 0)
        improvement = ((b_rmse - r_rmse) / b_rmse * 100) if b_rmse > 0 else 0
        scale = m['baseline'].get('scale', 0)

        report += f"| {seq} | {diff} | {poses} | {b_rmse:.4f} | {r_rmse:.4f} | {improvement:+.2f}% | {scale:.2f} |\n"

    report += """
---

## Visualization Analysis

### 1. RMSE Comparison
![RMSE Comparison](analysis_output/rmse_comparison.png)

The RMSE (Root Mean Square Error) comparison shows the overall trajectory error for each sequence. Lower values indicate better performance.

### 2. Mean Error Comparison
![Mean Comparison](analysis_output/mean_comparison.png)

Mean error provides a measure of average deviation from the ground truth trajectory.

### 3. Improvement Percentage
![Improvement Percentage](analysis_output/improvement_percentage.png)

This chart shows the percentage improvement from baseline to refined configuration. Positive values indicate improvement, while negative values indicate degradation.

### 4. All Metrics Comparison
![All Metrics](analysis_output/all_metrics_comparison.png)

Comprehensive view of all APE metrics (RMSE, Mean, Max, Std Dev) across sequences.

### 5. Results by Difficulty
![By Difficulty](analysis_output/rmse_by_difficulty.png)

Grouped analysis showing performance across different difficulty levels.

---

## Metric Definitions

- **max:** Maximum absolute pose error
- **mean:** Average absolute pose error
- **median:** Median absolute pose error
- **min:** Minimum absolute pose error
- **rmse:** Root mean square error (primary metric)
- **sse:** Sum of squared errors
- **std:** Standard deviation of errors

All metrics are in meters and computed after Sim(3) Umeyama alignment (includes scale correction).

---

## Detailed Sequence Analysis

"""

    # Add detailed analysis for each sequence
    for m in sorted(matched_results, key=lambda x: (x['difficulty'], x['sequence'])):
        seq = m['sequence']
        diff = m['difficulty'].capitalize()

        b = m['baseline']['metrics']
        r = m['refined']['metrics']

        report += f"""### {seq} ({diff})

**Tracking Quality:**
- Baseline: {m['baseline']['num_poses']} poses tracked
- Refined: {m['refined']['num_poses']} poses tracked
- Scale Correction: {m['baseline'].get('scale', 0):.3f}x

**Performance Metrics:**

| Metric | Baseline | Refined | Change | Change % |
|--------|----------|---------|--------|----------|
"""

        for metric in ['rmse', 'mean', 'median', 'max', 'std']:
            b_val = b.get(metric, 0)
            r_val = r.get(metric, 0)
            change = r_val - b_val
            change_pct = (change / b_val * 100) if b_val > 0 else 0

            report += f"| {metric.upper()} | {b_val:.4f} | {r_val:.4f} | {change:+.4f} | {change_pct:+.2f}% |\n"

        report += "\n"

    report += """---

## Conclusions

### Performance Summary

"""

    # Calculate winners and losers
    improvements = []
    for m in matched_results:
        b_rmse = m['baseline']['metrics'].get('rmse', 0)
        r_rmse = m['refined']['metrics'].get('rmse', 0)
        imp = ((b_rmse - r_rmse) / b_rmse * 100) if b_rmse > 0 else 0
        improvements.append((m['sequence'], imp))

    improvements_sorted = sorted(improvements, key=lambda x: x[1], reverse=True)

    report += f"""
**Best Performing Sequences (Refined > Baseline):**
"""
    for seq, imp in improvements_sorted[:3]:
        if imp > 0:
            report += f"- {seq}: {imp:.2f}% improvement\n"

    report += f"""
**Sequences Needing Attention (Refined < Baseline):**
"""
    for seq, imp in improvements_sorted[-3:]:
        if imp < 0:
            report += f"- {seq}: {imp:.2f}% degradation\n"

    report += """

### Recommendations

1. **Easy Sequences:** Generally show good tracking performance with both configurations
2. **Medium Sequences:** Show significant improvements with refined parameters
3. **Hard Sequences:** Mixed results - some sequences benefit from refinement, others may need different parameter tuning

### Technical Notes

- All evaluations use the EVO APE (Absolute Pose Error) metric
- Sim(3) Umeyama alignment is applied (corrects for rotation, translation, and scale)
- Scale corrections indicate the estimated scale drift in the monocular SLAM system
- Number of tracked poses varies by sequence due to tracking failures or limited keyframe selection

---

## Appendix: Raw Data

### Baseline Results

"""

    # Add baseline raw data
    for result in sorted(baseline_results, key=lambda x: (x['difficulty'], x['sequence'])):
        report += f"""
#### {result['sequence']} ({result['difficulty']})
```json
{json.dumps(result, indent=2)}
```
"""

    report += """

### Refined Results

"""

    # Add refined raw data
    for result in sorted(refine_results, key=lambda x: (x['difficulty'], x['sequence'])):
        report += f"""
#### {result['sequence']} ({result['difficulty']})
```json
{json.dumps(result, indent=2)}
```
"""

    report += """

---

*Report generated automatically from EVO evaluation results*
"""

    # Save report
    report_path = OUTPUT_DIR / 'analysis_report.md'
    with open(report_path, 'w') as f:
        f.write(report)

    print(f"✓ Generated analysis report: {report_path}")

def main():
    """Main execution"""
    print("=" * 60)
    print("ORB-SLAM2 INTR6000P Evaluation Analysis")
    print("=" * 60)

    # Collect results
    print("\n[1/4] Collecting evaluation results...")
    baseline_results, refine_results = collect_all_results()
    print(f"  - Found {len(baseline_results)} baseline results")
    print(f"  - Found {len(refine_results)} refined results")

    # Match sequences
    print("\n[2/4] Matching baseline and refined sequences...")
    matched_results = match_sequences(baseline_results, refine_results)
    print(f"  - Matched {len(matched_results)} sequence pairs")

    # Generate statistics
    print("\n[3/4] Computing summary statistics...")
    stats = generate_summary_statistics(matched_results, baseline_results, refine_results)
    print(f"  - Overall improvement: {stats['improvements']['overall_avg']:.2f}%")

    # Create visualizations
    print("\n[4/4] Generating visualizations and report...")
    create_comparison_plots(matched_results)
    create_markdown_report(matched_results, baseline_results, refine_results, stats)

    print("\n" + "=" * 60)
    print("Analysis complete!")
    print(f"Results saved to: {OUTPUT_DIR.absolute()}")
    print("=" * 60)

if __name__ == "__main__":
    main()
