@echo off
setlocal enabledelayedexpansion

rem BAT script that creates the library for conversion from OSM to OpenDRIVE (carla.org).
rem Run it through a cmd with the x64 Visual C++ Toolset enabled.

set LOCAL_PATH=%~dp0
set FILE_N=-[%~n0]:

rem Print batch params (debug purpose)，用于在运行时打印传入的批处理参数，方便调试查看传入的具体参数情况
echo %FILE_N% [Batch params]: %*

rem ============================================================================
rem -- Parse arguments ---------------------------------------------------------
rem ============================================================================

set DOC_STRING=Build LibCarla.
set USAGE_STRING=Usage: %FILE_N% [-h^|--help] [--rebuild] [--build] [--clean] [--no-pull]

set REMOVE_INTERMEDIATE=false
set BUILD_OSM2ODR=false
set GIT_PULL=true
set CURRENT_OSM2ODR_COMMIT=1835e1e9538d0778971acc8b19b111834aae7261
set OSM2ODR_BRANCH=aaron/defaultsidewalkwidth
set OSM2ODR_REPO=https://github.com/carla-simulator/sumo.git

:arg-parse
if not "%1"=="" (
    if "%1"=="--rebuild" (
        set REMOVE_INTERMEDIATE=true
        set BUILD_OSM2ODR=true
    )
    if "%1"=="--build" (
        set BUILD_OSM2ODR=true
    )
    if "%1"=="--no-pull" (
        set GIT_PULL=false
    )
    if "%1"=="--clean" (
        set REMOVE_INTERMEDIATE=true
    )
    if "%1"=="--generator" (
        set GENERATOR=%2
        shift
    )
    if "%1"=="-h" (
        echo %DOC_STRING%
        echo %USAGE_STRING%
        GOTO :eof
    )
    if "%1"=="--help" (
        echo %DOC_STRING%
        echo %USAGE_STRING%
        GOTO :eof
    )
    shift
    goto :arg-parse
)

if %REMOVE_INTERMEDIATE% == false (
    if %BUILD_OSM2ODR% == false (
        echo Nothing selected to be done.
        goto :eof
    )
)

rem ============================================================================
rem -- Local Variables ---------------------------------------------------------
rem ============================================================================

rem Set the visual studio solution directory
rem 以下是设置与项目相关的各种路径变量，包括 Visual Studio 项目路径、源码路径、安装路径等，
rem 并且将路径中的斜杠统一替换为反斜杠，以适配 Windows 下的路径格式要求
set OSM2ODR_VSPROJECT_PATH=%INSTALLATION_DIR:/=\%osm2odr-visualstudio\
set OSM2ODR_SOURCE_PATH=%INSTALLATION_DIR:/=\%osm2odr-source\
set OSM2ODR_INSTALL_PATH=%ROOT_PATH:/=\%PythonAPI\carla\dependencies\
set OSM2ODR__SERVER_INSTALL_PATH=%ROOT_PATH:/=\%Unreal\CarlaUE4\Plugins\Carla\CarlaDependencies
set CARLA_DEPENDENCIES_FOLDER=%ROOT_PATH:/=\%Unreal\CarlaUE4\Plugins\Carla\CarlaDependencies\

if %GENERATOR% == "" set GENERATOR="Visual Studio 16 2019"

rem 以下是添加编译依赖文件相关的部分，用于处理可能需要的一些前置依赖，比如确保相关依赖库的目录存在等

rem 检查并创建 proj 依赖相关的目录（如果不存在的话），proj 可能是项目中涉及坐标转换等功能的依赖库
if not exist "%INSTALLATION_DIR%\proj-install" (
    mkdir "%INSTALLATION_DIR%\proj-install"
)

rem 检查并创建 xerces-c 依赖相关的目录（如果不存在的话），xerces-c 可能用于处理 XML 相关操作，比如解析配置文件等
if not exist "%INSTALLATION_DIR%\xerces-c-3.2.3-install" (
    mkdir "%INSTALLATION_DIR%\xerces-c-3.2.3-install"
)

rem 以下代码块用于下载 proj 依赖库（这里只是示例伪代码，实际需要根据具体的 proj 下载源和方式来替换，比如可能是从官网下载安装包然后解压等操作）
rem 假设 proj 有对应的下载链接，这里使用 curl 模拟下载，实际可能需要替换为真实有效的下载方式
rem curl --retry 5 --retry-max-time 120 -L -o proj.zip https://example.com/proj.zip
rem tar -xf proj.zip
rem del proj.zip
rem ren proj proj-install

rem 以下代码块用于下载 xerces-c 依赖库（同样是示例伪代码，需按实际情况调整）
rem 假设 xerces-c 有对应的下载链接，此处模拟下载解压过程
rem curl --retry 5 --retry-max-time 120 -L -o xerces-c.zip https://example.com/xerces-c.zip
rem tar -xf xerces-c.zip
rem del xerces-c.zip
rem ren xerces-c xerces-c-3.2.3-install

if %REMOVE_INTERMEDIATE% == true (
    rem Remove directories，用于删除指定的中间文件目录，如果 REMOVE_INTERMEDIATE 变量为 true 的话，会遍历下面的目录并删除
    for %%G in (
        "%OSM2ODR_INSTALL_PATH%",
    ) do (
        if exist %%G (
            echo %FILE_N% Cleaning %%G
            rmdir /s/q %%G
        )
    )
)

rem Build OSM2ODR，根据 BUILD_OSM2ODR 变量的值来决定是否执行构建 OSM2ODR 的操作，构建过程涉及从源码获取、配置生成、编译安装等步骤
if %BUILD_OSM2ODR% == true (
    cd "%INSTALLATION_DIR%"
    if not exist "%OSM2ODR_SOURCE_PATH%" (
        curl --retry 5 --retry-max-time 120 -L -o OSM2ODR.zip https://github.com/carla-simulator/sumo/archive/%CURRENT_OSM2ODR_COMMIT%.zip
        tar -xf OSM2ODR.zip
        del OSM2ODR.zip
        ren sumo-%CURRENT_OSM2ODR_COMMIT% osm2odr-source
    )
    
    cd..
    if not exist "%OSM2ODR_VSPROJECT_PATH%" mkdir "%OSM2ODR_VSPROJECT_PATH%"
    cd "%OSM2ODR_VSPROJECT_PATH%"

    cmake -G %GENERATOR% -A x64^
        -DCMAKE_CXX_FLAGS_RELEASE="/MD /MP"^
        -DCMAKE_INSTALL_PREFIX="%OSM2ODR_INSTALL_PATH:\=/%"^
        -DPROJ_INCLUDE_DIR=%INSTALLATION_DIR:/=\%\proj-install\include^
        -DPROJ_LIBRARY=%INSTALLATION_DIR:/=\%\proj-install\lib\proj.lib^
        -DXercesC_INCLUDE_DIR=%INSTALLATION_DIR:/=\%\xerces-c-3.2.3-install\include^
        -DXercesC_LIBRARY=%INSTALLATION_DIR:/=\%\xerces-c-3.2.3-install\lib\xerces-c.lib^
        "%OSM2ODR_SOURCE_PATH%"
    if %errorlevel% neq 0 goto error_cmake

    cmake --build. --config Release --target install | findstr /V "Up-to-date:"
    if %errorlevel% neq 0 goto error_install
    copy %OSM2ODR_INSTALL_PATH%\lib\osm2odr.lib %CARLA_DEPENDENCIES_FOLDER%\lib
    copy %OSM2ODR_INSTALL_PATH%\include\OSM2ODR.h %CARLA_DEPENDENCIES_FOLDER%\include
)

goto success

rem ============================================================================
rem -- Messages and Errors -----------------------------------------------------
rem ============================================================================

:success
    if %BUILD_OSM2ODR% == true echo %FILE_N% OSM2ODR has been successfully installed in "%OSM2ODR_INSTALL_PATH%"!
    goto good_exit

:error_cmake
    echo.
    echo %FILE_N% [ERROR] An error ocurred while executing the cmake.
    echo           [ERROR] Possible causes:
    echo           [ERROR]  - Make sure "CMake" is installed.
    echo           [ERROR]  - Make sure it is available on your Windows "path".
    echo           [ERROR]  - CMake 3.9.0 or higher is required.
    goto bad_exit

:error_install
    echo.
    echo %FILE_N% [ERROR] An error ocurred while installing using %GENERATOR% Win64.
    echo           [ERROR] Possible causes:
    echo           [ERROR]  - Make sure you have Visual Studio installed.
    echo           [ERROR]  - Make sure you have the "x64 Visual C++ Toolset" in your path.
    echo           [ERROR]    For example using the "Visual Studio x64 Native Tools Command Prompt",
    echo           [ERROR]    or the "vcvarsall.bat".
    goto bad_exit

:good_exit
    endlocal
    exit /b 0

:bad_exit
    endlocal
    exit /b %errorlevel%
