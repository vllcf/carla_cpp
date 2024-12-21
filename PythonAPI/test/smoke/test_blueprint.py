
# Copyright (c) 2019 Computer Vision Center (CVC) at the Universitat Autonoma de
# Barcelona (UAB).
#
# This work is licensed under the terms of the MIT license.
# For a copy, see <https://opensource.org/licenses/MIT>.

import re

from. import SmokeTest


class TestBlueprintLibrary(SmokeTest):
    def test_blueprint_ids(self):
        # 打印测试方法名称
        print("TestBlueprintLibrary.test_blueprint_ids")
        # 获取 Carla 世界的蓝图库
        library = self.client.get_world().get_blueprint_library()
        # 检查蓝图库是否不为空，使用列表推导式生成列表并转换为布尔值，若不为空则为 True
        self.assertTrue([x for x in library])
        # 检查过滤出的以 sensor.* 开头的蓝图是否不为空
        self.assertTrue([x for x in library.filter('sensor.*')])
        # 检查过滤出的以 static.* 开头的蓝图是否不为空
        self.assertTrue([x for x in library.filter('static.*')])
        # 检查过滤出的以 vehicle.* 开头的蓝图是否不为空
        self.assertTrue([x for x in library.filter('vehicle.*')])
        # 检查过滤出的以 walker.* 开头的蓝图是否不为空
        self.assertTrue([x for x in library.filter('walker.*')])
        # 创建一个正则表达式对象，用于匹配至少一个非空字符，接着一个点，再接着至少一个非空字符，再接着一个点，最后接着至少一个非空字符
        rgx = re.compile(r'\S+\.\S+\.\S+')
        # 遍历蓝图库中的每个蓝图
        for bp in library:
            # 检查蓝图的 id 是否匹配上述正则表达式
            self.assertTrue(rgx.match(bp.id))
        # 创建一个正则表达式对象，用于匹配以 vehicle. 开头，接着一个点，再接着至少一个非空字符，再接着一个点，最后接着至少一个非空字符
        rgx = re.compile(r'(vehicle)\.\S+\.\S+')
        # 遍历过滤出的以 vehicle.* 开头的蓝图
        for bp in library.filter('vehicle.*'):
            # 检查这些蓝图的 id 是否匹配上述正则表达式
            self.assertTrue(rgx.match(bp.id))
