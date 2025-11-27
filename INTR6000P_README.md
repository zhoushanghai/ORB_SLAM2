# INTR6000P Dataset

INTR6000P 是一个用于视觉 SLAM 测试的数据集，包含多个难度级别的场景序列。

## 数据集结构

```
INTR6000P/
├── easy/                    # 简单场景
│   ├── carwelding2/
│   ├── factory1/
│   └── hospital/
├── medium/                  # 中等难度场景
│   ├── factory2/
│   └── factory6/
├── hard/                    # 困难场景
│   ├── amusement1/
│   └── amusement2/
├── INTR6000P_GT_POSES/      # 轨迹真值文件
│   ├── easy/
│   ├── medium/
│   └── hard/
└── tartanair.yaml           # 相机配置文件
```

### 序列文件夹内容

每个场景序列包含以下文件：

- `image_left/`: 左目相机图像（PNG 格式）
- `timestamps.txt`: 图像时间戳（纳秒）
- `pose_left.txt`: 相机位姿真值（用于评估）

## 相机参数

数据集使用 TartanAir 相机模型（针孔相机，无畸变）：

```yaml
fx: 320.0
fy: 320.0
cx: 320.0
cy: 240.0
分辨率: 640x480
```

## 使用方法

### 运行 ORB-SLAM2

```bash
cd /home/hz/intr6000/ORB_SLAM2

# 使用 mono_euroc 可执行文件
./Examples/Monocular/mono_euroc \
    Vocabulary/ORBvoc.txt \
    INTR6000P.yaml \
    INTR6000P/easy/factory1/image_left \
    INTR6000P/easy/factory1/timestamps.txt
```

### 输出结果

运行完成后会生成：
- `KeyFrameTrajectory.txt`: 关键帧轨迹（TUM 格式）
- 可视化窗口显示跟踪状态

### 评估轨迹精度

使用 `evo` 工具评估轨迹：

```bash
# 安装 evo
pip install evo

# 计算绝对轨迹误差 (APE)
evo_ape tum INTR6000P_GT_POSES/easy/factory1_pose.txt KeyFrameTrajectory.txt -va --plot

# 计算相对位姿误差 (RPE)
evo_rpe tum INTR6000P_GT_POSES/easy/factory1_pose.txt KeyFrameTrajectory.txt -va --plot
```

## 场景列表

| 难度 | 场景名称 | 描述 |
|------|----------|------|
| Easy | factory1 | 工厂场景 1 |
| Easy | carwelding2 | 汽车焊接场景 |
| Easy | hospital | 医院场景 |
| Medium | factory2 | 工厂场景 2 |
| Medium | factory6 | 工厂场景 6 |
| Hard | amusement1 | 游乐场景 1 |
| Hard | amusement2 | 游乐场景 2 |

## 配置文件说明

- **`INTR6000P.yaml`**: 推荐使用的配置文件（已优化 ORB 参数）
- **`tartanair.yaml`**: 原始 TartanAir 配置（ORB 阈值可能需要调整）

## 注意事项

1. 时间戳格式为纳秒（19 位数字），`mono_euroc` 会自动转换为秒
2. 图像文件名与时间戳对应（例如：`1700000000000000000.png`）
3. 建议从 `easy` 难度开始测试

## 参考

- ORB-SLAM2: https://github.com/raulmur/ORB_SLAM2
- TartanAir Dataset: https://theairlab.org/tartanair-dataset/
