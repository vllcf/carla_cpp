@echo off
setlocal enabledelayedexpansion

rem ==============================================================================
rem -- Set up environment --------------------------------------------------------
rem ==============================================================================

set REPLACE_LATEST=true
rem 设置一个变量，用于控制是否替换最新版本，初始值设为true，表示默认会进行替换最新版本的操作
set AWS_COPY=aws s3 cp
rem 定义用于执行AWS S3复制操作的命令字符串，后续通过改变这个变量来实现不同模式（如 dry-run 模式）下的行为

rem ==============================================================================
rem -- Parse arguments -----------------------------------------------------------
rem ==============================================================================

set DOC_STRING=Upload latest build to S3
rem 定义文档字符串，用于描述脚本的主要功能，即上传最新构建到S3存储桶
set USAGE_STRING="Usage: $0 [-h|--help] [--replace-latest] [--dry-run]"
rem 定义使用说明字符串，展示脚本的正确使用方式，告知用户可以使用哪些参数及功能

:arg-parse
rem 定义一个标签，用于参数解析的循环处理
if not "%1"=="" (
    rem 判断当前传入的第一个参数是否为空，如果不为空则进入参数判断分支
    if "%1"=="--replace-latest" (
        rem 如果参数是 --replace-latest，将 REPLACE_LATEST 变量设置为 true，确认要进行替换最新版本的操作
        set REPLACE_LATEST=true
    )

    if "%1"=="--dry-run" (
        rem 如果参数是 --dry-run，将 AWS_COPY 命令修改为以 rem 开头（在批处理中，rem 表示注释，这样实际执行时此命令就不会真正执行，用于模拟执行的情况）
        set AWS_COPY=rem aws s3 cp
    )

    if "%1"=="--help" (
        rem 如果参数是 --help，输出脚本的功能描述（DOC_STRING）和使用说明（USAGE_STRING），然后跳转到脚本末尾结束执行
        echo %DOC_STRING%
        echo %USAGE_STRING%
        GOTO :eof
    )

    shift
    rem 将命令行参数左移一位，去掉已经处理过的当前参数，继续循环处理下一个参数
    goto :arg-parse
)

rem Get repository version
rem 以下部分用于获取代码仓库的版本信息
for /f %%i in ('git describe --tags --dirty --always') do set REPOSITORY_TAG=%%i
rem 通过执行 git 命令获取仓库的标签描述信息（包含是否有未提交的更改等情况），并将结果赋值给 REPOSITORY_TAG 变量
if not defined REPOSITORY_TAG goto error_carla_version
rem 如果 REPOSITORY_TAG 变量未定义（即获取版本信息失败），跳转到 error_carla_version 标签处处理错误情况
echo REPOSITORY_TAG =!REPOSITORY_TAG!
rem 输出获取到的仓库版本信息（这里使用了延迟扩展，所以用! 来获取变量值）

rem Last package data
rem 以下部分设置与要上传的软件包相关的各种路径和文件名等变量
set CARLA_DIST_FOLDER=%~dp0%\Build\UE4Carla
rem 设置 CARLA 软件包所在的文件夹路径，%~dp0 表示当前批处理脚本所在的目录
set PACKAGE=CARLA_%REPOSITORY_TAG%.zip
rem 根据仓库版本号构建软件包的文件名
set PACKAGE_PATH=%CARLA_DIST_FOLDER%\%PACKAGE%
rem 构建软件包的完整路径
set PACKAGE2=AdditionalMaps_%REPOSITORY_TAG%.zip
set PACKAGE_PATH2=%CARLA_DIST_FOLDER%\%PACKAGE2%

set S3_PREFIX=s3://carla-releases/Windows
rem 设置要上传到的 S3 存储桶的前缀路径，用于区分不同操作系统等情况

set LATEST_DEPLOY_URI=!S3_PREFIX!/Dev/CARLA_Latest.zip
set LATEST_DEPLOY_URI2=!S3_PREFIX!/Dev/AdditionalMaps_Latest.zip
rem 设置用于替换最新版本时的目标 S3 路径，用于后续将当前上传的版本设置为最新版本的操作

rem Check for TAG version
rem 以下部分检查获取到的版本标签是否符合发布版本的格式要求（数字.数字.数字.其他内容）
echo %REPOSITORY_TAG% | findstr /R /C:"^[0-9]*\.[0-9]*\.[0-9]*.$" 1>nul
if %errorlevel% == 0 (
    rem 如果符合发布版本格式，输出相应提示信息，并设置正式部署时使用的文件名（和之前根据版本号构建的文件名一致）
    echo Detected release version with tag %REPOSITORY_TAG%
    set DEPLOY_NAME=CARLA_%REPOSITORY_TAG%.zip
    set DEPLOY_NAME2=AdditionalMaps_%REPOSITORY_TAG%.zip
) else (
    rem 如果不符合发布版本格式，说明是非发布版本，输出相应提示信息，调整 S3 前缀路径到开发路径下（/Dev），并通过 git 日志信息构建独特的部署文件名
    echo Detected non-release version with tag %REPOSITORY_TAG%
    set S3_PREFIX=!S3_PREFIX!/Dev
    git log --pretty=format:%%cd_%%h --date=format:%%Y%%m%%d -n 1 > tempo1234
    rem 通过 git 日志获取最近一次提交的日期和哈希值等信息，保存到临时文件 tempo1234 中
    set /p DEPLOY_NAME= < tempo1234
    del tempo1234
    rem 从临时文件中读取内容赋值给 DEPLOY_NAME 变量，然后删除临时文件，并添加.zip 后缀构建最终的部署文件名
    set DEPLOY_NAME=!DEPLOY_NAME!.zip
    echo deploy name =!DEPLOY_NAME!
    
    git log --pretty=format:%%h -n 1 > tempo1234
    set /p DEPLOY_NAME2= < tempo1234
    del tempo1234
    set DEPLOY_NAME2=AdditionalMaps_!DEPLOY_NAME2!.zip
    echo deploy name2 =!DEPLOY_NAME2!
)
echo Version detected: %REPOSITORY_TAG%
echo Using package %PACKAGE% as %DEPLOY_NAME%

if not exist "%PACKAGE_PATH%" (
    rem 判断软件包文件是否存在，如果不存在，输出提示信息，要求用户先运行 'make package' 命令来生成软件包，然后跳转到 bad_exit 标签结束脚本并返回错误码
    echo Latest package not found, please run 'make package'
    goto :bad_exit
)

rem ==============================================================================
rem -- Upload --------------------------------------------------------------------
rem ==============================================================================

set DEPLOY_URI=!S3_PREFIX!/%DEPLOY_NAME%
%AWS_COPY% %PACKAGE_PATH% %DEPLOY_URI%
echo Latest build uploaded to %DEPLOY_URI%
rem 根据前面设置的变量，构建要上传的 S3 目标路径，然后使用 AWS_COPY 命令（可能是真实执行或模拟执行，取决于参数设置）将软件包上传到 S3，并输出上传成功的提示信息

set DEPLOY_URI2=!S3_PREFIX!/%DEPLOY_NAME2%
%AWS_COPY% %PACKAGE_PATH2% %DEPLOY_URI2%
echo Latest build uploaded to %DEPLOY_URI2%
rem 同样的操作，上传第二个软件包（AdditionalMaps相关的）到 S3，并输出相应提示信息

rem ==============================================================================
rem -- Replace Latest ------------------------------------------------------------
rem ==============================================================================

if %REPLACE_LATEST%==true (
    rem 判断是否需要替换最新版本（根据前面的参数设置判断），如果是，则执行以下操作
    %AWS_COPY% %DEPLOY_URI% %LATEST_DEPLOY_URI%
    echo Latest build updated as %LATEST_DEPLOY_URI%
    %AWS_COPY% %DEPLOY_URI2% %LATEST_DEPLOY_URI2%
    echo Latest build updated as %LATEST_DEPLOY_URI2%
    rem 将刚上传的软件包复制到用于表示最新版本的 S3 路径下，实现更新最新版本的操作，并输出相应提示信息
)

rem ==============================================================================
rem --...and we are done --------------------------------------------------------
rem ==============================================================================

echo Success!

:success
    echo.
    goto good_exit
rem 成功结束的标签，输出空行后跳转到 good_exit 标签处结束脚本并返回成功码0，正常结束脚本执行

:error_carla_version
    echo.
    echo %FILE_N% [ERROR] Carla Version is not set
    goto bad_exit
rem 处理Carla版本未设置的错误情况，输出错误信息后跳转到 bad_exit 标签处结束脚本并返回错误码1，表示脚本执行出现错误

:good_exit
    endlocal
    exit /b 0
rem 正常结束脚本的标签，结束局部变量作用域并以成功码0退出脚本

:bad_exit
    endlocal
    exit /b 1
rem 错误结束脚本的标签，结束局部变量作用域并以错误码1退出脚本
