# EVO 评估修复说明

## 问题描述

原始的评估脚本保存的是**未对齐**的APE结果，这导致：
- RMSE值非常大（例如16-28m）
- 结果受到尺度和全局坐标系差异的影响
- 无法真实反映SLAM的相对轨迹精度

## 修复内容

### 修改文件
- `quick_eval_intr6000p.sh`

### 主要变更

#### 1. 添加 Sim(3) Umeyama 对齐选项

**修改位置**: 第126-134行

**修改前**:
```bash
echo 'Running EVO APE...'
uv run --with evo evo_ape tum "$GT_FILE" "$TRAJ_FILE" \
    -r trans_part \
    --save_results "$OUTPUT_DIR/ape_results.zip" \
    --verbose > "$EVO_STATS" 2>&1
```

**修改后**:
```bash
echo 'Running EVO APE with Sim(3) Umeyama alignment...'
uv run --with evo evo_ape tum "$GT_FILE" "$TRAJ_FILE" \
    -r trans_part \
    -as \
    --save_results "$OUTPUT_DIR/ape_results.zip" \
    --verbose > "$EVO_STATS" 2>&1
```

**关键变化**: 添加了 `-as` 选项（align with scale correction）

#### 2. 优化结果显示

**修改位置**: 第150-157行

**修改前**:
```bash
if [[ -f "$EVO_STATS" ]]; then
    echo ""
    grep -A 10 "^APE" "$EVO_STATS" || grep -i "rmse\|mean\|std" "$EVO_STATS" || cat "$EVO_STATS"
    echo ""
fi
```

**修改后**:
```bash
if [[ -f "$EVO_STATS" ]]; then
    echo ""
    echo "APE Statistics (with Sim(3) Umeyama alignment):"
    echo "================================================"
    # Extract aligned results (from "with Sim(3)" to "Saving results")
    sed -n '/with Sim(3) Umeyama alignment/,/Saving results/p' "$EVO_STATS" | head -15
    echo ""
fi
```

**关键变化**:
- 明确标注显示的是对齐后的结果
- 使用sed精确提取对齐后的统计数据

## 效果对比

### 以 carwelding2 序列为例

#### 修改前 (未对齐)
```
APE w.r.t. translation part (m)
(not aligned)

       max      30.52 m
      mean      15.05 m
    median      15.34 m
       min       1.76 m
      rmse      16.41 m    ← 很大的误差
       std       6.55 m
```

#### 修改后 (Sim(3)对齐)
```
APE w.r.t. translation part (m)
(with Sim(3) Umeyama alignment)

       max       0.571 m
      mean       0.247 m
    median       0.244 m
       min       0.036 m
      rmse       0.263 m    ← 真实的相对误差
       std       0.091 m
```

**改进幅度**: RMSE从 16.41m 降至 0.263m（提升 62倍）

### 以 amusement1 序列为例

#### 修改前 (未对齐)
```
RMSE: 27.76 m
Mean: 27.49 m
Std:   3.82 m
```

#### 修改后 (Sim(3)对齐)
```
RMSE:  0.134 m
Mean:  0.108 m
Std:   0.079 m
```

**改进幅度**: RMSE从 27.76m 降至 0.134m（提升 207倍）

## 技术说明

### 什么是 Sim(3) Umeyama 对齐？

Sim(3) Umeyama 对齐算法计算两条轨迹之间的**相似变换**，包括：
1. **旋转** (Rotation)
2. **平移** (Translation)
3. **尺度** (Scale) ← 关键！

对于单目SLAM，由于**尺度不确定性**，估计的轨迹和真值轨迹可能在：
- 全局位置不同（平移）
- 全局朝向不同（旋转）
- **尺度不同**（可能是10倍或0.1倍）

### 为什么需要对齐？

**未对齐的结果**反映的是：
```
误差 = 尺度差异 + 全局位置差异 + 真实轨迹误差
```

**对齐后的结果**反映的是：
```
误差 = 真实轨迹误差（相对精度）
```

对齐后的RMSE才能真正评估SLAM算法的**轨迹跟踪精度**！

### EVO 参数说明

| 参数 | 说明 |
|-----|------|
| `-r trans_part` | 仅评估平移部分（位置误差） |
| `-a` | 使用SE(3)对齐（旋转+平移，**不含尺度**） |
| `-as` | 使用Sim(3)对齐（旋转+平移+**尺度**） |
| `-s` | 仅使用尺度对齐 |

**单目SLAM必须使用 `-as`** 因为存在尺度不确定性！

## 验证步骤

1. **运行测试**:
   ```bash
   ./quick_eval_intr6000p.sh easy carwelding2
   ```

2. **检查输出**:
   应该看到：
   ```
   Running EVO APE with Sim(3) Umeyama alignment...
   ...
   APE Statistics (with Sim(3) Umeyama alignment):
   ================================================
   (with Sim(3) Umeyama alignment)

          max      0.571
         mean      0.247
       median      0.244
          min      0.036
         rmse      0.263    ← 应该是0.x量级，不是10-30量级
          std      0.091
   ```

3. **检查保存的文件**:
   ```bash
   cat output/quick_eval_*/evo_statistics.txt
   ```
   应该包含 "with Sim(3) Umeyama alignment" 部分

## 影响范围

### 需要重新评估的结果

所有之前使用**原始脚本**评估的结果都需要重新运行，包括：
1. ✗ `/home/hz/intr6000/ORB_SLAM2/resut/origin/output/` - 原始版本结果
2. ✓ 使用修复后脚本的所有新结果

### 文档需要更新

以下文档中的RMSE数值需要更新：
1. `ORIGINAL_VERSION_ANALYSIS.md` - 原始版本分析
2. `原始版本分析报告.md` - 中文报告
3. `original_results_summary.csv` - 数据汇总

**注意**: 所有之前报告的16-28m的RMSE值都是**未对齐**的结果，不应作为SLAM精度的评价指标。

## 最佳实践建议

### 论文/报告中应该报告什么？

✓ **应该报告**:
- **对齐后的APE RMSE** (with Sim(3) alignment)
- 这反映了SLAM的轨迹跟踪精度
- 示例: "RMSE = 0.263m"

✗ **不应该报告**:
- 未对齐的APE RMSE (not aligned)
- 这反映的是尺度+全局误差，不公平
- 示例: "RMSE = 16.41m" ← 误导性

### 其他评估指标

除了APE，还可以报告：
1. **RPE** (Relative Pose Error)
   - 评估局部一致性
   - 不受全局漂移影响

2. **对齐参数**
   - Scale factor: 反映尺度估计准确性
   - 示例: "Scale = 12.22" 表示估计尺度是真实的12.22倍

3. **轨迹完成度**
   - 成功跟踪的帧数 / 总帧数
   - 示例: "296/1314 = 22.5%"

## 参考资料

- EVO工具文档: https://github.com/MichaelGrupp/evo
- Umeyama算法论文: Umeyama, S. (1991). "Least-squares estimation of transformation parameters between two point patterns"

---

**修复日期**: 2025-12-01
**影响**: 所有ORB-SLAM2评估结果
**状态**: ✅ 已修复并验证
