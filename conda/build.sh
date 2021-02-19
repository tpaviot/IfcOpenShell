#!/bin/bash

declare -a CMAKE_PLATFORM_FLAGS
if [[ ${HOST} =~ .*linux.* ]]; then
    CMAKE_PLATFORM_FLAGS+=(-DCMAKE_TOOLCHAIN_FILE="${RECIPE_DIR}/cross-linux.cmake")
fi

cmake -G Ninja \
 -DCMAKE_INSTALL_PREFIX=$PREFIX \
 -DCMAKE_BUILD_TYPE=Release \
  ${CMAKE_PLATFORM_FLAGS[@]} \
 -DCMAKE_PREFIX_PATH=$PREFIX \
 -DCMAKE_SYSTEM_PREFIX_PATH=$PREFIX \
 -DPython3_FIND_STRATEGY=LOCATION \
 -DPython3_FIND_FRAMEWORK=NEVER \
 -DOCC_INCLUDE_DIR=$PREFIX/include/opencascade \
 -DOCC_LIBRARY_DIR=$PREFIX/lib \
 -DCOLLADA_SUPPORT=OFF \
 -DIFCXML_SUPPORT=ON \
 -DBUILD_EXAMPLES=OFF \
 -DBUILD_GEOMSERVER=ON \
 -DBUILD_CONVERT=ON \
 -DBUILD_IFCPYTHON=ON \
 -DBUILD_IFCGEOM=ON \
 -DIFCXML_SUPPORT=ON \
 -DLIBXML2_INCLUDE_DIR=$PREFIX/include/libxml2 \
 ./cmake

ninja

ninja install
