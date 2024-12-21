@echo off
setlocal enabledelayedexpansion

rem 这是一个用于为Carla（carla.org）创建二进制文件的BAT脚本。
rem 特别提醒，需要在启用了x64 Visual C++ 工具集的cmd中运行此脚本，以确保相关编译等操作能正常进行。

set LOCAL_PATH=%~dp0
set FILE_N=-[%~n0]:

rem 打印批处理参数（用于调试目的），这样在运行脚本时可以查看传入的参数情况，方便排查问题
echo %FILE_N% [Batch params]: %*
rem ============================================================================
rem -- 解析参数 --------------------------------------------------------------
rem ============================================================================

rem 初始化各个变量，为后续根据不同条件判断和操作做准备，以下是对每个变量含义的初始化设定
set BUILD_UE4_EDITOR=false        rem 是否构建UE4编辑器，初始化为不构建
set LAUNCH_UE4_EDITOR=false       rem 是否启动UE4编辑器，初始化为不启动
set REMOVE_INTERMEDIATE=false     rem 是否移除中间文件，初始化为不移除
set USE_CARSIM=false              rem 是否使用CarSim，初始化为不使用
set USE_CHRONO=false              rem 是否使用Chrono，初始化为不使用
set USE_UNITY=true                rem 是否使用Unity，初始化为使用
set CARSIM_STATE="CarSim OFF"     rem CarSim状态，初始化为关闭状态
set CHRONO_STATE="Chrono OFF"     rem Chrono状态，初始化为关闭状态
set UNITY_STATE="Unity ON"        rem Unity状态，初始化为开启状态
set AT_LEAST_WRITE_OPTIONALMODULES=false rem 是否至少写入可选模块，初始化为不写入
set EDITOR_FLAGS=""               rem 编辑器标志，初始化为空字符串
set USE_ROS2=false                rem 是否使用ROS2，初始化为不使用
set ROS2_STATE="Ros2 OFF"         rem ROS2状态，初始化为关闭状态

:arg-parse
echo %1
if not "%1"=="" (
    if "%1"=="--editor-flags" (
        set EDITOR_FLAGS=%2       rem 设置编辑器标志，当命令行参数传入 --editor-flags 时，将其后紧跟的参数作为编辑器标志赋值给 EDITOR_FLAGS 变量
        shift
    )
    if "%1"=="--build" (
        set BUILD_UE4_EDITOR=true rem 当命令行参数传入 --build 时，设置为构建UE4编辑器，即将对应变量置为 true
    )
    if "%1"=="--launch" (
        set LAUNCH_UE4_EDITOR=true rem 当命令行参数传入 --launch 时，设置为启动UE4编辑器，对应变量置为 true
    )
    if "%1"=="--clean" (
        set REMOVE_INTERMEDIATE=true rem 当命令行参数传入 --clean 时，设置为移除中间文件，改变对应变量状态为 true
    )
    if "%1"=="--carsim" (
        set USE_CARSIM=true       rem 当命令行参数传入 --carsim 时，设置为使用CarSim，将对应变量改为 true
    )
    if "%1"=="--chrono" (
        set USE_CHRONO=true       rem 当命令行参数传入 --chrono 时，设置为使用Chrono，相应变量置为 true
    )
    if "%1"=="--ros2" (
        set USE_ROS2=true         rem 当命令行参数传入 --ros2 时，设置为使用ROS2，对应变量赋值为 true
    )
    if "%1"=="--no-unity" (
        set USE_UNITY=false       rem 当命令行参数传入 --no-unity 时，设置为不使用Unity，改变对应变量的值为 false
    )
    if "%1"=="--at-least-write-optionalmodules" (
        set AT_LEAST_WRITE_OPTIONALMODULES=true rem 当命令行参数传入 --at-least-write-optionalmodules 时，设置为至少写入可选模块，将对应变量设为 true
    )
    if "%1"=="-h" (
        goto help                 rem 当命令行参数传入 -h 时，跳转到帮助信息部分，显示脚本的使用帮助
    )
    if "%1"=="--help" (
        goto help                 rem 当命令行参数传入 --help 时，同样跳转到帮助信息部分展示脚本使用说明
    )
    shift                         rem 移动到下一个参数，用于处理多个连续传入的参数情况，保证能逐个解析
    goto arg-parse                rem 继续解析参数，循环处理所有传入的命令行参数
)

rem 可以在此处添加实际的构建逻辑和命令，目前主要是对编辑器标志进行处理，移除其中可能存在的引号
set EDITOR_FLAGS=%EDITOR_FLAGS:"=%

rem 以下是一系列的条件判断，如果既不移除中间文件，也不启动、构建UE4编辑器，同时也不至少写入可选模块，那么就跳转到帮助信息部分，
rem 意味着在没有执行这些主要操作之一的情况下，脚本认为不符合预期使用方式，引导用户查看帮助了解正确用法
if %REMOVE_INTERMEDIATE% == false (
    if %LAUNCH_UE4_EDITOR% == false (
        if %BUILD_UE4_EDITOR% == false (
            if %AT_LEAST_WRITE_OPTIONALMODULES% == false (
                goto help
            )
        )
    )
)

rem 获取Unreal Engine的根目录
rem 如果未定义UE4_ROOT变量，就尝试从注册表中查找Unreal Engine的安装目录，
rem 查找的是64位注册表中的相关键值，找到后将其赋值给UE4_ROOT变量，若找不到则跳转到错误处理部分
if not defined UE4_ROOT (
    set KEY_NAME="HKEY_LOCAL_MACHINE\SOFTWARE\EpicGames\Unreal Engine"
    set VALUE_NAME=InstalledDirectory
    for /f "usebackq tokens=1,2,*" %%A in (`reg query!KEY_NAME! /s /reg:64`) do (
        if "%%A" == "!VALUE_NAME!" (
            set UE4_ROOT=%%C
        )
    )
    if not defined UE4_ROOT goto error_unreal_no_found
)
rem 确保UE4_ROOT的末尾有反斜杠，方便后续路径拼接等操作能正确进行，如果末尾不是反斜杠则添加
if not "%UE4_ROOT:~-1%"=="\" set UE4_ROOT=%UE4_ROOT%\

rem 设置Visual Studio解决方案的目录，先将ROOT_PATH中的斜杠替换为反斜杠，再拼接上Unreal\CarlaUE4\路径，
rem 然后切换到该目录下（通过pushd命令），后续的很多操作都将在此目录及其子目录下进行
set UE4_PROJECT_FOLDER=%ROOT_PATH:/=\%Unreal\CarlaUE4\
pushd "%UE4_PROJECT_FOLDER%"

rem 清除由构建系统生成的二进制文件和中间文件，根据 REMOVE_INTERMEDIATE 变量的值来决定是否执行清理操作
rem 如果变量为 true，则遍历指定的一系列目录和文件，若存在则进行删除操作，同时打印出清理的相关信息
if %REMOVE_INTERMEDIATE% == true (
    rem 删除以下目录
    for %%G in (
        "%UE4_PROJECT_FOLDER%Binaries",
        "%UE4_PROJECT_FOLDER%Build",
        "%UE4_PROJECT_FOLDER%Saved",
        "%UE4_PROJECT_FOLDER%Intermediate",
        "%UE4_PROJECT_FOLDER%Plugins\Carla\Binaries",
        "%UE4_PROJECT_FOLDER%Plugins\Carla\Intermediate",
        "%UE4_PROJECT_FOLDER%Plugins\HoudiniEngine\",
        "%UE4_PROJECT_FOLDER%.vs"
    ) do (
        if exist %%G (
            echo %FILE_N% Cleaning %%G
            rmdir /s/q %%G
        )
    )

    rem 删除以下文件
    for %%G in (
        "%UE4_PROJECT_FOLDER%CarlaUE4.sln"
    ) do (
        if exist %%G (
            echo %FILE_N% Cleaning %%G
            del %%G
        )
    )
)

rem 构建Carla编辑器，这部分包含对一些插件相关的处理以及根据不同模块使用情况对项目配置的修改等操作
rem 首先是对Omniverse插件的处理，如果插件文件夹存在，则进行相关文件的拷贝操作，并标记插件状态为开启；若不存在则标记为关闭
rem 然后根据 USE_CARSIM、USE_CHRONO、USE_ROS2、USE_UNITY 等变量的值来设置对应模块的状态，并将这些状态信息写入到可选模块的配置文件中
rem 最后根据 BUILD_UE4_EDITOR 变量的值决定是否执行构建Unreal Editor的命令，如果构建出现错误则跳转到相应的错误处理部分
set OMNIVERSE_PATCH_FOLDER=%ROOT_PATH%Util\Patches\omniverse_4.26\
set OMNIVERSE_PLUGIN_FOLDER=%UE4_ROOT%Engine\Plugins\Marketplace\NVIDIA\Omniverse\
if exist %OMNIVERSE_PLUGIN_FOLDER% (
    set OMNIVERSE_PLUGIN_INSTALLED="Omniverse ON"
    xcopy /Y /S /I "%OMNIVERSE_PATCH_FOLDER%USDCARLAInterface.h" "%OMNIVERSE_PLUGIN_FOLDER%Source\OmniverseUSD\Public\" > NUL
    xcopy /Y /S /I "%OMNIVERSE_PATCH_FOLDER%USDCARLAInterface.cpp" "%OMNIVERSE_PLUGIN_FOLDER%Source\OmniverseUSD\Private\" > NUL
) else (
    set OMNIVERSE_PLUGIN_INSTALLED="Omniverse OFF"
)

if %USE_CARSIM% == true (
    python %ROOT_PATH%Util/BuildTools/enable_carsim_to_uproject.py -f="%ROOT_PATH%Unreal/CarlaUE4/CarlaUE4.uproject" -e
    set CARSIM_STATE="CarSim ON"
) else {
    python %ROOT_PATH%Util/BuildTools/enable_carsim_to_uproject.py -f="%ROOT_PATH%Unreal/CarlaUE4/CarlaUE4.uproject"
    set CARSIM_STATE="CarSim OFF"
}
if %USE_CHRONO% == true (
    set CHRONO_STATE="Chrono ON"
) else {
    set CHRONO_STATE="Chrono OFF"
}
if %USE_ROS2% == true (
    set ROS2_STATE="Ros2 ON"
} else {
    set ROS2_STATE="Ros2 OFF"
}
if %USE_UNITY% == true (
    set UNITY_STATE="Unity ON"
} else {
    set UNITY_STATE="Unity OFF"
}
set OPTIONAL_MODULES_TEXT=%CARSIM_STATE% %CHRONO_STATE% %ROS2_STATE% %OMNIVERSE_PLUGIN_INSTALLED% %UNITY_STATE%
echo %OPTIONAL_MODULES_TEXT% > "%ROOT_PATH%Unreal/CarlaUE4/Config/OptionalModules.ini"

rem 检查是否构建Unreal Editor，如果 BUILD_UE4_EDITOR 变量为 true，则执行构建Unreal Editor的命令，
rem 这里分两次调用构建脚本，分别构建CarlaUE4Editor和CarlaUE4项目，如果构建过程中出现错误（通过 errorlevel 判断），则跳转到相应的错误处理部分
if %BUILD_UE4_EDITOR% == true (
    echo %FILE_N% Building Unreal Editor...

    call "%UE4_ROOT%Engine\Build\BatchFiles\Build.bat"^
        CarlaUE4Editor^
        Win64^
        Development^
        -WaitMutex^
        -FromMsBuild^
        "%ROOT_PATH%Unreal/CarlaUE4/CarlaUE4.uproject"
    if errorlevel 1 goto bad_exit

    call "%UE4_ROOT%Engine\Build\BatchFiles\Build.bat"^
        CarlaUE4^
        Win64^
        Development^
        -WaitMutex^
        -FromMsBuild^
        "%ROOT_PATH%Unreal/CarlaUE4/CarlaUE4.uproject"
    if errorlevel 1 goto bad_exit
)

rem 启动Carla Editor，根据 LAUNCH_UE4_EDITOR 变量的值来决定是否启动UE4编辑器，
rem 如果启动过程中出现错误（通过 errorlevel 判断），则跳转到相应的错误处理部分
if %LAUNCH_UE4_EDITOR% == true (
    echo %FILE_N% Launching Unreal Editor...
    call "%UE4_ROOT%\Engine\Binaries\Win64\UE4Editor.exe"^
        "%UE4_PROJECT_FOLDER%CarlaUE4.uproject" %EDITOR_FLAGS%
    if %errorlevel% neq 0 goto error_build
)

goto good_exit

rem ============================================================================
rem -- Messages and Errors -----------------------------------------------------
rem ============================================================================

:help
    echo Build LibCarla.
    echo "Usage: %FILE_N% [-h^|--help] [--build] [--launch] [--clean]"
    goto good_exit

:error_build
    echo.
    echo %FILE_N% [ERROR] There was a problem building CarlaUE4.
    echo %FILE_N%         Please go to "Carla\Unreal\CarlaUE4", right click on
    echo %FILE_N%         "CarlaUE4.uproject" and select:
    echo %FILE_N%         "Generate Visual Studio project files"
    echo %FILE_N%         Open de generated "CarlaUE4.sln" and try to manually compile it
    echo %FILE_N%         and check what is causing the error.
    goto bad_exit

:good_exit
    endlocal
    exit /b 0

:bad_exit
    endlocal
    exit /b %errorlevel%

:error_unreal_no_found
    echo.
    echo %FILE_N% [ERROR] Unreal Engine not detected
    goto bad_exit
