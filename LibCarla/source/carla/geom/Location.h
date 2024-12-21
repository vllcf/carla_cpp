// Copyright (c) 2017 Computer Vision Center (CVC) at the Universitat Autonoma
// de Barcelona (UAB).
//
// 位置类
// 
// This work is licensed under the terms of the MIT license.
// For a copy, see <https://opensource.org/licenses/MIT>.

#pragma once // 这是一个预处理指令，作用是确保该头文件在整个编译过程中只会被包含一次，
// 避免因多次包含同一头文件而导致的重复定义等编译错误。

#include "carla/geom/Vector3D.h" // 包含名为"carla/geom/Vector3D.h"的头文件，通常这个头文件中会定义三维向量相关的结构体、类或者函数等，
// 可能是用于表示空间中的向量信息，是当前代码实现功能所依赖的外部声明所在的头文件之一，
// 这里的位置类可能会基于三维向量的相关概念来构建其功能。
#include "carla/geom/Vector3DInt.h" // 包含名为"carla/geom/Vector3DInt.h"的头文件，推测里面定义了整数类型的三维向量相关内容，
// 可能用于在某些特定场景下（比如涉及到坐标的整数表示等情况）与位置相关的操作，同样是当前代码依赖的外部声明所在的头文件
#include "carla/geom/Math.h"

#ifdef LIBCARLA_INCLUDED_FROM_UE4
#include <compiler/enable-ue4-macros.h>
#include "Math/Vector.h"
#include <compiler/disable-ue4-macros.h>
#endif // LIBCARLA_INCLUDED_FROM_UE4

namespace carla {
namespace geom {

  class Location : public Vector3D {
  public:

    // =========================================================================
    // -- 构造函数 -------------------------------------------------------------
    // =========================================================================

    Location() = default;

    using Vector3D::Vector3D; // 这行代码使用了"using"声明，它将"Vector3D"类的构造函数引入到"Location"类中，
    // 使得"Location"类可以使用"Vector3D"类的构造函数来进行对象的初始化，方便复用已有的构造逻辑。

    Location(const Vector3D &rhs) : Vector3D(rhs) {} // 这是一个拷贝构造函数，它接受一个"Vector3D"类型的参数"rhs"，通过调用基类（"Vector3D"）的拷贝构造函数，
    // 将传入的"rhs"对象的内容复制到当前正在创建的"Location"类对象中，实现了从"Vector3D"类型对象到"Location"类对象的初始化。

    Location(const Vector3DInt &rhs) :
        Vector3D(static_cast<float>(rhs.x),
                 static_cast<float>(rhs.y),
                 static_cast<float>(rhs.z)) {}

    // =========================================================================
    // -- 其他方法 --------------------------------------------------------------
    // =========================================================================

    auto DistanceSquared(const Location &loc) const {
      return Math::DistanceSquared(*this, loc);
    }

    auto Distance(const Location &loc) const {
      return Math::Distance(*this, loc);
    }

    // =========================================================================
    // -- 算术运算符 ------------------------------------------------------------
    // =========================================================================

    Location &operator+=(const Location &rhs) {
      static_cast<Vector3D &>(*this) += rhs;
      return *this;
    }

    friend Location operator+(Location lhs, const Location &rhs) {
      lhs += rhs;
      return lhs;
    }

    Location &operator-=(const Location &rhs) {
      static_cast<Vector3D &>(*this) -= rhs;
      return *this;
    }

    friend Location operator-(Location lhs, const Location &rhs) {
      lhs -= rhs;
      return lhs;
    }

    // =========================================================================
    // -- 比较运算符 ------------------------------------------------------------
    // =========================================================================

    // 等于
    bool operator==(const Location &rhs) const {
      return static_cast<const Vector3D &>(*this) == rhs;
    }

    // 不等于
    bool operator!=(const Location &rhs) const {
      return !(*this == rhs);
    }

    // =========================================================================
    // -- 转换为 UE4 类型 -------------------------------------------------------
    // =========================================================================

#ifdef LIBCARLA_INCLUDED_FROM_UE4

    Location(const FVector &vector) // 从厘米到米（乘以0.01）。
      : Location(1e-2f * vector.X, 1e-2f * vector.Y, 1e-2f * vector.Z) {}

    operator FVector() const {
      return FVector{1e2f * x, 1e2f * y, 1e2f * z}; // 从米到厘米（乘以100）。
    }

#endif // LIBCARLA_INCLUDED_FROM_UE4
  };

} // namespace geom
} // namespace carla
