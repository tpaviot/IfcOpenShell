################################################################################
#                                                                              #
# This file is part of IfcOpenShell.                                           #
#                                                                              #
# IfcOpenShell is free software: you can redistribute it and/or modify         #
# it under the terms of the Lesser GNU General Public License as published by  #
# the Free Software Foundation, either version 3.0 of the License, or          #
# (at your option) any later version.                                          #
#                                                                              #
# IfcOpenShell is distributed in the hope that it will be useful,              #
# but WITHOUT ANY WARRANTY; without even the implied warranty of               #
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the                 #
# Lesser GNU General Public License for more details.                          #
#                                                                              #
# You should have received a copy of the Lesser GNU General Public License     #
# along with this program. If not, see <http://www.gnu.org/licenses/>.         #
#                                                                              #
################################################################################

find_package(SWIG)
if(NOT SWIG_FOUND)
	message(FATAL_ERROR "BUILD_IFCPYTHON enabled, but unable to find SWIG. Disable BUILD_IFCPYTHON or fix SWIG paths to proceed.")
endif()

include(${SWIG_USE_FILE})

if(NOT "$ENV{PYTHON_INCLUDE_DIR}" STREQUAL "")
	set(PYTHON_INCLUDE_DIR $ENV{PYTHON_INCLUDE_DIR} CACHE FILEPATH "Python header files")
	message(STATUS "Looking for Python header files in: ${PYTHON_INCLUDE_DIR}")
endif()
if(NOT "$ENV{PYTHON_LIBRARY}" STREQUAL "")
	set(PYTHON_LIBRARY $ENV{PYTHON_LIBRARY} CACHE FILEPATH "Python library file")
	message(STATUS "Looking for Python library file in: ${PYTHON_LIBRARY}")
endif()

# NOTE PYTHONLIBS_FOUND and PYTHONINTERP_FOUND cannot seem to be trusted so
# we need further checks to see whether the packages were actually found or not.
find_package(PythonLibs)
if(NOT PYTHONLIBS_FOUND OR "$PYTHON_INCLUDE_DIRS}" STREQUAL "")
	message(FATAL_ERROR "BUILD_IFCPYTHON enabled, but unable to find Python lib or header. Disable BUILD_IFCPYTHON or fix Python paths to proceed.")
endif()

include_directories(${PYTHON_INCLUDE_DIRS} ${CMAKE_CURRENT_SOURCE_DIR})

set(CMAKE_SWIG_FLAGS "")
# NOTE Workaround for most likely missing debug Python libraries on Windows (requires Python built from the source).
# Python 3.5 intaller and onwards will have an option to install the debug libraries too.
# NOTE PYTHON_DEBUG_LIBRARIES appears to be a deprecated variable
if(WIN32 AND NOT PYTHON_DEBUG_LIBRARIES)
	message(STATUS "PYTHON_DEBUG_LIBRARIES not found, defining SWIG_PYTHON_INTERPRETER_NO_DEBUG workaround for IfcWrap.")
	add_definitions(-DSWIG_PYTHON_INTERPRETER_NO_DEBUG)
endif()

set_source_files_properties(IfcPython.i PROPERTIES CPLUSPLUS ON)
swig_add_library(ifcopenshell_wrapper LANGUAGE python SOURCES IfcPython.i TYPE MODULE)
if("$ENV{LDFLAGS}" MATCHES ".undefined.suppress")
    # On osx there is some state in the python dylib. With `-Wl,undefined,suppress` we can ignore the missing symbols at compile time.
    SWIG_LINK_LIBRARIES(ifcopenshell_wrapper ${IFCOPENSHELL_LIBRARIES} ${OPENCASCADE_LIBRARIES} ${Boost_LIBRARIES})
else()
    SWIG_LINK_LIBRARIES(ifcopenshell_wrapper ${IFCOPENSHELL_LIBRARIES} ${PYTHON_LIBRARIES} ${OPENCASCADE_LIBRARIES} ${Boost_LIBRARIES})
endif()
if((NOT WIN32) AND BUILD_SHARED_LIBS)
    set_install_rpaths(${SWIG_MODULE_ifcopenshell_wrapper_REAL_NAME} "${IFCDIRS};${OCC_LIBRARY_DIR}")
endif()

# Try to find the Python interpreter to get the site-packages
# directory in which the wrapper can be installed.
find_package(PythonInterp)
if(PYTHONINTERP_FOUND AND NOT "${PYTHON_EXECUTABLE}" STREQUAL "")
    if(USERSPACE_PYTHON_PREFIX)
        EXECUTE_PROCESS(
            COMMAND ${PYTHON_EXECUTABLE} -c "import sys; import site; sys.stdout.write(site.USER_SITE)"
            OUTPUT_VARIABLE python_package_dir
        )
    else()
        EXECUTE_PROCESS(
            COMMAND ${PYTHON_EXECUTABLE} -c "import sys; from distutils.sysconfig import get_python_lib; sys.stdout.write(get_python_lib(1))"
            OUTPUT_VARIABLE python_package_dir
        )
    endif()

    if("${python_package_dir}" STREQUAL "")
        message(WARNING "Unable to locate Python site-package directory, unable to install the Python wrapper")
    else()
        file(GLOB_RECURSE sourcefiles 
            "${CMAKE_CURRENT_SOURCE_DIR}/../ifcopenshell-python/ifcopenshell/*"
        )
        foreach(file ${sourcefiles})
            file(RELATIVE_PATH relative "${CMAKE_CURRENT_SOURCE_DIR}/../ifcopenshell-python/ifcopenshell/" "${file}")
            get_filename_component(dir "${relative}" DIRECTORY)
			install(FILES "${file}"
                    DESTINATION "${python_package_dir}/ifcopenshell/${dir}")
        endforeach()
        install(FILES "${CMAKE_BINARY_DIR}/ifcwrap/ifcopenshell_wrapper.py"
                DESTINATION "${python_package_dir}/ifcopenshell")
        install(TARGETS _ifcopenshell_wrapper
                DESTINATION "${python_package_dir}/ifcopenshell")
    endif()
else()
    message(FATAL_ERROR "No Python interpreter found, unable to install the Python wrapper")
endif()
