#!/usr/bin/env bash
# fakebuild: harmless, simulated C++ build output. Does not compile or modify files.
set -u

# Keep output readable in a normal terminal and stop cleanly with Ctrl+C.
if [[ ! -t 1 ]]; then
  echo "fakebuild: run this in an interactive terminal." >&2
  exit 1
fi

trap 'printf "\n\n[100%%] Build simulation stopped by user. No files were compiled or changed.\n"; exit 0' INT TERM

project="nebula_renderer"
modules=(
  "src/core/application.cpp"
  "src/core/configuration.cpp"
  "src/render/render_graph.cpp"
  "src/render/pipeline_state.cpp"
  "src/render/material_system.cpp"
  "src/gpu/compute_backend.cpp"
  "src/gpu/memory_allocator.cpp"
  "src/assets/asset_registry.cpp"
  "src/platform/linux_window.cpp"
  "src/scene/scene_loader.cpp"
  "src/scene/spatial_index.cpp"
  "src/shaders/shader_compiler.cpp"
  "src/util/thread_pool.cpp"
  "src/util/file_watcher.cpp"
  "src/optimization/batch_scheduler.cpp"
)
stages=(
  "Scanning dependencies"
  "Generating build files"
  "Building CXX object"
  "Compiling shader"
  "Running static analysis"
  "Resolving symbols"
  "Linking CXX executable"
  "Checking target"
)
objects=0
total=${#modules[@]}

printf 'Build system: CMake 3.31.6\n'
printf 'Generator: Unix Makefiles\n'
printf 'Configuration: RelWithDebInfo\n'
printf 'Compiler: GNU C++ 14.2.0\n'
printf 'Target: %s\n\n' "$project"
sleep 0.7

while :; do
  printf '[  0%%] '
  printf '%s...\n' "${stages[0]}"
  sleep 0.45
  printf '[  3%%] Configuring target %s\n' "$project"
  sleep 0.45
  printf '[  6%%] Checking compiler features and include paths\n'
  sleep 0.5

  for ((i=0; i<total; i++)); do
    file="${modules[$i]}"
    pct=$((8 + (i * 82 / total)))
    if (( i % 5 == 3 )); then
      printf '[%3d%%] Compiling shader: shaders/%s\n' "$pct" \
        "$(basename "${file%.cpp}").glsl"
    else
      printf '[%3d%%] Building CXX object CMakeFiles/%s.dir/%s.o\n' \
        "$pct" "$project" "$file"
    fi
    # Occasional plausible, non-fatal build notes.
    if (( i % 6 == 2 )); then
      sleep 0.25
      printf '       note: using cached template instantiation results\n'
    fi
    sleep "$(awk -v seed="$RANDOM" 'BEGIN { srand(seed); printf "%.2f", 0.35 + rand()*0.65 }')"
  done

  printf '[ 92%%] Linking CXX executable %s\n' "$project"
  sleep 1.0
  printf '[ 96%%] Running post-build checks\n'
  sleep 0.8
  printf '[100%%] Built target %s\n' "$project"
  printf 'Build completed successfully (simulation only).\n\n'
  sleep 1.5
  printf 'Rechecking dependencies...\n'
  sleep 0.7
  printf 'Source tree changed; starting incremental build...\n\n'
  sleep 0.8
done
