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

cmake_minimum_required(VERSION 3.1.3)
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)  # not necessary, but encouraged

project (IfcOpenShell)

foreach(max_year RANGE 2014 2030)
    set(max_sdk "$ENV{ADSK_3DSMAX_SDK_${max_year}}")
    if (NOT "${max_sdk}" STREQUAL "")
        message(STATUS "Autodesk 3ds Max SDK found at ${max_sdk}")
        set(HAS_MAX TRUE)
    endif()
endforeach()

option(COLLADA_SUPPORT "Build IfcConvert with COLLADA support (requires OpenCOLLADA)." ON)
option(IFCXML_SUPPORT "Build IfcParse with ifcXML support (requires libxml2)." ON)
option(ENABLE_BUILD_OPTIMIZATIONS "Enable certain compiler and linker optimizations on RelWithDebInfo and Release builds." OFF)
option(IFCCONVERT_DOUBLE_PRECISION "IfcConvert: Use double precision floating-point numbers." ON)
option(BUILD_IFCGEOM "Build IfcGeom." ON)
option(BUILD_DOCUMENTATION "Build IfcOpenShell Documentation." OFF)
option(BUILD_IFCPYTHON "Build IfcPython." ON)
option(BUILD_EXAMPLES "Build example applications." ON)
option(BUILD_GEOMSERVER "Build IfcGeomServer executable." ON)
option(BUILD_CONVERT "Build IfcConvert executable." ON)
if(MSVC)
    OPTION(USE_VLD "Use Visual Leak Detector for debugging memory leaks, MSVC-only." OFF)
endif()
option(USE_MMAP "Adds a command line options to parse IFC files from memory mapped files using Boost.Iostreams" OFF)
option(BUILD_SHARED_LIBS "Build IfcParse and IfcGeom as shared libs (SO/DLL)." OFF)

if (${HAS_MAX})
    option(BUILD_IFCMAX "Build IfcMax, a 3ds Max plug-in, Windows-only." ON)
endif()
if(${BUILD_CONVERT})
    option(GLTF_SUPPORT "Build IfcConvert with glTF support (requires json.hpp)." OFF)
endif()
option(USERSPACE_PYTHON_PREFIX "Installs IfcPython for the current user only instead of system-wide." OFF)

# TODO QtViewer is deprecated ATM as it uses the 0.4 API
# OPTION(BUILD_QTVIEWER "Build IfcOpenShell Qt GUI Viewer (requires Qt 4 framework)." OFF)

if((BUILD_CONVERT OR BUILD_GEOMSERVER OR BUILD_IFCPYTHON) AND (NOT BUILD_IFCGEOM))
    message(STATUS "'IfcGeom' is required with current outputs")
    set(BUILD_IFCGEOM ON)
endif()

# Specify where to install files
if(NOT BINDIR)
    set(BINDIR bin)
endif()
if(NOT IS_ABSOLUTE ${BINDIR})
    set(BINDIR ${CMAKE_INSTALL_PREFIX}/${BINDIR})
endif()
MESSAGE(STATUS "BINDIR: ${BINDIR}")

IF(NOT INCLUDEDIR)
    set(INCLUDEDIR include)
ENDIF()
IF(NOT IS_ABSOLUTE ${INCLUDEDIR})
    set(INCLUDEDIR ${CMAKE_INSTALL_PREFIX}/${INCLUDEDIR})
ENDIF()
MESSAGE(STATUS "INCLUDEDIR: ${INCLUDEDIR}")

IF(NOT LIBDIR)
    set(LIBDIR lib)
ENDIF()
IF(NOT IS_ABSOLUTE ${LIBDIR})
    set(LIBDIR ${CMAKE_INSTALL_PREFIX}/${LIBDIR})
ENDIF()
MESSAGE(STATUS "LIBDIR: ${LIBDIR}")

set(IFCOPENSHELL_LIBARY_DIR "") # for *nix rpaths

if (BUILD_SHARED_LIBS)
    add_definitions(-DIFC_SHARED_BUILD)
    if (MSVC)
        message(WARNING "Building DLLs against the static VC run-time. This is not recommended if the DLLs are to be redistributed.")
        # C4521: 'identifier' : class 'type' needs to have dll-interface to be used by clients of class 'type2'
        # There will be couple hundreds of these so suppress them away, https://msdn.microsoft.com/en-us/library/esew7y1w.aspx
        add_definitions(-wd4251)
    endif()
    set(IFCOPENSHELL_LIBARY_DIR "${LIBDIR}")
endif()

# Create cache entries if absent for environment variables
macro(UNIFY_ENVVARS_AND_CACHE VAR)
	if((NOT DEFINED ${VAR}) AND (NOT "$ENV{${VAR}}" STREQUAL ""))
		set(${VAR} "$ENV{${VAR}}" CACHE STRING "${VAR}" FORCE)
	endif()
endmacro()

unify_envvars_and_cache(OCC_INCLUDE_DIR)
unify_envvars_and_cache(OCC_LIBRARY_DIR)
unify_envvars_and_cache(OPENCOLLADA_INCLUDE_DIR)
unify_envvars_and_cache(OPENCOLLADA_LIBRARY_DIR)
unify_envvars_and_cache(LIBXML2_INCLUDE_DIR)
unify_envvars_and_cache(LIBXML2_LIBRARIES)
unify_envvars_and_cache(PCRE_LIBRARY_DIR)
unify_envvars_and_cache(PYTHON_EXECUTABLE)

if(GLTF_SUPPORT AND BUILD_CONVERT)
    unify_envvars_and_cache(JSON_INCLUDE_DIR)
    find_file(json_hpp "json.hpp" ${JSON_INCLUDE_DIR}/nlohmann)
    if(json_hpp)
    	message(STATUS "JSON for Modern C++ header file found")
    else()
    	message(FATAL_ERROR "Unable to find JSON for Modern C++ header file, aborting")
    endif()
    add_definitions(-DWITH_GLTF)
endif()

# Set INSTALL_RPATH for target
macro(SET_INSTALL_RPATHS _target _paths)
    set(${_target}_rpaths "")
    foreach(_path ${_paths})
        list(FIND CMAKE_PLATFORM_IMPLICIT_LINK_DIRECTORIES "${_path}" isSystemDir)
        if("${isSystemDir}" STREQUAL "-1")
            list(APPEND ${_target}_rpaths ${_path})
        endif()
    endofreach()
    message(STATUS "Set INSTALL_RPATH for ${_target}: ${${_target}_rpaths}")
    set_target_properties(${_target} PROPERTIES INSTALL_RPATH "${${_target}_rpaths}")
endmacro()

# Find Boost: On win32 the (hardcoded) default is to use static libraries and
# runtime, when doing running conda-build we pick what conda prepared for us.
if(WIN32 AND ("$ENV{CONDA_BUILD}" STREQUAL ""))
	set(Boost_USE_STATIC_LIBS ON)
	set(Boost_USE_STATIC_RUNTIME ON)
	set(Boost_USE_MULTITHREADED ON)
    # Disable Boost's autolinking as the libraries to be linked to are supplied
    # already by CMake, and wrong libraries would be asked for when code is
    # compiled with a toolset different from default.
    if(MSVC)
        add_definitions(-DBOOST_ALL_NO_LIB)
        # Necessary for boost version >= 1.67
        set(BCRYPT_LIBRARIES "bcrypt.lib")
    endif()
else()
    # Disable Boost's autolinking as the libraries to be linked to are supplied
    # already by CMake, and it's going to conflict if there are multiple, as is
    # the case in conda-forge's libboost feedstock.
    add_definitions(-DBOOST_ALL_NO_LIB)
    if(WIN32)
        # Necessary for boost version >= 1.67
        set(BCRYPT_LIBRARIES "bcrypt.lib")
    endif()
endif()

set(BOOST_COMPONENTS system program_options regex thread date_time)
if(USE_MMAP)
    if(MSVC)
        # filesystem is necessary for the utf-16 wpath
        set(BOOST_COMPONENTS ${BOOST_COMPONENTS} iostreams filesystem)
    else()
        set(BOOST_COMPONENTS ${BOOST_COMPONENTS} iostreams)
    endif()
    add_definitions(-DUSE_MMAP)
endif()

if(IFCXML_SUPPORT)
    find_package(libxml2)
    if("${LIBXML2_INCLUDE_DIR}" STREQUAL "")
        message(FATAL_ERROR "Please set the LIBXML2_INCLUDE_DIR path")
    endif()
    set(LIBXML2_LIBRARIES xml2)
    add_definitions(-DWITH_IFCXML)
endif()

find_package(Boost REQUIRED COMPONENTS ${BOOST_COMPONENTS})
message(STATUS "Boost include files found in ${Boost_INCLUDE_DIRS}")
message(STATUS "Boost libraries found in ${Boost_LIBRARY_DIRS}")

# Usage:
# set(SOME_LIBRARIES foo bar)
# add_debug_variants(SOME_LIBRARIES "${SOME_LIRARIES}" d)
# "foo bar" -> "optimized foo debug food optimized bar debug bard"
# or
# set(SOME_LIBRARIES path/foo.lib)
# add_debug_variants(SOME_LIBRARIES "${SOME_LIBRARIES}" "d")
# "path/foo.lib" -> "optimized path/foo.lib debug path/food.lib"
# TODO Could be refined: take the library file extension as a parameter and
# make sure the lib variable ends with not just contains it.
function(add_debug_variants NAME LIBRARIES POSTFIX)
    set(LIBRARIES_STR "${LIBRARIES}")
    set(LIBRARIES "")
    # the result, "optimized <lib> debug <lib>", needs to be a list instead of a string
    foreach(lib ${LIBRARIES_STR})
        list(APPEND LIBRARIES optimized)
        if ("${lib}" MATCHES ".lib")
            string(REPLACE ".lib" "" lib ${lib})
            list(APPEND LIBRARIES ${lib}.lib)
        else()
            list(APPEND LIBRARIES ${lib})
        endif()

        list(APPEND LIBRARIES debug)
        if ("${lib}" MATCHES ".lib")
            string(REPLACE ".lib" "" lib ${lib})
            list(APPEND LIBRARIES ${lib}${POSTFIX}.lib)
        else()
            list(APPEND LIBRARIES ${lib}${POSTFIX})
        endif()
    endforeach()
    set(${NAME} ${LIBRARIES} PARENT_SCOPE)
endfunction()

if(BUILD_IFCGEOM)
    if(MSVC)
        add_debug_variants(LIBXML2_LIBRARIES "${LIBXML2_LIBRARIES}" d)
    endif()
    
    # Find Open CASCADE
    if("${OCC_INCLUDE_DIR}" STREQUAL "")
    	set(OCC_INCLUDE_DIR "/usr/include/oce/" CACHE FILEPATH "Open CASCADE header files")
    	message(STATUS "Looking for Open CASCADE include files in: ${OCC_INCLUDE_DIR}")
    	message(STATUS "Use OCC_INCLUDE_DIR to specify another directory")
    else()
    	set(OCC_INCLUDE_DIR ${OCC_INCLUDE_DIR} CACHE FILEPATH "Open CASCADE header files")
    	message(STATUS "Looking for Open CASCADE include files in: ${OCC_INCLUDE_DIR}")
    endif()

    find_file(gp_Pnt_hxx "gp_Pnt.hxx" ${OCC_INCLUDE_DIR})
    if(gp_Pnt_hxx)
    	message(STATUS "Header files found")
    else()
    	message(FATAL_ERROR "Unable to find header files, aborting")
    endif()

    set(OPENCASCADE_LIBRARY_NAMES
    	TKernel TKMath TKBRep TKGeomBase TKGeomAlgo TKG3d TKG2d TKShHealing TKTopAlgo TKMesh TKPrim TKBool TKBO
    	TKFillet TKSTEP TKSTEPBase TKSTEPAttr TKXSBase TKSTEP209 TKIGES TKOffset TKHLR
    )

    if("${OCC_LIBRARY_DIR}" STREQUAL "")
    	set(OCC_LIBRARY_DIR "/usr/lib/" CACHE FILEPATH "Open CASCADE library files")
    	message(STATUS "Looking for Open CASCADE library files in: ${OCC_LIBRARY_DIR}")
    	message(STATUS "Use OCC_LIBRARY_DIR to specify another directory")
    else()
    	set(OCC_LIBRARY_DIR ${OCC_LIBRARY_DIR} CACHE FILEPATH "Open CASCADE library files")
    	message(STATUS "Looking for Open CASCADE library files in: ${OCC_LIBRARY_DIR}")
    endif()

    find_library(libTKernel NAMES TKernel TKerneld PATHS ${OCC_LIBRARY_DIR} NO_DEFAULT_PATH)
    if(libTKernel)
    	message(STATUS "Library files found")
    else()
    	message(FATAL_ERROR "Unable to find library files, aborting")
    endif()

    # Use the found libTKernel as a template for all other OCC libraries
    # TODO Extract this into macro/function
    foreach(lib ${OPENCASCADE_LIBRARY_NAMES})
        # Make sure we'll handle the Windows/MSVC debug postfix convetion too.
        string(REPLACE TKerneld "${lib}" lib_path "${libTKernel}")
        string(REPLACE TKernel "${lib}" lib_path "${lib_path}")
    	list(APPEND OPENCASCADE_LIBRARIES "${lib_path}")
    endforeach()

    if(MSVC)
        add_definitions(-DHAVE_NO_DLL)
        add_debug_variants(OPENCASCADE_LIBRARIES "${OPENCASCADE_LIBRARIES}" d)
    endif()
    if (WIN32)
        # OCC might require linking to Winsock depending on the version and build configuration
        list(APPEND OPENCASCADE_LIBRARIES ws2_32.lib)
    endif()

    # Make sure cross-referenced symbols between static OCC libraries get
    # resolved. Also add thread and rt libraries.
    get_filename_component(libTKernelExt ${libTKernel} EXT)
    if("${libTKernelExt}" STREQUAL ".a")
        set(OCCT_STATIC ON)
    endif()

    if(OCCT_STATIC)
        find_package(Threads)
        # OPENCASCADE_LIBRARIES repeated three times below in order to fix cyclic dependencies - use --start-group ... --end-group instead?
        set(OPENCASCADE_LIBRARIES ${OPENCASCADE_LIBRARIES} ${OPENCASCADE_LIBRARIES} ${OPENCASCADE_LIBRARIES} ${OPENCASCADE_LIBRARIES} ${OPENCASCADE_LIBRARIES} ${CMAKE_THREAD_LIBS_INIT})
        if (NOT APPLE AND NOT WIN32)
            set(OPENCASCADE_LIBRARIES ${OPENCASCADE_LIBRARIES} "rt")
        endif()
        if (NOT WIN32)
            set(OPENCASCADE_LIBRARIES ${OPENCASCADE_LIBRARIES} "dl")
        endif()
    endif(OCCT_STATIC)

endif(BUILD_IFCGEOM)

if(COLLADA_SUPPORT AND BUILD_CONVERT)
	# Find OpenCOLLADA
	if("${OPENCOLLADA_INCLUDE_DIR}" STREQUAL "")
		message(STATUS "No OpenCOLLADA include directory specified")
		set(OPENCOLLADA_INCLUDE_DIR "/usr/include/opencollada" CACHE FILEPATH "OpenCOLLADA header files")
	else()
		set(OPENCOLLADA_INCLUDE_DIR "${OPENCOLLADA_INCLUDE_DIR}" CACHE FILEPATH "OpenCOLLADA header files")
	endif()

	if("${OPENCOLLADA_LIBRARY_DIR}" STREQUAL "")
		message(STATUS "No OpenCOLLADA library directory specified")
		find_library(OPENCOLLADA_FRAMEWORK_LIB NAMES OpenCOLLADAFramework
			PATHS /usr/lib64/opencollada /usr/lib/opencollada /usr/lib64 /usr/lib /usr/local/lib64 /usr/local/lib)
		GET_FILENAME_COMPONENT(OPENCOLLADA_LIBRARY_DIR ${OPENCOLLADA_FRAMEWORK_LIB} PATH)
	endif()

	find_library(OpenCOLLADAFramework NAMES OpenCOLLADAFramework OpenCOLLADAFrameworkd PATHS ${OPENCOLLADA_LIBRARY_DIR} NO_DEFAULT_PATH)
    if (OpenCOLLADAFramework)
        message(STATUS "OpenCOLLADA library files found")
    else()
        message(FATAL_ERROR "COLLADA_SUPPORT enabled, but unable to find OpenCOLLADA libraries. "
            "Disable COLLADA_SUPPORT or fix OpenCOLLADA paths to proceed.")
    endif()

	set(OPENCOLLADA_LIBRARY_DIR "${OPENCOLLADA_LIBRARY_DIR}" CACHE FILEPATH "OpenCOLLADA library files")

	set(OPENCOLLADA_INCLUDE_DIRS "${OPENCOLLADA_INCLUDE_DIR}/COLLADABaseUtils" "${OPENCOLLADA_INCLUDE_DIR}/COLLADAStreamWriter")

	find_file(COLLADASWStreamWriter_h "COLLADASWStreamWriter.h" ${OPENCOLLADA_INCLUDE_DIRS})
	if(COLLADASWStreamWriter_h)
		message(STATUS "OpenCOLLADA header files found")
		add_definitions(-DWITH_OPENCOLLADA)
		set(OPENCOLLADA_LIBRARY_NAMES
			GeneratedSaxParser MathMLSolver OpenCOLLADABaseUtils OpenCOLLADAFramework OpenCOLLADASaxFrameworkLoader
			OpenCOLLADAStreamWriter UTF buffer ftoa
		)

		# Use the found OpenCOLLADAFramework as a template for all other OpenCOLLADA libraries
		foreach(lib ${OPENCOLLADA_LIBRARY_NAMES})
            # Make sure we'll handle the Windows/MSVC debug postfix convetion too.
            string(REPLACE OpenCOLLADAFrameworkd "${lib}" lib_path "${OpenCOLLADAFramework}")
            string(REPLACE OpenCOLLADAFramework "${lib}" lib_path "${lib_path}")
 			list(APPEND OPENCOLLADA_LIBRARIES "${lib_path}")
		endforeach()

		if("${PCRE_LIBRARY_DIR}" STREQUAL "")
            if(WIN32)
                find_library(pcre_library NAMES pcre pcred PATHS ${OPENCOLLADA_LIBRARY_DIR} NO_DEFAULT_PATH)
            else()
                find_library(pcre_library NAMES pcre PATHS ${OPENCOLLADA_LIBRARY_DIR})
            endif()
			GET_FILENAME_COMPONENT(PCRE_LIBRARY_DIR ${pcre_library} PATH)
		else()
			find_library(pcre_library NAMES pcre pcred PATHS ${PCRE_LIBRARY_DIR} NO_DEFAULT_PATH)
		endif()

		if (pcre_library)
			SET(OPENCOLLADA_LIBRARY_DIR ${OPENCOLLADA_LIBRARY_DIR} ${PCRE_LIBRARY_DIR})
            if (MSVC)
                # Add release lib regardless whether release or debug found. Debug version will be appended below.
                list(APPEND OPENCOLLADA_LIBRARIES "${PCRE_LIBRARY_DIR}/pcre.lib")
            else()
                list(APPEND OPENCOLLADA_LIBRARIES "${pcre_library}")
            endif()
        else()
            message(FATAL_ERROR "COLLADA_SUPPORT enabled, but unable to find PCRE. "
                "Disable COLLADA_SUPPORT or fix PCRE_LIBRARY_DIR path to proceed.")
		endif()

		if(MSVC)
			add_debug_variants(OPENCOLLADA_LIBRARIES "${OPENCOLLADA_LIBRARIES}" d)
		endif()
	else()
        message(FATAL_ERROR "COLLADA_SUPPORT enabled, but unable to find OpenCOLLADA headers. "
            "Disable COLLADA_SUPPORT or fix OpenCOLLADA paths to proceed.")
	endif()
endif()

if(NOT CMAKE_BUILD_TYPE)
	set(CMAKE_BUILD_TYPE "Release")
endif()

if(ENABLE_BUILD_OPTIMIZATIONS)
	if(MSVC)
        # NOTE: RelWithDebInfo and Release use O2 (= /Ox /Gl /Gy/ = Og /Oi /Ot /Oy /Ob2 /Gs /GF /Gy) by default,
        # with the exception with RelWithDebInfo has /Ob1 instead. /Ob2 has been observed to improve the performance
        # of IfcConvert significantly.
        # TODO Setting of /GL and /LTCG don't seem to apply for static libraries (IfcGeom, IfcParse)
		# C++
		set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} /Ob2 /GL")
		set(CMAKE_CXX_FLAGS_RELWITHDEBINFO "${CMAKE_CXX_FLAGS_RELEASE} /Zi")
		# Linker
		# /OPT:REF enables also /OPT:ICF and disables INCREMENTAL
		set(CMAKE_SHARED_LINKER_FLAGS_RELEASE "${CMAKE_SHARED_LINKER_FLAGS_RELEASE} /LTCG /OPT:REF")
		# /OPT:NOICF is recommended when /DEBUG is used (http://msdn.microsoft.com/en-us/library/xe4t6fc1.aspx)
		set(CMAKE_SHARED_LINKER_FLAGS_RELWITHDEBINFO "${CMAKE_SHARED_LINKER_FLAGS_RELEASE} /DEBUG /OPT:NOICF")
		set(CMAKE_EXE_LINKER_FLAGS_RELEASE "${CMAKE_EXE_LINKER_FLAGS_RELEASE} /LTCG /OPT:REF")
		set(CMAKE_EXE_LINKER_FLAGS_RELWITHDEBINFO "${CMAKE_EXE_LINKER_FLAGS_RELEASE} /DEBUG /OPT:NOICF")
	else()
        # GCC-like: Release should use O3 but RelWithDebInfo 02 so enforce 03. Anything other useful that could be added here?
        set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -O3")
        set(CMAKE_CXX_FLAGS_RELWITHDEBINFO "${CMAKE_CXX_FLAGS_RELEASE} -O3")
	endif()
endif()

if(MSVC)
    # Enable solution folders (free VS versions prior to 2012 don't support solution folders)
    if (MSVC_VERSION GREATER 1600)
        set_property(GLOBAL PROPERTY USE_FOLDERS ON)
    endif()

	if(USE_VLD)
		add_definitions(-DUSE_VLD)
	endif()
	# Enforce Unicode for CRT and Win32 API calls
	add_definitions(-D_UNICODE -DUNICODE)
	# Disable warnings about unsafe C functions; we could use the safe C99 & C11 versions if we have no need for supporting old compilers.
	add_definitions(-D_SCL_SECURE_NO_WARNINGS -D_CRT_SECURE_NO_WARNINGS)
	add_definitions(-bigobj) # required for building the big ifcXXX.objs, https://msdn.microsoft.com/en-us/library/ms173499.aspx
	# Bump up the warning level from the default 3 to 4.
	add_definitions(-W4)
	if(MSVC_VERSION GREATER 1800) # > 2013
		# Disable overeager and false positives causing C4458 ("declaration of 'indentifier' hides class member"), at least for now.
		add_definitions(-wd4458)
	endif()
    # Enforce standards-conformance on VS > 2015, older Boost versions fail to compile with this    
    if (MSVC_VERSION GREATER 1900 AND (Boost_MAJOR_VERSION GREATER 1 OR Boost_MINOR_VERSION GREATER 66))
        add_definitions(-permissive-)
    endif()
	# Link against the static VC runtime
    # TODO Make this configurable
	if("$ENV{CONDA_BUILD}" STREQUAL "")
    	foreach(flag CMAKE_CXX_FLAGS CMAKE_CXX_FLAGS_DEBUG CMAKE_CXX_FLAGS_RELEASE CMAKE_CXX_FLAGS_MINSIZEREL
    			CMAKE_CXX_FLAGS_RELWITHDEBINFO CMAKE_C_FLAGS CMAKE_C_FLAGS_DEBUG CMAKE_C_FLAGS_RELEASE
    			CMAKE_C_FLAGS_MINSIZEREL CMAKE_C_FLAGS_RELWITHDEBINFO)
    		if(${flag} MATCHES "/MD")
    			string(REGEX REPLACE "/MD" "/MT" ${flag} "${${flag}}")
    		endif()
    		if(${flag} MATCHES "/MDd")
    			string(REGEX REPLACE "/MDd" "/MTd" ${flag} "${${flag}}")
    		endif()
    	endforeach()
	endif()
else(MSVC)
    add_definitions(-Wall -Wextra)
    if(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
        add_definitions(-Wno-tautological-constant-out-of-range-compare)
    else()
        add_definitions(-Wno-maybe-uninitialized)
    endif()
    # -fPIC is not relevant on Windows and creates pointless warnings
    if(UNIX)
        add_definitions(-fPIC)
    endif()
endif(MSVC)

if(IFCCONVERT_DOUBLE_PRECISION)
    set(CONVERT_PRECISION "-DIFCCONVERT_DOUBLE_PRECISION")
endif()

include_directories(${INCLUDE_DIRECTORIES} ${OCC_INCLUDE_DIR} ${OPENCOLLADA_INCLUDE_DIRS}
	${Boost_INCLUDE_DIRS} ${LIBXML2_INCLUDE_DIR} ${JSON_INCLUDE_DIR}
)

function(files_for_ifc_version IFC_VERSION RESULT_NAME)
    set(IFC_PARSE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../src/ifcparse)
    set(${RESULT_NAME} 
        ${IFC_PARSE_DIR}/Ifc${IFC_VERSION}.h 
        ${IFC_PARSE_DIR}/Ifc${IFC_VERSION}enum.h
        ${IFC_PARSE_DIR}/Ifc${IFC_VERSION}.cpp
		PARENT_SCOPE
    )
endfunction()

set(SCHEMA_VERSIONS "2x3" "4" "4x1" "4x2" "4x3_rc1" "4x3_rc2")

if(COMPILE_SCHEMA)
	# @todo, this appears to be untested at the moment

    find_package(PythonInterp)
    
    if(NOT PYTHONINTERP_FOUND)
        MESSAGE(FATAL_ERROR "A Python interpreter is necessary when COMPILE_SCHEMA is enabled. Disable COMPILE_SCHEMA or fix Python paths to proceed.")
    endif()
    
    set(IFC_RELEASE_NOT_USED ${SCHEMA_VERSIONS})
    
    # Install pyparsing if necessary
    execute_process(COMMAND ${PYTHON_EXECUTABLE} -m pip freeze OUTPUT_VARIABLE PYTHON_PACKAGE_LIST)
    if ("${PYTHON_PACKAGE_LIST}" STREQUAL "")
        execute_process(COMMAND pip freeze OUTPUT_VARIABLE PYTHON_PACKAGE_LIST)
        if ("${PYTHON_PACKAGE_LIST}" STREQUAL "")
            message(WARNING "Failed to find pip. Pip is required to automatically install pyparsing")
        endif()
    endif()
    string(FIND "${PYTHON_PACKAGE_LIST}" pyparsing PYPARSING_FOUND)
    if ("${PYPARSING_FOUND}" STREQUAL "-1")
        message(STATUS "Installing pyparsing")
        execute_process(COMMAND ${PYTHON_EXECUTABLE} -m pip "install" --user pyparsing RESULT_VARIABLE SUCCESS)
        if (NOT "${SUCCESS}" STREQUAL "0")
            execute_process(COMMAND pip "install" --user pyparsing RESULT_VARIABLE SUCCESS)
            if (NOT "${SUCCESS}" STREQUAL "0")
                message(WARNING "Failed to automatically install pyparsing. Please install manually")
            endif()
        endif()
    else()
        message(STATUS "Python interpreter with pyparsing found")
    endif()
    
    # Bootstrap the parser
    message(STATUS "Compiling schema, this will take a while...")
    execute_process(COMMAND ${PYTHON_EXECUTABLE} bootstrap.py express.bnf 
        WORKING_DIRECTORY ../src/ifcexpressparser 
        OUTPUT_FILE express_parser.py
        RESULT_VARIABLE SUCCESS)

    if (NOT "${SUCCESS}" STREQUAL "0")
        MESSAGE(FATAL_ERROR "Failed to bootstrap parser. Make sure pyparsing is installed")
    endif()
        
    # Generate code
    execute_process(COMMAND ${PYTHON_EXECUTABLE} ../ifcexpressparser/express_parser.py ../../${COMPILE_SCHEMA}
        WORKING_DIRECTORY ../src/ifcparse
        OUTPUT_VARIABLE COMPILED_SCHEMA_NAME)
    
    # Prevent the schema that had just been compiled from being excluded
	foreach(s ${SCHEMA_VERSIONS})
		if("${COMPILED_SCHEMA_NAME}" STREQUAL "${s}")
			list(REMOVE_ITEM IFC_RELEASE_NOT_USED "${s}")
		endif()
	endforeach()
endif()

# Boost >= 1.58 requires BOOST_OPTIONAL_USE_OLD_DEFINITION_OF_NONE to build on some Linux distros.
if(NOT Boost_VERSION LESS 105800)
    add_definitions(-DBOOST_OPTIONAL_USE_OLD_DEFINITION_OF_NONE)
endif()

set(IFCOPENSHELL_LIBRARIES IfcParse)

if(BUILD_IFCGEOM)
	foreach(s ${SCHEMA_VERSIONS})
		set(IFCGEOM_SCHEMA_LIBRARIES ${IFCGEOM_SCHEMA_LIBRARIES} IfcGeom_ifc${s})
	endforeach()
	set(IFCOPENSHELL_LIBRARIES ${IFCOPENSHELL_LIBRARIES} IfcGeom ${IFCGEOM_SCHEMA_LIBRARIES} IfcGeom ${IFCGEOM_SCHEMA_LIBRARIES})
endif()

if(BUILD_CONVERT)
	foreach(s ${SCHEMA_VERSIONS})
		set(SERIALIZER_SCHEMA_LIBRARIES ${SERIALIZER_SCHEMA_LIBRARIES} Serializers_ifc${s})
	endforeach()
	set(IFCOPENSHELL_LIBRARIES ${IFCOPENSHELL_LIBRARIES} Serializers ${SERIALIZER_SCHEMA_LIBRARIES})
endif()

# IfcParse
file(GLOB IFCPARSE_H_FILES ../src/ifcparse/*.h)
file(GLOB IFCPARSE_CPP_FILES ../src/ifcparse/*.cpp)
set(IFCPARSE_FILES ${IFCPARSE_CPP_FILES} ${IFCPARSE_H_FILES})

add_library(IfcParse ${IFCPARSE_FILES})
set_target_properties(IfcParse PROPERTIES COMPILE_FLAGS -DIFC_PARSE_EXPORTS VERSION "0.6.0" SOVERSION "0.6")

target_link_libraries(IfcParse ${Boost_LIBRARIES} ${BCRYPT_LIBRARIES} ${LIBXML2_LIBRARIES})

if(BUILD_IFCGEOM)
    # IfcGeom
    file(GLOB IFCGEOM_H_FILES ../src/ifcgeom/*.h)
    file(GLOB IFCGEOM_CPP_FILES ../src/ifcgeom/*.cpp)
    set(IFCGEOM_FILES ${IFCGEOM_CPP_FILES} ${IFCGEOM_H_FILES})

    foreach(s ${SCHEMA_VERSIONS})
    	add_library(IfcGeom_ifc${s} STATIC ${IFCGEOM_FILES})
    	set_target_properties(IfcGeom_ifc${s} PROPERTIES COMPILE_FLAGS "-DIFC_GEOM_EXPORTS -DIfcSchema=Ifc${s}")
    	target_link_libraries(IfcGeom_ifc${s} IfcParse ${OPENCASCADE_LIBRARIES})
    endforeach()

    # IfcGeom (schema agnostic)
    file(GLOB SCHEMA_AGNOSTIC_H_FILES ../src/ifcgeom_schema_agnostic/*.h)
    file(GLOB SCHEMA_AGNOSTIC_CPP_FILES ../src/ifcgeom_schema_agnostic/*.cpp)
    set(SCHEMA_AGNOSTIC_FILES ${SCHEMA_AGNOSTIC_H_FILES} ${SCHEMA_AGNOSTIC_CPP_FILES})

    add_library(IfcGeom ${SCHEMA_AGNOSTIC_FILES})
    set_target_properties(IfcGeom PROPERTIES COMPILE_FLAGS -DIFC_GEOM_EXPORTS VERSION "0.6.0" SOVERSION "0.6")

    if(UNIX)
        find_package(Threads)
    endif()

    target_link_libraries(IfcGeom ${IFCGEOM_SCHEMA_LIBRARIES} ${CMAKE_THREAD_LIBS_INIT})
endif(BUILD_IFCGEOM)

if(BUILD_CONVERT)
    # Serializers
    file(GLOB SERIALIZERS_H_FILES ../src/serializers/*.h)
    file(GLOB SERIALIZERS_CPP_FILES ../src/serializers/*.cpp)
    set(SERIALIZERS_FILES ${SERIALIZERS_H_FILES} ${SERIALIZERS_CPP_FILES})
    file(GLOB SERIALIZERS_S_H_FILES ../src/serializers/schema_dependent/*.h)
    file(GLOB SERIALIZERS_S_CPP_FILES ../src/serializers/schema_dependent/*.cpp)
    set(SERIALIZERS_S_FILES ${SERIALIZERS_S_H_FILES} ${SERIALIZERS_S_CPP_FILES})

    foreach(s ${SCHEMA_VERSIONS})
    	add_library(Serializers_ifc${s} STATIC ${SERIALIZERS_S_FILES})
    	set_target_properties(Serializers_ifc${s} PROPERTIES COMPILE_FLAGS "-DIFC_GEOM_EXPORTS -DIfcSchema=Ifc${s} ${CONVERT_PRECISION}")
    	target_link_libraries(Serializers_ifc${s} IfcGeom ${OPENCASCADE_LIBRARIES})
    endforeach()

    add_library(Serializers ${SERIALIZERS_FILES})
    set_target_properties(Serializers PROPERTIES COMPILE_FLAGS "-DIFC_GEOM_EXPORTS ${CONVERT_PRECISION}" VERSION "0.6.0" SOVERSION "0.6")

    target_link_libraries(Serializers ${SERIALIZER_SCHEMA_LIBRARIES})

    # IfcConvert
    file(GLOB IFCCONVERT_CPP_FILES ../src/ifcconvert/*.cpp)
    file(GLOB IFCCONVERT_H_FILES ../src/ifcconvert/*.h)
    set(IFCCONVERT_FILES ${IFCCONVERT_CPP_FILES} ${IFCCONVERT_H_FILES})
    add_executable(IfcConvert ${IFCCONVERT_FILES})
    set_target_properties(IfcConvert PROPERTIES COMPILE_FLAGS "${CONVERT_PRECISION}")

    target_link_libraries(IfcConvert ${IFCOPENSHELL_LIBRARIES} ${OPENCASCADE_LIBRARIES} ${Boost_LIBRARIES} ${OPENCOLLADA_LIBRARIES})

    if ((NOT WIN32) AND BUILD_SHARED_LIBS)
        # Only set RPATHs when building shared libraries (i.e. IfcParse and
        # IfcGeom are dynamically linked). Not necessarily a perfect solution
        # but probably a good indication of whether RPATHs are necessary.
        SET_INSTALL_RPATHS(IfcConvert "${IFCOPENSHELL_LIBARY_DIR};${OCC_LIBRARY_DIR};${Boost_LIBRARY_DIRS};${OPENCOLLADA_LIBRARY_DIR}")
    endif()

    install(TARGETS IfcConvert
        ARCHIVE DESTINATION ${LIBDIR}
        LIBRARY DESTINATION ${LIBDIR}
        RUNTIME DESTINATION ${BINDIR}
    )
endif(BUILD_CONVERT)

# IfcGeomServer
if(BUILD_GEOMSERVER)
    file(GLOB CPP_FILES ../src/ifcgeomserver/*.cpp)
    file(GLOB H_FILES ../src/ifcgeomserver/*.h)
    set(SOURCE_FILES ${CPP_FILES} ${H_FILES})
    add_executable(IfcGeomServer ${SOURCE_FILES})
    target_link_libraries(IfcGeomServer ${IFCOPENSHELL_LIBRARIES} ${OPENCASCADE_LIBRARIES} ${Boost_LIBRARIES})

    if ((NOT WIN32) AND BUILD_SHARED_LIBS)
        set_install_rpaths(IfcGeomServer "${IFCOPENSHELL_LIBARY_DIR};${OCC_LIBRARY_DIR};${Boost_LIBRARY_DIRS}")
    endif()

    install(TARGETS IfcGeomServer
        ARCHIVE DESTINATION ${LIBDIR}
        LIBRARY DESTINATION ${LIBDIR}
        RUNTIME DESTINATION ${BINDIR}
    )
endif(BUILD_GEOMSERVER)

if(BUILD_IFCPYTHON)
	add_subdirectory(../src/ifcwrap ifcwrap)
endif()

if(BUILD_EXAMPLES)
	add_subdirectory(../src/examples examples)
endif()

# Documentation	
if(BUILD_DOCUMENTATION)
	set(CMAKE_MODULE_PATH "../docs/cmake")
	add_subdirectory(../docs docs)
endif()

if(BUILD_IFCPYTHON)
	add_subdirectory(../src/ifcwrap ifcwrap)
endif()

if(BUILD_EXAMPLES)
	add_subdirectory(../src/examples examples)
endif()

if(BUILD_IFCMAX)
	add_subdirectory(../src/ifcmax ifcmax)
endif()

# CMake installation targets
install(FILES ${IFCPARSE_H_FILES} 
	DESTINATION ${INCLUDEDIR}/ifcparse
)

install(TARGETS IfcParse
	ARCHIVE DESTINATION ${LIBDIR}
	LIBRARY DESTINATION ${LIBDIR}
	RUNTIME DESTINATION ${BINDIR}
)

if(BUILD_IFCGEOM)
    install(FILES ${IFCGEOM_H_FILES} 
    	DESTINATION ${INCLUDEDIR}/ifcgeom
    )

    install(FILES  ${SCHEMA_AGNOSTIC_H_FILES} 
    	DESTINATION ${INCLUDEDIR}/ifcgeom_schema_agnostic
    )

    install(TARGETS ${IFCGEOM_SCHEMA_LIBRARIES} IfcGeom
    	ARCHIVE DESTINATION ${LIBDIR}
    	LIBRARY DESTINATION ${LIBDIR}
    	RUNTIME DESTINATION ${BINDIR}
    )
endif(BUILD_IFCGEOM)

if(BUILD_CONVERT)
    install(TARGETS Serializers ${SERIALIZER_SCHEMA_LIBRARIES}
    	ARCHIVE DESTINATION ${LIBDIR}
    	LIBRARY DESTINATION ${LIBDIR}
    	RUNTIME DESTINATION ${BINDIR}
    )

    install(FILES  ${SERIALIZERS_FILES}
    	DESTINATION ${INCLUDEDIR}/serializers/
    )

    install(FILES  ${SERIALIZERS_S_FILES}
    	DESTINATION ${INCLUDEDIR}/serializers/schema_dependent
    )
endif(BUILD_CONVERT)
