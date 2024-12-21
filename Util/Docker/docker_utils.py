#!/usr/bin/env python

# Copyright (c) 2019 Computer Vision Center (CVC) at the Universitat Autonoma
# de Barcelona (UAB).
#
# This work is licensed under the terms of the MIT license.
# For a copy, see <https://opensource.org/licenses/MIT>.

import tarfile
import os

# 定义不同颜色的 ANSI 转义序列，用于终端输出颜色设置，通过这些转义序列可以让终端输出呈现不同的颜色效果，增强显示的可读性和视觉区分度
BLUE = '\033[94m'
GREEN = '\033[92m'
RED = '\033[91m'
ENDC = '\033[0m'
BOLD = '\033[1m'
UNDERLINE = '\033[4m'


class ReadableStream():
    """
    这个类用于包装一个生成器，使其具有类似文件读取的 `read` 方法，方便后续按顺序获取生成器产生的数据。

    Attributes:
        _generator: 存储传入的生成器对象，用于后续迭代获取数据。
    """
    def __init__(self, generator):
        """
        初始化函数，接收一个生成器并存储在实例变量中，以便后续通过 `read` 方法获取生成器产生的元素。

        Args:
            generator: 一个生成器对象，将被包装在这个类中，用于按顺序提供数据。
        """
        self._generator = generator

    def read(self):
        """
        读取生成器的下一个元素。每次调用该方法时，会返回生成器的下一个值，类似于从文件中读取下一行数据。

        Returns:
            生成器产生的下一个元素。如果生成器耗尽（没有更多元素），会抛出 `StopIteration` 异常，不过通常在合适的调用环境中会被妥善处理。
        """
        return next(self._generator)


def get_container_name(container):
    """
    从容器的属性中获取容器的名称。

    假设容器对象有一个 `attrs` 属性，其内部的 `Config` 字典中包含 `Image` 键，对应的值就是容器的名称。

    Args:
        container: 表示容器的对象，应该包含相关属性用于获取容器名称的信息。

    Returns:
        以字符串形式返回容器的名称。
    """
    return str(container.attrs['Config']['Image'])


def exec_command(container, command, user="root",
                 silent=False, verbose=False, ignore_error=True):
    """
    在指定的容器中执行命令，并根据不同的参数设置进行相应的输出和错误处理。

    Args:
        container: 要在其中执行命令的容器对象，应该具备执行命令的相关接口或方法。
        command: 要执行的命令字符串，会在容器内的 bash 环境中运行。
        user (str, optional): 在容器内执行命令所使用的用户，默认为 "root"。
        silent (bool, optional): 如果设置为 `True`，则不会打印命令执行的相关信息（如命令本身、输出等），默认为 `False`。
        verbose (bool, optional): 如果设置为 `True`，当命令执行出错时会打印更详细的错误信息，默认为 `False`。
        ignore_error (bool, optional): 如果设置为 `True`，即使命令执行返回错误码（表示命令执行出错），也不会导致程序退出；若设置为 `False`，命令执行出错时会直接退出程序，默认为 `True`。

    Returns:
        命令执行的结果对象，该对象通常包含命令的退出码（`exit_code`）以及命令的输出内容（`output`）等信息，可用于后续判断命令执行情况和获取输出数据。
    """
    # 定义命令前缀，用于在容器中执行 bash 命令，确保命令能在 bash 环境下正确运行
    command_prefix = "bash -c '"
    if not silent:
        # 如果不是静默模式，打印命令执行的用户、容器名称以及要执行的命令信息，使用特定的颜色和格式设置，增强显示效果
        print(''.join([BOLD, BLUE,
                       user, '@', get_container_name(container),
                       ENDC, '$ ', str(command)]))

    # 在容器中执行命令，使用用户和命令前缀，调用容器对象的 `exec_run` 方法来执行命令，并获取执行结果
    command_result = container.exec_run(
        command_prefix + command + "'",
        user=user)
    if not silent and verbose and command_result.exit_code:
        # 如果不是静默模式且开启了详细输出，并且命令执行出错（即退出码不为 0），则打印详细的错误信息，包括命令本身以及退出码
        print(''.join([RED, 'Command: "', command,
                       '" exited with error: ', str(command_result.exit_code),
                       ENDC]))
        print('Error:')
    if not silent:
        # 如果不是静默模式，打印命令输出内容，先对输出内容进行解码并去除两端空白字符，然后判断是否有内容可打印（避免空输出的情况）
        out = command_result.output.decode().strip()
        if out:
            print(out)
    if not ignore_error and command_result.exit_code:
        # 如果不忽略错误且命令执行出错（退出码不为 0），直接退出整个程序，避免继续执行可能出现错误的后续逻辑
        exit(1)
    return command_result


def get_file_paths(container, path, user="root",
                   absolute_path=True, hidden_files=True, verbose=False):
    """
    获取指定容器内指定路径下的文件列表，可根据参数设置是否包含隐藏文件以及返回的路径是否为绝对路径等。

    Args:
        container: 目标容器对象，从中获取文件列表信息。
        path: 要查找文件的路径字符串，指定在容器内的文件查找位置。
        user (str, optional): 在容器内执行查找命令所使用的用户，默认为 "root"。
        absolute_path (bool, optional): 如果设置为 `True`，返回的文件路径为绝对路径；若设置为 `False`，则返回相对路径，默认为 `True`。
        hidden_files (bool, optional): 如果设置为 `True`，查找结果会包含隐藏文件（以点开头的文件）；若设置为 `False`，则不包含隐藏文件，默认为 `True`。
        verbose (bool, optional): 如果设置为 `True`，在查找过程中会打印更多详细信息，如找到的文件列表等，默认为 `False`。

    Returns:
        一个包含文件路径的列表，每个元素是一个字符串，表示在容器内查找到的文件路径。如果查找失败（命令执行出错）且没有开启详细输出，会返回空列表。
    """
    # 定义初始的 `ls` 命令，可根据后续参数进行相应修改，用于在容器内查找文件
    command = "ls "
    if hidden_files:
        # 如果需要包含隐藏文件，给 `ls` 命令添加 `-a` 参数，使其能列出包括隐藏文件在内的所有文件
        command += "-a "
    if absolute_path:
        # 如果需要获取绝对路径，给 `ls` 命令添加 `-d` 参数，确保返回的是文件的绝对路径
        command += "-d "
    # 执行命令获取文件列表，调用 `exec_command` 函数在容器内执行 `ls` 命令，并传入相应参数，获取命令执行结果
    result = exec_command(container, command + path, user=user, silent=True)
    if result.exit_code:
        if verbose:
            # 如果命令执行出错且开启了详细输出，打印提示信息，表明在指定路径下没有找到文件
            print(RED + "No files found in " + path + ENDC)
        return []
    # 将命令输出按行分割并过滤空行，得到文件列表，对命令执行结果的输出内容进行处理，将其按换行符分割成单个文件路径，并去除空字符串元素
    file_list = [x for x in result.output.decode('utf-8').split('\n') if x]
    if verbose:
        # 如果开启了详细输出，打印找到的文件列表信息，方便查看查找结果
        print("Found files: " + str(file_list))
    return file_list


def extract_files(container, file_list, out_path):
    """
    从容器中提取指定的文件列表到指定的输出路径下，过程涉及文件的复制、压缩解压以及临时文件清理等操作。

    Args:
        container: 文件所在的容器对象，从中获取文件数据。
        file_list: 要提取的文件路径列表，每个元素是容器内的一个文件路径字符串。
        out_path: 文件要提取到的目标输出路径字符串，指定在本地的存放位置。
    """
    # 遍历文件列表中的每个文件，依次进行提取操作
    for file in file_list:
        # 打印正在复制的文件和目标路径信息，方便在执行过程中查看文件提取的进度和相关情况
        print('Copying "' + file + '" to ' + out_path)
        # 从容器中获取文件的存档流和元数据，通过容器对象的相关方法获取文件的存档数据，用于后续的保存和解压操作
        strm, _ = container.get_archive(file)
        # 以二进制写入模式打开文件 `result.tar.gz`，在指定的输出路径下创建该临时文件，用于存储从容器中获取的存档数据
        f = open("%s/result.tar.gz" % out_path, "wb")
        # 将存档流中的数据写入文件，循环读取存档流中的数据块，并逐个写入到临时文件中，完成文件数据的复制
        for d in strm:
            f.write(d)
        # 关闭文件，确保数据写入完成后正确关闭文件资源，避免数据丢失或文件损坏等问题
        f.close()
        # 打开生成的 `tar.gz` 文件，使用 `tarfile` 模块以读取模式打开刚刚创建并写入数据的 `tar.gz` 文件，准备进行解压操作
        pw_tar = tarfile.TarFile("%s/result.tar.gz" % out_path)
        # 解压文件到指定的输出路径，将 `tar.gz` 文件中的所有文件和目录解压到目标输出路径下，完成文件提取到本地的操作
        pw_tar.extractall(out_path)
        # 删除生成的临时 `tar.gz` 文件，清理临时文件，释放磁盘空间，避免不必要的文件残留
        os.remove("%s/result.tar.gz" % out_path)
