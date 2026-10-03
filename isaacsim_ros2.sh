#!/usr/bin/env bash
# Start Isaac Sim with its internal ROS 2 libraries.
#
# Isaac Sim's Python (3.11 in 5.x, 3.12 in 6.x / 7.0) cannot use a system ROS 2 such as
# Humble (Python 3.10). If your ~/.bashrc sources /opt/ros/<distro>, starting Isaac Sim
# from that terminal makes ROS 2 nodes fail with "No module named 'rclpy._rclpy_pybind11'".
# This script removes the system ROS 2 for Isaac Sim only and adds Isaac Sim's own ROS 2
# libraries. ROS_DOMAIN_ID is kept, so normal terminals (ros2 topic echo, rviz2) still
# see Isaac Sim's topics.
#
# Usage:
#   conda activate <isaac-sim-env> && ./isaacsim_ros2.sh        # pip / conda install, GUI
#   ISAACSIM_ENV=<isaac-sim-env> ./isaacsim_ros2.sh             # same, activates the env for you
#   ISAAC_SIM_ROOT=~/isaacsim ./isaacsim_ros2.sh                # workstation (binary) install
#   ./isaacsim_ros2.sh python my_script.py                      # run a command instead of the GUI
#
# Options (environment variables):
#   ISAACSIM_ENV          conda environment that has the isaacsim pip package
#   ISAAC_SIM_ROOT        folder of a workstation install (contains isaac-sim.sh)
#   ISAACSIM_ROS_DISTRO   internal ROS 2 distro: humble (default) or jazzy
#   RMW                   middleware, match your system ROS 2: rmw_fastrtps_cpp (default) or rmw_cyclonedds_cpp

set -e

INTERNAL_DISTRO="${ISAACSIM_ROS_DISTRO:-humble}"
RMW="${RMW:-rmw_fastrtps_cpp}"

# Drop the system ROS 2 from this process only
unset PYTHONPATH AMENT_PREFIX_PATH COLCON_PREFIX_PATH CMAKE_PREFIX_PATH ROS_VERSION ROS_PYTHON_VERSION
LD_LIBRARY_PATH="$(printf '%s' "${LD_LIBRARY_PATH:-}" | tr ':' '\n' | grep -v -E '^/opt/ros/' | paste -sd: -)"
PATH="$(printf '%s' "$PATH" | tr ':' '\n' | grep -v -E '^/opt/ros/' | paste -sd: -)"

if [ -n "${ISAAC_SIM_ROOT:-}" ]; then
  ISAAC="$ISAAC_SIM_ROOT"
  LAUNCH=("$ISAAC_SIM_ROOT/isaac-sim.sh")
else
  if [ -n "${ISAACSIM_ENV:-}" ]; then
    CONDA_BIN="${CONDA_EXE:-$(command -v conda || true)}"
    if [ -z "$CONDA_BIN" ]; then
      echo "ISAACSIM_ENV is set but conda was not found." >&2
      exit 1
    fi
    # shellcheck disable=SC1091
    source "$("$CONDA_BIN" info --base)/etc/profile.d/conda.sh"
    conda activate "$ISAACSIM_ENV"
  fi
  if ! ISAAC="$(python -c 'import isaacsim, os; print(os.path.dirname(isaacsim.__file__))' 2>/dev/null)"; then
    echo "Isaac Sim not found: activate its Python environment, or set ISAACSIM_ENV or ISAAC_SIM_ROOT." >&2
    exit 1
  fi
  LAUNCH=(isaacsim)
fi

ROS_LIB=""
for ext in isaacsim.ros2.core isaacsim.ros2.bridge; do   # 6.x / 7.0 use .core, 5.x uses .bridge
  if [ -d "$ISAAC/exts/$ext/$INTERNAL_DISTRO/lib" ]; then ROS_LIB="$ISAAC/exts/$ext/$INTERNAL_DISTRO/lib"; break; fi
done
if [ -z "$ROS_LIB" ]; then
  echo "No internal ROS 2 '$INTERNAL_DISTRO' libraries found in $ISAAC/exts" >&2
  exit 1
fi

export ROS_DISTRO="$INTERNAL_DISTRO"
export RMW_IMPLEMENTATION="$RMW"
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:+$LD_LIBRARY_PATH:}$ROS_LIB"
export ROS_DOMAIN_ID="${ROS_DOMAIN_ID:-0}"

echo "Isaac Sim: $ISAAC"
echo "ROS 2: internal $ROS_DISTRO | RMW: $RMW_IMPLEMENTATION | ROS_DOMAIN_ID: $ROS_DOMAIN_ID"

if [ "$#" -gt 0 ]; then
  exec "$@"
else
  exec "${LAUNCH[@]}"
fi
