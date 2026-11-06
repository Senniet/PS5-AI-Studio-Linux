#include <c10/core/Scalar.h>
#include <ATen/core/TensorBody.h>
#include <type_traits>

namespace at {
namespace {
void check_type(const TensorBase& tensor, ScalarType type, const char* type_name) {
  TORCH_CHECK(
      tensor.scalar_type() == type ||
          (isQIntType(tensor.scalar_type()) && toUnderlying(tensor.scalar_type()) == type),
      "expected scalar type ", type_name, " but found ", tensor.scalar_type());
}
} // namespace

#define DEFINE_LEGACY_CONST_DATA_PTR(T, name)                              \
  template <>                                                              \
  TORCH_API const T* TensorBase::const_data_ptr<T>() const {               \
    check_type(*this, ScalarType::name, #name);                            \
    return this->unsafeGetTensorImpl()->data_ptr_impl<T>();                \
  }                                                                        \
  template <>                                                              \
  TORCH_API const std::remove_const_t<T>*                                  \
  TensorBase::const_data_ptr<const T>() const {                            \
    check_type(*this, ScalarType::name, #name);                            \
    return this->unsafeGetTensorImpl()->data_ptr_impl<std::remove_const_t<T>>(); \
  }

AT_FORALL_SCALAR_TYPES_WITH_COMPLEX(DEFINE_LEGACY_CONST_DATA_PTR)
AT_FORALL_QINT_TYPES(DEFINE_LEGACY_CONST_DATA_PTR)
DEFINE_LEGACY_CONST_DATA_PTR(uint16_t, UInt16)
DEFINE_LEGACY_CONST_DATA_PTR(uint32_t, UInt32)
DEFINE_LEGACY_CONST_DATA_PTR(uint64_t, UInt64)
#undef DEFINE_LEGACY_CONST_DATA_PTR
} // namespace at
