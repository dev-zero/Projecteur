cmake_minimum_required(VERSION 3.6)

# Use QTDIR environment variable with find_package,
#  e.g. set QTDIR=/home/user/Qt/5.9.6/gcc_64/
if(NOT "$ENV{QTDIR}" STREQUAL "")
  set(QTDIR $ENV{QTDIR})
  list(APPEND CMAKE_PREFIX_PATH $ENV{QTDIR})
elseif(QTDIR)
  list(APPEND CMAKE_PREFIX_PATH ${QTDIR})
endif()

# Set the default build type to release
if( NOT CMAKE_BUILD_TYPE )
  message(STATUS "Setting build type to 'Release' as none was specified.")
  set(CMAKE_BUILD_TYPE "Release" CACHE STRING "Choose the type of build." FORCE)
  set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS "Debug" "Release" "MinSizeRel" "RelWithDebInfo")
endif()

project(Projecteur LANGUAGES CXX)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake/modules")
include(GitVersion)

set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
find_package(Qt5 COMPONENTS Core Gui Quick Widgets REQUIRED)

add_executable(projecteur
  main.cc
  aboutdlg.cc           aboutdlg.h
  colorselector.cc      colorselector.h
  imageitem.cc          imageitem.h
  preferencesdlg.cc     preferencesdlg.h
  projecteurapp.cc      projecteurapp.h
  runguard.cc           runguard.h
  settings.cc           settings.h
  spotlight.cc          spotlight.h
  spotshapes.cc         spotshapes.h
  resources.qrc         qml/qml.qrc)

target_link_libraries(projecteur
  Qt5::Core Qt5::Quick Qt5::Widgets
)

# Set version project properties for builds not from a git repository (e.g. created with git archive)
# If creating the version number via git information fails, the following target properties
# will be used. IMPORTANT - when creating a release tag with git flow: 
#  Update this information - the version numbers and the version type.
#  VERSION_TYPE must be either 'release' or 'develop'
set_target_properties(projecteur PROPERTIES 
  VERSION_MAJOR 0
  VERSION_MINOR 6
  VERSION_PATCH 0
  VERSION_TYPE develop
)
add_version_info(projecteur "${CMAKE_CURRENT_SOURCE_DIR}")

# Add target with non-source files for convenience when using IDEs like QtCreator and others
add_custom_target(non-sources SOURCES README.md LICENSE.md)

# Install
install(TARGETS projecteur DESTINATION bin)
set(PROJECTEUR_INSTALL_PATH "${CMAKE_INSTALL_PREFIX}/bin/projecteur")

# Use udev.pc pkg-config file to set the dir path
if (NOT CMAKE_INSTALL_UDEVRULESDIR)
  set (UDEVDIR /lib/udev)
  find_package(PkgConfig)
  if(PKG_CONFIG_FOUND)
    pkg_check_modules(PKGCONFIG_UDEV udev)
    if(PKGCONFIG_UDEV_FOUND)
      execute_process(
        COMMAND ${PKG_CONFIG_EXECUTABLE} --variable=udevdir udev
        OUTPUT_VARIABLE PKGCONFIG_UDEVDIR
        OUTPUT_STRIP_TRAILING_WHITESPACE
      )
      if(PKGCONFIG_UDEVDIR)
        file(TO_CMAKE_PATH "${PKGCONFIG_UDEVDIR}" UDEVDIR)
      endif(PKGCONFIG_UDEVDIR)
    endif(PKGCONFIG_UDEV_FOUND)
  endif(PKG_CONFIG_FOUND)
endif(NOT CMAKE_INSTALL_UDEVRULESDIR)
set (CMAKE_INSTALL_UDEVRULESDIR ${UDEVDIR}/rules.d CACHE PATH "Where to install udev rules")
mark_as_advanced(CMAKE_INSTALL_UDEVRULESDIR)

# Configure and install files
set(DEVICE_USER_GROUP spotlight-device)
set(OUTDIR "${CMAKE_CURRENT_BINARY_DIR}")
set(TMPLDIR "${CMAKE_CURRENT_SOURCE_DIR}/cmake/templates")

configure_file("55-spotlight.rules.in" "55-spotlight.rules" @ONLY)
install(FILES "${OUTDIR}/55-spotlight.rules" DESTINATION ${CMAKE_INSTALL_UDEVRULESDIR}/)

install(FILES icons/projecteur-tray.svg DESTINATION /usr/share/icons/hicolor/48x48/apps/ RENAME projecteur.svg)
install(FILES icons/projecteur-tray.svg DESTINATION /usr/share/icons/hicolor/64x64/apps/ RENAME projecteur.svg)
install(FILES icons/projecteur-tray.svg DESTINATION /usr/share/icons/hicolor/128x128/apps/ RENAME projecteur.svg)
install(FILES icons/projecteur-tray.svg DESTINATION /usr/share/icons/hicolor/256x256/apps/ RENAME projecteur.svg)

configure_file("${TMPLDIR}/Projecteur.desktop.in" "projecteur.desktop" @ONLY)
install(FILES "${OUTDIR}/projecteur.desktop" DESTINATION /usr/share/applications/)

configure_file("${TMPLDIR}/preinst.in" "pkg/scripts/preinst" @ONLY)
configure_file("${TMPLDIR}/postinst.in" "pkg/scripts/postinst" @ONLY)

set(HOMEPAGE "https://github.com/jahnf/Projecteur")

# Add 'dist-package' target: Creates a deb/rpm/tgz package depending on the current Linux distribution
include(LinuxPackaging)
add_dist_package_target(
  PROJECT "${CMAKE_PROJECT_NAME}" 
  TARGET projecteur
  DESCRIPTION_BRIEF "Linux/X11 application for the Logitech Spotlight device."
  DESCRIPTION_FULL "Linux/X11 application for the Logitech Spotlight device.\nHomepage: ${HOMEPAGE}"
  CONTACT "Jahn Fuchs <github.jahnf@wolke7.net>"
  HOMEPAGE "${HOMEPAGE}"
  DEBIAN_SECTION "utils"
  PREINST_SCRIPT "${OUTDIR}/pkg/scripts/preinst"
  POSTINST_SCRIPT "${OUTDIR}/pkg/scripts/postinst"
)

# Add 'source-archive' target
add_source_archive_target(projecteur)

