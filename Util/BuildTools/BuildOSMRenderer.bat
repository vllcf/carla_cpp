rem if not exist "%VCPKG_PATH%" git clone %VCPKG_REPO% %VCPKG_PATH%
rem.\"%VCPKG_PATH:/=\%"bootstrap-vcpkg.bat
if not exist "%LIBOSMSCOUT_SOURCE_PATH%" git clone %LIBOSMSCOUT_REPO% %LIBOSMSCOUT_SOURCE_PATH%
if not exist "%LIBOSMSCOUT_VSPROJECT_PATH%" mkdir "%LIBOSMSCOUT_VSPROJECT_PATH%"
cd "%LIBOSMSCOUT_VSPROJECT_PATH%"
cmake -G "Visual Studio 16 2019"^
    -DCMAKE_INSTALL_PREFIX="%DEPENDENCIES_INSTALLATION_PATH:\=/%"^
    -DOSMSCOUT_BUILD_TOOL_STYLEEDITOR=OFF^
    -DOSMSCOUT_BUILD_TOOL_OSMSCOUT2=OFF^
    -DOSMSCOUT_BUILD_TESTS=OFF^
    -DOSMSCOUT_BUILD_CLIENT_QT=OFF^
    -DOSMSCOUT_BUILD_DEMOS=OFF^
    "%LIBOSMSCOUT_SOURCE_PATH%"
cmake --build. --config=Release --target install
if not exist "%OSM_RENDERER_VSPROJECT_PATH%" mkdir "%OSM_RENDERER_VSPROJECT_PATH%"
cd "%OSM_RENDERER_VSPROJECT_PATH%"
cmake -G "Visual Studio 16 2019" -A x64^
    -DCMAKE_CXX_FLAGS_RELEASE="/std:c++17 /wd4251 /I%INSTALLATION_DIR:/=\%boost-1.80.0-install\include"^
    "%OSM_RENDERER_SOURCE%"
cmake --build. --config Release
copy "%DEPENDENCIES_INSTALLATION_PATH:/=\%"bin "%OSM_RENDERER_VSPROJECT_PATH:/=\%"Release\
link_directories("C:/my_custom_libs")
target_link_libraries(<your_project_target> PRIVATE mylib)
link_directories("C:/my_custom_libs")
target_link_libraries(<your_project_target> PRIVATE mylib)
if not exist "%NEWLIB_SOURCE_PATH%" git clone %NEWLIB_REPO% %NEWLIB_SOURCE_PATH%
if not exist "%NEWLIB_VSPROJECT_PATH%" mkdir "%NEWLIB_VSPROJECT_PATH%"
cd "%NEWLIB_VSPROJECT_PATH%"
cmake -G "Visual Studio 16 2019"^
    -DCMAKE_INSTALL_PREFIX="%DEPENDENCIES_INSTALLATION_PATH:\=/%"^
    "%NEWLIB_SOURCE_PATH%"
cmake --build. --config=Release --target install
