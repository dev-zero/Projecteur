# This file is part of Projecteur - https://github.com/jahnf/projecteur - See LICENSE.md and README.md
cmake_minimum_required(VERSION 3.0)
include(LinuxDistributionInfo)

set(_LinuxPackaging_DIRECTORY "${CMAKE_CURRENT_LIST_DIR}")
set(_LinuxPackaging_cpack_template "LinuxPkgCPackConfig.cmake.in")
list(APPEND _LinuxPackaging_MAP_dist_pkgtype
  "debian::DEB"
  "ubuntu::DEB"
  "opensuse::RPM"
  "opensuse-leap::RPM"
  "fedora::RPM"
)
set(_LinuxPackaging_default_pkgtype "TGZ")

# Funtion that adds 'dist-package' target
# Arguments:
#  PROJECT            : Project name to package
#  TARGET             : Main executable target with version information
#  DESCRIPTION_BRIEF  : Brief package description.
#  DESCRIPTION_FULL   : Full package description.
#  CONTACT            : Package maintainer/contact.
#  HOMEAPGE           : The project homepage
#  DEBIAN_SECTION.....: A valid debian package section (default=devel)

function(add_dist_package_target)
  set(oneValueArgs 
    PROJECT # project name to package
    TARGET  # main executable build target that has version information attached to it
    DESCRIPTION_BRIEF 
    DESCRIPTION_FULL
    CONTACT # Maintainer / contact person
    HOMEPAGE 
    DEBIAN_SECTION
    PREINST_SCRIPT
    POSTINST_SCRIPT
    PRERM_SCRIPT
    POSTRM_SCRIPT
  )
  set(requiredArgs PROJECT TARGET)
  cmake_parse_arguments(PKG "" "${oneValueArgs}" "" ${ARGN})

  foreach(arg IN LISTS requiredArgs)
    if("${PKG_${arg}}" STREQUAL "")
      message(FATAL_ERROR "Required argument '${arg}' is not set.")
    endif()
  endforeach()

  if(NOT TARGET ${PKG_TARGET})
    message(FATAL_ERROR "Argument 'TARGET' needs to be a valid target.")
  endif()

  get_target_property(PKG_VERSION_STRING_FULL ${PKG_TARGET} VERSION_STRING)
  get_target_property(PKG_VERSION_MAJOR ${PKG_TARGET} VERSION_MAJOR)
  get_target_property(PKG_VERSION_MINOR ${PKG_TARGET} VERSION_MINOR)
  get_target_property(PKG_VERSION_PATCH ${PKG_TARGET} VERSION_PATCH)
  get_target_property(PKG_VERSION_FLAG ${PKG_TARGET} VERSION_FLAG)
  get_target_property(PKG_VERSION_DISTANCE ${PKG_TARGET} VERSION_DISTANCE)
  get_target_property(PKG_VERSION_BRANCH ${PKG_TARGET} VERSION_BRANCH)
  if("${PKG_VERSION_MAJOR}" STREQUAL "")
    set(PKG_VERSION_MAJOR 0)
  endif()
  if("${PKG_VERSION_MINOR}" STREQUAL "")
    set(PKG_VERSION_MINOR 0)
  endif()
  if("${PKG_VERSION_PATCH}" STREQUAL "")
    set(PKG_VERSION_PATCH 0)
  endif()
  set(PKG_VERSION_STRING "${PKG_VERSION_MAJOR}.${PKG_VERSION_MINOR}.${PKG_VERSION_PATCH}")
  set(PKG_VERSION_IDENTIFIERS "${PKG_VERSION_FLAG}.${PKG_VERSION_DISTANCE}")

  # Set defaults if not set
  if("${PKG_CONTACT}" STREQUAL "")
    set(PKG_CONTACT "Generic Maintainer <generic@main.tainer>")
  endif()

  if("${PKG_DEBIAN_SECTION}" STREQUAL "")
    set(PKG_DEBIAN_SECTION "devel")
  endif()

  find_program(CPACK_COMMAND cpack)
  if(NOT CPACK_COMMAND)
    message(FATAL_ERROR "CPack command was not found.")
  endif()

  get_linux_distribution(LINUX_DIST_NAME LINUX_DIST_VERSION)
  # Check if project package dependencies exist
  include(PkgDependencies${PKG_PROJECT} OPTIONAL RESULT_VARIABLE INCLUDED_PROJECT_DEPENDENCIES)
  if(INCLUDED_PROJECT_DEPENDENCIES AND PkgDependencies_MAP_${PKG_PROJECT})
    set(PKG_DEPENDENCY_FOUND 0)
    # Find dependencies for Linux distribution (and version)
    foreach(v "${LINUX_DIST_NAME}-${LINUX_DIST_VERSION}" "${LINUX_DIST_NAME}")
      foreach(pair ${PkgDependencies_MAP_${PKG_PROJECT}})
        if( "${pair}" MATCHES "${v}::(.*)")
          string(REPLACE ";" ", " PKG_DEPENDENCIES "${${CMAKE_MATCH_1}}")
          set(PKG_DEPENDENCY_FOUND 1)
          break()
        endif()
      endforeach()
      if(PKG_DEPENDENCY_FOUND)
        break()
      endif()
    endforeach()
  endif()

  # Get the package type to be generated by the target from our map variable
  set(PKG_TYPE "${_LinuxPackaging_default_pkgtype}")
  set(PKG_TYPE_FOUND 0)
  foreach(v "${LINUX_DIST_NAME}-${LINUX_DIST_VERSION}" "${LINUX_DIST_NAME}")
    foreach(pair ${_LinuxPackaging_MAP_dist_pkgtype})
      if( "${pair}" MATCHES "${v}::(.*)")
        set(PKG_TYPE "${CMAKE_MATCH_1}")
        set(PKG_TYPE_FOUND 1)
        break()
      endif()
    endforeach()
    if(PKG_TYPE_FOUND)
      break()
    endif()
  endforeach()

  string(TOLOWER "${PKG_PROJECT}" PKG_NAME)
  set(PKG_LICENSE "MIT")
  set(PKG_DIST "${LINUX_DIST_NAME}-${LINUX_DIST_VERSION}")
  string(TIMESTAMP PKG_DATE "%Y-%m-%d")

  set(PKG_CONFIG_TEMPLATE "${_LinuxPackaging_DIRECTORY}/LinuxPkgCPackConfig.cmake.in")
  set(PKG_CONFIG_FILE "${CMAKE_CURRENT_BINARY_DIR}/CPackConfig-${PKG_TYPE}.cmake")
  configure_file("${PKG_CONFIG_TEMPLATE}" "${PKG_CONFIG_FILE}" @ONLY)

  add_custom_target(dist-package
    COMMAND ${CPACK_COMMAND} --config "${PKG_CONFIG_FILE}"
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    VERBATIM
  )

  configure_file(
    "${_LinuxPackaging_DIRECTORY}/travis-ci-bintray-deploy.json.in" 
    "${CMAKE_CURRENT_BINARY_DIR}/travis-ci-bintray-deploy.json" @ONLY)

  message(STATUS "Configured target 'dist-package' with Linux '${PKG_DIST}' and package type '${PKG_TYPE}'")
endfunction()

## Add 'source-archive' target
function(add_source_archive_target target)
  find_package(Git)
  find_program(TAR_EXECUTABLE tar)
  find_program(GZIP_EXECUTABLE gzip)
  if(GIT_FOUND)
    get_target_property(VERSION_STRING ${target} VERSION_STRING)
    execute_process(COMMAND ${GIT_EXECUTABLE} describe --always
      RESULT_VARIABLE result
      OUTPUT_VARIABLE GIT_TREEISH
      ERROR_VARIABLE error_out
      OUTPUT_STRIP_TRAILING_WHITESPACE
      WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
    )
    if(NOT result EQUAL 0)
      set(GIT_TREEISH "HEAD")
    endif()

    # Write
    set(ARCHIVE_STAGE_DIR "${PROJECT_BINARY_DIR}/archive_stage")
    set(FILE_BASENAME "${target}-${VERSION_STRING}_source")
    set(GIT_TAR_FILE_PATH "${ARCHIVE_STAGE_DIR}/${FILE_BASENAME}.git-stage.tar")
    add_custom_command(OUTPUT "${GIT_TAR_FILE_PATH}"
      COMMAND ${CMAKE_COMMAND} ARGS -E make_directory "${ARCHIVE_STAGE_DIR}"
      COMMAND ${GIT_EXECUTABLE} ARGS archive --format=tar --prefix=${target}-${VERSION_STRING}/ --output="${GIT_TAR_FILE_PATH}" ${GIT_TREEISH}
      WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
      COMMENT "Running git archive (${target})..."
    )
    set(ARCHIVE_OUTPUT_DIR "${PROJECT_BINARY_DIR}/archive_output")
    set(TAR_FILE_PATH "${ARCHIVE_OUTPUT_DIR}/${FILE_BASENAME}.tar")
    set(TARGZ_FILE_PATH "${TAR_FILE_PATH}.gz")
    set(TAR_APPEND_DIR "${PROJECT_BINARY_DIR}/archive_append")
    add_custom_command(OUTPUT "${TARGZ_FILE_PATH}"
      DEPENDS "${GIT_TAR_FILE_PATH}"
      COMMAND ${CMAKE_COMMAND} ARGS -E copy "${GIT_TAR_FILE_PATH}" "${TAR_FILE_PATH}"
      COMMAND ${CMAKE_COMMAND} ARGS -E create_symlink "${PROJECT_BINARY_DIR}/archive_append" "${ARCHIVE_STAGE_DIR}/${target}-${VERSION_STRING}"
      COMMAND ${TAR_EXECUTABLE} ARGS -rf "${TAR_FILE_PATH}" "${target}-${VERSION_STRING}/*"
      COMMAND ${GZIP_EXECUTABLE} ARGS -9f "${TAR_FILE_PATH}"
      WORKING_DIRECTORY ${ARCHIVE_STAGE_DIR}
      COMMENT "Add version information to git archive (${target})..."
    )
    add_custom_target(source-archive DEPENDS "${TARGZ_FILE_PATH}")
  else()
    message(STATUS "Cannot add 'source-archive' target, git not found.")
  endif()
endfunction()
