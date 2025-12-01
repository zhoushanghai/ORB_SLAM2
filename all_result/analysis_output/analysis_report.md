# ORB-SLAM2 INTR6000P Evaluation Analysis Report

**Generated:** 2025-12-01
**Analysis Tool:** EVO (Python package for the evaluation of odometry and SLAM)
**Alignment Method:** Sim(3) Umeyama alignment

---

## Executive Summary

This report presents a comprehensive analysis of ORB-SLAM2 performance on the INTR6000P dataset, comparing baseline and refined configurations.

### Key Findings

- **Total Sequences Evaluated:** 5 matched pairs
- **Overall Average RMSE Improvement:** 18.31%
- **Best Improvement:** 75.43%
- **Worst Improvement:** -63.28%

---

## Dataset Overview

The INTR6000P dataset consists of sequences with varying difficulty levels:

### Easy Difficulty
- **Sequences:** 2
- **Baseline Avg RMSE:** 0.4449 m
- **Refined Avg RMSE:** 0.2686 m
- **Average Improvement:** 45.03%

### Medium Difficulty
- **Sequences:** 2
- **Baseline Avg RMSE:** 0.1436 m
- **Refined Avg RMSE:** 0.0971 m
- **Average Improvement:** 32.37%

### Hard Difficulty
- **Sequences:** 1
- **Baseline Avg RMSE:** 0.1425 m
- **Refined Avg RMSE:** 0.2326 m
- **Average Improvement:** -63.28%

---

## Detailed Results

### Sequence-by-Sequence Comparison

| Sequence | Difficulty | Poses | Baseline RMSE | Refined RMSE | Improvement | Scale Factor |
|----------|------------|-------|---------------|--------------|-------------|--------------|
| easy_carwelding2 | Easy | 296 | 0.5238 | 0.4472 | +14.63% | 13.06 |
| easy_factory1 | Easy | 79 | 0.3660 | 0.0899 | +75.43% | 3.94 |
| hard_amusement1 | Hard | 156 | 0.1425 | 0.2326 | -63.28% | 5.84 |
| medium_factory2 | Medium | 216 | 0.1437 | 0.1473 | -2.52% | 4.53 |
| medium_factory6 | Medium | 139 | 0.1434 | 0.0469 | +67.27% | 1.41 |

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

### easy_carwelding2 (Easy)

**Tracking Quality:**
- Baseline: 296 poses tracked
- Refined: 301 poses tracked
- Scale Correction: 13.058x

**Performance Metrics:**

| Metric | Baseline | Refined | Change | Change % |
|--------|----------|---------|--------|----------|
| RMSE | 0.5238 | 0.4472 | -0.0766 | -14.63% |
| MEAN | 0.4842 | 0.4239 | -0.0603 | -12.45% |
| MEDIAN | 0.5033 | 0.4041 | -0.0992 | -19.71% |
| MAX | 0.9620 | 0.7012 | -0.2608 | -27.11% |
| STD | 0.1999 | 0.1425 | -0.0575 | -28.74% |

### easy_factory1 (Easy)

**Tracking Quality:**
- Baseline: 79 poses tracked
- Refined: 79 poses tracked
- Scale Correction: 3.936x

**Performance Metrics:**

| Metric | Baseline | Refined | Change | Change % |
|--------|----------|---------|--------|----------|
| RMSE | 0.3660 | 0.0899 | -0.2761 | -75.43% |
| MEAN | 0.2053 | 0.0789 | -0.1264 | -61.57% |
| MEDIAN | 0.1098 | 0.0637 | -0.0461 | -41.96% |
| MAX | 2.0465 | 0.2089 | -1.8376 | -89.79% |
| STD | 0.3030 | 0.0431 | -0.2599 | -85.78% |

### hard_amusement1 (Hard)

**Tracking Quality:**
- Baseline: 156 poses tracked
- Refined: 154 poses tracked
- Scale Correction: 5.837x

**Performance Metrics:**

| Metric | Baseline | Refined | Change | Change % |
|--------|----------|---------|--------|----------|
| RMSE | 0.1425 | 0.2326 | +0.0902 | +63.28% |
| MEAN | 0.1289 | 0.1972 | +0.0682 | +52.93% |
| MEDIAN | 0.1207 | 0.1711 | +0.0504 | +41.75% |
| MAX | 0.3049 | 0.8437 | +0.5388 | +176.75% |
| STD | 0.0606 | 0.1234 | +0.0628 | +103.63% |

### medium_factory2 (Medium)

**Tracking Quality:**
- Baseline: 216 poses tracked
- Refined: 190 poses tracked
- Scale Correction: 4.534x

**Performance Metrics:**

| Metric | Baseline | Refined | Change | Change % |
|--------|----------|---------|--------|----------|
| RMSE | 0.1437 | 0.1473 | +0.0036 | +2.52% |
| MEAN | 0.1260 | 0.1210 | -0.0051 | -4.01% |
| MEDIAN | 0.1095 | 0.0973 | -0.0121 | -11.09% |
| MAX | 0.4437 | 0.4313 | -0.0124 | -2.79% |
| STD | 0.0691 | 0.0842 | +0.0150 | +21.71% |

### medium_factory6 (Medium)

**Tracking Quality:**
- Baseline: 139 poses tracked
- Refined: 126 poses tracked
- Scale Correction: 1.407x

**Performance Metrics:**

| Metric | Baseline | Refined | Change | Change % |
|--------|----------|---------|--------|----------|
| RMSE | 0.1434 | 0.0469 | -0.0964 | -67.27% |
| MEAN | 0.1249 | 0.0415 | -0.0834 | -66.78% |
| MEDIAN | 0.1102 | 0.0387 | -0.0715 | -64.90% |
| MAX | 0.3236 | 0.1132 | -0.2104 | -65.03% |
| STD | 0.0703 | 0.0219 | -0.0484 | -68.83% |

---

## Conclusions

### Performance Summary


**Best Performing Sequences (Refined > Baseline):**
- easy_factory1: 75.43% improvement
- medium_factory6: 67.27% improvement
- easy_carwelding2: 14.63% improvement

**Sequences Needing Attention (Refined < Baseline):**
- medium_factory2: -2.52% degradation
- hard_amusement1: -63.28% degradation


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


#### carwelding2 (easy)
```json
{
  "difficulty": "easy",
  "sequence": "carwelding2",
  "num_poses": 296,
  "scale": 13.05830827006703,
  "metrics": {
    "max": 0.961962,
    "mean": 0.484179,
    "median": 0.503342,
    "min": 0.096464,
    "rmse": 0.523824,
    "sse": 81.220056,
    "std": 0.199906
  },
  "method": "Baseline"
}
```

#### factory1 (easy)
```json
{
  "difficulty": "easy",
  "sequence": "factory1",
  "num_poses": 79,
  "scale": 3.936284912517205,
  "metrics": {
    "max": 2.046518,
    "mean": 0.20531,
    "median": 0.109811,
    "min": 0.039595,
    "rmse": 0.365968,
    "sse": 10.580691,
    "std": 0.302953
  },
  "method": "Baseline"
}
```

#### amusement1 (hard)
```json
{
  "difficulty": "hard",
  "sequence": "amusement1",
  "num_poses": 156,
  "scale": 5.83674212549155,
  "metrics": {
    "max": 0.304853,
    "mean": 0.128917,
    "median": 0.120723,
    "min": 0.025409,
    "rmse": 0.142456,
    "sse": 3.165815,
    "std": 0.060613
  },
  "method": "Baseline"
}
```

#### factory2 (medium)
```json
{
  "difficulty": "medium",
  "sequence": "factory2",
  "num_poses": 216,
  "scale": 4.533583099724821,
  "metrics": {
    "max": 0.443675,
    "mean": 0.126004,
    "median": 0.10949,
    "min": 0.030431,
    "rmse": 0.143727,
    "sse": 4.461984,
    "std": 0.06914
  },
  "method": "Baseline"
}
```

#### factory6 (medium)
```json
{
  "difficulty": "medium",
  "sequence": "factory6",
  "num_poses": 139,
  "scale": 1.4074903928533176,
  "metrics": {
    "max": 0.323574,
    "mean": 0.124946,
    "median": 0.110162,
    "min": 0.020764,
    "rmse": 0.143385,
    "sse": 2.857756,
    "std": 0.070341
  },
  "method": "Baseline"
}
```


### Refined Results


#### carwelding2 (easy)
```json
{
  "difficulty": "easy",
  "sequence": "carwelding2",
  "num_poses": 301,
  "scale": 12.232828479705075,
  "metrics": {
    "max": 0.701182,
    "mean": 0.423906,
    "median": 0.404118,
    "min": 0.171081,
    "rmse": 0.447201,
    "sse": 60.196665,
    "std": 0.142451
  },
  "method": "Refined"
}
```

#### factory1 (easy)
```json
{
  "difficulty": "easy",
  "sequence": "factory1",
  "num_poses": 79,
  "scale": 3.707760162628059,
  "metrics": {
    "max": 0.208906,
    "mean": 0.078901,
    "median": 0.063733,
    "min": 0.019291,
    "rmse": 0.089901,
    "sse": 0.638494,
    "std": 0.043091
  },
  "method": "Refined"
}
```

#### amusement1 (hard)
```json
{
  "difficulty": "hard",
  "sequence": "amusement1",
  "num_poses": 154,
  "scale": 6.474572264929936,
  "metrics": {
    "max": 0.843693,
    "mean": 0.197157,
    "median": 0.171119,
    "min": 0.023742,
    "rmse": 0.232606,
    "sse": 8.33224,
    "std": 0.123429
  },
  "method": "Refined"
}
```

#### amusement2 (hard)
```json
{
  "difficulty": "hard",
  "sequence": "amusement2",
  "num_poses": 22,
  "scale": 4.559927733907792,
  "metrics": {
    "max": 0.019199,
    "mean": 0.009526,
    "median": 0.010324,
    "min": 0.000888,
    "rmse": 0.010706,
    "sse": 0.002522,
    "std": 0.004887
  },
  "method": "Refined"
}
```

#### factory2 (medium)
```json
{
  "difficulty": "medium",
  "sequence": "factory2",
  "num_poses": 190,
  "scale": 4.680786556438453,
  "metrics": {
    "max": 0.431287,
    "mean": 0.120953,
    "median": 0.097345,
    "min": 0.010435,
    "rmse": 0.147347,
    "sse": 4.12512,
    "std": 0.084152
  },
  "method": "Refined"
}
```

#### factory6 (medium)
```json
{
  "difficulty": "medium",
  "sequence": "factory6",
  "num_poses": 126,
  "scale": 2.434310172373008,
  "metrics": {
    "max": 0.113159,
    "mean": 0.041502,
    "median": 0.038669,
    "min": 0.006458,
    "rmse": 0.046936,
    "sse": 0.277577,
    "std": 0.021922
  },
  "method": "Refined"
}
```


---

*Report generated automatically from EVO evaluation results*
