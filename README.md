# Isaac Sim Custom Action Graph Examples

**Two working custom Action Graph (OmniGraph) Python nodes for NVIDIA Isaac Sim, made with the
[Isaac Sim OmniGraph Node Builder](https://hrithik-verma.github.io/isaac-sim-omnigraph-node-builder/), plus ready-to-open scenes.**
No build step: add the folder to Isaac Sim, open a scene, press Play.

| Example | Node | What it shows |
|---|---|---|
| [`my.test.test_graph`](extensions/my.test.test_graph) | **Test Graph** | The basics: two number inputs `u`, `v`, a string output, an Action Graph node triggered by On Playback Tick and shown with Print Text |
| [`my.ros2.imu`](extensions/my.ros2.imu) | **Imu Publisher** | A ROS 2 node: reads Isaac Sim's IMU sensor and publishes `sensor_msgs/msg/Imu` with rclpy |

Tested with **Isaac Sim 6.1** (the scenes use Isaac Sim 6.1 assets). The extension format also works with Isaac Sim 5.x.

## Repository layout

```
extensions/
├── my.test.test_graph/          extension: config/extension.toml + nodes/OgnTestGraph.ogn/.py
└── my.ros2.imu/                 extension: config/extension.toml + nodes/OgnImuPublisher.ogn/.py
scenes/
├── test_graph.usd               On Playback Tick -> Test Graph -> Print Text
└── custom_imu_publisher.usd     Rigid-body cube + IMU sensor -> Isaac Read IMU -> Imu Publisher
isaacsim_ros2.sh                 starts Isaac Sim with its internal ROS 2 libraries
```

## Quick start

1. Clone this repository:
   ```bash
   git clone https://github.com/Hrithik-verma/isaac-sim-custom-action-graph-examples.git
   ```
2. In Isaac Sim open **Window > Extensions > (menu) > Settings** and add the **`extensions`** folder of this repo
   to *Extension Search Paths* (the folder that *contains* the extensions).
3. Search the extension list for **My Test Graph** and **Imu**, and enable them.
4. **File > Open** a file from `scenes/`, then press **Play**.

### Example 1: Test Graph

Open `scenes/test_graph.usd` and press Play. The node adds its two inputs and writes the result as text,
which Print Text shows on screen. The node's code is in
[`OgnTestGraph.py`](extensions/my.test.test_graph/my/test/test_graph/nodes/OgnTestGraph.py):

```python
# 2. Do your custom computation here
addition = str(v + u)
```

### Example 2: ROS 2 IMU publisher

The scene contains a cube with a rigid body and an **IMU sensor under the cube**. *Isaac Read IMU Node* reads the
sensor every tick and *Imu Publisher* publishes it on `/imu`.

ROS 2 nodes need Isaac Sim to use its **internal** ROS 2 libraries (see [ROS 2 setup](#ros-2-setup)):

```bash
conda activate <your-isaac-sim-env>      # or: ISAACSIM_ENV=<env>, or ISAAC_SIM_ROOT=~/isaacsim for a workstation install
./isaacsim_ros2.sh
```

Open `scenes/custom_imu_publisher.usd`, press Play, and in any normal terminal with ROS 2 sourced:

```bash
ros2 topic echo /imu
```

With the cube resting on the ground you should see `linear_acceleration.z: 9.80...` (gravity) and `frame_id: imu_link`.

How the message is filled in
[`OgnImuPublisher.py`](extensions/my.ros2.imu/my/ros2/imu/nodes/OgnImuPublisher.py):

```python
msg.header.stamp.sec = int(sensor_time)
msg.header.stamp.nanosec = int((sensor_time - int(sensor_time)) * 1e9)
msg.orientation.x = float(orientation_quaternion[0])        # OmniGraph quatd[4] is x, y, z, w
msg.angular_velocity.x = float(angular_velocity_vector[0])
msg.linear_acceleration.x = float(linear_acceleration_vector[0])
...
state.publisher.publish(msg)
```

## Make your own node

1. Open the [OmniGraph Node Builder](https://hrithik-verma.github.io/isaac-sim-omnigraph-node-builder/).
2. Set the extension name, add a node, and add its inputs and outputs. Turn on **Action Graph node** for Exec In/Out
   pins and **ROS 2** for a publisher or subscriber.
3. **Download .zip** and unzip it into a folder that is on Isaac Sim's Extension Search Paths.
4. Write your logic in step 2 of `compute()` in `Ogn<Node>.py`. Isaac Sim reloads the file while it runs.

To change inputs or outputs later, open the extension folder (or its zip) in the builder with **Open...**.
Your Python file is kept as you wrote it.

## ROS 2 setup

Isaac Sim's Python (3.11 in 5.x, 3.12 in 6.x / 7.0) cannot use a system ROS 2 such as Humble (Python 3.10).
If your `~/.bashrc` sources `/opt/ros/humble`, a ROS 2 node fails with:

```
ROS 2 is not available (No module named 'rclpy._rclpy_pybind11' ...)
```

[`isaacsim_ros2.sh`](isaacsim_ros2.sh) fixes that: it removes the system ROS 2 for Isaac Sim only, adds Isaac Sim's
internal ROS 2 libraries and keeps your `ROS_DOMAIN_ID`, so `ros2 topic echo` and `rviz2` in normal terminals still
see Isaac Sim's topics.

```bash
./isaacsim_ros2.sh                          # Isaac Sim GUI (active conda / pip environment)
ISAACSIM_ENV=isaacsim ./isaacsim_ros2.sh    # activate a conda environment first
ISAAC_SIM_ROOT=~/isaacsim ./isaacsim_ros2.sh   # workstation (binary) install
./isaacsim_ros2.sh python my_script.py      # standalone script
RMW=rmw_cyclonedds_cpp ./isaacsim_ros2.sh   # match the middleware of your system ROS 2
```

ROS 2 settings are read when Isaac Sim starts, so restart Isaac Sim after changing them.

## Common mistakes (and fixes)

| Symptom | Cause | Fix |
|---|---|---|
| `'module' object is not callable` | `string(x)` uses the `string` module | Use `str(x)` to turn a number into text |
| `ROS 2 is not available (... _rclpy_pybind11 ...)` | Isaac Sim started with the system ROS 2 sourced | Start it with `./isaacsim_ros2.sh` |
| `The 'stamp' field must be a sub message of type 'Time'` | Assigning a number or array to a ROS sub-message | Fill fields: `msg.header.stamp.sec = ...`, `msg.orientation.x = ...` |
| `The 'x' field must be of type 'float'` | `float[3]` inputs come as `numpy.float32` | Wrap values in `float(...)` (and `int(...)` for integer fields) |
| Isaac Read IMU Node outputs only zeros, no error | IMU Prim is not an IMU sensor, or the sensor is not under the rigid body | Select the rigid-body prim, **Create > Sensors > Imu Sensor**, and point IMU Prim at that `Imu_Sensor` |
| Error points at the `db.log_error(...)` line | The template catches errors from your code | The real mistake is in your step 2 code above it |

## License

[MIT](LICENSE). Community project, not affiliated with or endorsed by NVIDIA. Isaac Sim, Omniverse and OmniGraph
are trademarks of NVIDIA Corporation.
