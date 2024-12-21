// Copyright (c) 2017 Computer Vision Center (CVC) at the Universitat Autonoma
// de Barcelona (UAB).
//
// This work is licensed under the terms of the MIT license.
// For a copy, see <https://opensource.org/licenses/MIT>.

#include "carla/geom/Math.h"
#include "carla/geom/Rotation.h"

namespace carla {
namespace geom {

  // Math 类的成员函数 GetVectorAngle，用于计算两个三维向量 a 和 b 之间的夹角（以弧度为单位）。
  // 它通过向量点积公式计算夹角的余弦值（Dot(a, b) / (a.Length() * b.Length())）
  // 然后使用 std::acos 函数（反余弦函数）将余弦值转换为对应的夹角弧度值并返回。
  double Math::GetVectorAngle(const Vector3D &a, const Vector3D &b) {
    return std::acos(Dot(a, b) / (a.Length() * b.Length()));
  }

  // Math 类的成员函数 DistanceSegmentToPoint，用于计算点到线段的距离相关信息。
  // 参数 p 表示要计算距离的点，v 和 w 表示线段的两个端点。
  // 返回一个 std::pair<float, float>，第一个元素表示点在线段上的投影点对应的参数值（范围在 [0, 1]，0 表示投影在线段起点，1 表示投影在线段终点），
  // 第二个元素表示点到投影点的距离（二维平面上的距离）。
  std::pair<float, float> Math::DistanceSegmentToPoint(
      const Vector3D &p,
      const Vector3D &v,
      const Vector3D &w) {
    // 先计算线段 vw 在二维平面上的长度的平方（l2），通过调用 DistanceSquared2D 函数（应该是计算二维平面两点距离平方的函数）。
    const float l2 = DistanceSquared2D(v, w);
    // 再计算线段 vw 在二维平面上的实际长度（l），通过对长度平方取平方根得到。
    const float l = std::sqrt(l2);
    // 如果线段长度的平方为 0，说明线段长度为 0，即 v 和 w 重合，此时返回参数值为 0，距离为点 p 到重合点（v 或 w）的二维距离。
    if (l2 == 0.0f) {
      return std::make_pair(0.0f, Distance2D(v, p));
    }
    // 计算点 p 与线段起点 v 的向量和线段 vw 的向量的二维点积（dot_p_w），通过调用 Dot2D 函数（二维向量点积函数）。
    const float dot_p_w = Dot2D(p - v, w - v);
    // 计算点 p 在线段 vw 上投影对应的参数值 t，通过将点积除以线段长度的平方，并限制 t 的范围在 [0, 1] 内（通过 Clamp 函数，确保投影点在线段上）。
    const float t = Clamp(dot_p_w / l2);
    // 根据参数值 t 计算投影点的坐标（projection），通过线段起点 v 加上 t 倍的线段向量（w - v）得到。
    const Vector3D projection = v + t * (w - v);
    // 返回包含参数值 t 和点 p 到投影点 projection 的二维距离的 std::pair。
    return std::make_pair(t * l, Distance2D(projection, p));
  }

  // Math 类的成员函数 DistanceArcToPoint，用于计算点到圆弧的距离相关信息。
  // 参数 p 是要计算距离的点，start_pos 是圆弧的起始位置，length 是圆弧的长度，heading 是圆弧的起始航向（以弧度为单位），curvature 是圆弧的曲率。
  // 返回一个 std::pair<float, float>，第一个元素表示点沿着圆弧到某个相关位置的距离（可能是到投影点或者起点、终点等相关距离，根据具体情况），
  // 第二个元素表示点到对应位置的二维距离。
  std::pair<float, float> Math::DistanceArcToPoint(
      Vector3D p,
      Vector3D start_pos,
      const float length,
      float heading,       // [弧度]
      float curvature) {

    /// @todo: 因为虚幻的坐标，纠正-y的方法是比较老套的，这个以后必须改掉
    // 以下代码对传入的点和起始位置的 y 坐标取反，同时对航向和曲率也取反，这可能是为了适配某种特定的坐标系统或者算法要求，但此处标注为后续需要改进的地方。
    p.y = -p.y;
    start_pos.y = -start_pos.y;
    heading = -heading;
    curvature = -curvature;

    // 由于此算法适用于正曲率，并且我们仅计算距离，
    // 因此我们可以反转 y 轴（以及曲率和航向），因此如果曲率为负，算法将按预期工作
    if (curvature < 0.0f) {
      p.y = -p.y;
      start_pos.y = -start_pos.y;
      heading = -heading;
      curvature = -curvature;
    }

    // 运输点(transport point)相对于圆弧起始位置的旋转，通过调用 RotatePointOnOrigin2D 函数（应该是在二维平面绕原点旋转点的函数），
    // 将点 p 相对于起始位置 start_pos 进行旋转，旋转角度为 -heading（取反的航向角度）。
    const Vector3D rotated_p(RotatePointOnOrigin2D(p - start_pos, -heading));

    // 根据曲率计算圆弧的半径，半径等于曲率的倒数（这里假设曲率不为 0）。
    const float radius = 1.0f / curvature;
    // 定义圆弧的圆心坐标（在二维平面上，z 坐标为 0），圆心的 y 坐标为半径值。
    const Vector3D circ_center(0.0f, radius, 0.0f);

    // 检查点是否位于圆心，因此我们知道 p 与圆弧上每个可能点的距离都相同，
    // 如果旋转后的点 rotated_p 和圆心 circ_center 坐标相等，说明点就在圆心位置，
    // 此时返回参数值为 0，距离为半径值（因为点在圆心到圆弧上任意点距离就是半径）。
    if (rotated_p == circ_center) {
      return std::make_pair(0.0f, radius);  // std::make_pair 用于创建包含两个元素的 std::pair，元素类型可以不同
    }

    // 使用从圆心到该点的单位向量并乘以半径来找到交点位置，
    // 先计算 rotated_p 相对于圆心 circ_center 的向量，然后将其转换为单位向量，再乘以半径得到交点坐标 intersection。
    const Vector3D intersection = ((rotated_p - circ_center).MakeUnitVector() * radius) + circ_center;

    // 使用弧长来计算最后一个点的角度，根据圆的周长公式（circumference = 2 * PI * r）以及弧长与角度的关系（last_point_angle = (length / circumference) * 2 * PI），
    // 化简得到 last_point_angle = length / radius，这里计算出圆弧最后一个点对应的角度（以弧度为单位）。
    const float last_point_angle = length / radius;

    constexpr float pi_half = Pi<float>() / 2.0f;

    // 相对于圆心移动该点，并找到该点与 rad 中坐标中心之间的角度，
    // 通过 std::atan2 函数（根据坐标计算角度的函数）计算交点 intersection 相对于圆心（坐标中心）的角度，
    // 先计算 y 坐标差值和 x 坐标差值对应的角度，再加上 pi_half（可能是为了调整到特定的角度参考系）。
    float angle = std::atan2(intersection.y - radius, intersection.x) + pi_half;

    // 如果计算出的角度小于 0，将其加上 2 * PI（弧度制下一圈的角度），确保角度在 [0, 2 * PI) 范围内，符合后续判断逻辑。
    if (angle < 0.0f) {
      angle += Pi<float>() * 2.0f;
    }

    // 查看角度是否在 0 和 last_point_angle 之间，这里通过 DEBUG_ASSERT 进行断言检查（可能在调试版本中进行条件检查，如果不满足会触发调试中断等行为，发布版本可能会忽略），
    // 确保角度值符合预期范围。
    DEBUG_ASSERT(angle >= 0.0f);
    if (angle <= last_point_angle) {
      return std::make_pair(
          angle * radius,
          Distance2D(intersection, rotated_p));
    }

    // 找到距离交叉点最近的点、起点或终点，
    // 先计算点 rotated_p 到起点（坐标原点，这里用 Vector3D() 表示）的二维距离（start_dist），通过调用 Distance2D 函数。
    const float start_dist = Distance2D(Vector3D(), rotated_p);

    // 根据圆弧最后一个点的角度计算出最后一个点的坐标（end_pos），通过三角函数计算其在二维平面上的 x 和 y 坐标（基于半径和角度），z 坐标为 0。
    const Vector3D end_pos(
        radius * std::cos(last_point_angle - pi_half),
        radius * std::sin(last_point_angle - pi_half) + circ_center.y,
        0.0f);
    // 计算点 rotated_p 到最后一个点 end_pos 的二维距离（end_dist）。
    const float end_dist = Distance2D(end_pos, rotated_p);
    // 根据起点和终点距离 rotated_p 的远近，返回相应的距离信息，
    // 如果起点距离更近，返回参数值为 0，距离为起点到 rotated_p 的距离；如果终点距离更近，返回参数值为圆弧长度 length，距离为终点到 rotated_p 的距离。
    return (start_dist < end_dist)?
        std::make_pair(0.0f, start_dist) :
        std::make_pair(length, end_dist);
  }

  // Math 类的成员函数 RotatePointOnOrigin2D，用于在二维平面上将点 p 绕原点旋转指定的角度 angle（以弧度为单位）。
  // 返回旋转后的点坐标，通过二维旋转矩阵的计算方式（x' = x * cos(angle) - y * sin(angle)，y' = x * sin(angle) + y * cos(angle)）计算新的 x 和 y 坐标，z 坐标保持为 0。
  Vector3D Math::RotatePointOnOrigin2D(Vector3D p, float angle) {
    const float s = std::sin(angle);
    const float c = std::cos(angle);
    return Vector3D(p.x * c - p.y * s, p.x * s + p.y * c, 0.0f);
  }

  // Math 类的成员函数 GetForwardVector，用于根据给定的旋转信息 rotation 获取对应的前向向量（在三维空间中）。
  // 它先将旋转信息中的俯仰角（pitch）、偏航角（yaw）转换为弧度制（通过 ToRadians 函数，应该是角度转弧度的函数），
  // 然后根据三角函数关系计算前向向量的 x、y、z 坐标分量，返回表示前向向量的 Vector3D 对象。
  Vector3D Math::GetForwardVector(const Rotation &rotation) {
    const float cp = std::cos(ToRadians(rotation.pitch));
    const float sp = std::sin(ToRadians(rotation.pitch));
    const float cy = std::cos(ToRadians(rotation.yaw));
    const float sy = std::sin(ToRadians(rotation.yaw));
    return {cy * cp, sy * cp, sp};
  }

  // Math 类的成员函数 GetRightVector，用于根据给定的旋转信息 rotation 获取对应的右向向量（在三维空间中）。
  // 同样先将旋转信息中的横滚角（roll）、偏航角（yaw）、俯仰角（pitch）转换为弧度制，
  // 然后依据复杂的三角函数组合计算右向向量的 x、y、z 坐标分量，返回表示右向向量的 Vector3D 对象。
  Vector3D Math::GetRightVector(const Rotation &rotation) {
    const float cy = std::cos(ToRadians(rotation.yaw));
    const float sy = std::sin(ToRadians(rotation.yaw));
    const float cr = std::cos(ToRadians(rotation.roll));
    const float sr = std::sin(ToRadians(rotation.roll));
    const float cp = std::cos(ToRadians(rotation.pitch));
    const float sp = std::sin(ToRadians(rotation.pitch));
    return {
         cy * sp * sr - sy * cr,
         sy * sp * sr + cy * cr,
        -cp * sr};
  }

  // Math 类的成员函数 GetUpVector，用于根据给定的旋转信息 rotation 获取对应的上向向量（在三维空间中）。
  // 也是先将相关角度转换为弧度制，再通过一系列三角函数运算计算上向向量的 x、y、z 坐标分量，返回表示上向向量的 Vector3D 对象。
  Vector3D Math::GetUpVector(const Rotation &rotation) {
    const float cy = std::cos(ToRadians(rotation.yaw));
    const float sy = std::sin(ToRadians(rotation.yaw));
    const float cr = std::cos(ToRadians(rotation.roll));
    const float sr = std::sin(ToRadians(rotation.roll));
    const float cp = std::cos(ToRadians(rotation.pitch));
    const float sp = std::sin(ToRadians(rotation.pitch));
    return {
        -cy * sp * cr - sy * sr,
        -sy * sp * cr + cy * sr,
        cp * cr};
  }

  // Math 类的成员函数 GenerateRange，用于生成一个整数范围的向量。
  // 参数 a 和 b 表示范围的起始和结束值，根据 a 和 b 的大小关系，通过循环将范围内的整数依次添加到 result 向量中。
  // 如果 a < b，就从 a 开始递增到 b，将每个整数 push_back 到 result 向量；如果 a >= b，则从 a 开始递减到 b，同样将每个整数添加到 result 向量。
  // 最后返回包含指定整数范围的 std::vector<int> 类型的向量 result。
  std::vector<int> Math::GenerateRange(int a, int b) {
    std::vector<int> result;
    if (a < b) {
      for(int i = a; i <= b; ++i) {
        result.push_back(i);
      }
    } else {
      for(int i = a; i >= b; --i) {
        result.push_back(i);
      }
    }
    return result;
  }

} // namespace geom
} // namespace carla
